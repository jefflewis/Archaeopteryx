import Foundation
import ATProtoAdapter
import MastodonModels
import IDMapping
import ArchaeopteryxCore

/// Translates AT Protocol notifications to Mastodon notifications
public struct NotificationTranslator: Sendable {
    private let idMapping: any IDMappingProtocol & Sendable
    private let profileTranslator: ProfileTranslator
    private let statusTranslator: StatusTranslator

    public init(
        idMapping: any IDMappingProtocol,
        profileTranslator: ProfileTranslator,
        statusTranslator: StatusTranslator
    ) {
        self.idMapping = idMapping
        self.profileTranslator = profileTranslator
        self.statusTranslator = statusTranslator
    }

    /// Translate an AT Protocol notification to a Mastodon notification
    public func translate(
        _ notification: ATProtoNotification,
        sessionClient: ATProtoAdapter.SessionScopedClient? = nil,
        session: BlueskySessionData? = nil
    ) async throws -> MastodonNotification {
        // Get Snowflake ID for this notification's URI
        let snowflakeID = await idMapping.getSnowflakeID(forATURI: notification.uri)

        // Translate author profile
        let account = try await profileTranslator.translate(notification.author)

        // Map AT Protocol reason to Mastodon notification type
        let notificationType = mapNotificationType(notification.reason)

        // Parse created date
        let createdAt = parseDate(notification.indexedAt) ?? Date()

        // If this notification has a subject (like a post that was liked/reposted),
        // fetch and translate it
        var status: MastodonStatus? = nil
        if let reasonSubject = notification.reasonSubject,
           let sessionClient = sessionClient,
           let session = session {
            do {
                let post = try await sessionClient.getPost(uri: reasonSubject, session: session)
                status = try await statusTranslator.translate(post)
            } catch {
                // If we can't fetch the subject post, just omit it
                // This ensures notifications still work even if the post was deleted
            }
        }

        return MastodonNotification(
            id: String(snowflakeID),
            type: notificationType,
            createdAt: createdAt,
            account: account,
            status: status
        )
    }

    // MARK: - Private Helpers

    /// Map AT Protocol notification reason to Mastodon notification type
    private func mapNotificationType(_ reason: String) -> MastodonNotification.NotificationType {
        switch reason.lowercased() {
        case "like":
            return .favourite
        case "repost":
            return .reblog
        case "follow":
            return .follow
        case "mention":
            return .mention
        case "reply":
            return .mention // Treat replies as mentions in Mastodon
        case "quote":
            return .reblog // Treat quotes as reblogs in Mastodon
        default:
            return .mention // Default fallback
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
}
