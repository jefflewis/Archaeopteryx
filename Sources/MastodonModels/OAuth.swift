import Foundation

// MARK: - OAuth Application

/// OAuth application registration response
public struct OAuthApplication: Codable, Sendable, Equatable {
    /// Application ID
    public let id: String

    /// Application name
    public let name: String

    /// Application website
    public let website: String?

    /// Redirect URI for authorization
    public let redirectUri: String

    /// Client ID for OAuth flow
    public let clientId: String

    /// Client secret for OAuth flow
    public let clientSecret: String

    /// Vapor ID (Mastodon compatibility)
    public let vapidKey: String?

    public init(
        id: String,
        name: String,
        website: String? = nil,
        redirectUri: String,
        clientId: String,
        clientSecret: String,
        vapidKey: String? = nil
    ) {
        self.id = id
        self.name = name
        self.website = website
        self.redirectUri = redirectUri
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.vapidKey = vapidKey
    }
}

// MARK: - OAuth Token

/// OAuth token response
public struct OAuthToken: Codable, Sendable, Equatable {
    /// Access token
    public let accessToken: String

    /// Token type (typically "Bearer")
    public let tokenType: String

    /// Scope granted
    public let scope: String

    /// When the token was created (Unix timestamp)
    public let createdAt: Int

    /// Refresh token for getting new access tokens
    public let refreshToken: String?

    /// Token expiration time in seconds (optional, defaults to 7 days)
    public let expiresIn: Int?

    public init(
        accessToken: String,
        tokenType: String = "Bearer",
        scope: String,
        createdAt: Int,
        refreshToken: String? = nil,
        expiresIn: Int? = nil
    ) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.scope = scope
        self.createdAt = createdAt
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
    }

    /// Check if token is expired
    public func isExpired() -> Bool {
        guard let expiresIn = expiresIn else {
            // If no expiration set, assume 7 days default
            let sevenDaysInSeconds = 7 * 24 * 60 * 60
            let expirationTime = createdAt + sevenDaysInSeconds
            return Int(Date().timeIntervalSince1970) > expirationTime
        }

        let expirationTime = createdAt + expiresIn
        return Int(Date().timeIntervalSince1970) > expirationTime
    }
}

// MARK: - Authorization Code

/// Internal model for authorization codes (not part of Mastodon API)
public struct AuthorizationCode: Codable, Sendable {
    /// The authorization code
    public let code: String

    /// Client ID this code was issued to
    public let clientId: String

    /// Redirect URI for this authorization
    public let redirectUri: String

    /// Scope requested
    public let scope: String

    /// User's Bluesky handle
    public let handle: String

    /// User's Bluesky password (encrypted in production)
    public let password: String

    /// When the code was created
    public let createdAt: Date

    /// Whether the code has been used
    public var used: Bool

    public init(
        code: String,
        clientId: String,
        redirectUri: String,
        scope: String,
        handle: String,
        password: String,
        createdAt: Date,
        used: Bool
    ) {
        self.code = code
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.scope = scope
        self.handle = handle
        self.password = password
        self.createdAt = createdAt
        self.used = used
    }

    /// Check if code is expired (10 minutes lifetime)
    public func isExpired() -> Bool {
        let tenMinutes: TimeInterval = 10 * 60
        return Date().timeIntervalSince(createdAt) > tenMinutes
    }
}

// MARK: - OAuth Error Response

/// OAuth error response
public struct OAuthError: Codable, Sendable, Equatable {
    /// Error code
    public let error: String

    /// Error description
    public let errorDescription: String?

    public init(error: String, errorDescription: String? = nil) {
        self.error = error
        self.errorDescription = errorDescription
    }
}

// MARK: - OAuth Scopes

/// OAuth scopes for Mastodon API
public enum OAuthScope: String, Codable, Sendable {
    case read
    case write
    case follow
    case push

    /// Read sub-scopes
    case readAccounts = "read:accounts"
    case readBlocks = "read:blocks"
    case readBookmarks = "read:bookmarks"
    case readFavourites = "read:favourites"
    case readFilters = "read:filters"
    case readFollows = "read:follows"
    case readLists = "read:lists"
    case readMutes = "read:mutes"
    case readNotifications = "read:notifications"
    case readSearch = "read:search"
    case readStatuses = "read:statuses"

    /// Write sub-scopes
    case writeAccounts = "write:accounts"
    case writeBlocks = "write:blocks"
    case writeBookmarks = "write:bookmarks"
    case writeConversations = "write:conversations"
    case writeFavourites = "write:favourites"
    case writeFilters = "write:filters"
    case writeFollows = "write:follows"
    case writeLists = "write:lists"
    case writeMedia = "write:media"
    case writeMutes = "write:mutes"
    case writeNotifications = "write:notifications"
    case writeReports = "write:reports"
    case writeStatuses = "write:statuses"

    /// Parse scope string into array of scopes
    public static func parse(_ scopeString: String) -> [OAuthScope] {
        return scopeString
            .split(separator: " ")
            .compactMap { OAuthScope(rawValue: String($0)) }
    }

    /// Convert array of scopes to scope string
    public static func toString(_ scopes: [OAuthScope]) -> String {
        return scopes.map { $0.rawValue }.joined(separator: " ")
    }
}
