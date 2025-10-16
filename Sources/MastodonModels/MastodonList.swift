import Foundation

/// Represents a list of accounts that the user follows
public struct MastodonList: Codable, Equatable, Sendable {
    /// The internal database ID of the list
    public let id: String

    /// The user-defined title of the list
    public let title: String

    /// Which replies should be shown in the list
    public let repliesPolicy: MastodonListRepliesPolicy

    public init(
        id: String,
        title: String,
        repliesPolicy: MastodonListRepliesPolicy = .followed
    ) {
        self.id = id
        self.title = title
        self.repliesPolicy = repliesPolicy
    }
}

/// Replies policy for a list
public enum MastodonListRepliesPolicy: String, Codable, Sendable {
    /// Show replies to any followed user
    case followed

    /// Show replies to members of the list
    case list

    /// Show replies to no one
    case none
}
