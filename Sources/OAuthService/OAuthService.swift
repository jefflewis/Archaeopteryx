import Foundation
import CacheLayer
import MastodonModels
import ATProtoAdapter
import ArchaeopteryxCore
import Crypto
import ATProtoKit

/// OAuth 2.0 service for Mastodon API compatibility
public actor OAuthService {
    private let cache: any CacheService
    private let atprotoServiceURL: String

    // Cache key prefixes
    private let appPrefix = "oauth:app:"
    private let codePrefix = "oauth:code:"
    private let tokenPrefix = "oauth:token:"
    private let sessionPrefix = "session:"

    public init(cache: any CacheService, atprotoServiceURL: String = "https://bsky.social") {
        self.cache = cache
        self.atprotoServiceURL = atprotoServiceURL
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

        // Verify credentials with Bluesky (test connection)
        let atproto = await ATProtoKit(pdsURL: atprotoServiceURL)
        do {
            // Test the credentials by creating a session
            _ = try await atproto.createSession(with: handle, and: password)
        } catch {
            // Invalid credentials
            throw ArchaeopteryxError.unauthorized
        }

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

        // Create actual Bluesky session
        let atproto = await ATProtoKit(pdsURL: atprotoServiceURL)

        do {
            let session = try await atproto.createSession(with: authCode.handle, and: authCode.password)

            // Create session data
            let sessionData = BlueskySessionData(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                did: session.did,
                handle: session.handle,
                email: session.email,
                createdAt: Date()
            )

            // Create access token with session data
            let token = try await createAccessToken(
                did: session.did,
                handle: session.handle,
                sessionData: sessionData,
                scope: authCode.scope
            )

            return token
        } catch {
            // Map ATProtoKit errors to our error types
            throw ArchaeopteryxError.unauthorized
        }
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

        // Create actual Bluesky session
        let atproto = await ATProtoKit(pdsURL: atprotoServiceURL)

        do {
            let session = try await atproto.createSession(with: username, and: password)

            // Create session data
            let sessionData = BlueskySessionData(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                did: session.did,
                handle: session.handle,
                email: session.email,
                createdAt: Date()
            )

            // Create access token with session data
            let token = try await createAccessToken(
                did: session.did,
                handle: session.handle,
                sessionData: sessionData,
                scope: scope
            )

            return token
        } catch {
            // Map ATProtoKit errors to our error types
            throw ArchaeopteryxError.unauthorized
        }
    }

    // MARK: - Token Management

    /// Validate access token and return user context with session
    public func validateToken(_ accessToken: String) async throws -> UserContext {
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

        return UserContext(
            did: tokenData.did,
            handle: tokenData.handle,
            sessionData: tokenData.sessionData
        )
    }

    /// Refresh an AT Protocol session using the refresh token
    /// Returns updated UserContext with new access token
    public func refreshSession(accessToken: String) async throws -> UserContext {
        // Get current token data
        guard let tokenData: TokenData = try await cache.get("\(tokenPrefix)\(accessToken)") else {
            throw ArchaeopteryxError.unauthorized
        }

        // Use refresh token to get new session
        let atproto = await ATProtoKit(pdsURL: atprotoServiceURL)

        do {
            // ATProtoKit refreshSession method
            let refreshedSession = try await atproto.refreshSession(refreshToken: tokenData.sessionData.refreshToken)

            // Create updated session data
            let newSessionData = BlueskySessionData(
                accessToken: refreshedSession.accessToken,
                refreshToken: refreshedSession.refreshToken,
                did: refreshedSession.did,
                handle: refreshedSession.handle,
                email: tokenData.sessionData.email,
                createdAt: Date()
            )

            // Update token data in cache
            let updatedTokenData = TokenData(
                did: tokenData.did,
                handle: tokenData.handle,
                sessionData: newSessionData,
                scope: tokenData.scope,
                tokenType: tokenData.tokenType,
                createdAt: tokenData.createdAt,
                expiresIn: tokenData.expiresIn
            )

            try await cache.set("\(tokenPrefix)\(accessToken)", value: updatedTokenData, ttl: tokenData.expiresIn)

            // Also update session by DID
            try await cache.set("\(sessionPrefix)\(tokenData.did)", value: newSessionData, ttl: tokenData.expiresIn)

            return UserContext(
                did: tokenData.did,
                handle: tokenData.handle,
                sessionData: newSessionData
            )
        } catch {
            // If refresh fails, the session is invalid
            throw ArchaeopteryxError.unauthorized
        }
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
    private func createAccessToken(
        did: String,
        handle: String,
        sessionData: BlueskySessionData,
        scope: String
    ) async throws -> OAuthToken {
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

        // Store token data in cache (Valkey/Redis)
        let tokenData = TokenData(
            did: did,
            handle: handle,
            sessionData: sessionData,
            scope: scope,
            tokenType: "Bearer",
            createdAt: createdAt,
            expiresIn: expiresIn
        )

        try await cache.set("\(tokenPrefix)\(accessToken)", value: tokenData, ttl: expiresIn)

        // Also store session by DID for direct lookup
        try await cache.set("\(sessionPrefix)\(did)", value: sessionData, ttl: expiresIn)

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

/// Internal token data stored in cache (Valkey/Redis)
/// Made internal (not private) for testing purposes
struct TokenData: Codable, Sendable {
    /// User's AT Protocol DID
    let did: String

    /// User's Bluesky handle
    let handle: String

    /// Bluesky session data for API calls
    let sessionData: BlueskySessionData

    /// OAuth scope
    let scope: String

    /// Token type (always "Bearer")
    let tokenType: String

    /// When token was created (Unix timestamp)
    let createdAt: Int

    /// Token expiration in seconds
    let expiresIn: Int
}
