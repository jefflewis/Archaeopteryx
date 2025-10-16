import Foundation
import ATProtoAdapter
import MastodonModels
import IDMapping
import Crypto

/// Translates AT Protocol profiles to Mastodon accounts
public struct ProfileTranslator: Sendable {
    private let idMapping: any IDMappingProtocol & Sendable
    private let facetProcessor: FacetProcessor

    public init(idMapping: any IDMappingProtocol, facetProcessor: FacetProcessor) {
        self.idMapping = idMapping
        self.facetProcessor = facetProcessor
    }

    /// Translate an AT Protocol profile to a Mastodon account
    public func translate(_ profile: ATProtoProfile) async throws -> MastodonAccount {
        // Get Snowflake ID for this DID
        let snowflakeID = await idMapping.getSnowflakeID(forDID: profile.did)

        // Extract username from handle (part before first dot)
        let username = extractUsername(from: profile.handle)

        // Use display name or fall back to handle
        let displayName = profile.displayName?.isEmpty == false ?
            profile.displayName! : profile.handle

        // Process bio/description to HTML
        let note = processDescription(profile.description)

        // Generate profile URL
        let profileURL = generateProfileURL(for: profile.handle)

        // Use avatar or provide fallback
        let avatar = profile.avatar ?? generateDefaultAvatar(for: profile.handle)
        let avatarStatic = avatar // Bluesky doesn't have animated avatars

        // Use banner or provide fallback
        let header = profile.banner ?? generateDefaultHeader()
        let headerStatic = header

        // Parse created date or use current date
        let createdAt = parseDate(profile.indexedAt) ?? Date()

        return MastodonAccount(
            id: String(snowflakeID),
            username: username,
            acct: profile.handle,
            displayName: displayName,
            note: note,
            url: profileURL,
            avatar: avatar,
            avatarStatic: avatarStatic,
            header: header,
            headerStatic: headerStatic,
            followersCount: profile.followersCount,
            followingCount: profile.followsCount,
            statusesCount: profile.postsCount,
            createdAt: createdAt,
            bot: false,
            locked: false,
            fields: nil,
            emojis: nil
        )
    }

    // MARK: - Private Helpers

    /// Extract username from handle (part before first dot)
    private func extractUsername(from handle: String) -> String {
        return handle.components(separatedBy: ".").first ?? handle
    }

    /// Process description/bio to HTML
    private func processDescription(_ description: String?) -> String {
        guard let description = description, !description.isEmpty else {
            return "<p></p>"
        }

        // For now, treat as plain text (no facets in profile descriptions yet)
        return facetProcessor.processText(description, facets: nil)
    }

    /// Generate profile URL for Bluesky
    private func generateProfileURL(for handle: String) -> String {
        return "https://bsky.app/profile/\(handle)"
    }

    /// Generate default avatar using Gravatar
    private func generateDefaultAvatar(for handle: String) -> String {
        // Use Gravatar with handle as email
        let email = "\(handle)@gravatar.com"
        let hash = MD5(string: email)
        return "https://www.gravatar.com/avatar/\(hash)?d=identicon"
    }

    /// Generate default header/banner image
    private func generateDefaultHeader() -> String {
        // Return empty string for now, or a default gradient
        return ""
    }

    /// Parse ISO8601 date string
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

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

    /// Calculate MD5 hash for Gravatar
    private func MD5(string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
