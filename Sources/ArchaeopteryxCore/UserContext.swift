import Foundation

// MARK: - User Context

/// Context for an authenticated user request
/// Contains user identity and session information for API calls
public struct UserContext: Codable, Sendable, Equatable {
    /// User's AT Protocol DID (Decentralized Identifier)
    public let did: String

    /// User's Bluesky handle (e.g., "alice.bsky.social")
    public let handle: String

    /// Bluesky session data for API calls
    public let sessionData: BlueskySessionData

    public init(did: String, handle: String, sessionData: BlueskySessionData) {
        self.did = did
        self.handle = handle
        self.sessionData = sessionData
    }
}

// MARK: - Bluesky Session Data

/// Bluesky AT Protocol session data
/// Stored in Valkey/Redis for each authenticated user
public struct BlueskySessionData: Codable, Sendable, Equatable {
    /// AT Protocol access token
    public let accessToken: String

    /// AT Protocol refresh token
    public let refreshToken: String

    /// User's DID
    public let did: String

    /// User's handle
    public let handle: String

    /// User's email (optional)
    public let email: String?

    /// When the session was created
    public let createdAt: Date

    public init(
        accessToken: String,
        refreshToken: String,
        did: String,
        handle: String,
        email: String? = nil,
        createdAt: Date = Date()
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.did = did
        self.handle = handle
        self.email = email
        self.createdAt = createdAt
    }
}
