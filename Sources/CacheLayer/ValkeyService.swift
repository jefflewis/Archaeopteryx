import Foundation
import Valkey
import Logging
import ServiceLifecycle

/// Service wrapper for ValkeyClient that integrates with swift-service-lifecycle
public final class ValkeyService: Service, Sendable {
    private let client: ValkeyClient
    private let logger: Logger

    public init(
        hostname: String,
        port: Int,
        logger: Logger
    ) {
        self.logger = logger
        self.client = ValkeyClient(.hostname(hostname, port: port), logger: logger)
    }

    /// Access the underlying ValkeyClient
    public var valkeyClient: ValkeyClient {
        client
    }

    /// Service lifecycle run method
    public func run() async throws {
        logger.info("Starting Valkey client service", metadata: [
            "service": "valkey"
        ])

        // Run the ValkeyClient - this will block until the client is shut down
        await client.run()

        logger.info("Valkey client service stopped")
    }
}
