import Foundation

/// Represents the relationship between the authenticated user and another account
///
/// Used by endpoints like GET /api/v1/accounts/relationships
public struct MastodonRelationship: Codable, Equatable, Sendable {
    /// The account ID
    public let id: String

    /// Are you following this user?
    public let following: Bool

    /// Are you receiving this user's boosts in your home timeline?
    public let showingReblogs: Bool

    /// Have you enabled notifications for this user?
    public let notifying: Bool

    /// Which languages are you following from this user?
    public let languages: [String]

    /// Are you followed by this user?
    public let followedBy: Bool

    /// Are you blocking this user?
    public let blocking: Bool

    /// Is this user blocking you?
    public let blockedBy: Bool

    /// Are you muting this user?
    public let muting: Bool

    /// Are you muting notifications from this user?
    public let mutingNotifications: Bool

    /// Do you have a pending follow request for this user?
    public let requested: Bool

    /// Are you blocking this user's domain?
    public let domainBlocking: Bool

    /// Are you featuring this user on your profile?
    public let endorsed: Bool

    /// Personal note about this account
    public let note: String

    public init(
        id: String,
        following: Bool = false,
        showingReblogs: Bool = true,
        notifying: Bool = false,
        languages: [String] = [],
        followedBy: Bool = false,
        blocking: Bool = false,
        blockedBy: Bool = false,
        muting: Bool = false,
        mutingNotifications: Bool = false,
        requested: Bool = false,
        domainBlocking: Bool = false,
        endorsed: Bool = false,
        note: String = ""
    ) {
        self.id = id
        self.following = following
        self.showingReblogs = showingReblogs
        self.notifying = notifying
        self.languages = languages
        self.followedBy = followedBy
        self.blocking = blocking
        self.blockedBy = blockedBy
        self.muting = muting
        self.mutingNotifications = mutingNotifications
        self.requested = requested
        self.domainBlocking = domainBlocking
        self.endorsed = endorsed
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case id
        case following
        case showingReblogs = "showing_reblogs"
        case notifying
        case languages
        case followedBy = "followed_by"
        case blocking
        case blockedBy = "blocked_by"
        case muting
        case mutingNotifications = "muting_notifications"
        case requested
        case domainBlocking = "domain_blocking"
        case endorsed
        case note
    }
}
