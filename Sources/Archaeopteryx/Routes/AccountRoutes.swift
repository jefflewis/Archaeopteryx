import Foundation
import Hummingbird
import Logging
import OAuthService
import ATProtoAdapter
import MastodonModels
import IDMapping
import TranslationLayer
import CacheLayer
import ArchaeopteryxCore
import Dependencies

// MARK: - Account Routes

/// Account management routes for Mastodon API compatibility
///
/// This struct uses dependency injection via the @Dependency macro to access
/// the ATProtoClient. This makes the routes fully testable by allowing mock
/// implementations to be injected during tests.
struct AccountRoutes: Sendable {
    let oauthService: OAuthService
    @Dependency(\.atProtoClient) var atprotoClient
    let idMapping: IDMappingService
    let translator: ProfileTranslator
    let logger: Logger

    /// Add account routes to the router
    ///
    /// Note: ATProtoClient is injected via @Dependency, not passed as a parameter.
    /// This enables full testability by allowing mock implementations during tests.
    static func addRoutes(
        to router: Router<some RequestContext>,
        oauthService: OAuthService,
        idMapping: IDMappingService,
        translator: ProfileTranslator,
        logger: Logger
    ) {
        let routes = AccountRoutes(
            oauthService: oauthService,
            idMapping: idMapping,
            translator: translator,
            logger: logger
        )

        // GET /api/v1/accounts/verify_credentials - Get current user
        router.get("/api/v1/accounts/verify_credentials") { request, context -> Response in
            try await routes.verifyCredentials(request: request, context: context)
        }

        // GET /api/v1/accounts/lookup - Lookup account by handle
        router.get("/api/v1/accounts/lookup") { request, context -> Response in
            try await routes.lookupAccount(request: request, context: context)
        }

        // GET /api/v1/accounts/:id - Get account by ID
        router.get("/api/v1/accounts/{id}") { request, context -> Response in
            try await routes.getAccount(request: request, context: context)
        }

        // GET /api/v1/accounts/search - Search for accounts
        router.get("/api/v1/accounts/search") { request, context -> Response in
            try await routes.searchAccounts(request: request, context: context)
        }

        // GET /api/v1/accounts/:id/statuses - Get account statuses
        router.get("/api/v1/accounts/{id}/statuses") { request, context -> Response in
            try await routes.getAccountStatuses(request: request, context: context)
        }

        // GET /api/v1/accounts/:id/followers - Get account followers
        router.get("/api/v1/accounts/{id}/followers") { request, context -> Response in
            try await routes.getAccountFollowers(request: request, context: context)
        }

        // GET /api/v1/accounts/:id/following - Get accounts user is following
        router.get("/api/v1/accounts/{id}/following") { request, context -> Response in
            try await routes.getAccountFollowing(request: request, context: context)
        }

        // POST /api/v1/accounts/:id/follow - Follow an account
        router.post("/api/v1/accounts/{id}/follow") { request, context -> Response in
            try await routes.followAccount(request: request, context: context)
        }

        // POST /api/v1/accounts/:id/unfollow - Unfollow an account
        router.post("/api/v1/accounts/{id}/unfollow") { request, context -> Response in
            try await routes.unfollowAccount(request: request, context: context)
        }

        // GET /api/v1/accounts/relationships - Get relationships with multiple accounts
        router.get("/api/v1/accounts/relationships") { request, context -> Response in
            try await routes.getRelationships(request: request, context: context)
        }
    }

    /// Convenience method for tests
    ///
    /// Sets up all dependencies except ATProtoClient, which should be mocked
    /// using withDependencies { } in tests.
    static func addRoutes(
        to router: Router<some RequestContext>,
        oauthService: OAuthService
    ) {
        let logger = Logger(label: "archaeopteryx.accounts")
        let cache = InMemoryCache()
        let generator = SnowflakeIDGenerator()
        let idMapping = IDMappingService(cache: cache, generator: generator)
        let facetProcessor = FacetProcessor()
        let translator = ProfileTranslator(idMapping: idMapping, facetProcessor: facetProcessor)

        addRoutes(
            to: router,
            oauthService: oauthService,
            idMapping: idMapping,
            translator: translator,
            logger: logger
        )
    }

    // MARK: - Route Handlers

    /// GET /api/v1/accounts/verify_credentials - Return the authenticated user
    func verifyCredentials(request: Request, context: some RequestContext) async throws -> Response {
        // Extract and validate bearer token
        guard let authHeader = request.headers[.authorization],
              authHeader.hasPrefix("Bearer "),
              let token = authHeader.dropFirst("Bearer ".count).trimmingCharacters(in: .whitespaces).nilIfEmpty else {
            logger.warning("Missing or invalid authorization header")
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        do {
            // Validate token and get DID
            let did = try await oauthService.validateToken(token)

            // Get profile from AT Proto
            let profile = try await atprotoClient.getProfile(did)

            // Translate to Mastodon account
            let account = try await translator.translate(profile)

            logger.info("Verified credentials", metadata: ["did": "\(did)", "handle": "\(profile.handle)"])
            return try jsonResponse(account, status: .ok)
        } catch {
            logger.warning("Credentials verification failed", metadata: ["error": "\(error)"])
            return try errorResponse(error: "unauthorized", description: "Invalid or expired token", status: .unauthorized)
        }
    }

    /// GET /api/v1/accounts/lookup - Lookup account by handle (acct parameter)
    func lookupAccount(request: Request, context: some RequestContext) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Extract acct parameter
        let uri = request.uri
        let queryString = uri.query ?? ""
        let queryItems = parseQueryString(queryString)

        guard let acct = queryItems["acct"] else {
            logger.warning("Missing acct parameter in lookup request")
            return try errorResponse(error: "invalid_request", description: "Missing acct parameter", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Get profile from AT Proto (acct might be a handle)
            let profile = try await atprotoClient.getProfile(acct)

            // Translate to Mastodon account
            let account = try await translator.translate(profile)

            logger.info("Account lookup successful", metadata: ["acct": "\(acct)"])
            return try jsonResponse(account, status: .ok)
        } catch {
            logger.warning("Account lookup failed", metadata: ["acct": "\(acct)", "error": "\(error)"])
            return try errorResponse(error: "not_found", description: "Account not found", status: .notFound)
        }
    }

    /// GET /api/v1/accounts/:id - Get account by Snowflake ID
    func getAccount(request: Request, context: some RequestContext) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Extract ID from path
        guard let idString = context.parameters.get("id", as: String.self),
              let snowflakeID = Int64(idString) else {
            logger.warning("Invalid account ID in request")
            return try errorResponse(error: "invalid_request", description: "Invalid account ID", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Map snowflake ID to DID
            guard let did = await idMapping.getDID(forSnowflakeID: snowflakeID) else {
                logger.warning("No DID found for snowflake ID", metadata: ["snowflake_id": "\(snowflakeID)"])
                return try errorResponse(error: "not_found", description: "Account not found", status: .notFound)
            }

            // Get profile from AT Proto
            let profile = try await atprotoClient.getProfile(did)

            // Translate to Mastodon account
            let account = try await translator.translate(profile)

            logger.info("Account retrieved", metadata: ["id": "\(snowflakeID)", "did": "\(did)"])
            return try jsonResponse(account, status: .ok)
        } catch {
            logger.warning("Get account failed", metadata: ["id": "\(snowflakeID)", "error": "\(error)"])
            return try errorResponse(error: "not_found", description: "Account not found", status: .notFound)
        }
    }


    /// GET /api/v1/accounts/search - Search for accounts
    func searchAccounts(request: Request, context: some RequestContext) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Extract query parameter
        let uri = request.uri
        let queryString = uri.query ?? ""
        let queryItems = parseQueryString(queryString)

        guard let query = queryItems["q"] else {
            logger.warning("Missing query parameter in search request")
            return try errorResponse(error: "invalid_request", description: "Missing q parameter", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Search for actors
            let limit = Int(queryItems["limit"] ?? "40") ?? 40
            let response = try await atprotoClient.searchActors(query, min(limit, 40), nil)

            // Translate results
            let accounts = try await withThrowingTaskGroup(of: MastodonAccount?.self) { group in
                for actor in response.actors {
                    group.addTask {
                        try? await self.translator.translate(actor)
                    }
                }

                var results: [MastodonAccount] = []
                for try await account in group {
                    if let account = account {
                        results.append(account)
                    }
                }
                return results
            }

            logger.info("Account search successful", metadata: ["query": "\(query)", "results": "\(accounts.count)"])
            return try jsonResponse(accounts, status: .ok)
        } catch {
            logger.warning("Account search failed", metadata: ["query": "\(query)", "error": "\(error)"])
            return try errorResponse(error: "not_implemented", description: "Search not yet implemented", status: .notImplemented)
        }
    }

    /// GET /api/v1/accounts/:id/statuses - Get account statuses
    func getAccountStatuses(request: Request, context: some RequestContext) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Extract ID from path
        guard let idString = context.parameters.get("id", as: String.self),
              let snowflakeID = Int64(idString) else {
            logger.warning("Invalid account ID in request")
            return try errorResponse(error: "invalid_request", description: "Invalid account ID", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Map snowflake ID to DID
            guard let did = await idMapping.getDID(forSnowflakeID: snowflakeID) else {
                logger.warning("No DID found for snowflake ID", metadata: ["snowflake_id": "\(snowflakeID)"])
                return try errorResponse(error: "not_found", description: "Account not found", status: .notFound)
            }

            // Get author feed (posts) - for now return empty array
            _ = try await atprotoClient.getAuthorFeed(did, 20, nil, nil)

            logger.info("Account statuses retrieved (empty)", metadata: ["id": "\(snowflakeID)", "did": "\(did)"])
            // Return empty array until Status routes are implemented
            return try jsonResponse([] as [String], status: .ok)
        } catch {
            logger.warning("Get account statuses failed", metadata: ["id": "\(snowflakeID)", "error": "\(error)"])
            return try errorResponse(error: "not_found", description: "Posts not available", status: .notFound)
        }
    }

    /// GET /api/v1/accounts/:id/followers - Get account followers
    func getAccountFollowers(request: Request, context: some RequestContext) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Extract ID from path
        guard let idString = context.parameters.get("id", as: String.self),
              let snowflakeID = Int64(idString) else {
            logger.warning("Invalid account ID in request")
            return try errorResponse(error: "invalid_request", description: "Invalid account ID", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Map snowflake ID to DID
            guard let did = await idMapping.getDID(forSnowflakeID: snowflakeID) else {
                logger.warning("No DID found for snowflake ID", metadata: ["snowflake_id": "\(snowflakeID)"])
                return try errorResponse(error: "not_found", description: "Account not found", status: .notFound)
            }

            // Get followers
            let uri = request.uri
            let queryString = uri.query ?? ""
            let queryItems = parseQueryString(queryString)
            let limit = Int(queryItems["limit"] ?? "40") ?? 40

            let response = try await atprotoClient.getFollowers(did, min(limit, 80), nil)

            // Translate followers to accounts
            let accounts = try await withThrowingTaskGroup(of: MastodonAccount?.self) { group in
                for follower in response.followers {
                    group.addTask {
                        try? await self.translator.translate(follower)
                    }
                }

                var results: [MastodonAccount] = []
                for try await account in group {
                    if let account = account {
                        results.append(account)
                    }
                }
                return results
            }

            logger.info("Account followers retrieved", metadata: ["id": "\(snowflakeID)", "count": "\(accounts.count)"])
            return try jsonResponse(accounts, status: .ok)
        } catch {
            logger.warning("Get followers failed", metadata: ["id": "\(snowflakeID)", "error": "\(error)"])
            return try errorResponse(error: "not_found", description: "Could not retrieve followers", status: .notFound)
        }
    }

    /// GET /api/v1/accounts/:id/following - Get accounts user is following
    func getAccountFollowing(request: Request, context: some RequestContext) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Extract ID from path
        guard let idString = context.parameters.get("id", as: String.self),
              let snowflakeID = Int64(idString) else {
            logger.warning("Invalid account ID in request")
            return try errorResponse(error: "invalid_request", description: "Invalid account ID", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Map snowflake ID to DID
            guard let did = await idMapping.getDID(forSnowflakeID: snowflakeID) else {
                logger.warning("No DID found for snowflake ID", metadata: ["snowflake_id": "\(snowflakeID)"])
                return try errorResponse(error: "not_found", description: "Account not found", status: .notFound)
            }

            // Get following
            let uri = request.uri
            let queryString = uri.query ?? ""
            let queryItems = parseQueryString(queryString)
            let limit = Int(queryItems["limit"] ?? "40") ?? 40

            let response = try await atprotoClient.getFollowing(did, min(limit, 80), nil)

            // Translate following to accounts
            let accounts = try await withThrowingTaskGroup(of: MastodonAccount?.self) { group in
                for following in response.following {
                    group.addTask {
                        try? await self.translator.translate(following)
                    }
                }

                var results: [MastodonAccount] = []
                for try await account in group {
                    if let account = account {
                        results.append(account)
                    }
                }
                return results
            }

            logger.info("Account following retrieved", metadata: ["id": "\(snowflakeID)", "count": "\(accounts.count)"])
            return try jsonResponse(accounts, status: .ok)
        } catch {
            logger.warning("Get following failed", metadata: ["id": "\(snowflakeID)", "error": "\(error)"])
            return try errorResponse(error: "not_found", description: "Could not retrieve following", status: .notFound)
        }
    }

    /// POST /api/v1/accounts/:id/follow - Follow an account
    func followAccount(request: Request, context: some RequestContext) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Extract ID from path
        guard let idString = context.parameters.get("id", as: String.self),
              let snowflakeID = Int64(idString) else {
            logger.warning("Invalid account ID in request")
            return try errorResponse(error: "invalid_request", description: "Invalid account ID", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Map snowflake ID to DID
            guard let did = await idMapping.getDID(forSnowflakeID: snowflakeID) else {
                logger.warning("No DID found for snowflake ID", metadata: ["snowflake_id": "\(snowflakeID)"])
                return try errorResponse(error: "not_found", description: "Account not found", status: .notFound)
            }

            // Follow user
            _ = try await atprotoClient.followUser(did)

            // Return relationship
            let relationship = MastodonRelationship(
                id: "\(snowflakeID)",
                following: true,
                showingReblogs: true,
                notifying: false,
                followedBy: false,
                blocking: false,
                blockedBy: false,
                muting: false,
                mutingNotifications: false,
                requested: false,
                domainBlocking: false,
                endorsed: false,
                note: ""
            )

            logger.info("Account followed", metadata: ["id": "\(snowflakeID)", "did": "\(did)"])
            return try jsonResponse(relationship, status: .ok)
        } catch ATProtoError.notImplemented {
            logger.warning("Follow not implemented", metadata: ["id": "\(snowflakeID)"])
            return try errorResponse(error: "not_implemented", description: "Follow not yet implemented", status: .notImplemented)
        } catch {
            logger.warning("Follow account failed", metadata: ["id": "\(snowflakeID)", "error": "\(error)"])
            return try errorResponse(error: "internal_error", description: "Could not follow account", status: .internalServerError)
        }
    }

    /// POST /api/v1/accounts/:id/unfollow - Unfollow an account
    func unfollowAccount(request: Request, context: some RequestContext) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Extract ID from path
        guard let idString = context.parameters.get("id", as: String.self),
              let snowflakeID = Int64(idString) else {
            logger.warning("Invalid account ID in request")
            return try errorResponse(error: "invalid_request", description: "Invalid account ID", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Map snowflake ID to DID
            guard let did = await idMapping.getDID(forSnowflakeID: snowflakeID) else {
                logger.warning("No DID found for snowflake ID", metadata: ["snowflake_id": "\(snowflakeID)"])
                return try errorResponse(error: "not_found", description: "Account not found", status: .notFound)
            }

            // Unfollow user (requires follow record URI, which we don't have yet)
            // For now, throw notImplemented
            throw ATProtoError.notImplemented(feature: "unfollowUser")

            // Return relationship
            let relationship = MastodonRelationship(
                id: "\(snowflakeID)",
                following: false,
                showingReblogs: false,
                notifying: false,
                followedBy: false,
                blocking: false,
                blockedBy: false,
                muting: false,
                mutingNotifications: false,
                requested: false,
                domainBlocking: false,
                endorsed: false,
                note: ""
            )

            logger.info("Account unfollowed", metadata: ["id": "\(snowflakeID)", "did": "\(did)"])
            return try jsonResponse(relationship, status: .ok)
        } catch ATProtoError.notImplemented {
            logger.warning("Unfollow not implemented", metadata: ["id": "\(snowflakeID)"])
            return try errorResponse(error: "not_implemented", description: "Unfollow not yet implemented", status: .notImplemented)
        } catch {
            logger.warning("Unfollow account failed", metadata: ["id": "\(snowflakeID)", "error": "\(error)"])
            return try errorResponse(error: "internal_error", description: "Could not unfollow account", status: .internalServerError)
        }
    }

    /// GET /api/v1/accounts/relationships - Get relationships with multiple accounts
    func getRelationships(request: Request, context: some RequestContext) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Extract id[] parameters
        let uri = request.uri
        let queryString = uri.query ?? ""

        // Parse id[] parameters
        let pairs = queryString.split(separator: "&")
        var ids: [Int64] = []
        for pair in pairs {
            if pair.hasPrefix("id[]=") || pair.hasPrefix("id%5B%5D=") {
                let value = String(pair.split(separator: "=", maxSplits: 1).last ?? "")
                if let id = Int64(value) {
                    ids.append(id)
                }
            }
        }

        guard !ids.isEmpty else {
            logger.warning("Missing id[] parameters in relationships request")
            return try errorResponse(error: "invalid_request", description: "Missing id[] parameters", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // For now, return basic relationships (not following)
            let relationships = ids.map { id in
                MastodonRelationship(
                    id: "\(id)",
                    following: false,
                    showingReblogs: false,
                    notifying: false,
                    followedBy: false,
                    blocking: false,
                    blockedBy: false,
                    muting: false,
                    mutingNotifications: false,
                    requested: false,
                    domainBlocking: false,
                    endorsed: false,
                    note: ""
                )
            }

            logger.info("Relationships retrieved", metadata: ["count": "\(relationships.count)"])
            return try jsonResponse(relationships, status: .ok)
        } catch {
            logger.warning("Get relationships failed", metadata: ["error": "\(error)"])
            return try errorResponse(error: "internal_error", description: "Could not retrieve relationships", status: .internalServerError)
        }
    }

    // MARK: - Helper Methods

    /// Extract bearer token from request
    private func extractBearerToken(from request: Request) async throws -> String? {
        guard let authHeader = request.headers[.authorization],
              authHeader.hasPrefix("Bearer ") else {
            return nil
        }

        let token = authHeader.dropFirst("Bearer ".count).trimmingCharacters(in: .whitespaces)
        return token.isEmpty ? nil : token
    }

    /// Create a JSON response with proper content type
    private func jsonResponse<T: Encodable>(_ value: T, status: HTTPResponse.Status) throws -> Response {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)

        var response = Response(status: status)
        response.headers[.contentType] = "application/json"
        response.body = .init(byteBuffer: ByteBuffer(data: data))
        return response
    }

    /// Create an error response
    private func errorResponse(error: String, description: String, status: HTTPResponse.Status) throws -> Response {
        let errorResp: [String: String] = [
            "error": error,
            "error_description": description
        ]
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
                // Skip array parameters for this simple parser
                if !key.hasSuffix("[]") {
                    result[key] = value
                }
            }
        }

        return result
    }

}

// MARK: - String Extension

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
