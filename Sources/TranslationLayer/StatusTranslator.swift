import Foundation
import ATProtoAdapter
import MastodonModels
import IDMapping

/// Translates AT Protocol posts to Mastodon statuses
public struct StatusTranslator: Sendable {
    private let idMapping: any IDMappingProtocol & Sendable
    private let profileTranslator: ProfileTranslator
    private let facetProcessor: FacetProcessor

    public init(
        idMapping: any IDMappingProtocol,
        profileTranslator: ProfileTranslator,
        facetProcessor: FacetProcessor
    ) {
        self.idMapping = idMapping
        self.profileTranslator = profileTranslator
        self.facetProcessor = facetProcessor
    }

    /// Translate an AT Protocol post to a Mastodon status
    public func translate(_ post: ATProtoPost) async throws -> MastodonStatus {
        // Get Snowflake ID for this post's AT URI
        let snowflakeID = await idMapping.getSnowflakeID(forATURI: post.uri)

        // Translate author profile
        let account = try await profileTranslator.translate(post.author)

        // Convert facets from ATProto format to TranslationLayer format
        let translatedFacets = convertFacets(post.facets)

        // Process text with facets to HTML
        let content = facetProcessor.processText(post.text, facets: translatedFacets)

        // Extract mentions from facets
        let mentions = extractMentions(from: post.facets, text: post.text)

        // Extract hashtags from facets
        let tags = extractTags(from: post.facets)

        // Process embeds (images, external links, etc.)
        let mediaAttachments = processMediaEmbeds(post.embed)
        let card = processExternalEmbed(post.embed)

        // Parse created date
        let createdAt = parseDate(post.createdAt) ?? Date()

        // Handle replies
        var inReplyToId: String?
        var inReplyToAccountId: String?

        if let replyTo = post.replyTo {
            inReplyToId = String(await idMapping.getSnowflakeID(forATURI: replyTo))

            // Extract DID from AT URI to get account ID
            if let replyAuthorDID = extractDIDFromATURI(replyTo) {
                inReplyToAccountId = String(await idMapping.getSnowflakeID(forDID: replyAuthorDID))
            }
        }

        // Generate URI (Bluesky post URL)
        let uri = generatePostURI(from: post)

        return MastodonStatus(
            id: String(snowflakeID),
            uri: uri,
            createdAt: createdAt,
            account: account,
            content: content,
            visibility: .public,
            repliesCount: post.replyCount,
            reblogsCount: post.repostCount,
            favouritesCount: post.likeCount,
            reblogged: post.isReposted,
            favourited: post.isLiked,
            sensitive: false,
            spoilerText: "",
            inReplyToId: inReplyToId,
            inReplyToAccountId: inReplyToAccountId,
            reblog: nil,
            mediaAttachments: mediaAttachments,
            mentions: mentions,
            tags: tags,
            card: card,
            application: nil,
            language: nil,
            editedAt: nil
        )
    }

    // MARK: - Private Helpers

    /// Convert AT Proto facets to TranslationLayer facets
    private func convertFacets(_ atProtoFacets: [ATProtoFacet]?) -> [Facet]? {
        guard let atProtoFacets = atProtoFacets, !atProtoFacets.isEmpty else {
            return nil
        }

        return atProtoFacets.map { atProtoFacet in
            let features = atProtoFacet.features.map { feature -> Feature in
                switch feature {
                case .link(let uri):
                    return .link(uri: uri)
                case .mention(let did):
                    return .mention(did: did)
                case .tag(let tag):
                    return .tag(tag: tag)
                }
            }

            return Facet(
                index: ByteSlice(
                    start: atProtoFacet.index.byteStart,
                    end: atProtoFacet.index.byteEnd
                ),
                features: features
            )
        }
    }

    /// Extract mentions from facets and text
    private func extractMentions(from facets: [ATProtoFacet]?, text: String) -> [Mention]? {
        guard let facets = facets else { return nil }

        let mentions = facets.compactMap { facet -> Mention? in
            for feature in facet.features {
                if case .mention(let did) = feature {
                    // Extract the actual mention text from the post using byte indices
                    let handle = extractTextFromFacet(facet, text: text) ?? extractHandleFromDID(did)

                    // Remove @ prefix if present
                    let cleanHandle = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle

                    // Generate a snowflake ID for the mention
                    // Note: This would ideally be async, but for now we use a placeholder
                    return Mention(
                        id: String(abs(did.hashValue)),
                        username: extractUsername(from: cleanHandle),
                        acct: cleanHandle,
                        url: "https://bsky.app/profile/\(cleanHandle)"
                    )
                }
            }
            return nil
        }

        return mentions.isEmpty ? nil : mentions
    }

    /// Extract text from facet using byte indices
    private func extractTextFromFacet(_ facet: ATProtoFacet, text: String) -> String? {
        let utf8Data = Data(text.utf8)
        let start = facet.index.byteStart
        let end = facet.index.byteEnd

        guard start >= 0 && end <= utf8Data.count && start < end else {
            return nil
        }

        let range = start..<end
        let subdata = utf8Data.subdata(in: range)
        return String(data: subdata, encoding: .utf8)
    }

    /// Extract username from handle (part before first dot)
    private func extractUsername(from handle: String) -> String {
        return handle.components(separatedBy: ".").first ?? handle
    }

    /// Extract hashtags from facets
    private func extractTags(from facets: [ATProtoFacet]?) -> [Tag]? {
        guard let facets = facets else { return nil }

        let tags = facets.compactMap { facet -> Tag? in
            for feature in facet.features {
                if case .tag(let tag) = feature {
                    return Tag(
                        name: tag,
                        url: "https://bsky.app/hashtag/\(tag)"
                    )
                }
            }
            return nil
        }

        return tags.isEmpty ? nil : tags
    }

    /// Process media embeds (images)
    private func processMediaEmbeds(_ embed: ATProtoEmbed?) -> [MediaAttachment]? {
        guard let embed = embed else { return nil }

        switch embed {
        case .images(let images):
            return images.map { image in
                MediaAttachment(
                    id: String(abs(image.url.hashValue)), // Generate ID from URL hash
                    type: .image,
                    url: image.url,
                    previewUrl: image.url,
                    description: image.alt
                )
            }
        default:
            return nil
        }
    }

    /// Process external link embed as card
    private func processExternalEmbed(_ embed: ATProtoEmbed?) -> Card? {
        guard let embed = embed else { return nil }

        switch embed {
        case .external(let external):
            return Card(
                url: external.uri,
                title: external.title,
                description: external.description,
                type: .link,
                image: external.thumb
            )
        default:
            return nil
        }
    }

    /// Parse ISO8601 date string
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try with fractional seconds first
        if let date = formatter.date(from: dateString) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    /// Extract DID from AT URI
    /// Example: "at://did:plc:abc123/app.bsky.feed.post/xyz" -> "did:plc:abc123"
    private func extractDIDFromATURI(_ atURI: String) -> String? {
        let components = atURI.components(separatedBy: "/")
        guard components.count >= 3 else { return nil }

        let didPart = components[2]
        return didPart.hasPrefix("did:") ? didPart : nil
    }

    /// Extract handle from DID (placeholder - would need lookup)
    private func extractHandleFromDID(_ did: String) -> String {
        // In a real implementation, this would look up the handle from the DID
        // For now, return a placeholder based on the DID
        return did.replacingOccurrences(of: "did:plc:", with: "") + ".bsky.social"
    }

    /// Generate post URI for Bluesky
    private func generatePostURI(from post: ATProtoPost) -> String {
        let handle = post.author.handle
        // Extract post ID from AT URI
        let components = post.uri.components(separatedBy: "/")
        let postID = components.last ?? "unknown"

        return "https://bsky.app/profile/\(handle)/post/\(postID)"
    }
}
