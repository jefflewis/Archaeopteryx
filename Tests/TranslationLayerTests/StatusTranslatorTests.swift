import Foundation
import Testing
@testable import TranslationLayer
@testable import ATProtoAdapter
@testable import MastodonModels
@testable import IDMapping

/// Tests for StatusTranslator - ATProto post to MastodonStatus translation
@Suite struct StatusTranslatorTests {
    let sut: StatusTranslator
    var mockIDMapping: MockIDMappingService!
    var mockProfileTranslator: ProfileTranslator!
    var facetProcessor: FacetProcessor!

    init() async {
       mockIDMapping = MockIDMappingService()
        facetProcessor = FacetProcessor()
        mockProfileTranslator = ProfileTranslator(idMapping: mockIDMapping, facetProcessor: facetProcessor)
        sut = StatusTranslator(
            idMapping: mockIDMapping,
            profileTranslator: mockProfileTranslator,
            facetProcessor: facetProcessor
        )
    }

    // MARK: - Text-Only Post Tests

    @Test func TranslatePost_TextOnly_CreatesBasicStatus() async throws {
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
        #expect(result.id == "987654321")

        // Content should be wrapped in HTML
        #expect(result.content == "<p>Hello world!</p>")

        // Author should be translated
        #expect(result.account.id == "123456789")
        #expect(result.account.username == "alice")

        // Counts should be mapped
        #expect(result.favouritesCount == 5)
        #expect(result.reblogsCount == 2)
        #expect(result.repliesCount == 1)

        // Should not be a reply
        #expect(result.inReplyToId == nil)
        #expect(result.inReplyToAccountId == nil)

        // No reblog
        #expect(result.reblog == nil)
    }

    @Test func TranslatePost_EmptyText_CreatesEmptyParagraph() async throws {
        let author = createMockProfile()
        let post = ATProtoPost(
            uri: "at://did:plc:abc123/app.bsky.feed.post/xyz789",
            cid: "bafyreiabc123",
            author: author,
            text: "",
            createdAt: "2023-06-15T14:30:00Z"
        )

        let result = try await sut.translate(post)

        #expect(result.content == "<p></p>")
    }

    // MARK: - Facets Tests

    @Test func TranslatePost_WithFacets_ConvertsToHTML() async throws {
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
        #expect(result.content.contains("<a href="))
        #expect(result.content.contains("https://example.com"))
    }

    @Test func TranslatePost_WithMentions_ExtractsMentions() async throws {
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
        #expect(result.content.contains("h-card"))
        #expect(result.content.contains("mention"))

        // Should extract mention into mentions array
        #expect(result.mentions != nil)
        #expect(result.mentions?.count == 1)
        #expect(result.mentions?.first?.acct == "bob.bsky.social")
    }

    @Test func TranslatePost_WithHashtags_ExtractsTags() async throws {
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
        #expect(result.content.contains("hashtag"))
        #expect(result.content.contains("bluesky"))

        // Should extract tag into tags array
        #expect(result.tags != nil)
        #expect(result.tags?.count == 1)
        #expect(result.tags?.first?.name == "bluesky")
    }

    // MARK: - Reply Tests

    @Test func TranslatePost_Reply_SetsInReplyToFields() async throws {
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
        #expect(result.inReplyToId != nil)
        #expect(result.inReplyToId == "987654321")

        // Should set inReplyToAccountId
        #expect(result.inReplyToAccountId != nil)
        #expect(result.inReplyToAccountId == "123456789")
    }

    // MARK: - Image Embed Tests

    @Test func TranslatePost_WithImages_IncludesMediaAttachments() async throws {
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
        #expect(result.mediaAttachments != nil)
        #expect(result.mediaAttachments?.count == 2)

        // First attachment
        let first = result.mediaAttachments?.first
        #expect(first?.type == .image)
        #expect(first?.url == "https://cdn.bsky.app/img1.jpg")
        #expect(first?.description == "A beautiful sunset")

        // Second attachment
        let second = result.mediaAttachments?[1]
        #expect(second?.type == .image)
        #expect(second?.url == "https://cdn.bsky.app/img2.jpg")
        #expect(second?.description == nil)
    }

    // MARK: - External Link Embed Tests

    @Test func TranslatePost_WithExternalLink_CreatesCard() async throws {
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
        #expect(result.card != nil)
        #expect(result.card?.url == "https://example.com/article")
        #expect(result.card?.title == "Interesting Article")
        #expect(result.card?.description == "A very interesting article about Swift")
        #expect(result.card?.image == "https://example.com/thumb.jpg")
    }

    // MARK: - Date Parsing Tests

    @Test func TranslatePost_WithValidDate_ParsesCorrectly() async throws {
        let author = createMockProfile()
        let post = ATProtoPost(
            uri: "at://did:plc:abc123/app.bsky.feed.post/xyz789",
            cid: "bafyreiabc123",
            author: author,
            text: "Test post",
            createdAt: "2023-06-15T14:30:00.123Z"
        )

        let result = try await sut.translate(post)

        // Date should be in 2023
        let calendar = Calendar.current
        let year = calendar.component(.year, from: result.createdAt)
        #expect(year == 2023)
    }

    // MARK: - Visibility Tests

    @Test func TranslatePost_DefaultVisibility_IsPublic() async throws {
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
        #expect(result.visibility == .public)
    }

    // MARK: - URI and URL Tests

    @Test func TranslatePost_GeneratesCorrectURI() async throws {
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
        #expect(result.uri.contains("bsky.app"))
        #expect(result.uri.contains("post"))
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

