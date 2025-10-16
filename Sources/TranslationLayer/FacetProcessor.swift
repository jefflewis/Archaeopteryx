import Foundation

/// Processes AT Protocol rich text facets into HTML
public struct FacetProcessor: Sendable {
    public init() {}

    /// Process text with facets to generate HTML
    /// - Parameters:
    ///   - text: The plain text content
    ///   - facets: Optional array of facets to apply
    /// - Returns: HTML-formatted string
    public func processText(_ text: String, facets: [Facet]?) -> String {
        // Handle empty or nil facets - return plain text wrapped in paragraph
        guard let facets = facets, !facets.isEmpty else {
            return wrapInParagraph(escapeHTML(text).replacingOccurrences(of: "\n", with: "<br>"))
        }

        // Sort facets by start position
        let sortedFacets = facets.sorted { $0.index.start < $1.index.start }

        // Convert text to UTF-8 data for byte-based indexing
        let utf8Data = Data(text.utf8)
        var result = ""
        var lastByteIndex = 0

        for facet in sortedFacets {
            // Add text before this facet
            if lastByteIndex < facet.index.start {
                let beforeRange = lastByteIndex..<facet.index.start
                if let beforeText = extractText(from: utf8Data, range: beforeRange) {
                    result += escapeHTML(beforeText).replacingOccurrences(of: "\n", with: "<br>")
                }
            }

            // Process the facet
            let facetRange = facet.index.start..<facet.index.end
            if let facetText = extractText(from: utf8Data, range: facetRange) {
                result += processFacet(text: facetText, features: facet.features)
            }

            lastByteIndex = facet.index.end
        }

        // Add remaining text after last facet
        if lastByteIndex < utf8Data.count {
            let remainingRange = lastByteIndex..<utf8Data.count
            if let remainingText = extractText(from: utf8Data, range: remainingRange) {
                result += escapeHTML(remainingText).replacingOccurrences(of: "\n", with: "<br>")
            }
        }

        return wrapInParagraph(result)
    }

    // MARK: - Private Helpers

    /// Extract text from UTF-8 data using byte range
    private func extractText(from data: Data, range: Range<Int>) -> String? {
        guard range.lowerBound >= 0 && range.upperBound <= data.count else {
            return nil
        }
        let subdata = data.subdata(in: range)
        return String(data: subdata, encoding: .utf8)
    }

    /// Process a single facet into HTML
    private func processFacet(text: String, features: [Feature]) -> String {
        // Process the first feature (typically only one per facet)
        guard let feature = features.first else {
            return escapeHTML(text)
        }

        switch feature {
        case .link(let uri):
            return processLink(text: text, uri: uri)

        case .mention(let did):
            return processMention(text: text, did: did)

        case .tag(let tag):
            return processHashtag(text: text, tag: tag)
        }
    }

    /// Process a link facet
    private func processLink(text: String, uri: String) -> String {
        let escapedURI = escapeHTML(uri)
        let escapedText = escapeHTML(text)
        return "<a href=\"\(escapedURI)\" target=\"_blank\" rel=\"nofollow noopener noreferrer\">\(escapedText)</a>"
    }

    /// Process a mention facet
    private func processMention(text: String, did: String) -> String {
        let escapedText = escapeHTML(text)
        // Extract handle from text (should start with @)
        let handle = escapedText.hasPrefix("@") ? escapedText : "@\(escapedText)"

        // Create Mastodon-compatible mention HTML
        // TODO: Replace bsky.app with configurable domain
        let profileURL = "https://bsky.app/profile/\(handle.dropFirst())"

        return "<span class=\"h-card\"><a href=\"\(profileURL)\" class=\"u-url mention\">\(handle)</a></span>"
    }

    /// Process a hashtag facet
    private func processHashtag(text: String, tag: String) -> String {
        let escapedTag = escapeHTML(tag)
        let escapedText = escapeHTML(text)

        // Ensure text has # prefix
        let displayText = escapedText.hasPrefix("#") ? escapedText : "#\(escapedText)"

        // Create Mastodon-compatible hashtag HTML
        // TODO: Replace bsky.app with configurable domain
        let hashtagURL = "https://bsky.app/hashtag/\(escapedTag)"

        return "<a href=\"\(hashtagURL)\" class=\"mention hashtag\">\(displayText)</a>"
    }

    /// Escape HTML special characters
    private func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    /// Wrap content in paragraph tags
    private func wrapInParagraph(_ content: String) -> String {
        return "<p>\(content)</p>"
    }
}
