import Hummingbird
import Logging
import ArchaeopteryxCore

@main
struct ArchaeopteryxApp {
    static func main() async throws {
        // Load configuration
        let config = try ArchaeopteryxConfiguration.load()

        // Configure logger
        var logger = Logger(label: "archaeopteryx")
        logger.logLevel = parseLogLevel(config.logging.level)

        logger.info("Configuration loaded", metadata: [
            "server": "\(config.server.hostname):\(config.server.port)",
            "valkey": "\(config.valkey.host):\(config.valkey.port)",
            "atproto": "\(config.atproto.serviceURL)"
        ])

        // Create router
        let router = Router()

        // Add routes
        router.get("/") { request, context -> String in
            return #"{"name":"Archaeopteryx","version":"0.1.0","description":"Bluesky to Mastodon API bridge"}"#
        }

        // Health check endpoint
        router.get("/health") { request, context -> String in
            return #"{"status":"healthy"}"#
        }

        // Create application
        let app = Application(
            router: router,
            configuration: ApplicationConfiguration(address: .hostname(config.server.hostname, port: config.server.port)),
            logger: logger
        )

        logger.info("Starting Archaeopteryx on http://\(config.server.hostname):\(config.server.port)")

        // Run application
        try await app.runService()
    }

    /// Parse log level string to Logger.Level
    static func parseLogLevel(_ level: String) -> Logger.Level {
        switch level.lowercased() {
        case "trace": return .trace
        case "debug": return .debug
        case "info": return .info
        case "notice": return .notice
        case "warning": return .warning
        case "error": return .error
        case "critical": return .critical
        default: return .info
        }
    }
}
