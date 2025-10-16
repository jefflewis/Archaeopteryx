import XCTest
@testable import Archaeopteryx
@testable import MastodonModels
@testable import IDMapping
@testable import CacheLayer

final class MediaRoutesTests: XCTestCase {
    var cache: InMemoryCache!
    var idMapping: IDMappingService!
    var generator: SnowflakeIDGenerator!

    override func setUp() async throws {
        try await super.setUp()
        cache = InMemoryCache()
        generator = SnowflakeIDGenerator()
        idMapping = IDMappingService(cache: cache, generator: generator)
    }

    override func tearDown() async throws {
        cache = nil
        idMapping = nil
        generator = nil
        try await super.tearDown()
    }

    // MARK: - MediaAttachment Model Tests

    func testMediaAttachment_CanBeCreated() {
        let media = MediaAttachment(
            id: "123456",
            type: .image,
            url: "https://example.com/image.jpg",
            previewUrl: "https://example.com/thumb.jpg",
            description: "A beautiful sunset"
        )

        XCTAssertEqual(media.id, "123456")
        XCTAssertEqual(media.type, .image)
        XCTAssertEqual(media.url, "https://example.com/image.jpg")
        XCTAssertEqual(media.previewUrl, "https://example.com/thumb.jpg")
        XCTAssertEqual(media.description, "A beautiful sunset")
    }

    func testMediaAttachment_EncodesWithSnakeCase() throws {
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
        XCTAssertTrue(json.contains("preview_url"))
    }

    func testMediaAttachment_SupportsAllTypes() {
        XCTAssertEqual(MediaType.image.rawValue, "image")
        XCTAssertEqual(MediaType.video.rawValue, "video")
        XCTAssertEqual(MediaType.gifv.rawValue, "gifv")
        XCTAssertEqual(MediaType.audio.rawValue, "audio")
        XCTAssertEqual(MediaType.unknown.rawValue, "unknown")
    }

    func testMediaAttachment_WithoutOptionalFields() {
        let media = MediaAttachment(
            id: "789",
            type: .image,
            url: "https://example.com/img.png"
        )

        XCTAssertEqual(media.id, "789")
        XCTAssertNil(media.previewUrl)
        XCTAssertNil(media.description)
    }

    func testMediaAttachment_SupportsEquatable() {
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

        XCTAssertEqual(media1, media2)
    }

    func testMediaAttachment_DecodesCorrectly() throws {
        let original = MediaAttachment(
            id: "456",
            type: .gifv,
            url: "https://example.com/anim.gif",
            previewUrl: "https://example.com/preview.jpg",
            description: "Animated GIF"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MediaAttachment.self, from: data)

        XCTAssertEqual(decoded.id, "456")
        XCTAssertEqual(decoded.type, .gifv)
        XCTAssertEqual(decoded.url, "https://example.com/anim.gif")
        XCTAssertEqual(decoded.previewUrl, "https://example.com/preview.jpg")
        XCTAssertEqual(decoded.description, "Animated GIF")
    }

    // MARK: - ID Mapping Tests for Media

    func testIDMapping_GeneratesSnowflakeForBlobCID() async throws {
        let cid = "bafyreib2rxk3rh6kzwq"

        let snowflake1 = await idMapping.getSnowflakeID(forATURI: cid)
        let snowflake2 = await idMapping.getSnowflakeID(forATURI: cid)

        // Should be deterministic
        XCTAssertEqual(snowflake1, snowflake2)
        XCTAssertGreaterThan(snowflake1, 0)
    }

    func testIDMapping_ReverseLookupBlobCID() async throws {
        let cid = "bafkreifzjut3te2nhyekklss"

        let snowflake = await idMapping.getSnowflakeID(forATURI: cid)
        let retrievedCID = await idMapping.getATURI(forSnowflakeID: snowflake)

        XCTAssertEqual(retrievedCID, cid)
    }

    func testIDMapping_HandlesMultipleBlobCIDs() async throws {
        let cid1 = "bafyreiaaa"
        let cid2 = "bafyreibbb"
        let cid3 = "bafyreiccc"

        let snowflake1 = await idMapping.getSnowflakeID(forATURI: cid1)
        let snowflake2 = await idMapping.getSnowflakeID(forATURI: cid2)
        let snowflake3 = await idMapping.getSnowflakeID(forATURI: cid3)

        // All should be unique
        XCTAssertNotEqual(snowflake1, snowflake2)
        XCTAssertNotEqual(snowflake2, snowflake3)
        XCTAssertNotEqual(snowflake1, snowflake3)

        // Reverse lookups should work
        let retrieved1 = await idMapping.getATURI(forSnowflakeID: snowflake1)
        let retrieved2 = await idMapping.getATURI(forSnowflakeID: snowflake2)
        let retrieved3 = await idMapping.getATURI(forSnowflakeID: snowflake3)

        XCTAssertEqual(retrieved1, cid1)
        XCTAssertEqual(retrieved2, cid2)
        XCTAssertEqual(retrieved3, cid3)
    }

    // MARK: - Media Routes Integration Tests

    func testMediaRoutes_PlaceholderForUploadImplementation() {
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
        XCTAssertTrue(true, "Media routes need HTTP integration tests")
    }
}
