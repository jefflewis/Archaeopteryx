import Configuration
import Foundation

/// Application configuration using swift-configuration
struct ArchaeopteryxConfiguration: Codable {
    /// Server configuration
    var server: ServerConfiguration = ServerConfiguration()

    /// Valkey/Redis configuration
    var valkey: ValkeyConfiguration = ValkeyConfiguration()

    /// AT Protocol / Bluesky configuration
    var atproto: ATProtoConfiguration = ATProtoConfiguration()

    /// Logging configuration
    var logging: LoggingConfiguration = LoggingConfiguration()
}

struct ServerConfiguration: Codable {
    /// Server hostname
    var hostname: String = "0.0.0.0"

    /// Server port
    var port: Int = 8080
}

struct ValkeyConfiguration: Codable {
    /// Valkey/Redis host
    var host: String = "localhost"

    /// Valkey/Redis port
    var port: Int = 6379

    /// Optional password
    var password: String?

    /// Database number
    var database: Int = 0
}

struct ATProtoConfiguration: Codable {
    /// AT Protocol service URL
    var serviceURL: String = "https://bsky.social"

    /// Optional PDS (Personal Data Server) URL for custom instances
    var pdsURL: String?
}

struct LoggingConfiguration: Codable {
    /// Log level: trace, debug, info, notice, warning, error, critical
    var level: String = "info"
}

extension ArchaeopteryxConfiguration {
    /// Load configuration from environment variables and config files
    static func load() throws -> ArchaeopteryxConfiguration {
        var config = ArchaeopteryxConfiguration()

        // Load from environment variables
        if let port = ProcessInfo.processInfo.environment["PORT"],
           let portInt = Int(port) {
            config.server.port = portInt
        }

        if let hostname = ProcessInfo.processInfo.environment["HOSTNAME"] {
            config.server.hostname = hostname
        }

        if let valkeyHost = ProcessInfo.processInfo.environment["VALKEY_HOST"] {
            config.valkey.host = valkeyHost
        }

        if let valkeyPort = ProcessInfo.processInfo.environment["VALKEY_PORT"],
           let portInt = Int(valkeyPort) {
            config.valkey.port = portInt
        }

        if let valkeyPassword = ProcessInfo.processInfo.environment["VALKEY_PASSWORD"] {
            config.valkey.password = valkeyPassword
        }

        if let atprotoURL = ProcessInfo.processInfo.environment["ATPROTO_SERVICE_URL"] {
            config.atproto.serviceURL = atprotoURL
        }

        if let pdsURL = ProcessInfo.processInfo.environment["ATPROTO_PDS_URL"] {
            config.atproto.pdsURL = pdsURL
        }

        if let logLevel = ProcessInfo.processInfo.environment["LOG_LEVEL"] {
            config.logging.level = logLevel
        }

        // TODO: Add support for loading from config files (JSON/PLIST)
        // This can be extended to use swift-configuration's file providers

        return config
    }

    /// Valkey connection URL
    var valkeyURL: String {
        var url = "redis://"
        if let password = valkey.password {
            url += ":\(password)@"
        }
        url += "\(valkey.host):\(valkey.port)/\(valkey.database)"
        return url
    }
}
