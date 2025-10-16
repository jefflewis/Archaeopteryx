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

// MARK: - Search Routes

/// Search routes for Mastodon API compatibility
struct SearchRoutes {
    let logger: Logger
    @Dependency(\.atProtoClient) var atprotoClient
    let oauthService: OAuthService
    let idMapping: IDMappingService
    let profileTranslator: ProfileTranslator
    let cache: CacheService

    /// Add search routes to the router
    static func addRoutes(
        to router: Router<some RequestContext>,
        logger: Logger,
        oauthService: OAuthService,
        idMapping: IDMappingService,
        profileTranslator: ProfileTranslator,
        cache: CacheService
    ) {
        let routes = SearchRoutes(
            logger: logger,
            oauthService: oauthService,
            idMapping: idMapping,
            profileTranslator: profileTranslator,
            cache: cache
        )

        // GET /api/v2/search - Search for content
        router.get("/api/v2/search") { request, context -> Response in
            try await routes.search(request: request, context: context)
        }
    }

    // MARK: - Route Handlers

    /// GET /api/v2/search - Search for accounts, statuses, and hashtags
    /// Query parameters:
    /// - q: search query (required)
    /// - type: filter by type (accounts, statuses, hashtags) - optional
    /// - limit: max results per category (default 20, max 40)
    /// - offset: pagination offset (default 0)
    /// - resolve: attempt to resolve remote resources (default false)
    /// - following: only show results from accounts the user follows (requires auth)
    func search(request: Request, context: some RequestContext) async throws -> Response {
        // Get query parameter
        guard let query = request.uri.queryParameters.get("q"), !query.isEmpty else {
            return try errorResponse(error: "bad_request", description: "Missing or empty 'q' parameter", status: .badRequest)
        }

        // Get optional type filter
        let typeFilter = request.uri.queryParameters.get("type")

        // Validate type filter if provided
        if let type = typeFilter {
            let validTypes = ["accounts", "statuses", "hashtags"]
            guard validTypes.contains(type) else {
                return try errorResponse(
                    error: "bad_request",
                    description: "Invalid type parameter. Must be one of: accounts, statuses, hashtags",
                    status: .badRequest
                )
            }
        }

        // Get limit (default 20, max 40)
        let limitStr = request.uri.queryParameters.get("limit")
        let limit = limitStr.flatMap(Int.init) ?? 20
        let actualLimit = min(max(limit, 1), 40)

        // Get offset (default 0)
        let offsetStr = request.uri.queryParameters.get("offset")
        let offset = offsetStr.flatMap(Int.init) ?? 0

        // Optional authentication (search can work without auth)
        var authenticatedDID: String? = nil
        if let authHeader = request.headers[.authorization], authHeader.hasPrefix("Bearer ") {
            let token = String(authHeader.dropFirst(7))
            authenticatedDID = try? await oauthService.validateToken(token)
        }

        do {
            // Initialize empty results
            var accounts: [MastodonAccount] = []
            var statuses: [MastodonStatus] = []
            var hashtags: [MastodonTag] = []

            // Search for accounts (if type is nil, "accounts", or not specified)
            if typeFilter == nil || typeFilter == "accounts" {
                accounts = try await searchAccounts(query: query, limit: actualLimit, offset: offset)
            }

            // Search for statuses (if type is nil, "statuses")
            // Note: Bluesky doesn't have a direct post search API that's easily accessible
            // For MVP, we'll return empty array. This can be enhanced later.
            if typeFilter == nil || typeFilter == "statuses" {
                statuses = []
                logger.info("Status search not yet implemented - returning empty results")
            }

            // Search for hashtags (if type is nil, "hashtags")
            // Note: Bluesky doesn't have a dedicated hashtag search API
            // We could potentially extract hashtags from the query, but for MVP we'll return empty
            if typeFilter == nil || typeFilter == "hashtags" {
                hashtags = extractHashtags(from: query)
            }

            // Create search results
            let results = MastodonSearchResults(
                accounts: accounts,
                statuses: statuses,
                hashtags: hashtags
            )

            return try jsonResponse(results, status: .ok)

        } catch let error as ATProtoError {
            logger.error("AT Protocol search error: \(error)")
            return try errorResponse(error: "server_error", description: "Search failed", status: .internalServerError)
        } catch {
            logger.error("Unexpected search error: \(error)")
            return try errorResponse(error: "server_error", description: "Internal server error", status: .internalServerError)
        }
    }

    // MARK: - Helper Methods

    /// Search for accounts using AT Protocol
    private func searchAccounts(query: String, limit: Int, offset: Int) async throws -> [MastodonAccount] {
        // Note: AT Protocol doesn't support offset-based pagination, only cursor
        // For MVP, we'll ignore offset and just use limit
        let searchResponse = try await atprotoClient.searchActors(query, limit, nil)

        // Translate profiles to Mastodon accounts
        var accounts: [MastodonAccount] = []
        for profile in searchResponse.actors {
            let account = try await profileTranslator.translate(profile)
            accounts.append(account)
        }

        return accounts
    }

    /// Extract hashtags from query string
    /// For MVP, we'll create a simple hashtag response if the query looks like a hashtag
    private func extractHashtags(from query: String) -> [MastodonTag] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // If query starts with #, treat it as a hashtag search
        if cleanQuery.hasPrefix("#") {
            let tagName = String(cleanQuery.dropFirst()).lowercased()
            if !tagName.isEmpty {
                let tag = MastodonTag(
                    name: tagName,
                    url: "https://bsky.app/hashtag/\(tagName)"
                )
                return [tag]
            }
        } else if !cleanQuery.contains(" ") && !cleanQuery.isEmpty {
            // Single word without # could also be a hashtag search
            let tag = MastodonTag(
                name: cleanQuery.lowercased(),
                url: "https://bsky.app/hashtag/\(cleanQuery.lowercased())"
            )
            return [tag]
        }

        return []
    }

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

    /// Helper to create error response
    private func errorResponse(error: String, description: String, status: HTTPResponse.Status) throws -> Response {
        let errorResp: [String: String] = [
            "error": error,
            "error_description": description
        ]
        return try jsonResponse(errorResp, status: status)
    }
}
