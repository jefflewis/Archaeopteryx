import Foundation

/// Mastodon API notification model
public struct MastodonNotification: Codable, Sendable {
    /// The ID of the notification
    public let id: String

    /// The type of notification
    public let type: NotificationType

    /// The timestamp of the notification
    public let createdAt: Date

    /// The account that performed the action that generated the notification
    public let account: MastodonAccount

    /// The status that was the subject of the notification (for likes, reposts, etc.)
    public let status: MastodonStatus?

    public init(
        id: String,
        type: NotificationType,
        createdAt: Date,
        account: MastodonAccount,
        status: MastodonStatus? = nil
    ) {
        self.id = id
        self.type = type
        self.createdAt = createdAt
        self.account = account
        self.status = status
    }

    /// Notification types supported by Mastodon
    public enum NotificationType: String, Codable, Sendable {
        /// Someone mentioned you in their status
        case mention

        /// Someone you enabled notifications for has posted a status
        case status

        /// Someone boosted one of your statuses
        case reblog

        /// Someone favourited one of your statuses
        case favourite

        /// Someone followed you
        case follow

        /// Someone requested to follow you
        case followRequest = "follow_request"

        /// A poll you have voted in or created has ended
        case poll

        /// Someone edited a status you interacted with
        case update

        /// Someone signed up (admins only)
        case adminSignUp = "admin.sign_up"

        /// A new report has been filed (admins only)
        case adminReport = "admin.report"
    }
}
