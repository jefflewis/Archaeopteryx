import Foundation
import CacheLayer
import MastodonModels
import ATProtoAdapter
import ArchaeopteryxCore
import Crypto

/// OAuth 2.0 service for Mastodon API compatibility
public actor OAuthService {
    private let cache: any CacheService

    // Cache key prefixes
    private let appPrefix = "oauth:app:"
    private let codePrefix = "oauth:code:"
    private let tokenPrefix = "oauth:token:"

    public init(cache: any CacheService) {
        self.cache = cache
    }

    // MARK: - Application Registration

    /// Register a new OAuth application
    public func registerApplication(
        clientName: String,
        redirectUris: String,
        scopes: String,
        website: String?
    ) async throws -> OAuthApplication {
        // Validate inputs
        guard !clientName.isEmpty else {
            throw ArchaeopteryxError.validationFailed(
                field: "client_name",
                message: "Client name cannot be empty"
            )
        }

        guard !redirectUris.isEmpty else {
            throw ArchaeopteryxError.validationFailed(
                field: "redirect_uris",
                message: "Redirect URI cannot be empty"
            )
        }

        // Generate unique IDs
        let id = UUID().uuidString
        let clientId = generateSecureToken()
        let clientSecret = generateSecureToken()

        let app = OAuthApplication(
            id: id,
            name: clientName,
            website: website,
            redirectUri: redirectUris,
            clientId: clientId,
            clientSecret: clientSecret,
            vapidKey: nil
        )

        // Store in cache (no expiration)
        try await cache.set("\(appPrefix)\(clientId)", value: app, ttl: nil)

        return app
    }

    /// Get application by client ID
    public func getApplication(clientId: String) async throws -> OAuthApplication {
        guard let app: OAuthApplication = try await cache.get("\(appPrefix)\(clientId)") else {
            throw ArchaeopteryxError.notFound(resource: "OAuth application")
        }
        return app
    }

    // MARK: - Authorization Code Flow

    /// Generate authorization code for a user
    public func generateAuthorizationCode(
        clientId: String,
        redirectUri: String,
        scope: String,
        handle: String,
        password: String
    ) async throws -> String {
        // Verify client exists
        let app = try await getApplication(clientId: clientId)

        // Verify redirect URI matches
        guard app.redirectUri == redirectUri else {
            throw ArchaeopteryxError.validationFailed(
                field: "redirect_uri",
                message: "Redirect URI does not match registered URI"
            )
        }

        // TODO: In production, verify credentials with Bluesky
        // For now, we'll assume they're valid for testing

        // Generate authorization code
        let code = generateSecureToken()

        let authCode = AuthorizationCode(
            code: code,
            clientId: clientId,
            redirectUri: redirectUri,
            scope: scope,
            handle: handle,
            password: password,
            createdAt: Date(),
            used: false
        )

        // Store code with 10-minute expiration
        try await cache.set("\(codePrefix)\(code)", value: authCode, ttl: 600)

        return code
    }

    /// Exchange authorization code for access token
    public func exchangeAuthorizationCode(
        code: String,
        clientId: String,
        clientSecret: String,
        redirectUri: String
    ) async throws -> OAuthToken {
        // Verify client credentials
        let app = try await getApplication(clientId: clientId)
        guard app.clientSecret == clientSecret else {
            throw ArchaeopteryxError.unauthorized
        }

        // Retrieve authorization code
        guard var authCode: AuthorizationCode = try await cache.get("\(codePrefix)\(code)") else {
            throw ArchaeopteryxError.notFound(resource: "Authorization code")
        }

        // Check if code is expired
        guard !authCode.isExpired() else {
            throw ArchaeopteryxError.unauthorized
        }

        // Check if code has been used
        guard !authCode.used else {
            throw ArchaeopteryxError.unauthorized
        }

        // Verify client ID matches
        guard authCode.clientId == clientId else {
            throw ArchaeopteryxError.unauthorized
        }

        // Mark code as used
        authCode.used = true
        try await cache.set("\(codePrefix)\(code)", value: authCode, ttl: 60)

        // Create access token
        let token = try await createAccessToken(
            handle: authCode.handle,
            scope: authCode.scope
        )

        return token
    }

    // MARK: - Password Grant

    /// Direct password grant (creates session and returns token)
    public func passwordGrant(
        clientId: String,
        clientSecret: String,
        scope: String,
        username: String,
        password: String
    ) async throws -> OAuthToken {
        // Verify client credentials
        let app = try await getApplication(clientId: clientId)
        guard app.clientSecret == clientSecret else {
            throw ArchaeopteryxError.unauthorized
        }

        // TODO: In production, create actual Bluesky session
        // For now, we'll create a token for testing

        let token = try await createAccessToken(
            handle: username,
            scope: scope
        )

        return token
    }

    // MARK: - Token Management

    /// Validate access token and return associated handle
    public func validateToken(_ accessToken: String) async throws -> String {
        guard let tokenData: TokenData = try await cache.get("\(tokenPrefix)\(accessToken)") else {
            throw ArchaeopteryxError.unauthorized
        }

        // Check if token is expired
        let token = OAuthToken(
            accessToken: accessToken,
            tokenType: tokenData.tokenType,
            scope: tokenData.scope,
            createdAt: tokenData.createdAt,
            expiresIn: tokenData.expiresIn
        )

        guard !token.isExpired() else {
            throw ArchaeopteryxError.unauthorized
        }

        return tokenData.handle
    }

    /// Revoke an access token
    public func revokeToken(_ accessToken: String) async throws {
        // Delete from cache (no error if doesn't exist)
        try await cache.delete("\(tokenPrefix)\(accessToken)")
    }

    // MARK: - Scope Validation

    /// Validate and parse scope string
    nonisolated public func validateScopes(_ scopeString: String) throws -> Set<OAuthScope> {
        // Empty scope defaults to read
        if scopeString.isEmpty {
            return [.read]
        }

        let scopes = OAuthScope.parse(scopeString)

        // Check if any scopes are invalid
        let scopeStrings = scopeString.split(separator: " ").map { String($0) }
        let validScopeStrings = scopes.map { $0.rawValue }

        for scopeStr in scopeStrings {
            if !validScopeStrings.contains(scopeStr) {
                throw ArchaeopteryxError.validationFailed(
                    field: "scope",
                    message: "Invalid scope: \(scopeStr)"
                )
            }
        }

        return Set(scopes)
    }

    // MARK: - Private Helpers

    /// Create an access token for a user
    private func createAccessToken(handle: String, scope: String) async throws -> OAuthToken {
        let accessToken = generateSecureToken()
        let createdAt = Int(Date().timeIntervalSince1970)
        let expiresIn = 7 * 24 * 60 * 60 // 7 days

        let token = OAuthToken(
            accessToken: accessToken,
            tokenType: "Bearer",
            scope: scope,
            createdAt: createdAt,
            expiresIn: expiresIn
        )

        // Store token data in cache
        let tokenData = TokenData(
            handle: handle,
            scope: scope,
            tokenType: "Bearer",
            createdAt: createdAt,
            expiresIn: expiresIn
        )

        try await cache.set("\(tokenPrefix)\(accessToken)", value: tokenData, ttl: expiresIn)

        return token
    }

    /// Generate a cryptographically secure token
    private func generateSecureToken() -> String {
        let bytes = SymmetricKey(size: .bits256)
        return Data(bytes.withUnsafeBytes { Data($0) })
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Internal Models

/// Internal token data stored in cache
private struct TokenData: Codable, Sendable {
    let handle: String
    let scope: String
    let tokenType: String
    let createdAt: Int
    let expiresIn: Int
}
