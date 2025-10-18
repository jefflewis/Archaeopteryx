import Testing
@testable import TranslationLayer

/// Tests for FacetProcessor - Rich text to HTML conversion
@Suite struct FacetProcessorTests {
    let sut: FacetProcessor

    init() async {
       sut = FacetProcessor()
    }

    // MARK: - Plain Text Tests

    @Test func ProcessText_PlainText_WrapsInParagraph() {
        let text = "Hello world"
        let result = sut.processText(text, facets: nil)

        #expect(result == "<p>Hello world</p>")
    }

    @Test func ProcessText_EmptyText_ReturnsEmptyParagraph() {
        let text = ""
        let result = sut.processText(text, facets: nil)

        #expect(result == "<p></p>")
    }

    @Test func ProcessText_MultilineText_PreservesLineBreaks() {
        let text = "Line 1\nLine 2\nLine 3"
        let result = sut.processText(text, facets: nil)

        #expect(result == "<p>Line 1<br>Line 2<br>Line 3</p>")
    }

    @Test func ProcessText_SpecialHTMLCharacters_EscapesCorrectly() {
        let text = "Test <script>alert('xss')</script> & \"quotes\""
        let result = sut.processText(text, facets: nil)

        #expect(result.contains("&lt;script&gt;"))
        #expect(result.contains("&amp;"))
        #expect(result.contains("&quot;") || result.contains("\""))
    }

    // MARK: - Link Processing Tests

    @Test func ProcessFacets_WithLink_CreatesAnchorTag() {
        let text = "Check out https://bsky.app"
        let facets = [
            Facet(
                index: ByteSlice(start: 10, end: 26),
                features: [.link(uri: "https://bsky.app")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        #expect(result.contains("<a href=\"https://bsky.app\""))
        #expect(result.contains("target=\"_blank\""))
        #expect(result.contains("rel=\"nofollow noopener noreferrer\""))
    }

    @Test func ProcessFacets_WithMultipleLinks_CreatesMultipleTags() {
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

        #expect(result.contains("href=\"https://bsky.app\""))
        #expect(result.contains("href=\"https://example.com\""))
    }

    // MARK: - Mention Processing Tests

    @Test func ProcessFacets_WithMention_CreatesSpanAndAnchor() {
        let text = "Hello @alice.bsky.social"
        let facets = [
            Facet(
                index: ByteSlice(start: 6, end: 24),
                features: [.mention(did: "did:plc:abc123")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        #expect(result.contains("<span class=\"h-card\">"))
        #expect(result.contains("class=\"u-url mention\""))
        #expect(result.contains("@alice.bsky.social"))
    }

    @Test func ProcessFacets_WithMention_IncludesProperClasses() {
        let text = "@bob.bsky.social"
        let facets = [
            Facet(
                index: ByteSlice(start: 0, end: 16),
                features: [.mention(did: "did:plc:xyz789")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        #expect(result.contains("h-card"))
        #expect(result.contains("u-url mention"))
    }

    // MARK: - Hashtag Processing Tests

    @Test func ProcessFacets_WithHashtag_CreatesProperLink() {
        let text = "Love #bluesky"
        let facets = [
            Facet(
                index: ByteSlice(start: 5, end: 13),
                features: [.tag(tag: "bluesky")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        #expect(result.contains("<a href=\""))
        #expect(result.contains("/hashtag/bluesky\""))
        #expect(result.contains("class=\"mention hashtag\""))
        #expect(result.contains("#bluesky"))
    }

    @Test func ProcessFacets_WithMultipleHashtags_ProcessesAll() {
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

        #expect(result.contains("#swift"))
        #expect(result.contains("#programming"))
    }

    // MARK: - Complex Scenarios

    @Test func ProcessFacets_MixedFacets_ProcessesInOrder() {
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
        #expect(result.contains("@alice.bsky.social"))
        #expect(result.contains("https://bsky.app"))
        #expect(result.contains("#bluesky"))
    }

    @Test func ProcessFacets_NoFacets_ReturnsPlainTextInParagraph() {
        let text = "Just plain text"
        let result = sut.processText(text, facets: nil)

        #expect(result == "<p>Just plain text</p>")
    }

    @Test func ProcessFacets_EmptyFacetsArray_ReturnsPlainTextInParagraph() {
        let text = "Just plain text"
        let result = sut.processText(text, facets: [])

        #expect(result == "<p>Just plain text</p>")
    }

    // MARK: - Edge Cases

    @Test func ProcessFacets_FacetAtStartOfText_ProcessesCorrectly() {
        let text = "#hashtag at start"
        let facets = [
            Facet(
                index: ByteSlice(start: 0, end: 8),
                features: [.tag(tag: "hashtag")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        #expect(result.contains("#hashtag"))
    }

    @Test func ProcessFacets_FacetAtEndOfText_ProcessesCorrectly() {
        let text = "Link at end https://example.com"
        let facets = [
            Facet(
                index: ByteSlice(start: 12, end: 31),
                features: [.link(uri: "https://example.com")]
            )
        ]

        let result = sut.processText(text, facets: facets)

        #expect(result.contains("href=\"https://example.com\""))
    }

    @Test func ProcessFacets_AdjacentFacets_HandlesCorrectly() {
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

        #expect(result.contains("@alice.bsky.social"), "Result should contain first mention")
        #expect(result.contains("@bob.bsky.social"), "Result should contain second mention")
    }

    @Test func ProcessText_VeryLongText_HandlesCorrectly() {
        let text = String(repeating: "Long text ", count: 100)
        let result = sut.processText(text, facets: nil)

        #expect(result.hasPrefix("<p>"))
        #expect(result.hasSuffix("</p>"))
        #expect(result.contains("Long text"))
    }

    // MARK: - UTF-8 Byte Index Tests

    @Test func ProcessFacets_WithEmoji_HandlesUTF8ByteIndicesCorrectly() {
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

        #expect(result.contains("@alice.bsky.social"), "Result should contain mention")
        #expect(result.contains("👋"), "Result should contain emoji")
    }
}

