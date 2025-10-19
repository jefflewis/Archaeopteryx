import Foundation
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
import NIOCore
import Prometheus
import ProfileRecorderServer

@main
struct ArchaeopteryxApp {
    static func main() async throws {
        // Load configuration
        let config = try await ArchaeopteryxConfiguration.load()

        // Bootstrap Prometheus metrics exporter
        let prometheusRegistry = PrometheusCollectorRegistry()
        MetricsSystem.bootstrap(PrometheusMetricsFactory(registry: prometheusRegistry))

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

        // Initialize Valkey cache
        logger.info("Initializing Valkey cache connection", metadata: [
            "host": "\(config.valkey.host)",
            "port": "\(config.valkey.port)",
            "database": "\(config.valkey.database)"
        ])
        
        let valkeyService = ValkeyService(
            hostname: config.valkey.host,
            port: config.valkey.port,
            password: config.valkey.password,
            database: config.valkey.database,
            logger: logger
        )
        
        let cache = ValkeyCache()

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

        // Set up dependencies for the application globally
        // Dependencies are prepared once and available throughout the app lifecycle
        prepareDependencies {
            $0.atProtoClient = .live(client: atprotoClient)
            $0.redisClient = .live(client: valkeyService.valkeyClient)
        }
        
        // Start ProfileRecorderServer in the background if enabled via environment
        // Example: PROFILE_RECORDER_SERVER_URL_PATTERN='unix:///tmp/archaeopteryx-samples-{PID}.sock'
        async let _ = ProfileRecorderServer(configuration: .parseFromEnvironment()).runIgnoringFailures(logger: logger)
        
        do {
            // Create router with observability middleware
            let router = Router()

            // Add error handling middleware (first, to catch all errors)
            router.middlewares.add(ErrorHandlingMiddleware(logger: logger))

            // Add rate limiting middleware (second, to reject requests early)
            router.middlewares.add(RateLimitMiddleware(cache: cache, logger: logger))

            // Add metrics middleware (always enabled for Prometheus)
            router.middlewares.add(MetricsMiddleware(logger: logger))

            // Add tracing middleware (if OTel is enabled)
            if config.observability?.tracingEnabled == true {
                router.middlewares.add(TracingMiddleware(logger: logger))
            }

            // Add logging middleware for request/response logging
            // Logs are automatically exported to OTLP when OTel is configured
            router.middlewares.add(LoggingMiddleware(logger: logger))

            // Add basic routes
            router.get("/") { request, context -> Response in
                let html = """
                <!DOCTYPE html>
                <html lang="en">
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>Archaeopteryx - Use Mastodon Clients with Bluesky</title>
                    <style>
                        * { margin: 0; padding: 0; box-sizing: border-box; }
                        body { 
                            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                            line-height: 1.6;
                            color: #333;
                            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                            min-height: 100vh;
                            padding: 20px;
                        }
                        .container {
                            max-width: 900px;
                            margin: 0 auto;
                            background: white;
                            border-radius: 12px;
                            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                            overflow: hidden;
                        }
                        header {
                            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                            color: white;
                            padding: 40px 30px;
                            text-align: center;
                        }
                        h1 { font-size: 2.5em; margin-bottom: 10px; }
                        .tagline { font-size: 1.2em; opacity: 0.95; }
                        .content { padding: 40px 30px; }
                        h2 { color: #667eea; margin-top: 30px; margin-bottom: 15px; font-size: 1.8em; }
                        h3 { color: #764ba2; margin-top: 20px; margin-bottom: 10px; }
                        p { margin-bottom: 15px; }
                        ul, ol { margin-left: 20px; margin-bottom: 15px; }
                        li { margin-bottom: 8px; }
                        code { 
                            background: #f4f4f4; 
                            padding: 2px 6px; 
                            border-radius: 3px;
                            font-family: "SF Mono", Monaco, Consolas, monospace;
                            font-size: 0.9em;
                        }
                        .highlight { 
                            background: #fff3cd; 
                            padding: 15px; 
                            border-left: 4px solid #ffc107;
                            margin: 20px 0;
                            border-radius: 4px;
                        }
                        .info-box {
                            background: #e3f2fd;
                            padding: 15px;
                            border-left: 4px solid #2196f3;
                            margin: 20px 0;
                            border-radius: 4px;
                        }
                        .warning-box {
                            background: #ffebee;
                            padding: 15px;
                            border-left: 4px solid #f44336;
                            margin: 20px 0;
                            border-radius: 4px;
                        }
                        .cta-button {
                            display: inline-block;
                            background: #667eea;
                            color: white;
                            padding: 15px 30px;
                            text-decoration: none;
                            border-radius: 6px;
                            font-weight: bold;
                            margin: 10px 10px 10px 0;
                            transition: background 0.3s;
                        }
                        .cta-button:hover { background: #764ba2; }
                        .cta-section { 
                            text-align: center; 
                            margin: 30px 0;
                            padding: 30px;
                            background: #f8f9fa;
                            border-radius: 8px;
                        }
                        footer {
                            background: #f8f9fa;
                            padding: 20px 30px;
                            text-align: center;
                            color: #666;
                            font-size: 0.9em;
                        }
                        footer a { color: #667eea; text-decoration: none; }
                        footer a:hover { text-decoration: underline; }
                        .feature-grid {
                            display: grid;
                            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                            gap: 20px;
                            margin: 20px 0;
                        }
                        .feature-card {
                            background: #f8f9fa;
                            padding: 20px;
                            border-radius: 8px;
                            border: 1px solid #e9ecef;
                        }
                        .feature-card h3 { margin-top: 0; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <header>
                            <h1>🦖 Archaeopteryx</h1>
                            <p class="tagline">Use your favorite Mastodon clients with Bluesky</p>
                        </header>
                        
                        <div class="content">
                            <h2>What is Archaeopteryx?</h2>
                            <p>Archaeopteryx is an HTTP bridge that translates Mastodon API calls to the AT Protocol (Bluesky). This allows you to use any Mastodon client application to connect to Bluesky without any modifications to the client.</p>
                            
                            <div class="feature-grid">
                                <div class="feature-card">
                                    <h3>🔄 Full Translation</h3>
                                    <p>Automatically converts between Mastodon and Bluesky formats</p>
                                </div>
                                <div class="feature-card">
                                    <h3>👥 Multi-User</h3>
                                    <p>Support for multiple Bluesky accounts with session isolation</p>
                                </div>
                                <div class="feature-card">
                                    <h3>⚡ Fast & Cached</h3>
                                    <p>Redis/Valkey caching for optimal performance</p>
                                </div>
                                <div class="feature-card">
                                    <h3>🔒 Secure</h3>
                                    <p>OAuth 2.0 flow with app-specific passwords</p>
                                </div>
                            </div>

                            <h2>Getting Started</h2>
                            <ol>
                                <li><strong>Generate an App Password</strong> - Visit <a href="https://bsky.app/settings/app-passwords" target="_blank">bsky.app/settings/app-passwords</a> to create a new app-specific password</li>
                                <li><strong>Configure Your Client</strong> - Add this instance URL: <code>http://\(config.server.hostname):\(config.server.port)</code></li>
                                <li><strong>Login</strong> - Use your Bluesky handle (e.g. <code>alice.bsky.social</code>) and the app password you just created</li>
                                <li><strong>Enjoy</strong> - Browse Bluesky through your Mastodon client!</li>
                            </ol>

                            <div class="cta-section">
                                <h3>Try It Now</h3>
                                <p>Launch the Elk web client to see Archaeopteryx in action:</p>
                                <a href="https://elk.zone" class="cta-button" target="_blank">🚀 Open Elk Client</a>
                            </div>

                            <div class="info-box">
                                <h3>✅ Tested Clients</h3>
                                <ul>
                                    <li><strong>iOS:</strong> <a href="https://tapbots.com/ivory/" target="_blank">Ivory</a>, <a href="https://apps.apple.com/app/mona-for-mastodon/id1659154653" target="_blank">Mona</a>, <a href="https://apps.apple.com/app/ice-cubes-for-mastodon/id6444915884" target="_blank">Ice Cubes</a></li>
                                    <li><strong>Android:</strong> <a href="https://tusky.app/" target="_blank">Tusky</a></li>
                                    <li><strong>Web:</strong> <a href="https://elk.zone" target="_blank">Elk</a></li>
                                </ul>
                            </div>

                            <h2>Privacy & Data Storage</h2>
                            
                            <h3>What We Store:</h3>
                            <ul>
                                <li><strong>Session Tokens</strong> - Encrypted OAuth tokens in Redis/Valkey (7 day expiration)</li>
                                <li><strong>ID Mappings</strong> - DID ↔ Snowflake ID conversions (permanent, deterministic)</li>
                                <li><strong>Cached Content</strong> - Temporary caching of profiles (15 min), posts (5 min), timelines (2 min)</li>
                            </ul>

                            <h3>What We DON'T Store:</h3>
                            <ul>
                                <li>❌ Your Bluesky password (you use app-specific passwords)</li>
                                <li>❌ Your posts or messages</li>
                                <li>❌ Your personal information</li>
                                <li>❌ Your browsing history</li>
                                <li>❌ Analytics or tracking data</li>
                            </ul>

                            <div class="warning-box">
                                <strong>⚠️ App-Specific Passwords Required</strong>
                                <p>For security, you <strong>must</strong> use a Bluesky app password, not your main account password. Generate one at <a href="https://bsky.app/settings/app-passwords" target="_blank">bsky.app/settings/app-passwords</a>. You can revoke it anytime.</p>
                            </div>

                            <h2>Supported Features</h2>
                            <ul>
                                <li>✅ View home timeline, notifications, and profiles</li>
                                <li>✅ Create, delete, like, and repost posts</li>
                                <li>✅ Follow/unfollow accounts</li>
                                <li>✅ Search for accounts and posts</li>
                                <li>✅ Upload images (up to 4 per post)</li>
                                <li>✅ View lists (mapped from Bluesky feeds)</li>
                                <li>✅ 44 Mastodon API endpoints implemented</li>
                            </ul>

                            <h2>Known Limitations</h2>
                            <p>Due to differences between Bluesky and Mastodon:</p>
                            <ul>
                                <li>❌ Character limit is 300 (not 500)</li>
                                <li>❌ No pinned posts, custom emojis, or polls</li>
                                <li>❌ All posts are public (no private/unlisted visibility)</li>
                                <li>❌ Lists are read-only (create them in the Bluesky app)</li>
                                <li>❌ No real-time streaming (clients need to poll)</li>
                            </ul>
                            <p>See the full <a href="https://github.com/yourusername/archaeopteryx/blob/main/LIMITATIONS.md" target="_blank">limitations documentation</a> for details.</p>

                            <h2>API Endpoints</h2>
                            <p>This instance implements 44 Mastodon API v1/v2 endpoints:</p>
                            <ul>
                                <li><strong>OAuth:</strong> App registration, authorization, token exchange (5 endpoints)</li>
                                <li><strong>Accounts:</strong> Profiles, follow/unfollow, search (10 endpoints)</li>
                                <li><strong>Statuses:</strong> Posts, likes, reposts, context (10 endpoints)</li>
                                <li><strong>Timelines:</strong> Home, public, hashtag, list (4 endpoints)</li>
                                <li><strong>Notifications:</strong> List, get, clear, dismiss (4 endpoints)</li>
                                <li><strong>Media:</strong> Upload, get, update (4 endpoints)</li>
                                <li><strong>Search:</strong> Unified search (1 endpoint)</li>
                                <li><strong>Lists:</strong> Get lists, members, timeline (4 endpoints)</li>
                                <li><strong>Instance:</strong> Metadata v1/v2 (2 endpoints)</li>
                            </ul>

                            <div class="highlight">
                                <strong>📊 Instance Info:</strong> <code>GET <a href="/api/v1/instance">/api/v1/instance</a></code><br>
                                <strong>📊 Health Check:</strong> <code>GET <a href="/health">/health</a></code><br>
                                <strong>📈 Metrics:</strong> <code>GET <a href="/metrics">/metrics</a></code>
                            </div>

                            <h2>Technology</h2>
                            <p>Archaeopteryx is built with modern Swift technologies:</p>
                            <ul>
                                <li><strong>Swift 6.0</strong> with strict concurrency</li>
                                <li><strong>Hummingbird 2.0</strong> HTTP server</li>
                                <li><strong>ATProtoKit</strong> for Bluesky integration</li>
                                <li><strong>Valkey/Redis</strong> for caching and sessions</li>
                                <li><strong>OpenTelemetry</strong> for observability</li>
                                <li><strong>252 tests</strong> with 80%+ code coverage</li>
                            </ul>

                            <h2>Performance</h2>
                            <ul>
                                <li>Account lookups: p95 &lt; 200ms</li>
                                <li>Timeline loads: p95 &lt; 500ms</li>
                                <li>Throughput: 100+ requests/second</li>
                                <li>Cache hit rates: &gt;90% profiles, &gt;80% posts</li>
                            </ul>

                            <h2>Open Source</h2>
                            <p>Archaeopteryx is open source under the MIT license. Contributions welcome!</p>
                            <p>Visit the <a href="https://github.com/yourusername/archaeopteryx" target="_blank">GitHub repository</a> to view the source code, report issues, or contribute.</p>
                        </div>

                        <footer>
                            <p>Archaeopteryx v0.1.0 | <a href="https://github.com/yourusername/archaeopteryx">GitHub</a> | <a href="https://github.com/yourusername/archaeopteryx/blob/main/LICENSE">MIT License</a></p>
                            <p>Built with Swift 6.0 | Powered by <a href="https://github.com/MasterJ93/ATProtoKit">ATProtoKit</a></p>
                        </footer>
                    </div>
                </body>
                </html>
                """
                
                return Response(
                    status: .ok,
                    headers: [.contentType: "text/html; charset=utf-8"],
                    body: .init(byteBuffer: ByteBuffer(string: html))
                )
            }

            // Health check endpoint
            router.get("/health") { request, context -> Response in
                let healthCheck = #"{"status":"ok"}"#
                return Response(
                    status: .ok,
                    headers: [.contentType: "application/json"],
                    body: .init(byteBuffer: ByteBuffer(string: healthCheck))
                )
            }

            // Metrics endpoint for Grafana/Prometheus
            router.get("/metrics") { request, context -> Response in
                // Collect all Prometheus metrics from the registry
                let prometheusMetrics = prometheusRegistry.emitToString()
                
                // Add custom application metrics
                let uptime = ProcessInfo.processInfo.systemUptime
                let customMetrics = """
                
                # HELP archaeopteryx_uptime_seconds Application uptime in seconds
                # TYPE archaeopteryx_uptime_seconds gauge
                archaeopteryx_uptime_seconds \(uptime)
                
                # HELP archaeopteryx_version Application version
                # TYPE archaeopteryx_version gauge
                archaeopteryx_version{version="0.1.0"} 1
                
                # HELP archaeopteryx_info Application information
                # TYPE archaeopteryx_info gauge
                archaeopteryx_info{version="0.1.0",environment="\(config.environment ?? "development")"} 1
                """
                
                let fullMetrics = prometheusMetrics + customMetrics

                return Response(
                    status: .ok,
                    headers: [.contentType: "text/plain; version=0.0.4"],
                    body: .init(byteBuffer: ByteBuffer(string: fullMetrics))
                )
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

            // Add search routes
            SearchRoutes.addRoutes(
                to: router,
                logger: logger,
                sessionClient: sessionClient,
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

            // Add ValkeyService to application lifecycle
            app.addServices(valkeyService)
            logger.info("Added ValkeyService to application lifecycle")

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
