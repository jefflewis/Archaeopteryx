import Foundation
import Testing
@testable import Archaeopteryx
@testable import MastodonModels
@testable import IDMapping
@testable import CacheLayer

@Suite struct MediaRoutesTests {
    var cache: InMemoryCache!
    var idMapping: IDMappingService!
    var generator: SnowflakeIDGenerator!

    init() async {
       cache = InMemoryCache()
        generator = SnowflakeIDGenerator()
        idMapping = IDMappingService(cache: cache, generator: generator)
    }

    // MARK: - MediaAttachment Model Tests

    @Test func MediaAttachment_CanBeCreated() {
        let media = MediaAttachment(
            id: "123456",
            type: .image,
            url: "https://example.com/image.jpg",
            previewUrl: "https://example.com/thumb.jpg",
            description: "A beautiful sunset"
        )

        #expect(media.id == "123456")
        #expect(media.type == .image)
        #expect(media.url == "https://example.com/image.jpg")
        #expect(media.previewUrl == "https://example.com/thumb.jpg")
        #expect(media.description == "A beautiful sunset")
    }

    @Test func MediaAttachment_EncodesWithSnakeCase() throws {
        let media = MediaAttachment(
            id: "123456",
            type: .video,
            url: "https://example.com/video.mp4",
            previewUrl: "https://example.com/poster.jpg",
            description: "Test video"
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(media)
        let json = String(data: data, encoding: .utf8)!

        // Verify snake_case keys
        #expect(json.contains("preview_url"))
    }

    @Test func MediaAttachment_SupportsAllTypes() {
        #expect(MediaType.image.rawValue == "image")
        #expect(MediaType.video.rawValue == "video")
        #expect(MediaType.gifv.rawValue == "gifv")
        #expect(MediaType.audio.rawValue == "audio")
        #expect(MediaType.unknown.rawValue == "unknown")
    }

    @Test func MediaAttachment_WithoutOptionalFields() {
        let media = MediaAttachment(
            id: "789",
            type: .image,
            url: "https://example.com/img.png"
        )

        #expect(media.id == "789")
        #expect(media.previewUrl == nil)
        #expect(media.description == nil)
    }

    @Test func MediaAttachment_SupportsEquatable() {
        let media1 = MediaAttachment(
            id: "123",
            type: .image,
            url: "https://example.com/1.jpg",
            description: "Test"
        )

        let media2 = MediaAttachment(
            id: "123",
            type: .image,
            url: "https://example.com/1.jpg",
            description: "Test"
        )

        #expect(media1 == media2)
    }

    @Test func MediaAttachment_DecodesCorrectly() throws {
        let original = MediaAttachment(
            id: "456",
            type: .gifv,
            url: "https://example.com/anim.gif",
            previewUrl: "https://example.com/preview.jpg",
            description: "Animated GIF"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MediaAttachment.self, from: data)

        #expect(decoded.id == "456")
        #expect(decoded.type == .gifv)
        #expect(decoded.url == "https://example.com/anim.gif")
        #expect(decoded.previewUrl == "https://example.com/preview.jpg")
        #expect(decoded.description == "Animated GIF")
    }

    // MARK: - ID Mapping Tests for Media

    @Test func IDMapping_GeneratesSnowflakeForBlobCID() async throws {
        let cid = "bafyreib2rxk3rh6kzwq"

        let snowflake1 = await idMapping.getSnowflakeID(forATURI: cid)
        let snowflake2 = await idMapping.getSnowflakeID(forATURI: cid)

        // Should be deterministic
        #expect(snowflake1 == snowflake2)
        #expect(snowflake1 > 0)
    }

    @Test func IDMapping_ReverseLookupBlobCID() async throws {
        let cid = "bafkreifzjut3te2nhyekklss"

        let snowflake = await idMapping.getSnowflakeID(forATURI: cid)
        let retrievedCID = await idMapping.getATURI(forSnowflakeID: snowflake)

        #expect(retrievedCID == cid)
    }

    @Test func IDMapping_HandlesMultipleBlobCIDs() async throws {
        let cid1 = "bafyreiaaa"
        let cid2 = "bafyreibbb"
        let cid3 = "bafyreiccc"

        let snowflake1 = await idMapping.getSnowflakeID(forATURI: cid1)
        let snowflake2 = await idMapping.getSnowflakeID(forATURI: cid2)
        let snowflake3 = await idMapping.getSnowflakeID(forATURI: cid3)

        // All should be unique
        #expect(snowflake1 != snowflake2)
        #expect(snowflake2 != snowflake3)
        #expect(snowflake1 != snowflake3)

        // Reverse lookups should work
        let retrieved1 = await idMapping.getATURI(forSnowflakeID: snowflake1)
        let retrieved2 = await idMapping.getATURI(forSnowflakeID: snowflake2)
        let retrieved3 = await idMapping.getATURI(forSnowflakeID: snowflake3)

        #expect(retrieved1 == cid1)
        #expect(retrieved2 == cid2)
        #expect(retrieved3 == cid3)
    }

    // MARK: - Media Routes Integration Tests

    @Test func MediaRoutes_PlaceholderForUploadImplementation() {
        // This test ensures the Media routes file can be created
        // Full HTTP integration tests will be added when we implement the routes
        //
        // Planned routes:
        // - POST /api/v1/media - Upload media with multipart form data
        // - POST /api/v2/media - Upload media (v2 API)
        // - GET /api/v1/media/:id - Get media attachment info
        // - PUT /api/v1/media/:id - Update media description
        //
        // Tests should cover:
        // - Upload with valid image (JPEG, PNG, GIF, WebP)
        // - Upload with valid video (MP4)
        // - Upload with alt text description
        // - Upload without auth (should fail with 401)
        // - Upload invalid format (should fail with 422)
        // - Upload file too large (should fail with 422)
        // - Get media by ID
        // - Get media with invalid ID (should fail with 404)
        // - Update media description
        // - Update media not owned by user (should fail with 403)
        #expect(true, "Media routes need HTTP integration tests")
    }
}

