import Foundation

/// Application configuration using environment variables and config files
public struct ArchaeopteryxConfiguration: Codable, Sendable {
    /// Server configuration
    public var server: ServerConfiguration

    /// Valkey/Redis configuration
    public var valkey: ValkeyConfiguration

    /// AT Protocol / Bluesky configuration
    public var atproto: ATProtoConfiguration

    /// Logging configuration
    public var logging: LoggingConfiguration

    public init(
        server: ServerConfiguration = ServerConfiguration(),
        valkey: ValkeyConfiguration = ValkeyConfiguration(),
        atproto: ATProtoConfiguration = ATProtoConfiguration(),
        logging: LoggingConfiguration = LoggingConfiguration()
    ) {
        self.server = server
        self.valkey = valkey
        self.atproto = atproto
        self.logging = logging
    }
}

public struct ServerConfiguration: Codable, Sendable {
    /// Server hostname
    public var hostname: String

    /// Server port
    public var port: Int

    public init(hostname: String = "0.0.0.0", port: Int = 8080) {
        self.hostname = hostname
        self.port = port
    }
}

public struct ValkeyConfiguration: Codable, Sendable {
    /// Valkey/Redis host
    public var host: String

    /// Valkey/Redis port
    public var port: Int

    /// Optional password
    public var password: String?

    /// Database number
    public var database: Int

    public init(
        host: String = "localhost",
        port: Int = 6379,
        password: String? = nil,
        database: Int = 0
    ) {
        self.host = host
        self.port = port
        self.password = password
        self.database = database
    }
}

public struct ATProtoConfiguration: Codable, Sendable {
    /// AT Protocol service URL
    public var serviceURL: String

    /// Optional PDS (Personal Data Server) URL for custom instances
    public var pdsURL: String?

    public init(
        serviceURL: String = "https://bsky.social",
        pdsURL: String? = nil
    ) {
        self.serviceURL = serviceURL
        self.pdsURL = pdsURL
    }
}

public struct LoggingConfiguration: Codable, Sendable {
    /// Log level: trace, debug, info, notice, warning, error, critical
    public var level: String

    public init(level: String = "info") {
        self.level = level
    }
}

extension ArchaeopteryxConfiguration {
    /// Load configuration from environment variables and config files
    public static func load() throws -> ArchaeopteryxConfiguration {
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

        return config
    }

    /// Valkey connection URL
    public var valkeyURL: String {
        var url = "redis://"
        if let password = valkey.password {
            url += ":\(password)@"
        }
        url += "\(valkey.host):\(valkey.port)/\(valkey.database)"
        return url
    }
}
