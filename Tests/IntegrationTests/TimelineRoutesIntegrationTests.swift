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

/// Integration tests for Timeline API endpoints
@Suite(.dependencies) struct TimelineRoutesIntegrationTests {

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

        // Pre-populate ID mappings for test lists (Snowflake ID 123456 -> test feed URI)
        let testSnowflakeID: Int64 = 123456
        let testFeedURI = "at://did:plc:test123456/app.bsky.feed.generator/feed1"
        try await cache.set("snowflake_to_at_uri:\(testSnowflakeID)", value: testFeedURI, ttl: nil)
        try await cache.set("at_uri_to_snowflake:\(testFeedURI)", value: testSnowflakeID, ttl: nil)

        // Build app
        let router = Router()
        TimelineRoutes.addRoutes(
            to: router,
            oauthService: oauthService,
            sessionClient: sessionClient,
            idMapping: idMapping,
            statusTranslator: statusTranslator,
            logger: logger
        )
        return Application(responder: router.buildResponder(), logger: logger)
    }

    // MARK: - Tests

    @Test func GetHomeTimeline_Success() async throws {
        await MockRequestExecutor.clearMocks()
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.feed.getTimeline",
            statusCode: 200,
            data: BlueskyAPIFixtures.getTimelineResponse
        )

        let app = try await buildApp()

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/timelines/home",
                method: .get,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                #expect(response.status == .ok)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                let statuses = try decoder.decode([MastodonStatus].self, from: Data(buffer: try #require(response.body)))
                #expect(statuses.count >= 0)
            }
        }
    }

    @Test func GetPublicTimeline_Success() async throws {
        await MockRequestExecutor.clearMocks()
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.feed.getTimeline",
            statusCode: 200,
            data: BlueskyAPIFixtures.getTimelineResponse
        )

        let app = try await buildApp()

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/timelines/public",
                method: .get,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                #expect(response.status == .ok)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                let statuses = try decoder.decode([MastodonStatus].self, from: Data(buffer: try #require(response.body)))
                #expect(statuses.count >= 0)
            }
        }
    }

    @Test func GetHashtagTimeline_Success() async throws {
        await MockRequestExecutor.clearMocks()
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.feed.searchPosts",
            statusCode: 200,
            data: BlueskyAPIFixtures.getTimelineResponse
        )

        let app = try await buildApp()

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/timelines/tag/swift",
                method: .get,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                #expect(response.status == .ok)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                let statuses = try decoder.decode([MastodonStatus].self, from: Data(buffer: try #require(response.body)))
                #expect(statuses.count >= 0)
            }
        }
    }

    @Test func GetListTimeline_Success() async throws {
        await MockRequestExecutor.clearMocks()
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.feed.getFeed",
            statusCode: 200,
            data: BlueskyAPIFixtures.getFeedResponse
        )

        let app = try await buildApp()

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/timelines/list/123456",
                method: .get,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                #expect(response.status == .ok)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                let statuses = try decoder.decode([MastodonStatus].self, from: Data(buffer: try #require(response.body)))
                #expect(statuses.count >= 0)
            }
        }
    }
}

