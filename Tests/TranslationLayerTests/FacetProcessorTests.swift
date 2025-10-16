import XCTest
@testable import TranslationLayer

/// Tests for FacetProcessor - Rich text to HTML conversion
final class FacetProcessorTests: XCTestCase {
    var sut: FacetProcessor!

    override func setUp() async throws {
        try await super.setUp()
        sut = FacetProcessor()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Plain Text Tests

    func testProcessText_PlainText_WrapsInParagraph() {
        let text = "Hello world"
        let result = sut.processText(text, facets: nil)

        XCTAssertEqual(result, "<p>Hello world</p>")
    }

    func testProcessText_EmptyText_ReturnsEmptyParagraph() {
        let text = ""
        let result = sut.processText(text, facets: nil)

        XCTAssertEqual(result, "<p></p>")
    }

    func testProcessText_MultilineText_PreservesLineBreaks() {
        let text = "Line 1\nLine 2\nLine 3"
        let result = sut.processText(text, facets: nil)

        XCTAssertEqual(result, "<p>Line 1<br>Line 2<br>Line 3</p>")
    }

    func testProcessText_SpecialHTMLCharacters_EscapesCorrectly() {
        let text = "Test <script>alert('xss')</script> & \"quotes\""
        let result = sut.processText(text, facets: nil)

        XCTAssertTrue(result.contains("&lt;script&gt;"))
        XCTAssertTrue(result.contains("&amp;"))
        XCTAssertTrue(result.contains("&quot;") || result.contains("\""))
    }

    // MARK: - Link Processing Tests

    func testProcessFacets_WithLink_CreatesAnchorTag() {
        let text = "Check out https://bsky.app"
        let facets = [
            Facet(
                index: ByteSlice(start: 10, end: 26),
                features: [.link(uri: "https://bsky.app")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        XCTAssertTrue(result.contains("<a href=\"https://bsky.app\""))
        XCTAssertTrue(result.contains("target=\"_blank\""))
        XCTAssertTrue(result.contains("rel=\"nofollow noopener noreferrer\""))
    }

    func testProcessFacets_WithMultipleLinks_CreatesMultipleTags() {
        let text = "Visit https://bsky.app and https://example.com"
        let facets = [
            Facet(
                index: ByteSlice(start: 6, end: 22),
                features: [.link(uri: "https://bsky.app")]
            ),
            Facet(
                index: ByteSlice(start: 27, end: 46),
                features: [.link(uri: "https://example.com")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        XCTAssertTrue(result.contains("href=\"https://bsky.app\""))
        XCTAssertTrue(result.contains("href=\"https://example.com\""))
    }

    // MARK: - Mention Processing Tests

    func testProcessFacets_WithMention_CreatesSpanAndAnchor() {
        let text = "Hello @alice.bsky.social"
        let facets = [
            Facet(
                index: ByteSlice(start: 6, end: 24),
                features: [.mention(did: "did:plc:abc123")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        XCTAssertTrue(result.contains("<span class=\"h-card\">"))
        XCTAssertTrue(result.contains("class=\"u-url mention\""))
        XCTAssertTrue(result.contains("@alice.bsky.social"))
    }

    func testProcessFacets_WithMention_IncludesProperClasses() {
        let text = "@bob.bsky.social"
        let facets = [
            Facet(
                index: ByteSlice(start: 0, end: 16),
                features: [.mention(did: "did:plc:xyz789")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        XCTAssertTrue(result.contains("h-card"))
        XCTAssertTrue(result.contains("u-url mention"))
    }

    // MARK: - Hashtag Processing Tests

    func testProcessFacets_WithHashtag_CreatesProperLink() {
        let text = "Love #bluesky"
        let facets = [
            Facet(
                index: ByteSlice(start: 5, end: 13),
                features: [.tag(tag: "bluesky")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        XCTAssertTrue(result.contains("<a href=\""))
        XCTAssertTrue(result.contains("/hashtag/bluesky\""))
        XCTAssertTrue(result.contains("class=\"mention hashtag\""))
        XCTAssertTrue(result.contains("#bluesky"))
    }

    func testProcessFacets_WithMultipleHashtags_ProcessesAll() {
        let text = "#swift #programming is fun"
        let facets = [
            Facet(
                index: ByteSlice(start: 0, end: 6),
                features: [.tag(tag: "swift")]
            ),
            Facet(
                index: ByteSlice(start: 7, end: 19),
                features: [.tag(tag: "programming")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        XCTAssertTrue(result.contains("#swift"))
        XCTAssertTrue(result.contains("#programming"))
    }

    // MARK: - Complex Scenarios

    func testProcessFacets_MixedFacets_ProcessesInOrder() {
        let text = "Hello @alice.bsky.social! Check out https://bsky.app #bluesky"
        let facets = [
            Facet(
                index: ByteSlice(start: 6, end: 24),
                features: [.mention(did: "did:plc:abc123")]
            ),
            Facet(
                index: ByteSlice(start: 36, end: 52),
                features: [.link(uri: "https://bsky.app")]
            ),
            Facet(
                index: ByteSlice(start: 53, end: 61),
                features: [.tag(tag: "bluesky")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        // Verify all facets are present
        XCTAssertTrue(result.contains("@alice.bsky.social"))
        XCTAssertTrue(result.contains("https://bsky.app"))
        XCTAssertTrue(result.contains("#bluesky"))
    }

    func testProcessFacets_NoFacets_ReturnsPlainTextInParagraph() {
        let text = "Just plain text"
        let result = sut.processText(text, facets: nil)

        XCTAssertEqual(result, "<p>Just plain text</p>")
    }

    func testProcessFacets_EmptyFacetsArray_ReturnsPlainTextInParagraph() {
        let text = "Just plain text"
        let result = sut.processText(text, facets: [])

        XCTAssertEqual(result, "<p>Just plain text</p>")
    }

    // MARK: - Edge Cases

    func testProcessFacets_FacetAtStartOfText_ProcessesCorrectly() {
        let text = "#hashtag at start"
        let facets = [
            Facet(
                index: ByteSlice(start: 0, end: 8),
                features: [.tag(tag: "hashtag")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        XCTAssertTrue(result.contains("#hashtag"))
    }

    func testProcessFacets_FacetAtEndOfText_ProcessesCorrectly() {
        let text = "Link at end https://example.com"
        let facets = [
            Facet(
                index: ByteSlice(start: 12, end: 31),
                features: [.link(uri: "https://example.com")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        XCTAssertTrue(result.contains("href=\"https://example.com\""))
    }

    func testProcessFacets_AdjacentFacets_HandlesCorrectly() {
        let text = "@alice.bsky.social@bob.bsky.social"
        let facets = [
            Facet(
                index: ByteSlice(start: 0, end: 18),
                features: [.mention(did: "did:plc:alice")]
            ),
            Facet(
                index: ByteSlice(start: 18, end: 34), // Fixed: text is only 34 bytes
                features: [.mention(did: "did:plc:bob")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        XCTAssertTrue(result.contains("@alice.bsky.social"), "Result should contain first mention")
        XCTAssertTrue(result.contains("@bob.bsky.social"), "Result should contain second mention")
    }

    func testProcessText_VeryLongText_HandlesCorrectly() {
        let text = String(repeating: "Long text ", count: 100)
        let result = sut.processText(text, facets: nil)

        XCTAssertTrue(result.hasPrefix("<p>"))
        XCTAssertTrue(result.hasSuffix("</p>"))
        XCTAssertTrue(result.contains("Long text"))
    }

    // MARK: - UTF-8 Byte Index Tests

    func testProcessFacets_WithEmoji_HandlesUTF8ByteIndicesCorrectly() {
        // Emojis are multi-byte characters - test byte-based indexing
        // "Hello " = 6 bytes, "👋" = 4 bytes, " " = 1 byte, "@alice.bsky.social" = 18 bytes
        let text = "Hello 👋 @alice.bsky.social"
        let facets = [
            Facet(
                index: ByteSlice(start: 11, end: 29), // Byte indices: after emoji and space
                features: [.mention(did: "did:plc:abc123")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        XCTAssertTrue(result.contains("@alice.bsky.social"), "Result should contain mention")
        XCTAssertTrue(result.contains("👋"), "Result should contain emoji")
    }
}
