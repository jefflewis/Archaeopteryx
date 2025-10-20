import Foundation
import HummingbirdTesting
import HTTPTypes
import Logging
import Testing
@testable import Hummingbird

import ATProtoKit
import Dependencies
import DependenciesTestSupport
@testable import Archaeopteryx
@testable import ATProtoAdapter
@testable import CacheLayer
@testable import OAuthService
@testable import IDMapping
@testable import TranslationLayer
@testable import MastodonModels
@testable import ArchaeopteryxCore

/// Integration tests for Notification API endpoints
@Suite(.dependencies) struct NotificationRoutesIntegrationTests {

    init() async {
       await MockRequestExecutor.clearMocks()
    }

    // MARK: - Helper

    func buildApp() async throws -> some ApplicationProtocol {
        let token = "test_token_123"
        let did = "did:plc:test123456"
        let handle = "test.bsky.social"

        var logger = Logger(label: "test")
        logger.logLevel = .critical
        let cache = InMemoryCache()

        // OAuth token with Bluesky session data
        struct TokenData: Codable {
            let did: String
            let handle: String
            let sessionData: BlueskySessionData
            let scope: String
            let tokenType: String
            let createdAt: Int
            let expiresIn: Int
        }

        let sessionData = BlueskySessionData(
            accessToken: "mock_access_token",
            refreshToken: "mock_refresh_token",
            did: did,
            handle: handle,
            email: "test.com",
            createdAt: Date()
        )

        let tokenData = TokenData(
            did: did,
            handle: handle,
            sessionData: sessionData,
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

        // SessionScopedClient with mock (for multi-user support)
        let sessionClient = await SessionScopedClient(
            serviceURL: "https://bsky.social"
        )

        // Other services
        let oauthService = OAuthService(cache: cache)
        let generator = SnowflakeIDGenerator()
        let idMapping = IDMappingService(cache: cache, generator: generator)
        let facetProcessor = FacetProcessor()
        let profileTranslator = ProfileTranslator(idMapping: idMapping, facetProcessor: facetProcessor)
        let statusTranslator = StatusTranslator(idMapping: idMapping, profileTranslator: profileTranslator, facetProcessor: facetProcessor)
        let notificationTranslator = NotificationTranslator(idMapping: idMapping, profileTranslator: profileTranslator, statusTranslator: statusTranslator)

        // Build app
        let router = Router()
        NotificationRoutes.addRoutes(
            to: router,
            oauthService: oauthService,
            sessionClient: sessionClient,
            idMapping: idMapping,
            notificationTranslator: notificationTranslator,
            logger: logger
        )
        return Application(responder: router.buildResponder(), logger: logger)
    }

    // MARK: - Tests

    @Test func GetNotifications_Success() async throws {
        await MockRequestExecutor.clearMocks()
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
                #expect(response.status == .ok)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                let notifications = try decoder.decode([MastodonNotification].self, from: Data(buffer: try #require(response.body)))
                #expect(notifications.count >= 0)
            }
        }
    }

    @Test func GetNotification_Success() async throws {
        await MockRequestExecutor.clearMocks()
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
                #expect(response.status == .ok)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                let notification = try decoder.decode(MastodonNotification.self, from: Data(buffer: try #require(response.body)))
                #expect(notification.id != nil)
            }
        }
    }

    @Test func ClearNotifications_Success() async throws {
        await MockRequestExecutor.clearMocks()
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
                #expect(response.status == .ok)
            }
        }
    }

    @Test func DismissNotification_Success() async throws {
        await MockRequestExecutor.clearMocks()
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
                #expect(response.status == .ok)
            }
        }
    }
}

