import Foundation

/// Mastodon-compatible account representation
/// Represents a Bluesky user profile in Mastodon API format
public struct MastodonAccount: Codable, Sendable, Equatable {
    /// The account ID (Snowflake ID as string)
    public let id: String

    /// The username (handle without domain)
    public let username: String

    /// The full account name (handle with domain for remote accounts)
    public let acct: String

    /// The account's display name
    public let displayName: String

    /// The account's bio/description (HTML)
    public let note: String

    /// URL to the account's profile page
    public let url: String

    /// URL to the account's avatar image
    public let avatar: String

    /// URL to the account's static avatar (same as avatar for Bluesky)
    public let avatarStatic: String

    /// URL to the account's header image
    public let header: String

    /// URL to the account's static header (same as header for Bluesky)
    public let headerStatic: String

    /// Number of followers
    public let followersCount: Int

    /// Number of accounts being followed
    public let followingCount: Int

    /// Number of statuses/posts
    public let statusesCount: Int

    /// Account creation date
    public let createdAt: Date

    /// Whether this is a bot account
    public let bot: Bool

    /// Whether the account is locked (requires follow approval)
    public let locked: Bool

    /// Optional fields for Mastodon compatibility
    public var fields: [Field]?
    public var emojis: [CustomEmoji]?

    public init(
        id: String,
        username: String,
        acct: String,
        displayName: String,
        note: String,
        url: String,
        avatar: String,
        avatarStatic: String,
        header: String,
        headerStatic: String,
        followersCount: Int,
        followingCount: Int,
        statusesCount: Int,
        createdAt: Date,
        bot: Bool,
        locked: Bool,
        fields: [Field]? = nil,
        emojis: [CustomEmoji]? = nil
    ) {
        self.id = id
        self.username = username
        self.acct = acct
        self.displayName = displayName
        self.note = note
        self.url = url
        self.avatar = avatar
        self.avatarStatic = avatarStatic
        self.header = header
        self.headerStatic = headerStatic
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.statusesCount = statusesCount
        self.createdAt = createdAt
        self.bot = bot
        self.locked = locked
        self.fields = fields
        self.emojis = emojis
    }
}

/// Profile field (name/value pair)
public struct Field: Codable, Sendable, Equatable {
    public let name: String
    public let value: String
    public let verifiedAt: Date?

    public init(name: String, value: String, verifiedAt: Date? = nil) {
        self.name = name
        self.value = value
        self.verifiedAt = verifiedAt
    }
}

/// Custom emoji
public struct CustomEmoji: Codable, Sendable, Equatable {
    public let shortcode: String
    public let url: String
    public let staticUrl: String

    public init(shortcode: String, url: String, staticUrl: String) {
        self.shortcode = shortcode
        self.url = url
        self.staticUrl = staticUrl
    }
}
