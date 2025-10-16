import Foundation
import Hummingbird
import Logging
import OAuthService
import MastodonModels
import CacheLayer
import ArchaeopteryxCore

// MARK: - Request/Response DTOs

/// App registration request
struct AppRequest: Decodable {
    let clientName: String
    let redirectUris: String
    let scopes: String?
    let website: String?

    enum CodingKeys: String, CodingKey {
        case clientName = "client_name"
        case redirectUris = "redirect_uris"
        case scopes
        case website
    }
}

/// Token request
struct TokenRequest: Decodable {
    let grantType: String
    let code: String?
    let clientId: String
    let clientSecret: String
    let redirectUri: String?
    let username: String?
    let password: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case code
        case clientId = "client_id"
        case clientSecret = "client_secret"
        case redirectUri = "redirect_uri"
        case username
        case password
        case scope
    }
}

/// Revoke request
struct RevokeRequest: Decodable {
    let token: String
}

/// Authorization request
struct AuthorizeRequest: Decodable {
    let clientId: String
    let redirectUri: String
    let scope: String?
    let handle: String
    let password: String

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case redirectUri = "redirect_uri"
        case scope
        case handle
        case password
    }
}

/// OAuth error response
struct OAuthErrorResponse: Codable {
    let error: String
    let errorDescription: String

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - OAuth Routes

/// OAuth 2.0 routes for Mastodon API compatibility
struct OAuthRoutes {
    let oauthService: OAuthService
    let logger: Logger

    /// Add OAuth routes to the router
    static func addRoutes(to router: Router<some RequestContext>, oauthService: OAuthService, logger: Logger) {
        let routes = OAuthRoutes(oauthService: oauthService, logger: logger)

        // POST /api/v1/apps - Register OAuth application
        router.post("/api/v1/apps") { request, context -> Response in
            try await routes.registerApp(request: request, context: context)
        }

        // POST /oauth/token - Exchange code for token or password grant
        router.post("/oauth/token") { request, context -> Response in
            try await routes.token(request: request, context: context)
        }

        // POST /oauth/revoke - Revoke access token
        router.post("/oauth/revoke") { request, context -> Response in
            try await routes.revoke(request: request, context: context)
        }

        // GET /oauth/authorize - Authorization page (for browser flow)
        router.get("/oauth/authorize") { request, context -> Response in
            try await routes.getAuthorize(request: request, context: context)
        }

        // POST /oauth/authorize - Handle authorization (simplified for Bluesky)
        router.post("/oauth/authorize") { request, context -> Response in
            try await routes.postAuthorize(request: request, context: context)
        }
    }

    // MARK: - Route Handlers

    /// POST /api/v1/apps - Register a new OAuth application
    func registerApp(request: Request, context: some RequestContext) async throws -> Response {
        let body: AppRequest
        do {
            body = try await request.decode(as: AppRequest.self, context: context)
        } catch {
            logger.warning("Failed to decode app registration request", metadata: ["error": "\(error)"])
            let response = try errorResponse(error: "invalid_request", description: "Invalid request body", status: .badRequest)
            var modifiedResponse = response
            modifiedResponse.status = .init(code: 422, reasonPhrase: "Unprocessable Entity")
            return modifiedResponse
        }

        // Register application
        do {
            let app = try await oauthService.registerApplication(
                clientName: body.clientName,
                redirectUris: body.redirectUris,
                scopes: body.scopes ?? "read",
                website: body.website
            )

            logger.info("Registered OAuth application", metadata: ["client_id": "\(app.clientId)"])

            return try jsonResponse(app, status: .ok)
        } catch let error as ArchaeopteryxError {
            logger.warning("App registration failed", metadata: ["error": "\(error)"])

            switch error {
            case .validationFailed(let field, let message):
                let response = try errorResponse(error: "invalid_request", description: "Validation failed for \(field): \(message)", status: .badRequest)
                var modifiedResponse = response
                modifiedResponse.status = .init(code: 422, reasonPhrase: "Unprocessable Entity")
                return modifiedResponse
            default:
                return try errorResponse(error: "server_error", description: "Internal server error", status: .internalServerError)
            }
        }
    }

    /// POST /oauth/token - Exchange authorization code for access token or password grant
    func token(request: Request, context: some RequestContext) async throws -> Response {
        let body: TokenRequest
        do {
            body = try await request.decode(as: TokenRequest.self, context: context)
        } catch {
            logger.warning("Failed to decode token request", metadata: ["error": "\(error)"])
            return try errorResponse(error: "invalid_request", description: "Invalid request body", status: .badRequest)
        }

        do {
            switch body.grantType {
            case "authorization_code":
                // Exchange authorization code for token
                guard let code = body.code, let redirectUri = body.redirectUri else {
                    return try errorResponse(error: "invalid_request", description: "Missing code or redirect_uri", status: .badRequest)
                }

                let token = try await oauthService.exchangeAuthorizationCode(
                    code: code,
                    clientId: body.clientId,
                    clientSecret: body.clientSecret,
                    redirectUri: redirectUri
                )

                logger.info("Exchanged authorization code for token", metadata: ["client_id": "\(body.clientId)"])
                return try jsonResponse(token, status: .ok)

            case "password":
                // Password grant flow
                guard let username = body.username, let password = body.password else {
                    return try errorResponse(error: "invalid_request", description: "Missing username or password", status: .badRequest)
                }

                let token = try await oauthService.passwordGrant(
                    clientId: body.clientId,
                    clientSecret: body.clientSecret,
                    scope: body.scope ?? "read",
                    username: username,
                    password: password
                )

                logger.info("Password grant successful", metadata: ["client_id": "\(body.clientId)", "username": "\(username)"])
                return try jsonResponse(token, status: .ok)

            default:
                return try errorResponse(error: "unsupported_grant_type", description: "Grant type '\(body.grantType)' is not supported", status: .badRequest)
            }
        } catch let error as ArchaeopteryxError {
            logger.warning("Token request failed", metadata: ["error": "\(error)", "grant_type": "\(body.grantType)"])

            switch error {
            case .unauthorized:
                return try errorResponse(error: "invalid_grant", description: "Authorization grant is invalid or expired", status: .unauthorized)
            case .notFound:
                return try errorResponse(error: "invalid_client", description: "Client authentication failed", status: .unauthorized)
            case .validationFailed(let field, let message):
                return try errorResponse(error: "invalid_request", description: "Validation failed for \(field): \(message)", status: .badRequest)
            default:
                return try errorResponse(error: "server_error", description: "Internal server error", status: .internalServerError)
            }
        }
    }

    /// POST /oauth/revoke - Revoke an access token
    func revoke(request: Request, context: some RequestContext) async throws -> Response {
        let body: RevokeRequest
        do {
            body = try await request.decode(as: RevokeRequest.self, context: context)
        } catch {
            logger.warning("Failed to decode revoke request", metadata: ["error": "\(error)"])
            // Per OAuth spec, revoke should succeed even with invalid request
            return Response(status: .ok)
        }

        do {
            try await oauthService.revokeToken(body.token)
            logger.info("Token revoked", metadata: ["token_prefix": "\(body.token.prefix(8))"])
        } catch {
            // Per OAuth spec, revoke should always return 200, even if token doesn't exist
            logger.debug("Token revocation attempted for non-existent token")
        }

        return Response(status: .ok)
    }

    /// GET /oauth/authorize - Display authorization page
    func getAuthorize(request: Request, context: some RequestContext) async throws -> Response {
        // Extract query parameters
        let uri = request.uri

        // Parse query parameters manually
        let queryString = uri.query ?? ""
        let queryItems = parseQueryString(queryString)

        guard let clientId = queryItems["client_id"],
              let redirectUri = queryItems["redirect_uri"] else {
            return try errorResponse(error: "invalid_request", description: "Missing client_id or redirect_uri", status: .badRequest)
        }

        let scope = queryItems["scope"] ?? "read"

        // For simplicity, return a JSON response that clients can use
        // In a full implementation, this would return HTML
        let authInfo: [String: String] = [
            "client_id": clientId,
            "redirect_uri": redirectUri,
            "scope": scope,
            "message": "Authorization required. Use POST /oauth/authorize with handle and password."
        ]

        return try jsonResponse(authInfo, status: .ok)
    }

    /// POST /oauth/authorize - Handle authorization (simplified for Bluesky)
    func postAuthorize(request: Request, context: some RequestContext) async throws -> Response {
        let body: AuthorizeRequest
        do {
            body = try await request.decode(as: AuthorizeRequest.self, context: context)
        } catch {
            logger.warning("Failed to decode authorize request", metadata: ["error": "\(error)"])
            return try errorResponse(error: "invalid_request", description: "Invalid request body", status: .badRequest)
        }

        do {
            // Generate authorization code
            let code = try await oauthService.generateAuthorizationCode(
                clientId: body.clientId,
                redirectUri: body.redirectUri,
                scope: body.scope ?? "read",
                handle: body.handle,
                password: body.password
            )

            logger.info("Authorization code generated", metadata: ["client_id": "\(body.clientId)", "handle": "\(body.handle)"])

            // For out-of-band redirect URI, return the code directly
            if body.redirectUri == "urn:ietf:wg:oauth:2.0:oob" {
                let response: [String: String] = ["code": code]
                return try jsonResponse(response, status: .ok)
            } else {
                // For other redirect URIs, return a redirect response
                // In a real implementation, this would be an HTTP 302 redirect
                let redirectUrl = "\(body.redirectUri)?code=\(code)"
                let response: [String: String] = ["redirect_url": redirectUrl, "code": code]
                return try jsonResponse(response, status: .ok)
            }
        } catch let error as ArchaeopteryxError {
            logger.warning("Authorization failed", metadata: ["error": "\(error)", "client_id": "\(body.clientId)"])

            switch error {
            case .unauthorized:
                return try errorResponse(error: "access_denied", description: "Invalid credentials", status: .unauthorized)
            case .notFound:
                return try errorResponse(error: "invalid_client", description: "Unknown client", status: .badRequest)
            case .validationFailed(let field, let message):
                return try errorResponse(error: "invalid_request", description: "Validation failed for \(field): \(message)", status: .badRequest)
            default:
                return try errorResponse(error: "server_error", description: "Internal server error", status: .internalServerError)
            }
        }
    }

    // MARK: - Helper Methods

    /// Create a JSON response with proper content type
    private func jsonResponse<T: Encodable>(_ value: T, status: HTTPResponse.Status) throws -> Response {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(value)

        var response = Response(status: status)
        response.headers[.contentType] = "application/json"
        response.body = .init(byteBuffer: ByteBuffer(data: data))
        return response
    }

    /// Create an OAuth error response
    private func errorResponse(error: String, description: String, status: HTTPResponse.Status) throws -> Response {
        let errorResp = OAuthErrorResponse(error: error, errorDescription: description)
        return try jsonResponse(errorResp, status: status)
    }

    /// Parse query string into dictionary
    private func parseQueryString(_ query: String) -> [String: String] {
        var result: [String: String] = [:]

        let pairs = query.split(separator: "&")
        for pair in pairs {
            let components = pair.split(separator: "=", maxSplits: 1)
            if components.count == 2 {
                let key = String(components[0])
                let value = String(components[1]).removingPercentEncoding ?? String(components[1])
                result[key] = value
            }
        }

        return result
    }
}
