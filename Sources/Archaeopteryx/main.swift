import Hummingbird
import Logging

@main
struct ArchaeopteryxApp {
    static func main() async throws {
        // Configure logger
        var logger = Logger(label: "archaeopteryx")
        logger.logLevel = .info

        // Create router
        let router = Router()

        // Add routes
        router.get("/") { request, context in
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(data: #"{"name":"Archaeopteryx","version":"0.1.0","description":"Bluesky to Mastodon API bridge"}"#.data(using: .utf8)!)
            )
        }

        // Health check endpoint
        router.get("/health") { request, context in
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(data: #"{"status":"healthy"}"#.data(using: .utf8)!)
            )
        }

        // Create application
        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname("0.0.0.0", port: 8080)
            ),
            logger: logger
        )

        logger.info("Starting Archaeopteryx on http://0.0.0.0:8080")

        // Run application
        try await app.runService()
    }
}
