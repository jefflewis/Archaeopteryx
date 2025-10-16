import XCTest
@testable import TranslationLayer
@testable import ATProtoAdapter
@testable import MastodonModels
@testable import IDMapping

/// Tests for StatusTranslator - ATProto post to MastodonStatus translation
final class StatusTranslatorTests: XCTestCase {
    var sut: StatusTranslator!
    var mockIDMapping: MockIDMappingService!
    var mockProfileTranslator: ProfileTranslator!
    var facetProcessor: FacetProcessor!

    override func setUp() async throws {
        try await super.setUp()
        mockIDMapping = MockIDMappingService()
        facetProcessor = FacetProcessor()
        mockProfileTranslator = ProfileTranslator(idMapping: mockIDMapping, facetProcessor: facetProcessor)
        sut = StatusTranslator(
            idMapping: mockIDMapping,
            profileTranslator: mockProfileTranslator,
            facetProcessor: facetProcessor
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockIDMapping = nil
        mockProfileTranslator = nil
        facetProcessor = nil
        try await super.tearDown()
    }

    // MARK: - Text-Only Post Tests

    func testTranslatePost_TextOnly_CreatesBasicStatus() async throws {
        let author = createMockProfile()
        let post = ATProtoPost(
            uri: "at://did:plc:abc123/app.bsky.feed.post/xyz789",
            cid: "bafyreiabc123",
            author: author,
            text: "Hello world!",
            facets: nil,
            embed: nil,
            replyTo: nil,
            replyRoot: nil,
            createdAt: "2023-06-15T14:30:00Z",
            likeCount: 5,
            repostCount: 2,
            replyCount: 1
        )

        let result = try await sut.translate(post)

        // ID should be mapped from AT URI
        XCTAssertEqual(result.id, "987654321")

        // Content should be wrapped in HTML
        XCTAssertEqual(result.content, "<p>Hello world!</p>")

        // Author should be translated
        XCTAssertEqual(result.account.id, "123456789")
        XCTAssertEqual(result.account.username, "alice")

        // Counts should be mapped
        XCTAssertEqual(result.favouritesCount, 5)
        XCTAssertEqual(result.reblogsCount, 2)
        XCTAssertEqual(result.repliesCount, 1)

        // Date should be parsed
        XCTAssertNotNil(result.createdAt)

        // Should not be a reply
        XCTAssertNil(result.inReplyToId)
        XCTAssertNil(result.inReplyToAccountId)

        // No reblog
        XCTAssertNil(result.reblog)
    }

    func testTranslatePost_EmptyText_CreatesEmptyParagraph() async throws {
        let author = createMockProfile()
        let post = ATProtoPost(
            uri: "at://did:plc:abc123/app.bsky.feed.post/xyz789",
            cid: "bafyreiabc123",
            author: author,
            text: "",
            createdAt: "2023-06-15T14:30:00Z"
        )

        let result = try await sut.translate(post)

        XCTAssertEqual(result.content, "<p></p>")
    }

    // MARK: - Facets Tests

    func testTranslatePost_WithFacets_ConvertsToHTML() async throws {
        let author = createMockProfile()
        let facets = [
            ATProtoFacet(
                index: ATProtoByteSlice(byteStart: 0, byteEnd: 16),
                features: [.link(uri: "https://example.com")]
            )
        ]
        let post = ATProtoPost(
            uri: "at://did:plc:abc123/app.bsky.feed.post/xyz789",
            cid: "bafyreiabc123",
            author: author,
            text: "https://example.com",
            facets: facets,
            createdAt: "2023-06-15T14:30:00Z"
        )

        let result = try await sut.translate(post)

        // Should contain HTML anchor tag
        XCTAssertTrue(result.content.contains("<a href="))
        XCTAssertTrue(result.content.contains("https://example.com"))
    }

    func testTranslatePost_WithMentions_ExtractsMentions() async throws {
        let author = createMockProfile()
        let facets = [
            ATProtoFacet(
                index: ATProtoByteSlice(byteStart: 0, byteEnd: 16),
                features: [.mention(did: "did:plc:bob456")]
            )
        ]
        let post = ATProtoPost(
            uri: "at://did:plc:abc123/app.bsky.feed.post/xyz789",
            cid: "bafyreiabc123",
            author: author,
            text: "@bob.bsky.social",
            facets: facets,
            createdAt: "2023-06-15T14:30:00Z"
        )

        let result = try await sut.translate(post)

        // Should have mention in HTML
        XCTAssertTrue(result.content.contains("h-card"))
        XCTAssertTrue(result.content.contains("mention"))

        // Should extract mention into mentions array
        XCTAssertNotNil(result.mentions)
        XCTAssertEqual(result.mentions?.count, 1)
        XCTAssertEqual(result.mentions?.first?.acct, "bob.bsky.social")
    }

    func testTranslatePost_WithHashtags_ExtractsTags() async throws {
        let author = createMockProfile()
        let facets = [
            ATProtoFacet(
                index: ATProtoByteSlice(byteStart: 0, byteEnd: 8),
                features: [.tag(tag: "bluesky")]
            )
        ]
        let post = ATProtoPost(
            uri: "at://did:plc:abc123/app.bsky.feed.post/xyz789",
            cid: "bafyreiabc123",
            author: author,
            text: "#bluesky",
            facets: facets,
            createdAt: "2023-06-15T14:30:00Z"
        )

        let result = try await sut.translate(post)

        // Should have hashtag in HTML
        XCTAssertTrue(result.content.contains("hashtag"))
        XCTAssertTrue(result.content.contains("bluesky"))

        // Should extract tag into tags array
        XCTAssertNotNil(result.tags)
        XCTAssertEqual(result.tags?.count, 1)
        XCTAssertEqual(result.tags?.first?.name, "bluesky")
    }

    // MARK: - Reply Tests

    func testTranslatePost_Reply_SetsInReplyToFields() async throws {
        let author = createMockProfile()
        let post = ATProtoPost(
            uri: "at://did:plc:abc123/app.bsky.feed.post/xyz789",
            cid: "bafyreiabc123",
            author: author,
            text: "This is a reply",
            replyTo: "at://did:plc:bob456/app.bsky.feed.post/parent123",
            replyRoot: "at://did:plc:bob456/app.bsky.feed.post/root123",
            createdAt: "2023-06-15T14:30:00Z"
        )

        let result = try await sut.translate(post)

        // Should set inReplyToId
        XCTAssertNotNil(result.inReplyToId)
        XCTAssertEqual(result.inReplyToId, "987654321")

        // Should set inReplyToAccountId
        XCTAssertNotNil(result.inReplyToAccountId)
        XCTAssertEqual(result.inReplyToAccountId, "123456789")
    }

    // MARK: - Image Embed Tests

    func testTranslatePost_WithImages_IncludesMediaAttachments() async throws {
        let author = createMockProfile()
        let embed = ATProtoEmbed.images([
            ATProtoImage(url: "https://cdn.bsky.app/img1.jpg", alt: "A beautiful sunset"),
            ATProtoImage(url: "https://cdn.bsky.app/img2.jpg", alt: nil)
        ])
        let post = ATProtoPost(
            uri: "at://did:plc:abc123/app.bsky.feed.post/xyz789",
            cid: "bafyreiabc123",
            author: author,
            text: "Check out these photos!",
            embed: embed,
            createdAt: "2023-06-15T14:30:00Z"
        )

        let result = try await sut.translate(post)

        // Should have media attachments
        XCTAssertNotNil(result.mediaAttachments)
        XCTAssertEqual(result.mediaAttachments?.count, 2)

        // First attachment
        let first = result.mediaAttachments?.first
        XCTAssertEqual(first?.type, .image)
        XCTAssertEqual(first?.url, "https://cdn.bsky.app/img1.jpg")
        XCTAssertEqual(first?.description, "A beautiful sunset")

        // Second attachment
        let second = result.mediaAttachments?[1]
        XCTAssertEqual(second?.type, .image)
        XCTAssertEqual(second?.url, "https://cdn.bsky.app/img2.jpg")
        XCTAssertNil(second?.description)
    }

    // MARK: - External Link Embed Tests

    func testTranslatePost_WithExternalLink_CreatesCard() async throws {
        let author = createMockProfile()
        let embed = ATProtoEmbed.external(
            ATProtoExternal(
                uri: "https://example.com/article",
                title: "Interesting Article",
                description: "A very interesting article about Swift",
                thumb: "https://example.com/thumb.jpg"
            )
        )
        let post = ATProtoPost(
            uri: "at://did:plc:abc123/app.bsky.feed.post/xyz789",
            cid: "bafyreiabc123",
            author: author,
            text: "Check this out!",
            embed: embed,
            createdAt: "2023-06-15T14:30:00Z"
        )

        let result = try await sut.translate(post)

        // Should have card
        XCTAssertNotNil(result.card)
        XCTAssertEqual(result.card?.url, "https://example.com/article")
        XCTAssertEqual(result.card?.title, "Interesting Article")
        XCTAssertEqual(result.card?.description, "A very interesting article about Swift")
        XCTAssertEqual(result.card?.image, "https://example.com/thumb.jpg")
    }

    // MARK: - Date Parsing Tests

    func testTranslatePost_WithValidDate_ParsesCorrectly() async throws {
        let author = createMockProfile()
        let post = ATProtoPost(
            uri: "at://did:plc:abc123/app.bsky.feed.post/xyz789",
            cid: "bafyreiabc123",
            author: author,
            text: "Test post",
            createdAt: "2023-06-15T14:30:00.123Z"
        )

        let result = try await sut.translate(post)

        // Should parse date
        XCTAssertNotNil(result.createdAt)

        // Date should be in 2023
        let calendar = Calendar.current
        let year = calendar.component(.year, from: result.createdAt)
        XCTAssertEqual(year, 2023)
    }

    // MARK: - Visibility Tests

    func testTranslatePost_DefaultVisibility_IsPublic() async throws {
        let author = createMockProfile()
        let post = ATProtoPost(
            uri: "at://did:plc:abc123/app.bsky.feed.post/xyz789",
            cid: "bafyreiabc123",
            author: author,
            text: "Test post",
            createdAt: "2023-06-15T14:30:00Z"
        )

        let result = try await sut.translate(post)

        // Default visibility should be public
        XCTAssertEqual(result.visibility, .public)
    }

    // MARK: - URI and URL Tests

    func testTranslatePost_GeneratesCorrectURI() async throws {
        let author = createMockProfile()
        let post = ATProtoPost(
            uri: "at://did:plc:abc123/app.bsky.feed.post/xyz789",
            cid: "bafyreiabc123",
            author: author,
            text: "Test post",
            createdAt: "2023-06-15T14:30:00Z"
        )

        let result = try await sut.translate(post)

        // URI should match the Bluesky post URL
        XCTAssertTrue(result.uri.contains("bsky.app"))
        XCTAssertTrue(result.uri.contains("post"))
    }

    // MARK: - Helper Methods

    private func createMockProfile() -> ATProtoProfile {
        return ATProtoProfile(
            did: "did:plc:abc123",
            handle: "alice.bsky.social",
            displayName: "Alice",
            description: nil,
            avatar: nil,
            banner: nil,
            followersCount: 100,
            followsCount: 50,
            postsCount: 25,
            indexedAt: nil
        )
    }
}
