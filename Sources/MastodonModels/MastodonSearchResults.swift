import Foundation

/// Search results from the Mastodon API
public struct MastodonSearchResults: Codable, Equatable, Sendable {
    /// Accounts matching the query
    public let accounts: [MastodonAccount]

    /// Statuses matching the query
    public let statuses: [MastodonStatus]

    /// Hashtags matching the query
    public let hashtags: [MastodonTag]

    public init(
        accounts: [MastodonAccount],
        statuses: [MastodonStatus],
        hashtags: [MastodonTag]
    ) {
        self.accounts = accounts
        self.statuses = statuses
        self.hashtags = hashtags
    }
}
