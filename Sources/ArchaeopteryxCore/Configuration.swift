import Foundation
import Configuration

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

    /// Observability configuration (OpenTelemetry)
    public var observability: ObservabilityConfiguration?

    /// Environment name (development, staging, production)
    public var environment: String?

    public init(
        server: ServerConfiguration = ServerConfiguration(),
        valkey: ValkeyConfiguration = ValkeyConfiguration(),
        atproto: ATProtoConfiguration = ATProtoConfiguration(),
        logging: LoggingConfiguration = LoggingConfiguration(),
        observability: ObservabilityConfiguration? = nil,
        environment: String? = nil
    ) {
        self.server = server
        self.valkey = valkey
        self.atproto = atproto
        self.logging = logging
        self.observability = observability
        self.environment = environment
    }
}

public struct ServerConfiguration: Codable, Sendable {
    /// Server hostname
    public var hostname: String

    /// Server port
    public var port: Int

    /// Public URL for instance metadata (e.g., "https://archaeopteryx.fly.dev")
    public var publicURL: String?

    public init(hostname: String = "0.0.0.0", port: Int = 8080, publicURL: String? = nil) {
        self.hostname = hostname
        self.port = port
        self.publicURL = publicURL
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

public struct ObservabilityConfiguration: Codable, Sendable {
    /// OpenTelemetry OTLP collector endpoint
    public var otlpEndpoint: String

    /// Whether to enable tracing
    public var tracingEnabled: Bool

    /// Whether to enable metrics
    public var metricsEnabled: Bool

    public init(
        otlpEndpoint: String = "http://localhost:4317",
        tracingEnabled: Bool = true,
        metricsEnabled: Bool = true
    ) {
        self.otlpEndpoint = otlpEndpoint
        self.tracingEnabled = tracingEnabled
        self.metricsEnabled = metricsEnabled
    }
}

extension ArchaeopteryxConfiguration {
    /// Load configuration from environment variables and config files
    public static func load() async throws -> ArchaeopteryxConfiguration {
        // Create configuration provider: reads from .env file (if exists) and environment variables
        // Environment variables override .env file values
        let provider: EnvironmentVariablesProvider
        if let envFileProvider = try? await EnvironmentVariablesProvider(environmentFilePath: ".env") {
            // .env file exists (local development)
            provider = envFileProvider
        } else {
            // .env file doesn't exist (production/Fly.io) - use environment variables only
            provider = EnvironmentVariablesProvider()
        }
        let config_reader = ConfigReader(provider: provider)

        var config = ArchaeopteryxConfiguration()

        // Load server configuration
        if let port = config_reader.int(forKey: "PORT") {
            config.server.port = port
        }
        if let hostname = config_reader.string(forKey: "HOSTNAME") {
            config.server.hostname = hostname
        }
        if let publicURL = config_reader.string(forKey: "PUBLIC_URL") {
            config.server.publicURL = publicURL
        }

        // Parse REDIS_URL if provided (Fly.io sets this automatically)
        if let redisURL = config_reader.string(forKey: "REDIS_URL") {
            if let parsed = parseRedisURL(redisURL) {
                config.valkey.host = parsed.host
                config.valkey.port = parsed.port
                if let password = parsed.password {
                    config.valkey.password = password
                }
                config.valkey.database = parsed.database
            }
        } else {
            // Load individual Valkey settings if REDIS_URL not present
            if let host = config_reader.string(forKey: "VALKEY_HOST") {
                config.valkey.host = host
            }
            if let port = config_reader.int(forKey: "VALKEY_PORT") {
                config.valkey.port = port
            }
            if let password = config_reader.string(forKey: "VALKEY_PASSWORD") {
                config.valkey.password = password
            }
            if let database = config_reader.int(forKey: "VALKEY_DATABASE") {
                config.valkey.database = database
            }
        }

        // Load AT Protocol configuration
        if let serviceURL = config_reader.string(forKey: "ATPROTO_SERVICE_URL") {
            config.atproto.serviceURL = serviceURL
        }
        if let pdsURL = config_reader.string(forKey: "ATPROTO_PDS_URL") {
            config.atproto.pdsURL = pdsURL
        }

        // Load logging configuration
        if let logLevel = config_reader.string(forKey: "LOG_LEVEL") {
            config.logging.level = logLevel
        }

        // Load observability configuration
        if let otlpEndpoint = config_reader.string(forKey: "OTLP_ENDPOINT") {
            var obsConfig = ObservabilityConfiguration(otlpEndpoint: otlpEndpoint)

            if let tracingEnabled = config_reader.string(forKey: "TRACING_ENABLED"),
               tracingEnabled.lowercased() == "false" {
                obsConfig.tracingEnabled = false
            }
            if let metricsEnabled = config_reader.string(forKey: "METRICS_ENABLED"),
               metricsEnabled.lowercased() == "false" {
                obsConfig.metricsEnabled = false
            }

            config.observability = obsConfig
        }

        // Load environment
        if let environment = config_reader.string(forKey: "ENVIRONMENT") {
            config.environment = environment
        }

        return config
    }

    /// Parse Redis URL (format: redis://[user][:password]@host:port[/database])
    private static func parseRedisURL(_ urlString: String) -> (host: String, port: Int, password: String?, database: Int)? {
        guard let url = URL(string: urlString) else { return nil }

        guard url.scheme == "redis" || url.scheme == "rediss" else { return nil }

        guard let host = url.host else { return nil }

        let port = url.port ?? 6379

        let password = url.password

        // Parse database from path (e.g., /0, /1, etc.)
        var database = 0
        if let path = url.path.split(separator: "/").first,
           let db = Int(path) {
            database = db
        }

        return (host: host, port: port, password: password, database: database)
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
