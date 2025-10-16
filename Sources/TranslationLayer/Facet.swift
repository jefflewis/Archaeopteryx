import Foundation

/// Represents a rich text facet from AT Protocol
/// Facets are used to annotate text with links, mentions, hashtags, etc.
public struct Facet: Codable, Sendable, Equatable {
    /// Byte slice indicating where this facet applies in the text
    public let index: ByteSlice

    /// Features of this facet (link, mention, tag, etc.)
    public let features: [Feature]

    public init(index: ByteSlice, features: [Feature]) {
        self.index = index
        self.features = features
    }
}

/// Byte range for a facet
public struct ByteSlice: Codable, Sendable, Equatable {
    /// Start byte index (inclusive)
    public let start: Int

    /// End byte index (exclusive)
    public let end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }
}

/// Facet feature types
public enum Feature: Codable, Sendable, Equatable {
    /// Link to an external URL
    case link(uri: String)

    /// Mention of another user
    case mention(did: String)

    /// Hashtag
    case tag(tag: String)

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case uri
        case did
        case tag
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "app.bsky.richtext.facet#link":
            let uri = try container.decode(String.self, forKey: .uri)
            self = .link(uri: uri)

        case "app.bsky.richtext.facet#mention":
            let did = try container.decode(String.self, forKey: .did)
            self = .mention(did: did)

        case "app.bsky.richtext.facet#tag":
            let tag = try container.decode(String.self, forKey: .tag)
            self = .tag(tag: tag)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown facet type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .link(let uri):
            try container.encode("app.bsky.richtext.facet#link", forKey: .type)
            try container.encode(uri, forKey: .uri)

        case .mention(let did):
            try container.encode("app.bsky.richtext.facet#mention", forKey: .type)
            try container.encode(did, forKey: .did)

        case .tag(let tag):
            try container.encode("app.bsky.richtext.facet#tag", forKey: .type)
            try container.encode(tag, forKey: .tag)
        }
    }
}
