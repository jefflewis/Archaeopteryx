import Foundation
import Hummingbird
import Logging
import MastodonModels
import ArchaeopteryxCore

// MARK: - Instance Routes

/// Instance information routes for Mastodon API compatibility
struct InstanceRoutes {
    let logger: Logger
    let config: ArchaeopteryxConfiguration

    /// Add instance routes to the router
    static func addRoutes(
        to router: Router<some RequestContext>,
        logger: Logger,
        config: ArchaeopteryxConfiguration
    ) {
        let routes = InstanceRoutes(logger: logger, config: config)

        // GET /api/v1/instance - Instance information (v1 API)
        router.get("/api/v1/instance") { request, context -> Response in
            try await routes.getInstance(request: request, context: context)
        }

        // GET /api/v2/instance - Instance information (v2 API)
        router.get("/api/v2/instance") { request, context -> Response in
            try await routes.getInstance(request: request, context: context)
        }
    }

    /// Convenience method for tests (uses default config)
    static func addRoutes(to router: Router<some RequestContext>) {
        let logger = Logger(label: "archaeopteryx.instance")
        let config = (try? ArchaeopteryxConfiguration.load()) ?? .default
        addRoutes(to: router, logger: logger, config: config)
    }

    // MARK: - Route Handlers

    /// GET /api/v1/instance - Return instance information
    func getInstance(request: Request, context: some RequestContext) async throws -> Response {
        logger.debug("Fetching instance information")

        // Build instance metadata
        let instance = buildInstanceInfo()

        return try jsonResponse(instance, status: .ok)
    }

    // MARK: - Helper Methods

    /// Build instance information from configuration
    private func buildInstanceInfo() -> Instance {
        // Determine base URI from configuration
        let baseUri = "\(config.server.hostname):\(config.server.port)"

        return Instance(
            uri: baseUri,
            title: "Archaeopteryx",
            shortDescription: "Bluesky to Mastodon API bridge",
            description: """
            Archaeopteryx is a compatibility bridge that allows Mastodon clients to connect to Bluesky. \
            It translates Mastodon API calls to AT Protocol calls, enabling existing Mastodon applications \
            to work with Bluesky without modification.
            """,
            email: "admin@\(config.server.hostname)",
            version: "4.0.0 (compatible; Archaeopteryx 0.1.0)",
            languages: ["en"],
            registrations: false,  // Users must register on Bluesky
            approvalRequired: true,
            invitesEnabled: false,
            configuration: InstanceConfiguration(
                statuses: StatusConfiguration(
                    maxCharacters: 300,  // Bluesky limit
                    maxMediaAttachments: 4,
                    charactersReservedPerUrl: 23
                ),
                mediaAttachments: MediaConfiguration(),
                polls: PollConfiguration()
            ),
            urls: InstanceURLs(
                streamingApi: "wss://\(baseUri)/api/v1/streaming"
            ),
            stats: InstanceStats(
                userCount: 0,  // Unknown (Bluesky doesn't expose this)
                statusCount: 0,  // Unknown
                domainCount: 1  // This bridge only
            ),
            thumbnail: nil,
            contactAccount: nil,
            rules: [
                InstanceRule(
                    id: "1",
                    text: "Follow Bluesky's Community Guidelines"
                ),
                InstanceRule(
                    id: "2",
                    text: "Be respectful and kind to others"
                ),
                InstanceRule(
                    id: "3",
                    text: "No spam, harassment, or illegal content"
                )
            ]
        )
    }

    /// Create a JSON response with proper content type
    private func jsonResponse<T: Encodable>(_ value: T, status: HTTPResponse.Status) throws -> Response {
        let encoder = JSONEncoder()
        // Don't use automatic snake_case conversion - Instance model has explicit CodingKeys
        let data = try encoder.encode(value)

        var response = Response(status: status)
        response.headers[.contentType] = "application/json"
        response.body = .init(byteBuffer: ByteBuffer(data: data))
        return response
    }
}

// MARK: - Configuration Extension

extension ArchaeopteryxConfiguration {
    /// Default configuration for testing
    static var `default`: ArchaeopteryxConfiguration {
        ArchaeopteryxConfiguration(
            server: ServerConfiguration(hostname: "localhost", port: 8080),
            valkey: ValkeyConfiguration(
                host: "localhost",
                port: 6379,
                password: "",
                database: 0
            ),
            atproto: ATProtoConfiguration(serviceURL: "https://bsky.social"),
            logging: LoggingConfiguration(level: "info")
        )
    }
}
