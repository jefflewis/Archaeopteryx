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
        password: String? = nil,
        database: Int = 0,
        logger: Logger
    ) {
        self.logger = logger
        var config = ValkeyClientConfiguration()
        if let password = password {
            config.authentication = .init(username: "default", password: password)
        }
        let address = ValkeyServerAddress.hostname(hostname, port: port)
        self.client = ValkeyClient(address, configuration: config, logger: logger)
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

        // Start the ValkeyClient connection pool
        // This is non-blocking and runs until the service is cancelled
        await client.run()

        logger.info("Valkey client service stopped")
    }
}
