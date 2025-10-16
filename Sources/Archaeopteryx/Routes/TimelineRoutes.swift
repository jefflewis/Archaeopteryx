import Hummingbird
import HummingbirdCore
import Logging
import Foundation
import OAuthService
import ATProtoAdapter
import IDMapping
import TranslationLayer
import MastodonModels
import Dependencies

/// Routes for timeline/feed operations
struct TimelineRoutes: Sendable {
    let oauthService: OAuthService
    @Dependency(\.atProtoClient) var atprotoClient
    let idMapping: IDMappingService
    let statusTranslator: StatusTranslator
    let logger: Logger

    static func addRoutes(
        to router: Router<some RequestContext>,
        oauthService: OAuthService,
        idMapping: IDMappingService,
        statusTranslator: StatusTranslator,
        logger: Logger
    ) {
        let routes = TimelineRoutes(
            oauthService: oauthService,
            idMapping: idMapping,
            statusTranslator: statusTranslator,
            logger: logger
        )

        // GET /api/v1/timelines/home - Home timeline
        router.get("/api/v1/timelines/home", use: routes.getHomeTimeline)

        // GET /api/v1/timelines/public - Public timeline
        router.get("/api/v1/timelines/public", use: routes.getPublicTimeline)

        // GET /api/v1/timelines/tag/:hashtag - Hashtag timeline
        router.get("/api/v1/timelines/tag/{hashtag}", use: routes.getHashtagTimeline)

        // GET /api/v1/timelines/list/:list_id - List timeline
        router.get("/api/v1/timelines/list/{list_id}", use: routes.getListTimeline)
    }

    // MARK: - Route Handlers

    /// GET /api/v1/timelines/home - Get home timeline
    /// Returns statuses from followed accounts
    func getHomeTimeline(request: Request, context: some RequestContext) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Parse query parameters
        let uri = request.uri
        let queryString = uri.query ?? ""
        let queryItems = parseQueryString(queryString)

        let limit = min(Int(queryItems["limit"] ?? "20") ?? 20, 40)
        let maxID = queryItems["max_id"]

        do {
            // Validate token and get user DID
            let userDID = try await oauthService.validateToken(token)

            logger.info("Getting home timeline", metadata: [
                "user": "\(userDID)",
                "limit": "\(limit)"
            ])

            // Get timeline from AT Protocol
            let feedResponse = try await atprotoClient.getTimeline(limit, maxID)

            // Translate posts to Mastodon statuses
            let statuses = try await withThrowingTaskGroup(of: MastodonStatus?.self) { group in
                for post in feedResponse.posts {
                    group.addTask {
                        try? await self.statusTranslator.translate(post)
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

            logger.info("Home timeline retrieved", metadata: ["count": "\(statuses.count)"])
            return try jsonResponse(statuses, status: .ok)
        } catch let error as ATProtoError where error.description.contains("not implemented") {
            logger.warning("Timeline not yet implemented")
            // Return empty array for now
            let emptyArray: [MastodonStatus] = []
            return try jsonResponse(emptyArray, status: .ok)
        } catch {
            logger.error("Failed to get home timeline", metadata: ["error": "\(error)"])
            // Return empty array instead of error
            let emptyArray: [MastodonStatus] = []
            return try jsonResponse(emptyArray, status: .ok)
        }
    }

    /// GET /api/v1/timelines/public - Get public timeline
    /// Note: Bluesky doesn't have a global public feed, so this returns empty
    func getPublicTimeline(request: Request, context: some RequestContext) async throws -> Response {
        logger.info("Public timeline requested - returning empty (Bluesky limitation)")

        // Bluesky doesn't have a global public feed
        let emptyArray: [MastodonStatus] = []
        return try jsonResponse(emptyArray, status: .ok)
    }

    /// GET /api/v1/timelines/tag/:hashtag - Get hashtag timeline
    func getHashtagTimeline(request: Request, context: some RequestContext) async throws -> Response {
        guard let hashtag = context.parameters.get("hashtag", as: String.self) else {
            return try errorResponse(error: "invalid_request", description: "Missing hashtag parameter", status: .badRequest)
        }

        logger.info("Hashtag timeline requested", metadata: ["hashtag": "\(hashtag)"])

        // TODO: Implement hashtag search via AT Protocol
        // For now, return empty array
        let emptyArray: [MastodonStatus] = []
        return try jsonResponse(emptyArray, status: .ok)
    }

    /// GET /api/v1/timelines/list/:list_id - Get list timeline
    func getListTimeline(request: Request, context: some RequestContext) async throws -> Response {
        // Verify authentication
        guard let token = try await extractBearerToken(from: request) else {
            return try errorResponse(error: "unauthorized", description: "Missing or invalid bearer token", status: .unauthorized)
        }

        // Extract list ID
        guard let listIDString = context.parameters.get("list_id", as: String.self),
              let listSnowflakeID = Int64(listIDString) else {
            return try errorResponse(error: "invalid_request", description: "Invalid list ID", status: .badRequest)
        }

        // Parse query parameters
        let uri = request.uri
        let queryString = uri.query ?? ""
        let queryItems = parseQueryString(queryString)

        let limit = min(Int(queryItems["limit"] ?? "20") ?? 20, 40)
        let maxID = queryItems["max_id"]

        do {
            // Validate token
            _ = try await oauthService.validateToken(token)

            // Map Snowflake ID back to AT URI (feed URI)
            let feedURI = await idMapping.getATURI(forSnowflakeID: listSnowflakeID) ?? ""

            logger.info("List timeline requested", metadata: [
                "list_id": "\(listSnowflakeID)",
                "feed_uri": "\(feedURI)"
            ])

            // Get feed from AT Protocol
            let feedResponse = try await atprotoClient.getFeed(feedURI, limit, maxID)

            // Translate posts to Mastodon statuses
            let statuses = try await withThrowingTaskGroup(of: MastodonStatus?.self) { group in
                for post in feedResponse.posts {
                    group.addTask {
                        try? await self.statusTranslator.translate(post)
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

            logger.info("List timeline retrieved", metadata: ["list_id": "\(listSnowflakeID)", "count": "\(statuses.count)"])
            return try jsonResponse(statuses, status: .ok)
        } catch let error as ATProtoError where error.description.contains("not implemented") {
            logger.warning("List timeline not yet implemented")
            // Return empty array for now
            let emptyArray: [MastodonStatus] = []
            return try jsonResponse(emptyArray, status: .ok)
        } catch {
            logger.error("Failed to get list timeline", metadata: ["error": "\(error)"])
            // Return empty array instead of error
            let emptyArray: [MastodonStatus] = []
            return try jsonResponse(emptyArray, status: .ok)
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
                result[key] = value
            }
        }

        return result
    }
}
