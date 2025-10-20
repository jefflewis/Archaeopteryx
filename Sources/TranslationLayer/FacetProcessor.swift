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
        // Handle empty or nil facets - auto-link URLs and return wrapped in paragraph
        guard let facets = facets, !facets.isEmpty else {
            let processedText = autoLinkURLs(in: text)
            return wrapInParagraph(processedText.replacingOccurrences(of: "\n", with: "<br>"))
        }

        // Sort facets by start position
        let sortedFacets = facets.sorted { $0.index.start < $1.index.start }

        // Convert text to UTF-8 data for byte-based indexing
        let utf8Data = Data(text.utf8)
        var result = ""
        var lastByteIndex = 0

        for facet in sortedFacets {
            // Add text before this facet (with auto-linking for unfaceted URLs)
            if lastByteIndex < facet.index.start {
                let beforeRange = lastByteIndex..<facet.index.start
                if let beforeText = extractText(from: utf8Data, range: beforeRange) {
                    let processedBefore = autoLinkURLs(in: beforeText)
                    result += processedBefore.replacingOccurrences(of: "\n", with: "<br>")
                }
            }

            // Process the facet
            let facetRange = facet.index.start..<facet.index.end
            if let facetText = extractText(from: utf8Data, range: facetRange) {
                result += processFacet(text: facetText, features: facet.features)
            }

            lastByteIndex = facet.index.end
        }

        // Add remaining text after last facet (with auto-linking for unfaceted URLs)
        if lastByteIndex < utf8Data.count {
            let remainingRange = lastByteIndex..<utf8Data.count
            if let remainingText = extractText(from: utf8Data, range: remainingRange) {
                let processedRemaining = autoLinkURLs(in: remainingText)
                result += processedRemaining.replacingOccurrences(of: "\n", with: "<br>")
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
    
    /// Auto-link URLs in plain text (for text without facets)
    /// Detects URLs and converts them to clickable links
    private func autoLinkURLs(in text: String) -> String {
        let escapedText = escapeHTML(text)
        
        // Regular expression to match URLs
        // Matches http://, https://, and www. URLs
        let urlPattern = #"(?:https?://|www\.)[^\s<>\"']+"#
        
        guard let regex = try? NSRegularExpression(pattern: urlPattern, options: []) else {
            return escapedText
        }
        
        let nsString = escapedText as NSString
        let matches = regex.matches(in: escapedText, options: [], range: NSRange(location: 0, length: nsString.length))
        
        // Process matches in reverse order to maintain string positions
        var result = escapedText
        for match in matches.reversed() {
            let matchRange = match.range
            let matchedURL = nsString.substring(with: matchRange)
            
            // Ensure URL has protocol
            let fullURL = matchedURL.hasPrefix("www.") ? "https://\(matchedURL)" : matchedURL
            
            // Create link HTML
            let link = "<a href=\"\(fullURL)\" target=\"_blank\" rel=\"nofollow noopener noreferrer\">\(matchedURL)</a>"
            
            // Replace in result string
            if let range = Range(matchRange, in: result) {
                result.replaceSubrange(range, with: link)
            }
        }
        
        return result
    }
}
