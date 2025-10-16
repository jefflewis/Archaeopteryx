import Foundation

/// Represents a hashtag used within the content of a status
public struct MastodonTag: Codable, Equatable, Sendable {
    /// The value of the hashtag after the # sign
    public let name: String

    /// A link to the hashtag on the instance
    public let url: String

    /// Usage statistics for given days (7 days by default)
    public let history: [MastodonTagHistory]?

    /// Optional: Whether this tag is being followed by the user (requires auth)
    public let following: Bool?

    public init(
        name: String,
        url: String,
        history: [MastodonTagHistory]? = nil,
        following: Bool? = nil
    ) {
        self.name = name
        self.url = url
        self.history = history
        self.following = following
    }
}

/// Usage statistics for a hashtag
public struct MastodonTagHistory: Codable, Equatable, Sendable {
    /// UNIX timestamp on midnight of the given day
    public let day: String

    /// Number of statuses using this hashtag
    public let uses: String

    /// Number of accounts using this hashtag
    public let accounts: String

    public init(day: String, uses: String, accounts: String) {
        self.day = day
        self.uses = uses
        self.accounts = accounts
    }
}
