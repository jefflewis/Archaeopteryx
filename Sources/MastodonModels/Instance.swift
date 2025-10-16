import Foundation

/// Mastodon instance information (v1 API)
///
/// Represents server metadata and statistics
public struct Instance: Codable, Equatable, Sendable {
    /// The domain name of the instance
    public let uri: String

    /// The title of the instance
    public let title: String

    /// A short description of the instance
    public let shortDescription: String

    /// A longer description of the instance
    public let description: String

    /// An email address for contact
    public let email: String

    /// The version of Mastodon installed on the instance
    public let version: String

    /// Primary languages of the instance
    public let languages: [String]

    /// Whether registrations are enabled
    public let registrations: Bool

    /// Whether registrations require approval
    public let approvalRequired: Bool

    /// Whether invites are enabled
    public let invitesEnabled: Bool

    /// Instance configuration limits
    public let configuration: InstanceConfiguration

    /// URLs for various instance resources
    public let urls: InstanceURLs

    /// Instance usage statistics
    public let stats: InstanceStats

    /// Thumbnail image for the instance
    public let thumbnail: String?

    /// Information about the instance admin contact
    public let contactAccount: MastodonAccount?

    /// Instance rules
    public let rules: [InstanceRule]

    public init(
        uri: String,
        title: String,
        shortDescription: String,
        description: String,
        email: String,
        version: String,
        languages: [String] = ["en"],
        registrations: Bool = false,
        approvalRequired: Bool = true,
        invitesEnabled: Bool = false,
        configuration: InstanceConfiguration = InstanceConfiguration(),
        urls: InstanceURLs = InstanceURLs(),
        stats: InstanceStats = InstanceStats(),
        thumbnail: String? = nil,
        contactAccount: MastodonAccount? = nil,
        rules: [InstanceRule] = []
    ) {
        self.uri = uri
        self.title = title
        self.shortDescription = shortDescription
        self.description = description
        self.email = email
        self.version = version
        self.languages = languages
        self.registrations = registrations
        self.approvalRequired = approvalRequired
        self.invitesEnabled = invitesEnabled
        self.configuration = configuration
        self.urls = urls
        self.stats = stats
        self.thumbnail = thumbnail
        self.contactAccount = contactAccount
        self.rules = rules
    }

    enum CodingKeys: String, CodingKey {
        case uri
        case title
        case shortDescription = "short_description"
        case description
        case email
        case version
        case languages
        case registrations
        case approvalRequired = "approval_required"
        case invitesEnabled = "invites_enabled"
        case configuration
        case urls
        case stats
        case thumbnail
        case contactAccount = "contact_account"
        case rules
    }
}

/// Instance configuration limits
public struct InstanceConfiguration: Codable, Equatable, Sendable {
    public let statuses: StatusConfiguration
    public let mediaAttachments: MediaConfiguration
    public let polls: PollConfiguration

    public init(
        statuses: StatusConfiguration = StatusConfiguration(),
        mediaAttachments: MediaConfiguration = MediaConfiguration(),
        polls: PollConfiguration = PollConfiguration()
    ) {
        self.statuses = statuses
        self.mediaAttachments = mediaAttachments
        self.polls = polls
    }

    enum CodingKeys: String, CodingKey {
        case statuses
        case mediaAttachments = "media_attachments"
        case polls
    }
}

/// Status/post configuration limits
public struct StatusConfiguration: Codable, Equatable, Sendable {
    /// Maximum characters per status
    public let maxCharacters: Int

    /// Maximum number of media attachments
    public let maxMediaAttachments: Int

    /// Characters reserved per URL
    public let charactersReservedPerUrl: Int

    public init(
        maxCharacters: Int = 300,  // Bluesky default
        maxMediaAttachments: Int = 4,
        charactersReservedPerUrl: Int = 23
    ) {
        self.maxCharacters = maxCharacters
        self.maxMediaAttachments = maxMediaAttachments
        self.charactersReservedPerUrl = charactersReservedPerUrl
    }

    enum CodingKeys: String, CodingKey {
        case maxCharacters = "max_characters"
        case maxMediaAttachments = "max_media_attachments"
        case charactersReservedPerUrl = "characters_reserved_per_url"
    }
}

/// Media attachment configuration limits
public struct MediaConfiguration: Codable, Equatable, Sendable {
    /// Supported MIME types
    public let supportedMimeTypes: [String]

    /// Maximum image size in bytes
    public let imageSizeLimit: Int

    /// Maximum image matrix (pixels)
    public let imageMatrixLimit: Int

    /// Maximum video size in bytes
    public let videoSizeLimit: Int

    /// Maximum video frame rate
    public let videoFrameRateLimit: Int

    /// Maximum video matrix (pixels)
    public let videoMatrixLimit: Int

    public init(
        supportedMimeTypes: [String] = [
            "image/jpeg",
            "image/png",
            "image/gif",
            "image/webp",
            "video/mp4",
            "video/webm"
        ],
        imageSizeLimit: Int = 10_485_760,  // 10 MB
        imageMatrixLimit: Int = 16_777_216,  // 4096 x 4096
        videoSizeLimit: Int = 41_943_040,  // 40 MB
        videoFrameRateLimit: Int = 60,
        videoMatrixLimit: Int = 8_294_400  // 1920 x 1080 x 4
    ) {
        self.supportedMimeTypes = supportedMimeTypes
        self.imageSizeLimit = imageSizeLimit
        self.imageMatrixLimit = imageMatrixLimit
        self.videoSizeLimit = videoSizeLimit
        self.videoFrameRateLimit = videoFrameRateLimit
        self.videoMatrixLimit = videoMatrixLimit
    }

    enum CodingKeys: String, CodingKey {
        case supportedMimeTypes = "supported_mime_types"
        case imageSizeLimit = "image_size_limit"
        case imageMatrixLimit = "image_matrix_limit"
        case videoSizeLimit = "video_size_limit"
        case videoFrameRateLimit = "video_frame_rate_limit"
        case videoMatrixLimit = "video_matrix_limit"
    }
}

/// Poll configuration limits
public struct PollConfiguration: Codable, Equatable, Sendable {
    /// Maximum poll options
    public let maxOptions: Int

    /// Maximum characters per option
    public let maxCharactersPerOption: Int

    /// Minimum expiration time in seconds
    public let minExpiration: Int

    /// Maximum expiration time in seconds
    public let maxExpiration: Int

    public init(
        maxOptions: Int = 4,
        maxCharactersPerOption: Int = 50,
        minExpiration: Int = 300,  // 5 minutes
        maxExpiration: Int = 2_629_746  // 1 month
    ) {
        self.maxOptions = maxOptions
        self.maxCharactersPerOption = maxCharactersPerOption
        self.minExpiration = minExpiration
        self.maxExpiration = maxExpiration
    }

    enum CodingKeys: String, CodingKey {
        case maxOptions = "max_options"
        case maxCharactersPerOption = "max_characters_per_option"
        case minExpiration = "min_expiration"
        case maxExpiration = "max_expiration"
    }
}

/// Instance URLs for various resources
public struct InstanceURLs: Codable, Equatable, Sendable {
    /// WebSocket URL for streaming API
    public let streamingApi: String

    public init(streamingApi: String = "wss://localhost/api/v1/streaming") {
        self.streamingApi = streamingApi
    }

    enum CodingKeys: String, CodingKey {
        case streamingApi = "streaming_api"
    }
}

/// Instance usage statistics
public struct InstanceStats: Codable, Equatable, Sendable {
    /// Number of users on the instance
    public let userCount: Int

    /// Number of statuses/posts
    public let statusCount: Int

    /// Number of federated domains
    public let domainCount: Int

    public init(
        userCount: Int = 0,
        statusCount: Int = 0,
        domainCount: Int = 0
    ) {
        self.userCount = userCount
        self.statusCount = statusCount
        self.domainCount = domainCount
    }

    enum CodingKeys: String, CodingKey {
        case userCount = "user_count"
        case statusCount = "status_count"
        case domainCount = "domain_count"
    }
}

/// Instance rule
public struct InstanceRule: Codable, Equatable, Sendable {
    /// Rule ID
    public let id: String

    /// Rule text
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}
