import Hummingbird
import Logging
import Metrics
import Tracing
import OTel
import OTLPGRPC
import ServiceLifecycle
import ArchaeopteryxCore
import CacheLayer
import OAuthService
import ATProtoAdapter
import IDMapping
import TranslationLayer
import MastodonModels
import Dependencies

@main
struct ArchaeopteryxApp {
    static func main() async throws {
        // Load configuration
        let config = try ArchaeopteryxConfiguration.load()

        // Bootstrap OpenTelemetry if configured
        var otelServices: (metricsReader: (any Service)?, tracer: (any Service)?) = (nil, nil)

        if let obsConfig = config.observability {
            let otelSetup = OpenTelemetrySetup(
                serviceName: "archaeopteryx",
                serviceVersion: "1.0.0",
                environment: config.environment ?? "development",
                otlpEndpoint: obsConfig.otlpEndpoint,
                tracingEnabled: obsConfig.tracingEnabled,
                metricsEnabled: obsConfig.metricsEnabled
            )
            otelServices = try await otelSetup.bootstrap(logLevel: parseLogLevel(config.logging.level))
        } else {
            // Bootstrap basic logging if OTel is not configured
            LoggingSystem.bootstrap { label in
                var handler = StreamLogHandler.standardOutput(label: label)
                handler.logLevel = parseLogLevel(config.logging.level)
                handler.metadata = [
                    "service.name": "archaeopteryx",
                    "service.version": "1.0.0",
                    "environment": "\(config.environment ?? "development")",
                ]
                return handler
            }
        }

        // Create logger
        var logger = Logger(label: "archaeopteryx")
        logger.logLevel = parseLogLevel(config.logging.level)

        logger.info("Logging initialized", metadata: [
            "service_name": "archaeopteryx",
            "environment": "\(config.environment ?? "development")",
            "otel_enabled": "\(config.observability != nil)"
        ])

        logger.info("Configuration loaded", metadata: [
            "server": "\(config.server.hostname):\(config.server.port)",
            "valkey": "\(config.valkey.host):\(config.valkey.port)",
            "atproto": "\(config.atproto.serviceURL)"
        ])

        // Initialize cache (and ValkeyService if using Valkey)
        logger.info("Initializing cache connection")
        let (cache, valkeyService) = try await createCache(config: config, logger: logger)

        // Initialize ID mapping
        let snowflakeGenerator = SnowflakeIDGenerator()
        let idMapping = IDMappingService(cache: cache, generator: snowflakeGenerator)

        // Initialize session-scoped AT Protocol client (for multi-user support)
        let sessionClient = await SessionScopedClient(serviceURL: config.atproto.serviceURL)

        // Initialize AT Protocol client (backward compatibility for routes not yet migrated)
        let atprotoClient = await ATProtoClient(
            serviceURL: config.atproto.serviceURL,
            cache: cache
        )

        // Initialize translators
        let facetProcessor = FacetProcessor()
        let profileTranslator = ProfileTranslator(
            idMapping: idMapping,
            facetProcessor: facetProcessor
        )
        let statusTranslator = StatusTranslator(
            idMapping: idMapping,
            profileTranslator: profileTranslator,
            facetProcessor: facetProcessor
        )
        let notificationTranslator = NotificationTranslator(
            idMapping: idMapping,
            profileTranslator: profileTranslator,
            statusTranslator: statusTranslator
        )

        // Initialize OAuth service (with AT Proto service URL for creating sessions)
        let oauthService = OAuthService(
            cache: cache,
            atprotoServiceURL: config.atproto.serviceURL
        )

        // Set up dependencies for the application
        // The live ATProtoClient dependency is injected here and will be available
        // to all routes via @Dependency(\.atProtoClient)
        try await withDependencies {
            $0.atProtoClient = .live(client: atprotoClient)
        } operation: {
            // Create router with observability middleware
            let router = Router()

            // Add error handling middleware (first, to catch all errors)
            router.middlewares.add(ErrorHandlingMiddleware(logger: logger))

            // Add rate limiting middleware (second, to reject requests early)
            router.middlewares.add(RateLimitMiddleware(cache: cache, logger: logger))

            // Add tracing middleware (if OTel is enabled)
            if config.observability?.tracingEnabled == true {
                router.middlewares.add(TracingMiddleware(logger: logger))
            }

            // Add metrics middleware (if OTel is enabled)
            if config.observability?.metricsEnabled == true {
                router.middlewares.add(MetricsMiddleware(logger: logger))
            }

            // Add logging middleware for request/response logging
            // Logs are automatically exported to OTLP when OTel is configured
            router.middlewares.add(LoggingMiddleware(logger: logger))

            // Add basic routes
            router.get("/") { request, context -> String in
                return #"{"name":"Archaeopteryx","version":"0.1.0","description":"Bluesky to Mastodon API bridge"}"#
            }

            // Health check endpoint
            router.get("/health") { request, context -> String in
                return #"{"status":"healthy"}"#
            }

            // Add OAuth routes
            OAuthRoutes.addRoutes(to: router, oauthService: oauthService, logger: logger)

            // Add instance routes
            InstanceRoutes.addRoutes(to: router, logger: logger, config: config)

            // Add account routes (using session-scoped client for multi-user support)
            AccountRoutes.addRoutes(
                to: router,
                oauthService: oauthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                translator: profileTranslator,
                logger: logger
            )

            // Add status routes (using session-scoped client for multi-user support)
            StatusRoutes.addRoutes(
                to: router,
                oauthService: oauthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: logger
            )

            // Add timeline routes (using session-scoped client for multi-user support)
            TimelineRoutes.addRoutes(
                to: router,
                oauthService: oauthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: logger
            )

            // Add notification routes (using session-scoped client for multi-user support)
            NotificationRoutes.addRoutes(
                to: router,
                oauthService: oauthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                notificationTranslator: notificationTranslator,
                logger: logger
            )

            // Add media routes (ATProtoClient injected via @Dependency)
            MediaRoutes.addRoutes(
                to: router,
                logger: logger,
                oauthService: oauthService,
                idMapping: idMapping,
                cache: cache
            )

            // Add search routes (ATProtoClient injected via @Dependency)
            SearchRoutes.addRoutes(
                to: router,
                logger: logger,
                oauthService: oauthService,
                idMapping: idMapping,
                profileTranslator: profileTranslator,
                cache: cache
            )

            // Add list routes (using session-scoped client for multi-user support)
            ListRoutes.addRoutes(
                to: router,
                logger: logger,
                oauthService: oauthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                cache: cache
            )

            // Create application
            var app = Application(
                router: router,
                configuration: ApplicationConfiguration(address: .hostname(config.server.hostname, port: config.server.port)),
                logger: logger
            )

            // Add ValkeyService to application lifecycle (if using Valkey)
            if let valkeyService = valkeyService {
                app.addServices(valkeyService)
                logger.info("Added ValkeyService to application lifecycle")
            }

            // Add OTel services to application lifecycle (if enabled)
            if let metricsReader = otelServices.metricsReader {
                app.addServices(metricsReader)
            }
            if let tracer = otelServices.tracer {
                app.addServices(tracer)
            }

            logger.info("Starting Archaeopteryx on http://\(config.server.hostname):\(config.server.port)")

            // Run application - this will start all services including ValkeyService
            try await app.runService()
        }
    }

    /// Create cache instance based on configuration
    /// Returns tuple of (cache, valkeyService) where valkeyService is nil for in-memory cache
    static func createCache(config: ArchaeopteryxConfiguration, logger: Logger) async throws -> (any CacheService & CacheProtocol, ValkeyService?) {
        // Check if Valkey is configured (production)
        if config.valkey.enabled {
            logger.info("Using Valkey/Redis cache", metadata: [
                "host": "\(config.valkey.host)",
                "port": "\(config.valkey.port)",
                "database": "\(config.valkey.database)"
            ])

            // Create ValkeyService which will manage the ValkeyClient lifecycle
            let valkeyService = ValkeyService(
                hostname: config.valkey.host,
                port: config.valkey.port,
                logger: logger
            )

            // Inject the live Redis client dependency using ValkeyService's client
            let cache = await withDependencies {
                $0.redisClient = .live(client: valkeyService.valkeyClient)
            } operation: {
                ValkeyCache()
            }

            return (cache, valkeyService)
        } else {
            // Development: use in-memory cache
            logger.info("Using in-memory cache for development")
            return (InMemoryCache(), nil)
        }
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
