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

/// Integration tests for Status API endpoints
final class StatusRoutesIntegrationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await MockRequestExecutor.clearMocks()
    }

    override func tearDown() async throws {
        await MockRequestExecutor.clearMocks()
        try await super.tearDown()
    }

    // MARK: - Helper

    func buildApp(useSessionConfig: Bool = false) async throws -> some ApplicationProtocol {
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

        let atProtoClient: ATProtoClient
        if useSessionConfig {
            // For write operations: use SessionConfiguration to authenticate ATProtoKit
            let sessionConfig = MockSessionConfiguration(
                pdsURL: "https://bsky.social",
                accessToken: mockSession.accessToken,
                refreshToken: mockSession.refreshToken
            )
            atProtoClient = await ATProtoClient(
                serviceURL: "https://bsky.social",
                cache: cache,
                sessionConfiguration: sessionConfig,
                apiClientConfiguration: apiClientConfig
            )

            // Register the session in ATProtoKit's global session registry
            // This is required for write operations to pass session validation
            let userSession = UserSession(
                handle: handle,
                sessionDID: did,
                email: "test@example.com",
                isEmailConfirmed: true,
                isEmailAuthenticationFactorEnabled: false,
                didDocument: nil,
                isActive: true,
                status: nil,
                serviceEndpoint: URL(string: "https://bsky.social")!,
                pdsURL: "https://bsky.social"
            )
            await UserSessionRegistry.shared.register(sessionConfig.instanceUUID, session: userSession)
        } else {
            // For read operations: no SessionConfiguration needed
            atProtoClient = await ATProtoClient(
                serviceURL: "https://bsky.social",
                cache: cache,
                apiClientConfiguration: apiClientConfig
            )
        }
        await atProtoClient.setSession(mockSession)

        // Other services
        let oauthService = OAuthService(cache: cache)
        let generator = SnowflakeIDGenerator()
        let idMapping = IDMappingService(cache: cache, generator: generator)
        let facetProcessor = FacetProcessor()
        let profileTranslator = ProfileTranslator(idMapping: idMapping, facetProcessor: facetProcessor)
        let statusTranslator = StatusTranslator(idMapping: idMapping, profileTranslator: profileTranslator, facetProcessor: facetProcessor)

        // Pre-populate ID mappings for test posts (Snowflake ID 123456 -> test AT URI)
        let testSnowflakeID: Int64 = 123456
        let testATURI = "at://did:plc:test123456/app.bsky.feed.post/post1"
        try await cache.set("snowflake_to_at_uri:\(testSnowflakeID)", value: testATURI, ttl: nil)
        try await cache.set("at_uri_to_snowflake:\(testATURI)", value: testSnowflakeID, ttl: nil)
        // Also map DID for account lookups
        try await cache.set("snowflake_to_did:\(testSnowflakeID)", value: did, ttl: nil)
        try await cache.set("did_to_snowflake:\(did)", value: testSnowflakeID, ttl: nil)

        // Build app
        return try await withDependencies {
            $0.atProtoClient = .live(client: atProtoClient)
        } operation: {
            let router = Router()
            StatusRoutes.addRoutes(
                to: router,
                oauthService: oauthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: logger
            )
            return Application(responder: router.buildResponder(), logger: logger)
        }
    }

    static func decodeStatus(from body: ByteBuffer) throws -> MastodonStatus {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MastodonStatus.self, from: Data(buffer: body))
    }

    static func decodeAccount(from body: ByteBuffer) throws -> MastodonAccount {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MastodonAccount.self, from: Data(buffer: body))
    }

    // MARK: - Tests

    func testGetStatus_Success() async throws {
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.feed.getPostThread",
            statusCode: 200,
            data: BlueskyAPIFixtures.getPostThreadResponse
        )

        let app = try await buildApp()

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/statuses/123456",
                method: .get,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let status = try Self.decodeStatus(from: XCTUnwrap(response.body))
                XCTAssertNotNil(status.id)
            }
        }
    }

    func testCreateStatus_Success() async throws {
        // Mock session validation/refresh endpoints
        await MockRequestExecutor.registerMock(
            pattern: "com.atproto.server.getSession",
            statusCode: 200,
            data: BlueskyAPIFixtures.createSessionResponse
        )
        await MockRequestExecutor.registerMock(
            pattern: "com.atproto.server.refreshSession",
            statusCode: 200,
            data: BlueskyAPIFixtures.createSessionResponse
        )

        await MockRequestExecutor.registerMock(
            pattern: "com.atproto.repo.createRecord",
            statusCode: 200,
            data: BlueskyAPIFixtures.createPostResponse
        )
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.feed.getPostThread",
            statusCode: 200,
            data: BlueskyAPIFixtures.getPostThreadResponse
        )

        let app = try await buildApp(useSessionConfig: true)

        try await app.test(.router) { client in
            let body = #"{"status": "Hello World!"}"#
            try await client.execute(
                uri: "/api/v1/statuses",
                method: .post,
                headers: [
                    .authorization: "Bearer test_token_123",
                    .contentType: "application/json"
                ],
                body: ByteBuffer(string: body)
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let status = try Self.decodeStatus(from: XCTUnwrap(response.body))
                XCTAssertNotNil(status.id)
            }
        }
    }

    func testDeleteStatus_Success() async throws {
        await MockRequestExecutor.registerMock(
            pattern: "com.atproto.repo.deleteRecord",
            statusCode: 200,
            data: Data()
        )

        let app = try await buildApp(useSessionConfig: true)

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/statuses/123456",
                method: .delete,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testGetStatusContext_Success() async throws {
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.feed.getPostThread",
            statusCode: 200,
            data: BlueskyAPIFixtures.getPostThreadResponse
        )

        let app = try await buildApp()

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/statuses/123456/context",
                method: .get,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                XCTAssertEqual(response.status, .ok)
                // Context contains ancestors and descendants arrays
                let body = try XCTUnwrap(response.body)
                XCTAssertGreaterThan(body.readableBytes, 0)
            }
        }
    }

    func testFavouriteStatus_Success() async throws {
        await MockRequestExecutor.registerMock(
            pattern: "com.atproto.repo.createRecord",
            statusCode: 200,
            data: BlueskyAPIFixtures.likePostResponse
        )
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.feed.getPostThread",
            statusCode: 200,
            data: BlueskyAPIFixtures.getPostThreadResponse
        )

        let app = try await buildApp(useSessionConfig: true)

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/statuses/123456/favourite",
                method: .post,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let status = try Self.decodeStatus(from: XCTUnwrap(response.body))
                XCTAssertNotNil(status.id)
            }
        }
    }

    func testUnfavouriteStatus_Success() async throws {
        await MockRequestExecutor.registerMock(
            pattern: "com.atproto.repo.deleteRecord",
            statusCode: 200,
            data: Data()
        )
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.feed.getPostThread",
            statusCode: 200,
            data: BlueskyAPIFixtures.getPostThreadResponse
        )

        let app = try await buildApp()

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/statuses/123456/unfavourite",
                method: .post,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let status = try Self.decodeStatus(from: XCTUnwrap(response.body))
                XCTAssertNotNil(status.id)
            }
        }
    }

    func testReblogStatus_Success() async throws {
        await MockRequestExecutor.registerMock(
            pattern: "com.atproto.repo.createRecord",
            statusCode: 200,
            data: BlueskyAPIFixtures.repostResponse
        )
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.feed.getPostThread",
            statusCode: 200,
            data: BlueskyAPIFixtures.getPostThreadResponse
        )

        let app = try await buildApp(useSessionConfig: true)

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/statuses/123456/reblog",
                method: .post,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let status = try Self.decodeStatus(from: XCTUnwrap(response.body))
                XCTAssertNotNil(status.id)
            }
        }
    }

    func testUnreblogStatus_Success() async throws {
        await MockRequestExecutor.registerMock(
            pattern: "com.atproto.repo.deleteRecord",
            statusCode: 200,
            data: Data()
        )
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.feed.getPostThread",
            statusCode: 200,
            data: BlueskyAPIFixtures.getPostThreadResponse
        )

        let app = try await buildApp()

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/statuses/123456/unreblog",
                method: .post,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let status = try Self.decodeStatus(from: XCTUnwrap(response.body))
                XCTAssertNotNil(status.id)
            }
        }
    }

    func testGetFavouritedBy_Success() async throws {
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.feed.getLikes",
            statusCode: 200,
            data: BlueskyAPIFixtures.getLikesResponse
        )

        let app = try await buildApp()

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/statuses/123456/favourited_by",
                method: .get,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                let accounts = try decoder.decode([MastodonAccount].self, from: Data(buffer: XCTUnwrap(response.body)))
                XCTAssertGreaterThanOrEqual(accounts.count, 0)
            }
        }
    }

    func testGetRebloggedBy_Success() async throws {
        await MockRequestExecutor.registerMock(
            pattern: "app.bsky.feed.getRepostedBy",
            statusCode: 200,
            data: BlueskyAPIFixtures.getRepostedByResponse
        )

        let app = try await buildApp()

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/statuses/123456/reblogged_by",
                method: .get,
                headers: [.authorization: "Bearer test_token_123"]
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                let accounts = try decoder.decode([MastodonAccount].self, from: Data(buffer: XCTUnwrap(response.body)))
                XCTAssertGreaterThanOrEqual(accounts.count, 0)
            }
        }
    }
}
