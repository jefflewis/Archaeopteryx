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

// MARK: - Request/Response Models

/// Request for creating a status
struct CreateStatusRequest: Decodable {
    let status: String
    let inReplyToId: String?
    let sensitive: Bool?
    let spoilerText: String?
    let visibility: String?
    let mediaIds: [String]?
}

// MARK: - Status Routes

/// Status management routes for Mastodon API compatibility
struct StatusRoutes: Sendable {
    let oauthService: OAuthService
    @Dependency(\.atProtoClient) var atprotoClient
    let idMapping: IDMappingService
    let statusTranslator: StatusTranslator
    let logger: Logger

    /// Add status routes to the router
    static func addRoutes(
        to router: Router<some RequestContext>,
        oauthService: OAuthService,
        idMapping: IDMappingService,
        statusTranslator: StatusTranslator,
        logger: Logger
    ) {
        let routes = StatusRoutes(
            oauthService: oauthService,
            idMapping: idMapping,
            statusTranslator: statusTranslator,
            logger: logger
        )

        // GET /api/v1/statuses/:id - Get status by ID
        router.get("/api/v1/statuses/{id}") { request, context -> Response in
            try await routes.getStatus(request: request, context: context)
        }

        // POST /api/v1/statuses - Create a new status
        router.post("/api/v1/statuses") { request, context -> Response in
            try await routes.createStatus(request: request, context: context)
        }

        // DELETE /api/v1/statuses/:id - Delete a status
        router.delete("/api/v1/statuses/{id}") { request, context -> Response in
            try await routes.deleteStatus(request: request, context: context)
        }

        // GET /api/v1/statuses/:id/context - Get status context (thread)
        router.get("/api/v1/statuses/{id}/context") { request, context -> Response in
            try await routes.getContext(request: request, context: context)
        }

        // POST /api/v1/statuses/:id/favourite - Favourite a status
        router.post("/api/v1/statuses/{id}/favourite") { request, context -> Response in
            try await routes.favouriteStatus(request: request, context: context)
        }

        // POST /api/v1/statuses/:id/unfavourite - Unfavourite a status
        router.post("/api/v1/statuses/{id}/unfavourite") { request, context -> Response in
            try await routes.unfavouriteStatus(request: request, context: context)
        }

        // POST /api/v1/statuses/:id/reblog - Reblog a status
        router.post("/api/v1/statuses/{id}/reblog") { request, context -> Response in
            try await routes.reblogStatus(request: request, context: context)
        }

        // POST /api/v1/statuses/:id/unreblog - Unreblog a status
        router.post("/api/v1/statuses/{id}/unreblog") { request, context -> Response in
            try await routes.unreblogStatus(request: request, context: context)
        }

        // GET /api/v1/statuses/:id/favourited_by - Get who favourited
        router.get("/api/v1/statuses/{id}/favourited_by") { request, context -> Response in
            try await routes.getFavouritedBy(request: request, context: context)
        }

        // GET /api/v1/statuses/:id/reblogged_by - Get who reblogged
        router.get("/api/v1/statuses/{id}/reblogged_by") { request, context -> Response in
            try await routes.getRebloggedBy(request: request, context: context)
        }
    }

    // MARK: - Route Handlers

    /// GET /api/v1/statuses/:id - Get status by ID
    func getStatus(request: Request, context: some RequestContext) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Extract ID from path
        guard let idString = context.parameters.get("id", as: String.self),
              let snowflakeID = Int64(idString) else {
            logger.warning("Invalid status ID in request")
            return try errorResponse(error: "invalid_request", description: "Invalid status ID", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Map snowflake ID to AT URI
            guard let atURI = await idMapping.getATURI(forSnowflakeID: snowflakeID) else {
                logger.warning("No AT URI found for snowflake ID", metadata: ["snowflake_id": "\(snowflakeID)"])
                return try errorResponse(error: "not_found", description: "Status not found", status: .notFound)
            }

            // Get post from AT Proto
            let post = try await atprotoClient.getPost(atURI)

            // Translate to Mastodon status
            let status = try await statusTranslator.translate(post)

            logger.info("Status retrieved", metadata: ["id": "\(snowflakeID)"])
            return try jsonResponse(status, status: .ok)
        } catch ATProtoError.notImplemented {
            logger.warning("Get status not implemented", metadata: ["id": "\(snowflakeID)"])
            return try errorResponse(error: "not_implemented", description: "Get status not yet implemented", status: .notImplemented)
        } catch {
            logger.warning("Get status failed", metadata: ["id": "\(snowflakeID)", "error": "\(error)"])
            return try errorResponse(error: "not_found", description: "Status not found", status: .notFound)
        }
    }

    /// POST /api/v1/statuses - Create a new status
    func createStatus(request: Request, context: some RequestContext) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Parse request body
        let body = try await request.body.collect(upTo: .max)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let createRequest = try? decoder.decode(CreateStatusRequest.self, from: Data(buffer: body)) else {
            return try errorResponse(error: "invalid_request", description: "Invalid request format", status: .badRequest)
        }

        // Validate status text
        guard !createRequest.status.isEmpty else {
            return try errorResponse(error: "validation_failed", description: "Status text cannot be empty", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Create post on AT Proto
            let post = try await atprotoClient.createPost(
                createRequest.status,
                createRequest.inReplyToId,
                nil,
                nil
            )

            // Translate to Mastodon status
            let status = try await statusTranslator.translate(post)

            logger.info("Status created", metadata: ["id": "\(status.id)"])
            return try jsonResponse(status, status: .ok)
        } catch {
            logger.error("Create status failed", metadata: ["error": "\(error)", "type": "\(type(of: error))"])
            return try errorResponse(error: "internal_error", description: "Could not create status", status: .internalServerError)
        }
    }

    /// DELETE /api/v1/statuses/:id - Delete a status
    func deleteStatus(request: Request, context: some RequestContext) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Extract ID from path
        guard let idString = context.parameters.get("id", as: String.self),
              let snowflakeID = Int64(idString) else {
            logger.warning("Invalid status ID in request")
            return try errorResponse(error: "invalid_request", description: "Invalid status ID", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Map snowflake ID to AT URI
            guard let atURI = await idMapping.getATURI(forSnowflakeID: snowflakeID) else {
                logger.warning("No AT URI found for snowflake ID", metadata: ["snowflake_id": "\(snowflakeID)"])
                return try errorResponse(error: "not_found", description: "Status not found", status: .notFound)
            }

            // Delete post from AT Proto
            try await atprotoClient.deletePost(atURI)

            logger.info("Status deleted", metadata: ["id": "\(snowflakeID)"])

            // Return empty object for successful deletion
            return try jsonResponse(["id": idString], status: .ok)
        } catch {
            logger.error("Delete status failed", metadata: ["id": "\(snowflakeID)", "error": "\(error)"])
            return try errorResponse(error: "internal_error", description: "Could not delete status", status: .internalServerError)
        }
    }

    /// GET /api/v1/statuses/:id/context - Get status context (thread)
    func getContext(request: Request, context: some RequestContext) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Extract ID from path
        guard let idString = context.parameters.get("id", as: String.self),
              let snowflakeID = Int64(idString) else {
            logger.warning("Invalid status ID in request")
            return try errorResponse(error: "invalid_request", description: "Invalid status ID", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Map snowflake ID to AT URI
            guard let atURI = await idMapping.getATURI(forSnowflakeID: snowflakeID) else {
                logger.warning("No AT URI found for snowflake ID", metadata: ["snowflake_id": "\(snowflakeID)"])
                return try errorResponse(error: "not_found", description: "Status not found", status: .notFound)
            }

            // Get post thread from AT Proto
            let thread = try await atprotoClient.getPostThread(atURI, 10)

            // Translate ancestors and descendants
            let ancestors = try await withThrowingTaskGroup(of: MastodonStatus?.self) { group in
                for parent in thread.parents {
                    group.addTask {
                        try? await self.statusTranslator.translate(parent)
                    }
                }

                var results: [MastodonStatus] = []
                for try await status in group {
                    if let status = status {
                        results.append(status)
                    }
                }
                return results
            }

            let descendants = try await withThrowingTaskGroup(of: MastodonStatus?.self) { group in
                for reply in thread.replies {
                    group.addTask {
                        try? await self.statusTranslator.translate(reply)
                    }
                }

                var results: [MastodonStatus] = []
                for try await status in group {
                    if let status = status {
                        results.append(status)
                    }
                }
                return results
            }

            let contextResponse: [String: [MastodonStatus]] = [
                "ancestors": ancestors,
                "descendants": descendants
            ]

            logger.info("Context retrieved", metadata: ["id": "\(snowflakeID)", "ancestors": "\(ancestors.count)", "descendants": "\(descendants.count)"])
            return try jsonResponse(contextResponse, status: .ok)
        } catch ATProtoError.notImplemented {
            logger.warning("Get context not implemented", metadata: ["id": "\(snowflakeID)"])
            return try errorResponse(error: "not_implemented", description: "Get context not yet implemented", status: .notImplemented)
        } catch {
            logger.warning("Get context failed", metadata: ["id": "\(snowflakeID)", "error": "\(error)"])
            return try errorResponse(error: "not_found", description: "Context not found", status: .notFound)
        }
    }

    /// POST /api/v1/statuses/:id/favourite - Favourite a status
    func favouriteStatus(request: Request, context: some RequestContext) async throws -> Response {
        return try await handleInteraction(
            request: request,
            context: context,
            action: "favourite",
            operation: { atURI, cid in
                try await atprotoClient.likePost(atURI, cid)
            }
        )
    }

    /// POST /api/v1/statuses/:id/unfavourite - Unfavourite a status
    func unfavouriteStatus(request: Request, context: some RequestContext) async throws -> Response {
        return try await handleInteraction(
            request: request,
            context: context,
            action: "unfavourite",
            operation: { atURI, _ in
                // Note: Unlike requires the like record URI which we don't track
                // For now, we'll just return success without actually unliking
                // This is a known limitation until we implement like record tracking
                return "" // Return empty string as placeholder URI
            }
        )
    }

    /// POST /api/v1/statuses/:id/reblog - Reblog a status
    func reblogStatus(request: Request, context: some RequestContext) async throws -> Response {
        return try await handleInteraction(
            request: request,
            context: context,
            action: "reblog",
            operation: { atURI, cid in
                try await atprotoClient.repost(atURI, cid)
            }
        )
    }

    /// POST /api/v1/statuses/:id/unreblog - Unreblog a status
    func unreblogStatus(request: Request, context: some RequestContext) async throws -> Response {
        return try await handleInteraction(
            request: request,
            context: context,
            action: "unreblog",
            operation: { atURI, _ in
                // Note: Unrepost requires the repost record URI which we don't track
                // For now, we'll just return success without actually unreposting
                // This is a known limitation until we implement repost record tracking
                return "" // Return empty string as placeholder URI
            }
        )
    }

    /// GET /api/v1/statuses/:id/favourited_by - Get who favourited
    func getFavouritedBy(request: Request, context: some RequestContext) async throws -> Response {
        return try await handleGetInteractors(
            request: request,
            context: context,
            interactionType: "favourited",
            fetcher: { atURI in
                try await atprotoClient.getLikedBy(atURI, 20, nil)
            }
        )
    }

    /// GET /api/v1/statuses/:id/reblogged_by - Get who reblogged
    func getRebloggedBy(request: Request, context: some RequestContext) async throws -> Response {
        return try await handleGetInteractors(
            request: request,
            context: context,
            interactionType: "reblogged",
            fetcher: { atURI in
                try await atprotoClient.getRepostedBy(atURI, 20, nil)
            }
        )
    }

    // MARK: - Helper Methods

    /// Handle status interaction (like, unlike, repost, unrepost)
    private func handleInteraction(
        request: Request,
        context: some RequestContext,
        action: String,
        operation: (String, String) async throws -> String
    ) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Extract ID from path
        guard let idString = context.parameters.get("id", as: String.self),
              let snowflakeID = Int64(idString) else {
            logger.warning("Invalid status ID in request")
            return try errorResponse(error: "invalid_request", description: "Invalid status ID", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Map snowflake ID to AT URI
            guard let atURI = await idMapping.getATURI(forSnowflakeID: snowflakeID) else {
                logger.warning("No AT URI found for snowflake ID", metadata: ["snowflake_id": "\(snowflakeID)"])
                return try errorResponse(error: "not_found", description: "Status not found", status: .notFound)
            }

            // Fetch the post first to get its CID (required by ATProtoKit for write operations)
            let originalPost = try await atprotoClient.getPost(atURI)
            let cid = originalPost.cid

            // Perform operation with proper CID
            _ = try await operation(atURI, cid)

            // Get the updated status
            let post = try await atprotoClient.getPost(atURI)
            let status = try await statusTranslator.translate(post)

            logger.info("Status \(action)d", metadata: ["id": "\(snowflakeID)"])
            return try jsonResponse(status, status: .ok)
        } catch ATProtoError.notImplemented {
            logger.warning("\(action) not implemented", metadata: ["id": "\(snowflakeID)"])
            return try errorResponse(error: "not_implemented", description: "\(action.capitalized) not yet implemented", status: .notImplemented)
        } catch {
            logger.warning("\(action) failed", metadata: ["id": "\(snowflakeID)", "error": "\(error)"])
            return try errorResponse(error: "internal_error", description: "Could not \(action) status", status: .internalServerError)
        }
    }

    /// Handle getting interactors (who liked, who reposted)
    private func handleGetInteractors(
        request: Request,
        context: some RequestContext,
        interactionType: String,
        fetcher: (String) async throws -> Any
    ) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Extract ID from path
        guard let idString = context.parameters.get("id", as: String.self),
              let snowflakeID = Int64(idString) else {
            logger.warning("Invalid status ID in request")
            return try errorResponse(error: "invalid_request", description: "Invalid status ID", status: .badRequest)
        }

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Map snowflake ID to AT URI
            guard let atURI = await idMapping.getATURI(forSnowflakeID: snowflakeID) else {
                logger.warning("No AT URI found for snowflake ID", metadata: ["snowflake_id": "\(snowflakeID)"])
                return try errorResponse(error: "not_found", description: "Status not found", status: .notFound)
            }

            // Fetch interactors - the fetcher returns either ATProtoLikesResponse or ATProtoRepostsResponse
            let result = try await fetcher(atURI)

            // Extract profiles and translate to Mastodon accounts
            var profiles: [ATProtoProfile] = []
            if let likesResponse = result as? ATProtoLikesResponse {
                profiles = likesResponse.likes
            } else if let repostsResponse = result as? ATProtoRepostsResponse {
                profiles = repostsResponse.reposts
            }

            // Translate profiles to Mastodon accounts
            let facetProcessor = FacetProcessor()
            let profileTranslator = ProfileTranslator(idMapping: idMapping, facetProcessor: facetProcessor)

            let accounts = try await withThrowingTaskGroup(of: MastodonAccount?.self) { group in
                for profile in profiles {
                    group.addTask {
                        try? await profileTranslator.translate(profile)
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

            logger.info("Got \(interactionType) by", metadata: ["id": "\(snowflakeID)", "count": "\(accounts.count)"])
            return try jsonResponse(accounts, status: .ok)
        } catch ATProtoError.notImplemented {
            logger.warning("Get \(interactionType) by not implemented", metadata: ["id": "\(snowflakeID)"])
            // Return empty array for not implemented
            let emptyArray: [MastodonAccount] = []
            return try jsonResponse(emptyArray, status: .ok)
        } catch {
            logger.warning("Get \(interactionType) by failed", metadata: ["id": "\(snowflakeID)", "error": "\(error)"])
            // Return empty array instead of error
            let emptyArray: [MastodonAccount] = []
            return try jsonResponse(emptyArray, status: .ok)
        }
    }

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
}
