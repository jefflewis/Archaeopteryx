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

/// Simple integration tests using Hummingbird testing framework
@Suite(.dependencies) struct SimpleIntegrationTests {

    init() async {
       // Clear mock request executor
        await MockRequestExecutor.clearMocks()
    }

    /// Test basic route without mocking
    @Test func BasicRoute() async throws {
        let router = Router()
        router.get("/hello") { _, _ -> String in
            "Hello World"
        }
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                #expect(response.status == .ok)
                let string = String(buffer: response.body)
                #expect(string == "Hello World")
            }
        }
    }

    /// Test that MockRequestExecutor is working
    @Test func MockRequestExecutor_Works() async throws {
        // GIVEN: Register a mock
        await MockRequestExecutor.clearMocks()
        await MockRequestExecutor.registerMock(
            pattern: "test",
            statusCode: 200,
            data: "test response".data(using: .utf8)
        )

        // WHEN: Create executor and make request
        let executor = MockRequestExecutor()
        let url = URL(string: "https://example.com/test")!
        let request = URLRequest(url: url)
        let (data, response) = try await executor.execute(request)

        // THEN: Should get mocked response
        let httpResponse = response as! HTTPURLResponse
        #expect(httpResponse.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "test response")
    }

    /// Test that MockURLProtocol is working
    @Test func MockURLProtocol_Intercepts() async throws {
        // GIVEN: Register a simple mock
        MockURLProtocol.registerMock(
            pattern: "bsky.social",
            statusCode: 200,
            data: "test response".data(using: .utf8)
        )

        // Create URLSession with mock
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        // WHEN: Make a request
        let url = URL(string: "https://bsky.social/test")!
        let (data, response) = try await session.data(from: url)

        // THEN: Should get mocked response
        let httpResponse = response as! HTTPURLResponse
        #expect(httpResponse.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "test response")
    }

    /// Test account verification with full stack
    @Test func VerifyCredentials_Success() async throws {
        // GIVEN: Mock Bluesky API using request executor
        await MockRequestExecutor.clearMocks()
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.actor.getProfile",
            statusCode: 200,
            data: BlueskyAPIFixtures.getProfileResponse
        )

        // Create services (MUST share same cache instance!)
        var logger = Logger(label: "test")
        logger.logLevel = .critical
        let cache = InMemoryCache()

        // Create test token AND session BEFORE building app
        let token = "test_token_123"
        let did = "did:plc:test123456"
        let handle = "test.bsky.social"

        // Set up OAuth token data (must match OAuthService.TokenData structure)
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
            expiresIn: 7 * 24 * 60 * 60  // 7 days
        )
        try await cache.set("oauth:token:\(token)", value: tokenData, ttl: 3600)

        // Create a mock session for ATProtoClient
        let mockSession = ATProtoSession(
            did: did,
            handle: "test.bsky.social",
            accessToken: "mock_access_token",
            refreshToken: "mock_refresh_token",
            email: "test@example.com",
            createdAt: Date()
        )
        try await cache.set("session:\(did)", value: mockSession, ttl: 3600)

        // SessionScopedClient for multi-user support
        let sessionClient = await SessionScopedClient(
            serviceURL: "https://bsky.social"
        )

        // Create other services with same cache
        let oauthService = OAuthService(cache: cache)
        let generator = SnowflakeIDGenerator()
        let idMapping = IDMappingService(cache: cache, generator: generator)
        let facetProcessor = FacetProcessor()
        let profileTranslator = ProfileTranslator(idMapping: idMapping, facetProcessor: facetProcessor)

        // Build app
        let router = Router()

        // Add account routes
        AccountRoutes.addRoutes(
            to: router,
            oauthService: oauthService,
            sessionClient: sessionClient,
            idMapping: idMapping,
            translator: profileTranslator,
            logger: logger
        )

        let app = Application(responder: router.buildResponder(), logger: logger)

        // WHEN: Make request
        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/accounts/verify_credentials",
                method: .get,
                headers: [.authorization: "Bearer \(token)"]
            ) { response in
                // THEN: Verify response
                #expect(response.status == .ok)

                // Decode account
                let body = try #require(response.body)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                let account = try decoder.decode(MastodonAccount.self, from: Data(buffer: body))

                #expect(account.username == "test")
                #expect(account.acct == "test.bsky.social")
                #expect(account.displayName == "Test User")
                #expect(account.followersCount == 42)
            }
        }
    }

    /// Test missing authentication
    @Test func VerifyCredentials_NoAuth_Returns401() async throws {
        var logger = Logger(label: "test")
        logger.logLevel = .critical
        let cache = InMemoryCache()
        let oauthService = OAuthService(cache: cache)
        let sessionClient = await SessionScopedClient(serviceURL: "https://bsky.social")
        let generator = SnowflakeIDGenerator()
        let idMapping = IDMappingService(cache: cache, generator: generator)
        let facetProcessor = FacetProcessor()
        let profileTranslator = ProfileTranslator(idMapping: idMapping, facetProcessor: facetProcessor)

        let router = Router()
        AccountRoutes.addRoutes(
            to: router,
            oauthService: oauthService,
            sessionClient: sessionClient,
            idMapping: idMapping,
            translator: profileTranslator,
            logger: logger
        )

        let app = Application(responder: router.buildResponder(), logger: logger)

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/accounts/verify_credentials",
                method: .get
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
}

