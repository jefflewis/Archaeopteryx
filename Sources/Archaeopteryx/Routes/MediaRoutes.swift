import Foundation
import Hummingbird
import Logging
import ATProtoAdapter
import MastodonModels
import IDMapping
import OAuthService
import CacheLayer
import Dependencies

// MARK: - Media Routes

/// Media upload routes for Mastodon API compatibility
struct MediaRoutes {
    let logger: Logger
    @Dependency(\.atProtoClient) var atprotoClient
    let oauthService: OAuthService
    let idMapping: IDMappingService
    let cache: CacheService

    /// Add media routes to the router
    static func addRoutes(
        to router: Router<some RequestContext>,
        logger: Logger,
        oauthService: OAuthService,
        idMapping: IDMappingService,
        cache: CacheService
    ) {
        let routes = MediaRoutes(
            logger: logger,
            oauthService: oauthService,
            idMapping: idMapping,
            cache: cache
        )

        // POST /api/v1/media - Upload media (v1)
        router.post("/api/v1/media") { request, context -> Response in
            try await routes.uploadMediaV1(request: request, context: context)
        }

        // POST /api/v2/media - Upload media (v2, async processing)
        router.post("/api/v2/media") { request, context -> Response in
            try await routes.uploadMediaV2(request: request, context: context)
        }

        // GET /api/v1/media/:id - Get media attachment
        router.get("/api/v1/media/:id") { request, context -> Response in
            try await routes.getMedia(request: request, context: context)
        }

        // PUT /api/v1/media/:id - Update media attachment
        router.put("/api/v1/media/:id") { request, context -> Response in
            try await routes.updateMedia(request: request, context: context)
        }
    }

    // MARK: - Route Handlers

    /// POST /api/v1/media - Upload media (v1)
    /// Accepts multipart/form-data with 'file' field and optional 'description' field
    /// Or raw binary data with Content-Type header
    func uploadMediaV1(request: Request, context: some RequestContext) async throws -> Response {
        // Authenticate user
        guard let authHeader = request.headers[.authorization] else {
            return try errorResponse(error: "unauthorized", description: "Missing authorization header", status: .unauthorized)
        }

        guard authHeader.hasPrefix("Bearer ") else {
            return try errorResponse(error: "unauthorized", description: "Invalid authorization format", status: .unauthorized)
        }

        let token = String(authHeader.dropFirst(7))

        do {
            // Validate token and get user context
            let userContext = try await oauthService.validateToken(token)

            // Get content type
            guard let contentType = request.headers[.contentType] else {
                return try errorResponse(error: "bad_request", description: "Missing Content-Type header", status: .badRequest)
            }

            // For MVP, we'll accept raw binary data with Content-Type
            // Full multipart/form-data parsing can be added later
            let bodyBuffer = try await request.body.collect(upTo: .max)
            let fileData = Data(buffer: bodyBuffer)

            // Validate file size
            let maxSize = contentType.starts(with: "video/") ? 40 * 1024 * 1024 : 10 * 1024 * 1024
            guard fileData.count <= maxSize else {
                var response = try errorResponse(
                    error: "validation_failed",
                    description: "File size exceeds limit (\(maxSize / 1024 / 1024)MB)",
                    status: .badRequest
                )
                response.status = .init(code: 422, reasonPhrase: "Unprocessable Entity")
                return response
            }

            // Validate MIME type
            let allowedMimeTypes = ["image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp", "video/mp4"]
            guard allowedMimeTypes.contains(where: { contentType.starts(with: $0) }) else {
                var response = try errorResponse(
                    error: "validation_failed",
                    description: "Unsupported media type. Allowed: \(allowedMimeTypes.joined(separator: ", "))",
                    status: .badRequest
                )
                response.status = .init(code: 422, reasonPhrase: "Unprocessable Entity")
                return response
            }

            // Generate filename from content type
            let ext = contentType.starts(with: "image/png") ? "png" :
                      contentType.starts(with: "image/gif") ? "gif" :
                      contentType.starts(with: "image/webp") ? "webp" :
                      contentType.starts(with: "video/mp4") ? "mp4" : "jpg"
            let filename = "\(UUID().uuidString).\(ext)"

            // Upload blob to AT Protocol
            let blobRef = try await atprotoClient.uploadBlob(fileData, filename, contentType)

            logger.info("Uploaded blob with CID: \(blobRef.cid)")

            // Generate Snowflake ID for this media attachment
            let snowflakeID = await idMapping.getSnowflakeID(forATURI: blobRef.cid)

            // Extract description from query parameter (optional)
            let description = request.uri.queryParameters.get("description")

            // Store metadata in cache
            let metadata = MediaMetadata(
                cid: blobRef.cid,
                mimeType: blobRef.mimeType,
                size: blobRef.size,
                description: description,
                ownerDID: userContext.did,
                createdAt: Date()
            )

            let cacheKey = "media:\(snowflakeID)"
            try await cache.set(cacheKey, value: metadata, ttl: 24 * 60 * 60) // 24 hour TTL

            // Construct media URL (using CID for now)
            let mediaURL = "https://cdn.bsky.app/img/feed_thumbnail/plain/\(userContext.did)/\(blobRef.cid)@jpeg"

            // Determine media type
            let mediaType: MastodonModels.MediaType = contentType.starts(with: "video/") ? .video :
                                       contentType.starts(with: "image/gif") ? .gifv : .image

            // Return MediaAttachment
            let attachment = MediaAttachment(
                id: "\(snowflakeID)",
                type: mediaType,
                url: mediaURL,
                previewUrl: mediaURL,
                description: description
            )

            return try jsonResponse(attachment, status: .ok)

        } catch is OAuthError {
            return try errorResponse(error: "unauthorized", description: "Invalid or expired token", status: .unauthorized)
        } catch let error as ATProtoError {
            logger.error("AT Protocol error: \(error)")
            return try errorResponse(error: "server_error", description: "Failed to upload media", status: .internalServerError)
        } catch {
            logger.error("Unexpected error: \(error)")
            return try errorResponse(error: "server_error", description: "Internal server error", status: .internalServerError)
        }
    }

    /// POST /api/v2/media - Upload media (v2, async processing)
    /// For MVP, delegates to v1 implementation
    func uploadMediaV2(request: Request, context: some RequestContext) async throws -> Response {
        // Mastodon v2 API is identical to v1 for our use case
        return try await uploadMediaV1(request: request, context: context)
    }

    /// GET /api/v1/media/:id - Get media attachment
    func getMedia(request: Request, context: some RequestContext) async throws -> Response {
        guard let mediaIDStr = context.parameters.get("id", as: String.self),
              let mediaID = Int64(mediaIDStr) else {
            return try errorResponse(error: "bad_request", description: "Invalid media ID", status: .badRequest)
        }

        do {
            // Look up CID from Snowflake ID
            guard let cid = await idMapping.getATURI(forSnowflakeID: mediaID) else {
                return try errorResponse(error: "not_found", description: "Media attachment not found", status: .notFound)
            }

            // Retrieve metadata from cache
            let cacheKey = "media:\(mediaID)"
            guard let metadata: MediaMetadata = try await cache.get(cacheKey) else {
                return try errorResponse(error: "not_found", description: "Media metadata not found", status: .notFound)
            }

            // Construct media URL
            let mediaURL = "https://cdn.bsky.app/img/feed_thumbnail/plain/\(metadata.ownerDID)/\(cid)@jpeg"

            // Determine media type from MIME type
            let mediaType: MastodonModels.MediaType = metadata.mimeType.starts(with: "video/") ? .video :
                                       metadata.mimeType.starts(with: "image/gif") ? .gifv : .image

            // Return MediaAttachment
            let attachment = MediaAttachment(
                id: "\(mediaID)",
                type: mediaType,
                url: mediaURL,
                previewUrl: mediaURL,
                description: metadata.description
            )

            return try jsonResponse(attachment, status: .ok)

        } catch {
            logger.error("Error retrieving media: \(error)")
            return try errorResponse(error: "server_error", description: "Failed to retrieve media", status: .internalServerError)
        }
    }

    /// PUT /api/v1/media/:id - Update media attachment (typically alt text)
    func updateMedia(request: Request, context: some RequestContext) async throws -> Response {
        guard let mediaIDStr = context.parameters.get("id", as: String.self),
              let mediaID = Int64(mediaIDStr) else {
            return try errorResponse(error: "bad_request", description: "Invalid media ID", status: .badRequest)
        }

        // Authenticate user
        guard let authHeader = request.headers[.authorization] else {
            return try errorResponse(error: "unauthorized", description: "Missing authorization header", status: .unauthorized)
        }

        guard authHeader.hasPrefix("Bearer ") else {
            return try errorResponse(error: "unauthorized", description: "Invalid authorization format", status: .unauthorized)
        }

        let token = String(authHeader.dropFirst(7))

        do {
            // Validate token and get user context
            let userContext = try await oauthService.validateToken(token)

            // Retrieve existing metadata
            let cacheKey = "media:\(mediaID)"
            guard var metadata: MediaMetadata = try await cache.get(cacheKey) else {
                return try errorResponse(error: "not_found", description: "Media attachment not found", status: .notFound)
            }

            // Verify ownership
            guard metadata.ownerDID == userContext.did else {
                return try errorResponse(error: "forbidden", description: "You don't own this media attachment", status: .forbidden)
            }

            // Parse update request body
            let bodyBuffer = try await request.body.collect(upTo: .max)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let updateRequest = try decoder.decode(MediaUpdateRequest.self, from: Data(buffer: bodyBuffer))

            // Update description
            metadata.description = updateRequest.description

            // Save updated metadata
            try await cache.set(cacheKey, value: metadata, ttl: 24 * 60 * 60)

            // Construct media URL
            let mediaURL = "https://cdn.bsky.app/img/feed_thumbnail/plain/\(metadata.ownerDID)/\(metadata.cid)@jpeg"

            // Determine media type
            let mediaType: MastodonModels.MediaType = metadata.mimeType.starts(with: "video/") ? .video :
                                       metadata.mimeType.starts(with: "image/gif") ? .gifv : .image

            // Return updated MediaAttachment
            let attachment = MediaAttachment(
                id: "\(mediaID)",
                type: mediaType,
                url: mediaURL,
                previewUrl: mediaURL,
                description: metadata.description
            )

            return try jsonResponse(attachment, status: .ok)

        } catch is OAuthError {
            return try errorResponse(error: "unauthorized", description: "Invalid or expired token", status: .unauthorized)
        } catch is DecodingError {
            logger.error("Failed to decode update request")
            return try errorResponse(error: "bad_request", description: "Invalid request body", status: .badRequest)
        } catch {
            logger.error("Error updating media: \(error)")
            return try errorResponse(error: "server_error", description: "Failed to update media", status: .internalServerError)
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

    /// Helper to create error response
    private func errorResponse(error: String, description: String, status: HTTPResponse.Status) throws -> Response {
        let errorResp: [String: String] = [
            "error": error,
            "error_description": description
        ]
        return try jsonResponse(errorResp, status: status)
    }
}

// MARK: - Supporting Types

/// Metadata for uploaded media stored in cache
struct MediaMetadata: Codable, Sendable {
    /// The CID (Content Identifier) of the blob in AT Protocol
    let cid: String

    /// MIME type of the media
    let mimeType: String

    /// Size in bytes
    let size: Int

    /// Optional description/alt text
    var description: String?

    /// DID of the user who uploaded this media
    let ownerDID: String

    /// When the media was uploaded
    let createdAt: Date
}

/// Request body for updating media
struct MediaUpdateRequest: Codable, Sendable {
    /// Updated description/alt text
    let description: String?
}
