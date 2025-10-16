import Foundation
import Hummingbird
import Logging
import ATProtoAdapter
import MastodonModels
import IDMapping
import OAuthService
import TranslationLayer
import CacheLayer
import Dependencies

// MARK: - List Routes

/// List routes for Mastodon API compatibility
///
/// Note: Bluesky doesn't have user-curated lists like Mastodon.
/// For MVP, these routes return empty results. Future versions could map
/// Bluesky custom feeds to Mastodon lists (read-only).
struct ListRoutes {
    let logger: Logger
    @Dependency(\.atProtoClient) var atprotoClient
    let oauthService: OAuthService
    let idMapping: IDMappingService
    let statusTranslator: StatusTranslator
    let cache: CacheService

    /// Add list routes to the router
    static func addRoutes(
        to router: Router<some RequestContext>,
        logger: Logger,
        oauthService: OAuthService,
        idMapping: IDMappingService,
        statusTranslator: StatusTranslator,
        cache: CacheService
    ) {
        let routes = ListRoutes(
            logger: logger,
            oauthService: oauthService,
            idMapping: idMapping,
            statusTranslator: statusTranslator,
            cache: cache
        )

        // GET /api/v1/lists - Get all lists for authenticated user
        router.get("/api/v1/lists") { request, context -> Response in
            try await routes.getLists(request: request, context: context)
        }

        // GET /api/v1/lists/:id - Get a single list
        router.get("/api/v1/lists/:id") { request, context -> Response in
            try await routes.getList(request: request, context: context)
        }

        // GET /api/v1/lists/:id/accounts - Get accounts in a list
        router.get("/api/v1/lists/:id/accounts") { request, context -> Response in
            try await routes.getListAccounts(request: request, context: context)
        }

        // GET /api/v1/timelines/list/:id - Get statuses from list members
        router.get("/api/v1/timelines/list/:id") { request, context -> Response in
            try await routes.getListTimeline(request: request, context: context)
        }
    }

    // MARK: - Route Handlers

    /// GET /api/v1/lists - Get all lists for authenticated user
    /// Returns empty array for MVP since Bluesky doesn't have lists
    func getLists(request: Request, context: some RequestContext) async throws -> Response {
        // Authenticate user
        guard let authHeader = request.headers[.authorization] else {
            return try errorResponse(error: "unauthorized", description: "Missing authorization header", status: .unauthorized)
        }

        guard authHeader.hasPrefix("Bearer ") else {
            return try errorResponse(error: "unauthorized", description: "Invalid authorization format", status: .unauthorized)
        }

        let token = String(authHeader.dropFirst(7))

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // For MVP, return empty array
            // Future: Could fetch and translate Bluesky custom feeds
            let lists: [MastodonList] = []

            logger.info("Returning empty lists (Bluesky doesn't support user-curated lists)")
            return try jsonResponse(lists, status: .ok)

        } catch is OAuthError {
            return try errorResponse(error: "unauthorized", description: "Invalid or expired token", status: .unauthorized)
        } catch {
            logger.error("Error fetching lists: \(error)")
            return try errorResponse(error: "server_error", description: "Failed to fetch lists", status: .internalServerError)
        }
    }

    /// GET /api/v1/lists/:id - Get a single list
    /// Returns 404 for MVP since Bluesky doesn't have lists
    func getList(request: Request, context: some RequestContext) async throws -> Response {
        // Authenticate user
        guard let authHeader = request.headers[.authorization] else {
            return try errorResponse(error: "unauthorized", description: "Missing authorization header", status: .unauthorized)
        }

        guard authHeader.hasPrefix("Bearer ") else {
            return try errorResponse(error: "unauthorized", description: "Invalid authorization format", status: .unauthorized)
        }

        let token = String(authHeader.dropFirst(7))

        // Get list ID from path
        guard let listID = context.parameters.get("id", as: String.self) else {
            return try errorResponse(error: "bad_request", description: "Missing list ID", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Return a generic list to satisfy API compatibility
            // Bluesky doesn't have user-curated lists, but we return a placeholder
            let list = MastodonList(
                id: listID,
                title: "Bluesky Feed",
                repliesPolicy: .list
            )

            logger.info("Returning generic list \(listID) (Bluesky doesn't support user-curated lists)")
            return try jsonResponse(list, status: .ok)

        } catch is OAuthError {
            return try errorResponse(error: "unauthorized", description: "Invalid or expired token", status: .unauthorized)
        } catch {
            logger.error("Error fetching list: \(error)")
            return try errorResponse(error: "server_error", description: "Failed to fetch list", status: .internalServerError)
        }
    }

    /// GET /api/v1/lists/:id/accounts - Get accounts in a list
    /// Returns empty array for MVP since Bluesky doesn't have lists
    func getListAccounts(request: Request, context: some RequestContext) async throws -> Response {
        // Authenticate user
        guard let authHeader = request.headers[.authorization] else {
            return try errorResponse(error: "unauthorized", description: "Missing authorization header", status: .unauthorized)
        }

        guard authHeader.hasPrefix("Bearer ") else {
            return try errorResponse(error: "unauthorized", description: "Invalid authorization format", status: .unauthorized)
        }

        let token = String(authHeader.dropFirst(7))

        // Get list ID from path
        guard let listID = context.parameters.get("id", as: String.self) else {
            return try errorResponse(error: "bad_request", description: "Missing list ID", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // For MVP, return empty array
            // Future: Could return accounts from Bluesky custom feed
            let accounts: [MastodonAccount] = []

            logger.info("Returning empty accounts for list \(listID) (Bluesky doesn't support user-curated lists)")
            return try jsonResponse(accounts, status: .ok)

        } catch is OAuthError {
            return try errorResponse(error: "unauthorized", description: "Invalid or expired token", status: .unauthorized)
        } catch {
            logger.error("Error fetching list accounts: \(error)")
            return try errorResponse(error: "server_error", description: "Failed to fetch list accounts", status: .internalServerError)
        }
    }

    /// GET /api/v1/timelines/list/:id - Get statuses from list members
    /// Returns empty array for MVP since Bluesky doesn't have lists
    func getListTimeline(request: Request, context: some RequestContext) async throws -> Response {
        // Authenticate user
        guard let authHeader = request.headers[.authorization] else {
            return try errorResponse(error: "unauthorized", description: "Missing authorization header", status: .unauthorized)
        }

        guard authHeader.hasPrefix("Bearer ") else {
            return try errorResponse(error: "unauthorized", description: "Invalid authorization format", status: .unauthorized)
        }

        let token = String(authHeader.dropFirst(7))

        // Get list ID from path
        guard let listID = context.parameters.get("id", as: String.self) else {
            return try errorResponse(error: "bad_request", description: "Missing list ID", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Get pagination parameters
            let limit = request.uri.queryParameters.get("limit").flatMap(Int.init) ?? 20
            let actualLimit = min(max(limit, 1), 40)

            // For MVP, return empty array
            // Future: Could fetch posts from Bluesky custom feed
            let statuses: [MastodonStatus] = []

            logger.info("Returning empty timeline for list \(listID) (Bluesky doesn't support user-curated lists)")
            return try jsonResponse(statuses, status: .ok)

        } catch is OAuthError {
            return try errorResponse(error: "unauthorized", description: "Invalid or expired token", status: .unauthorized)
        } catch {
            logger.error("Error fetching list timeline: \(error)")
            return try errorResponse(error: "server_error", description: "Failed to fetch list timeline", status: .internalServerError)
        }
    }

    // MARK: - Helper Methods

    /// Create a JSON response with proper content type
    private func jsonResponse<T: Encodable>(_ value: T, status: HTTPResponse.Status) throws -> Response {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        // Set date encoding strategy
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)

        var response = Response(status: status)
        response.headers[.contentType] = "application/json"
        response.body = .init(byteBuffer: ByteBuffer(data: data))
        return response
    }

    /// Helper to create error response
    private func errorResponse(error: String, description: String, status: HTTPResponse.Status) throws -> Response {
        let errorResp: [String: String] = [
            "error": error,
            "error_description": description
        ]
        return try jsonResponse(errorResp, status: status)
    }
}
