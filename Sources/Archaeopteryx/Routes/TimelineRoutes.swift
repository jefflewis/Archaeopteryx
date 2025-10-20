import Hummingbird
import HummingbirdCore
import Logging
import Foundation
import OAuthService
import ATProtoAdapter
import IDMapping
import TranslationLayer
import MastodonModels
import ArchaeopteryxCore

/// Routes for timeline/feed operations
struct TimelineRoutes: Sendable {
    let oauthService: OAuthService
    let sessionClient: SessionScopedClient
    let idMapping: IDMappingService
    let statusTranslator: StatusTranslator
    let logger: Logger

    static func addRoutes(
        to router: Router<some RequestContext>,
        oauthService: OAuthService,
        sessionClient: SessionScopedClient,
        idMapping: IDMappingService,
        statusTranslator: StatusTranslator,
        logger: Logger
    ) {
        let routes = TimelineRoutes(
            oauthService: oauthService,
            sessionClient: sessionClient,
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
    /// Returns statuses from followed accounts (maps to app.bsky.feed.getTimeline)
    /// This endpoint returns posts from accounts the authenticated user follows
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
        let minID = queryItems["min_id"]
        let sinceID = queryItems["since_id"]

        do {
            // Validate token and get user context
            let userContext = try await oauthService.validateToken(token)

            logger.info("Getting home timeline", metadata: [
                "user": "\(userContext.did)",
                "limit": "\(limit)",
                "max_id": "\(maxID ?? "none")",
                "min_id": "\(minID ?? "none")",
                "since_id": "\(sinceID ?? "none")"
            ])

            // Determine cursor for AT Protocol based on Mastodon pagination params
            // Note: Mastodon uses post IDs for pagination, Bluesky uses opaque cursors
            // We can't directly convert Snowflake IDs to Bluesky cursors
            // Strategy: Fetch more posts and filter client-side based on max_id/min_id
            let cursor: String? = nil
            
            // Fetch extra posts to account for filtering
            let fetchLimit = maxID != nil ? limit * 3 : limit

            // Get timeline from AT Protocol with user's session
            let feedResponse = try await sessionClient.getTimeline(
                limit: fetchLimit,
                cursor: cursor,
                session: userContext.sessionData
            )

            // Translate posts to Mastodon statuses
            var statuses = try await withThrowingTaskGroup(of: MastodonStatus?.self) { group in
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

            // Apply Mastodon-style pagination filters
            // max_id: Return posts older than this ID (standard "load more")
            if let maxID = maxID, let maxIDValue = Int64(maxID) {
                statuses = statuses.filter { Int64($0.id) ?? 0 < maxIDValue }
            }
            
            // min_id/since_id: Return posts newer than this ID (pull-to-refresh)
            if let minID = minID, let minIDValue = Int64(minID) {
                statuses = statuses.filter { Int64($0.id) ?? 0 > minIDValue }
            } else if let sinceID = sinceID, let sinceIDValue = Int64(sinceID) {
                statuses = statuses.filter { Int64($0.id) ?? 0 > sinceIDValue }
            }
            
            // Limit to requested amount after filtering
            if statuses.count > limit {
                statuses = Array(statuses.prefix(limit))
            }

            logger.info("Home timeline retrieved", metadata: [
                "fetched": "\(feedResponse.posts.count)",
                "translated": "\(statuses.count)",
                "max_id_filter": "\(maxID ?? "none")",
                "min_id_filter": "\(minID ?? "none")",
                "has_cursor": "\(feedResponse.cursor != nil)"
            ])
            
            // Add Link headers for pagination
            var response = try jsonResponse(statuses, status: .ok)
            if let linkHeader = buildLinkHeader(
                path: "/api/v1/timelines/home",
                queryItems: queryItems,
                statuses: statuses,
                cursor: feedResponse.cursor
            ) {
                response.headers[.init("Link")!] = linkHeader
            }
            
            return response
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
    /// Maps to Bluesky feeds based on `local` query parameter:
    /// - local=true → Discover feed (at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot)
    /// - local=false → What's Hot feed (at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/hot-classic)
    func getPublicTimeline(request: Request, context: some RequestContext) async throws -> Response {
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
        let minID = queryItems["min_id"]
        let sinceID = queryItems["since_id"]
        let isLocal = queryItems["local"]?.lowercased() == "true"

        do {
            // Validate token and get user context
            let userContext = try await oauthService.validateToken(token)

            // Select feed based on local parameter
            let feedURI: String
            if isLocal {
                feedURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"
                logger.info("Getting local timeline (Discover feed)", metadata: [
                    "user": "\(userContext.did)",
                    "limit": "\(limit)",
                    "max_id": "\(maxID ?? "none")",
                    "min_id": "\(minID ?? "none")"
                ])
            } else {
                feedURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/hot-classic"
                logger.info("Getting federated timeline (What's Hot feed)", metadata: [
                    "user": "\(userContext.did)",
                    "limit": "\(limit)",
                    "max_id": "\(maxID ?? "none")",
                    "min_id": "\(minID ?? "none")"
                ])
            }

            // Determine cursor for AT Protocol based on Mastodon pagination params
            let cursor: String? = maxID  // Only use max_id for cursor, min_id/since_id need fresh data

            // Get feed from AT Protocol with user's session
            let feedResponse = try await sessionClient.getFeed(
                feedURI: feedURI,
                limit: limit,
                cursor: cursor,
                session: userContext.sessionData
            )

            // Translate posts to Mastodon statuses
            var statuses = try await withThrowingTaskGroup(of: MastodonStatus?.self) { group in
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

            logger.info("Public timeline retrieved", metadata: [
                "local": "\(isLocal)",
                "count": "\(statuses.count)"
            ])
            
            // Add Link headers for pagination
            var response = try jsonResponse(statuses, status: .ok)
            if let linkHeader = buildLinkHeader(
                path: "/api/v1/timelines/public",
                queryItems: queryItems,
                statuses: statuses,
                cursor: feedResponse.cursor
            ) {
                response.headers[.init("Link")!] = linkHeader
            }
            
            return response
        } catch let error as ATProtoError where error.description.contains("not implemented") {
            logger.warning("Public timeline not yet implemented")
            let emptyArray: [MastodonStatus] = []
            return try jsonResponse(emptyArray, status: .ok)
        } catch {
            logger.error("Failed to get public timeline", metadata: ["error": "\(error)"])
            let emptyArray: [MastodonStatus] = []
            return try jsonResponse(emptyArray, status: .ok)
        }
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
        let minID = queryItems["min_id"]
        let sinceID = queryItems["since_id"]

        do {
            // Validate token and get user context
            let userContext = try await oauthService.validateToken(token)

            // Map Snowflake ID back to AT URI (feed URI)
            let feedURI = await idMapping.getATURI(forSnowflakeID: listSnowflakeID) ?? ""

            logger.info("List timeline requested", metadata: [
                "list_id": "\(listSnowflakeID)",
                "feed_uri": "\(feedURI)",
                "max_id": "\(maxID ?? "none")",
                "min_id": "\(minID ?? "none")"
            ])

            // Determine cursor for AT Protocol based on Mastodon pagination params
            let cursor = maxID ?? minID ?? sinceID

            // Get feed from AT Protocol with user's session
            let feedResponse = try await sessionClient.getFeed(
                feedURI: feedURI,
                limit: limit,
                cursor: cursor,
                session: userContext.sessionData
            )

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
            
            // Add Link headers for pagination
            var response = try jsonResponse(statuses, status: .ok)
            if let linkHeader = buildLinkHeader(
                path: "/api/v1/timelines/list/\(listSnowflakeID)",
                queryItems: queryItems,
                statuses: statuses,
                cursor: feedResponse.cursor
            ) {
                response.headers[.init("Link")!] = linkHeader
            }
            
            return response
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
        encoder.dateEncodingStrategy = .mastodonISO8601
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
    
    /// Build Link header for pagination
    /// Format: Link: <https://example.com/api/v1/timelines/home?max_id=103>; rel="next", <https://example.com/api/v1/timelines/home?since_id=105>; rel="prev"
    private func buildLinkHeader(
        path: String,
        queryItems: [String: String],
        statuses: [MastodonStatus],
        cursor: String?
    ) -> String? {
        guard !statuses.isEmpty else { return nil }
        
        var links: [String] = []
        
        // Get the oldest and newest status IDs
        let oldestID = statuses.last?.id
        let newestID = statuses.first?.id
        
        // Build next link (older posts) using max_id
        if let oldestID = oldestID {
            var nextParams = queryItems
            nextParams["max_id"] = oldestID
            nextParams.removeValue(forKey: "since_id")
            nextParams.removeValue(forKey: "min_id")
            
            let queryString = buildQueryString(from: nextParams)
            links.append("<\(path)?\(queryString)>; rel=\"next\"")
        }
        
        // Build prev link (newer posts) using min_id (for pull-to-refresh)
        if let newestID = newestID {
            var prevParams = queryItems
            prevParams["min_id"] = newestID
            prevParams.removeValue(forKey: "max_id")
            prevParams.removeValue(forKey: "since_id")
            
            let queryString = buildQueryString(from: prevParams)
            links.append("<\(path)?\(queryString)>; rel=\"prev\"")
        }
        
        return links.isEmpty ? nil : links.joined(separator: ", ")
    }
    
    /// Build query string from parameters
    private func buildQueryString(from params: [String: String]) -> String {
        params.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }.joined(separator: "&")
    }
}
