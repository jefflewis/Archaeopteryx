import Foundation

/// Represents an authenticated session with the AT Protocol service
public struct ATProtoSession: Codable, Sendable {
    /// User's DID (Decentralized Identifier)
    public let did: String

    /// User's handle (e.g., "alice.bsky.social")
    public let handle: String

    /// Access token for API requests
    public let accessToken: String

    /// Refresh token for renewing the session
    public let refreshToken: String

    /// Optional email address
    public let email: String?

    /// When the session was created
    public let createdAt: Date

    /// When the access token expires (if known)
    public let expiresAt: Date?

    public init(
        did: String,
        handle: String,
        accessToken: String,
        refreshToken: String,
        email: String? = nil,
        createdAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.did = did
        self.handle = handle
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.email = email
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    /// Check if the session is expired
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else {
            return false // If no expiration, assume valid
        }
        return Date() > expiresAt
    }

    /// Check if the session is about to expire (within 5 minutes)
    public var needsRefresh: Bool {
        guard let expiresAt = expiresAt else {
            return false
        }
        let fiveMinutesFromNow = Date().addingTimeInterval(5 * 60)
        return fiveMinutesFromNow > expiresAt
    }
}
