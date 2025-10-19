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
        // Log the content type for debugging
        let contentType = request.headers[.contentType] ?? "not set"
        logger.info("App registration request", metadata: ["content_type": "\(contentType)"])

        // Collect the body ONCE (can't read it twice)
        let bodyBuffer = try await request.body.collect(upTo: .max)

        guard let bodyString = bodyBuffer.getString(at: 0, length: bodyBuffer.readableBytes) else {
            let response = try errorResponse(error: "invalid_request", description: "Invalid body encoding", status: .badRequest)
            var modifiedResponse = response
            modifiedResponse.status = .init(code: 422, reasonPhrase: "Unprocessable Entity")
            return modifiedResponse
        }

        logger.info("Request body", metadata: ["body": .string(bodyString)])

        let body: AppRequest

        // Determine content type
        if let ct = request.headers[.contentType], ct.contains("multipart/form-data") {
            // Parse multipart/form-data
            do {
                let params = try parseMultipartFormData(bodyString, contentType: ct)
                let jsonData = try JSONSerialization.data(withJSONObject: params)
                let decoder = JSONDecoder()
                body = try decoder.decode(AppRequest.self, from: jsonData)
            } catch {
                logger.warning("Failed to decode multipart form data", metadata: ["error": "\(error)"])
                let response = try errorResponse(error: "invalid_request", description: "Invalid multipart data", status: .badRequest)
                var modifiedResponse = response
                modifiedResponse.status = .init(code: 422, reasonPhrase: "Unprocessable Entity")
                return modifiedResponse
            }
        } else if let ct = request.headers[.contentType], ct.contains("application/x-www-form-urlencoded") {
            // Parse URL-encoded form data
            do {
                let params = parseQueryString(bodyString)
                let jsonData = try JSONSerialization.data(withJSONObject: params)
                let decoder = JSONDecoder()
                body = try decoder.decode(AppRequest.self, from: jsonData)
            } catch {
                logger.warning("Failed to decode form-urlencoded data", metadata: ["error": "\(error)"])
                let response = try errorResponse(error: "invalid_request", description: "Invalid form data", status: .badRequest)
                var modifiedResponse = response
                modifiedResponse.status = .init(code: 422, reasonPhrase: "Unprocessable Entity")
                return modifiedResponse
            }
        } else {
            // Try JSON
            do {
                guard let jsonData = bodyString.data(using: .utf8) else {
                    throw ArchaeopteryxError.validationFailed(field: "body", message: "Invalid UTF-8 encoding")
                }
                let decoder = JSONDecoder()
                body = try decoder.decode(AppRequest.self, from: jsonData)
            } catch {
                logger.warning("Failed to decode JSON data", metadata: ["error": "\(error)"])
                let response = try errorResponse(error: "invalid_request", description: "Invalid JSON", status: .badRequest)
                var modifiedResponse = response
                modifiedResponse.status = .init(code: 422, reasonPhrase: "Unprocessable Entity")
                return modifiedResponse
            }
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
        // Collect the body ONCE
        let bodyBuffer = try await request.body.collect(upTo: .max)

        guard let bodyString = bodyBuffer.getString(at: 0, length: bodyBuffer.readableBytes) else {
            return try errorResponse(error: "invalid_request", description: "Invalid body encoding", status: .badRequest)
        }

        let body: TokenRequest

        // Log body for debugging
        logger.info("Token request body", metadata: ["body": .string(bodyString), "content_type": .string(request.headers[.contentType] ?? "not set")])

        // Determine content type and decode accordingly
        if let ct = request.headers[.contentType], ct.contains("multipart/form-data") {
            // Parse multipart/form-data
            do {
                let params = try parseMultipartFormData(bodyString, contentType: ct)
                let jsonData = try JSONSerialization.data(withJSONObject: params)
                let decoder = JSONDecoder()
                body = try decoder.decode(TokenRequest.self, from: jsonData)
            } catch {
                logger.warning("Failed to decode multipart form data for token request", metadata: ["error": "\(error)"])
                return try errorResponse(error: "invalid_request", description: "Invalid multipart data", status: .badRequest)
            }
        } else if let ct = request.headers[.contentType], ct.contains("application/x-www-form-urlencoded") {
            // Parse URL-encoded form data
            do {
                let params = parseQueryString(bodyString)
                let jsonData = try JSONSerialization.data(withJSONObject: params)
                let decoder = JSONDecoder()
                body = try decoder.decode(TokenRequest.self, from: jsonData)
            } catch {
                logger.warning("Failed to decode form-urlencoded data for token request", metadata: ["error": "\(error)"])
                return try errorResponse(error: "invalid_request", description: "Invalid form data", status: .badRequest)
            }
        } else {
            // Try JSON
            do {
                guard let jsonData = bodyString.data(using: .utf8) else {
                    throw ArchaeopteryxError.validationFailed(field: "body", message: "Invalid UTF-8 encoding")
                }
                let decoder = JSONDecoder()
                body = try decoder.decode(TokenRequest.self, from: jsonData)
            } catch {
                logger.warning("Failed to decode token request", metadata: ["error": "\(error)"])
                return try errorResponse(error: "invalid_request", description: "Invalid request body", status: .badRequest)
            }
        }

        logger.info("Token request decoded", metadata: ["grant_type": .string(body.grantType), "client_id": .string(body.clientId)])

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

            case "client_credentials":
                // Client credentials grant flow (app-level access)
                let token = try await oauthService.clientCredentialsGrant(
                    clientId: body.clientId,
                    clientSecret: body.clientSecret,
                    scope: body.scope ?? "read"
                )

                logger.info("Client credentials grant successful", metadata: ["client_id": "\(body.clientId)"])
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
        let responseType = queryItems["response_type"] ?? "code"

        // Return HTML login page
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Archaeopteryx - Authorize Access</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    padding: 20px;
                }
                .container {
                    background: white;
                    border-radius: 16px;
                    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                    max-width: 450px;
                    width: 100%;
                    padding: 40px;
                }
                h1 {
                    color: #333;
                    font-size: 28px;
                    margin-bottom: 8px;
                    text-align: center;
                }
                .subtitle {
                    color: #666;
                    font-size: 14px;
                    text-align: center;
                    margin-bottom: 32px;
                }
                .info-box {
                    background: #f7f9fc;
                    border-radius: 8px;
                    padding: 16px;
                    margin-bottom: 24px;
                    border-left: 4px solid #667eea;
                }
                .info-box p {
                    color: #555;
                    font-size: 14px;
                    line-height: 1.6;
                }
                .form-group {
                    margin-bottom: 20px;
                }
                label {
                    display: block;
                    color: #333;
                    font-weight: 500;
                    margin-bottom: 8px;
                    font-size: 14px;
                }
                input[type="text"],
                input[type="password"] {
                    width: 100%;
                    padding: 12px 16px;
                    border: 2px solid #e1e8ed;
                    border-radius: 8px;
                    font-size: 15px;
                    transition: border-color 0.3s;
                }
                input[type="text"]:focus,
                input[type="password"]:focus {
                    outline: none;
                    border-color: #667eea;
                }
                button {
                    width: 100%;
                    padding: 14px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    border: none;
                    border-radius: 8px;
                    font-size: 16px;
                    font-weight: 600;
                    cursor: pointer;
                    transition: transform 0.2s, box-shadow 0.2s;
                }
                button:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4);
                }
                button:active {
                    transform: translateY(0);
                }
                .error {
                    background: #fee;
                    border-left-color: #e53e3e;
                    color: #c53030;
                    padding: 12px;
                    border-radius: 8px;
                    margin-bottom: 20px;
                    display: none;
                    font-size: 14px;
                }
                .footer {
                    text-align: center;
                    margin-top: 24px;
                    color: #999;
                    font-size: 13px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>Archaeopteryx</h1>
                <p class="subtitle">Connect to Bluesky via Mastodon API</p>

                <div class="info-box">
                    <p>An application wants to access your Bluesky account. Enter your Bluesky credentials to authorize access.</p>
                </div>

                <div id="error" class="error"></div>

                <form id="authForm" action="/oauth/authorize" method="POST">
                    <input type="hidden" name="client_id" value="\(clientId)">
                    <input type="hidden" name="redirect_uri" value="\(redirectUri)">
                    <input type="hidden" name="scope" value="\(scope)">
                    <input type="hidden" name="response_type" value="\(responseType)">

                    <div class="form-group">
                        <label for="handle">Bluesky Handle</label>
                        <input
                            type="text"
                            id="handle"
                            name="handle"
                            placeholder="user.bsky.social"
                            required
                            autocomplete="username"
                        >
                    </div>

                    <div class="form-group">
                        <label for="password">App Password</label>
                        <input
                            type="password"
                            id="password"
                            name="password"
                            placeholder="Enter your Bluesky app password"
                            required
                            autocomplete="current-password"
                        >
                    </div>

                    <button type="submit">Authorize</button>
                </form>

                <div class="footer">
                    <p>Your credentials are sent directly to Bluesky and are not stored by Archaeopteryx.</p>
                </div>
            </div>

            <script>
                document.getElementById('authForm').addEventListener('submit', async (e) => {
                    e.preventDefault();
                    const form = e.target;
                    const formData = new FormData(form);
                    const errorDiv = document.getElementById('error');

                    try {
                        const response = await fetch('/oauth/authorize', {
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/x-www-form-urlencoded',
                            },
                            body: new URLSearchParams(formData)
                        });

                        const data = await response.json();

                        if (response.ok) {
                            if (data.redirect_url) {
                                window.location.href = data.redirect_url;
                            } else if (data.code) {
                                // Out-of-band flow - show the code
                                alert('Authorization Code: ' + data.code);
                            }
                        } else {
                            errorDiv.textContent = data.error_description || data.error || 'Authorization failed';
                            errorDiv.style.display = 'block';
                        }
                    } catch (error) {
                        errorDiv.textContent = 'Network error. Please try again.';
                        errorDiv.style.display = 'block';
                    }
                });
            </script>
        </body>
        </html>
        """

        var response = Response(status: .ok)
        response.headers[.contentType] = "text/html; charset=utf-8"
        response.body = .init(byteBuffer: ByteBuffer(string: html))
        return response
    }

    /// POST /oauth/authorize - Handle authorization (simplified for Bluesky)
    func postAuthorize(request: Request, context: some RequestContext) async throws -> Response {
        let body: AuthorizeRequest
        do {
            // Try form-urlencoded first, then JSON
            if let contentType = request.headers[.contentType],
               contentType.contains("application/x-www-form-urlencoded") {
                body = try await decodeFormURLEncoded(AuthorizeRequest.self, from: request)
            } else {
                body = try await request.decode(as: AuthorizeRequest.self, context: context)
            }
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

    /// Parse multipart/form-data into dictionary
    private func parseMultipartFormData(_ body: String, contentType: String) throws -> [String: String] {
        // Extract boundary from Content-Type header
        // Format: "multipart/form-data; boundary=_X__X__X___X_XXXX_____X_X__X_X_XX_"
        guard let boundaryRange = contentType.range(of: "boundary=") else {
            throw ArchaeopteryxError.validationFailed(field: "content-type", message: "Missing boundary in multipart/form-data")
        }

        let boundary = String(contentType[boundaryRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        var result: [String: String] = [:]

        // Split by boundary
        let parts = body.components(separatedBy: "--\(boundary)")

        for part in parts {
            // Skip empty parts and the final closing boundary
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "--" {
                continue
            }

            // Parse each part: headers + blank line + value
            let lines = trimmed.components(separatedBy: "\r\n")
            var fieldName: String?
            var value: String?

            // Find the Content-Disposition header to get the field name
            for (index, line) in lines.enumerated() {
                if line.hasPrefix("Content-Disposition:") {
                    // Extract name from: Content-Disposition: form-data; name="client_name"
                    if let nameRange = line.range(of: "name=\"") {
                        let afterName = line[nameRange.upperBound...]
                        if let endQuote = afterName.firstIndex(of: "\"") {
                            fieldName = String(afterName[..<endQuote])
                        }
                    }
                }

                // Value starts after the first blank line (after headers)
                if line.isEmpty && index < lines.count - 1 {
                    // Join remaining lines as the value
                    value = lines[(index + 1)...].joined(separator: "\r\n")
                    break
                }
            }

            if let name = fieldName, let val = value {
                result[name] = val
            }
        }

        return result
    }

    /// Decode form-urlencoded request body
    private func decodeFormURLEncoded<T: Decodable>(_ type: T.Type, from request: Request) async throws -> T {
        // Collect body bytes
        let bodyBuffer = try await request.body.collect(upTo: .max)

        guard let bodyString = bodyBuffer.getString(at: 0, length: bodyBuffer.readableBytes) else {
            throw ArchaeopteryxError.validationFailed(field: "body", message: "Invalid body encoding")
        }

        let params = parseQueryString(bodyString)

        // Convert to JSON and decode
        // Note: Don't use convertFromSnakeCase here because the models already have CodingKeys
        let jsonData = try JSONSerialization.data(withJSONObject: params)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: jsonData)
    }
}
