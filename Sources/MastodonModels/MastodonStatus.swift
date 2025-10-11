import Foundation

/// Mastodon-compatible status/post representation
/// Represents a Bluesky post in Mastodon API format
public struct MastodonStatus: Codable, Sendable, Equatable {
    /// The status ID (Snowflake ID as string)
    public let id: String

    /// The AT Protocol URI of the post
    public let uri: String

    /// The timestamp when the status was created
    public let createdAt: Date

    /// The account that posted this status
    public let account: MastodonAccount

    /// The content of the status (HTML)
    public let content: String

    /// Visibility of the status
    public let visibility: Visibility

    /// Number of replies to this status
    public let repliesCount: Int

    /// Number of boosts/reblogs
    public let reblogsCount: Int

    /// Number of favorites/likes
    public let favouritesCount: Int

    /// Whether the current user has reblogged this status
    public let reblogged: Bool

    /// Whether the current user has favorited this status
    public let favourited: Bool

    /// Whether media in this status should be hidden by default
    public let sensitive: Bool

    /// Content warning / spoiler text
    public let spoilerText: String

    /// Reply information
    public let inReplyToId: String?
    public let inReplyToAccountId: String?

    /// Optional fields
    public var reblog: Box<MastodonStatus>? // For reblogs/quotes
    public var mediaAttachments: [MediaAttachment]?
    public var mentions: [Mention]?
    public var tags: [Tag]?
    public var card: Card?
    public var application: ClientApplication?
    public var language: String?
    public var editedAt: Date?

    public init(
        id: String,
        uri: String,
        createdAt: Date,
        account: MastodonAccount,
        content: String,
        visibility: Visibility,
        repliesCount: Int,
        reblogsCount: Int,
        favouritesCount: Int,
        reblogged: Bool,
        favourited: Bool,
        sensitive: Bool,
        spoilerText: String,
        inReplyToId: String? = nil,
        inReplyToAccountId: String? = nil,
        reblog: Box<MastodonStatus>? = nil,
        mediaAttachments: [MediaAttachment]? = nil,
        mentions: [Mention]? = nil,
        tags: [Tag]? = nil,
        card: Card? = nil,
        application: ClientApplication? = nil,
        language: String? = nil,
        editedAt: Date? = nil
    ) {
        self.id = id
        self.uri = uri
        self.createdAt = createdAt
        self.account = account
        self.content = content
        self.visibility = visibility
        self.repliesCount = repliesCount
        self.reblogsCount = reblogsCount
        self.favouritesCount = favouritesCount
        self.reblogged = reblogged
        self.favourited = favourited
        self.sensitive = sensitive
        self.spoilerText = spoilerText
        self.inReplyToId = inReplyToId
        self.inReplyToAccountId = inReplyToAccountId
        self.reblog = reblog
        self.mediaAttachments = mediaAttachments
        self.mentions = mentions
        self.tags = tags
        self.card = card
        self.application = application
        self.language = language
        self.editedAt = editedAt
    }
}

/// Status visibility
public enum Visibility: String, Codable, Sendable, Equatable {
    case `public`
    case unlisted
    case `private`
    case direct
}

/// Media attachment
public struct MediaAttachment: Codable, Sendable, Equatable {
    public let id: String
    public let type: MediaType
    public let url: String
    public let previewUrl: String?
    public let description: String?

    public init(id: String, type: MediaType, url: String, previewUrl: String? = nil, description: String? = nil) {
        self.id = id
        self.type = type
        self.url = url
        self.previewUrl = previewUrl
        self.description = description
    }
}

public enum MediaType: String, Codable, Sendable, Equatable {
    case image
    case video
    case gifv
    case audio
    case unknown
}

/// Mention of another account
public struct Mention: Codable, Sendable, Equatable {
    public let id: String
    public let username: String
    public let acct: String
    public let url: String

    public init(id: String, username: String, acct: String, url: String) {
        self.id = id
        self.username = username
        self.acct = acct
        self.url = url
    }
}

/// Hashtag
public struct Tag: Codable, Sendable, Equatable {
    public let name: String
    public let url: String

    public init(name: String, url: String) {
        self.name = name
        self.url = url
    }
}

/// Link preview card
public struct Card: Codable, Sendable, Equatable {
    public let url: String
    public let title: String
    public let description: String
    public let type: CardType
    public let image: String?

    public init(url: String, title: String, description: String, type: CardType, image: String? = nil) {
        self.url = url
        self.title = title
        self.description = description
        self.type = type
        self.image = image
    }
}

public enum CardType: String, Codable, Sendable, Equatable {
    case link
    case photo
    case video
    case rich
}

/// Client application that posted the status
public struct ClientApplication: Codable, Sendable, Equatable {
    public let name: String
    public let website: String?

    public init(name: String, website: String? = nil) {
        self.name = name
        self.website = website
    }
}

/// Box type to avoid recursive struct issues with reblog
/// Using a class for indirection to break the recursive value type cycle
public final class Box<T: Codable>: Codable where T: Equatable, T: Sendable {
    public let value: T

    public init(_ value: T) {
        self.value = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(T.self)
    }
}

extension Box: Equatable where T: Equatable {
    public static func == (lhs: Box<T>, rhs: Box<T>) -> Bool {
        lhs.value == rhs.value
    }
}

extension Box: @unchecked Sendable where T: Sendable {}
