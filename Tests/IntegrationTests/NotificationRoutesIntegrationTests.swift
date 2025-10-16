import HummingbirdTesting
import HTTPTypes
import Logging
import XCTest
@testable import Hummingbird

import ATProtoKit
import Dependencies
@testable import Archaeopteryx
@testable import ATProtoAdapter
@testable import CacheLayer
@testable import OAuthService
@testable import IDMapping
@testable import TranslationLayer
@testable import MastodonModels

/// Integration tests for Notification API endpoints
final class NotificationRoutesIntegrationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await MockRequestExecutor.clearMocks()
    }

    override func tearDown() async throws {
        await MockRequestExecutor.clearMocks()
        try await super.tearDown()
    }

    // MARK: - Helper

    func buildApp() async throws -> some ApplicationProtocol {
        let token = "test_token_123"
        let did = "did:plc:test123456"
        let handle = "test.bsky.social"

        var logger = Logger(label: "test")
        logger.logLevel = .critical
        let cache = InMemoryCache()

        // OAuth token
        struct TokenData: Codable {
            let handle: String
            let scope: String
            let tokenType: String
            let createdAt: Int
            let expiresIn: Int
        }

        let tokenData = TokenData(
            handle: handle,
            scope: "read write",
            tokenType: "Bearer",
            createdAt: Int(Date().timeIntervalSince1970),
            expiresIn: 7 * 24 * 60 * 60
        )
        try await cache.set("oauth:token:\(token)", value: tokenData, ttl: 3600)

        // Mock session
        let mockSession = ATProtoSession(
            did: did,
            handle: handle,
            accessToken: "mock_access_token",
            refreshToken: "mock_refresh_token",
            email: "test@example.com",
            createdAt: Date()
        )
        try await cache.set("session:\(did)", value: mockSession, ttl: 3600)

        // ATProtoClient with mock
        let mockExecutor = MockRequestExecutor()
        let apiClientConfig = APIClientConfiguration(responseProvider: mockExecutor)
        let atProtoClient = await ATProtoClient(
            serviceURL: "https://bsky.social",
            cache: cache,
            apiClientConfiguration: apiClientConfig
        )
        await atProtoClient.setSession(mockSession)

        // Other services
        let oauthService = OAuthService(cache: cache)
        let generator = SnowflakeIDGenerator()
        let idMapping = IDMappingService(cache: cache, generator: generator)
        let facetProcessor = FacetProcessor()
        let profileTranslator = ProfileTranslator(idMapping: idMapping, facetProcessor: facetProcessor)
        let statusTranslator = StatusTranslator(idMapping: idMapping, profileTranslator: profileTranslator, facetProcessor: facetProcessor)
        let notificationTranslator = NotificationTranslator(idMapping: idMapping, profileTranslator: profileTranslator, statusTranslator: statusTranslator)

        // Build app
        return try await withDependencies {
            $0.atProtoClient = .live(client: atProtoClient)
        } operation: {
            let router = Router()
            NotificationRoutes.addRoutes(
                to: router,
                oauthService: oauthService,
                idMapping: idMapping,
                notificationTranslator: notificationTranslator,
                logger: logger
            )
            return Application(responder: router.buildResponder(), logger: logger)
        }
    }

    // MARK: - Tests

    func testGetNotifications_Success() async throws {
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.notification.listNotifications",
            statusCode: 200,
            data: BlueskyAPIFixtures.listNotificationsResponse
        )

        let app = try await buildApp()

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/notifications",
                method: .get,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                let notifications = try decoder.decode([MastodonNotification].self, from: Data(buffer: XCTUnwrap(response.body)))
                XCTAssertGreaterThanOrEqual(notifications.count, 0)
            }
        }
    }

    func testGetNotification_Success() async throws {
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.notification.listNotifications",
            statusCode: 200,
            data: BlueskyAPIFixtures.listNotificationsResponse
        )

        let app = try await buildApp()

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/notifications/123456",
                method: .get,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                let notification = try decoder.decode(MastodonNotification.self, from: Data(buffer: XCTUnwrap(response.body)))
                XCTAssertNotNil(notification.id)
            }
        }
    }

    func testClearNotifications_Success() async throws {
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.notification.updateSeen",
            statusCode: 200,
            data: Data("{}" .utf8)
        )

        let app = try await buildApp()

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/notifications/clear",
                method: .post,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testDismissNotification_Success() async throws {
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.notification.updateSeen",
            statusCode: 200,
            data: Data("{}" .utf8)
        )

        let app = try await buildApp()

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/notifications/123456/dismiss",
                method: .post,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }
}
