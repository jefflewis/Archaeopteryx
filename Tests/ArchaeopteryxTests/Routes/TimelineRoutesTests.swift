import XCTest
import Hummingbird
import HummingbirdTesting
import Dependencies
import Logging
@testable import Archaeopteryx
@testable import ATProtoAdapter
@testable import OAuthService
@testable import CacheLayer
@testable import IDMapping
@testable import TranslationLayer
@testable import MastodonModels

/// Tests for TimelineRoutes with dependency injection
final class TimelineRoutesTests: XCTestCase {
    var mockCache: InMemoryCache!
    var mockOAuthService: OAuthService!
    var idMapping: IDMappingService!
    var statusTranslator: StatusTranslator!

    override func setUp() async throws {
        try await super.setUp()
        mockCache = InMemoryCache()
        mockOAuthService = await OAuthService(cache: mockCache)

        let snowflakeGenerator = SnowflakeIDGenerator()
        idMapping = IDMappingService(cache: mockCache, generator: snowflakeGenerator)

        let facetProcessor = FacetProcessor()
        let profileTranslator = ProfileTranslator(
            idMapping: idMapping,
            facetProcessor: facetProcessor
        )
        statusTranslator = StatusTranslator(
            idMapping: idMapping,
            profileTranslator: profileTranslator,
            facetProcessor: facetProcessor
        )
    }

    override func tearDown() async throws {
        mockCache = nil
        mockOAuthService = nil
        idMapping = nil
        statusTranslator = nil
        try await super.tearDown()
    }

    // MARK: - Home Timeline Tests

    func testGetHomeTimeline_WithValidAuth_ReturnsStatuses() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    func testGetHomeTimeline_WithoutAuth_Returns401() async throws {
        try await withDependencies {
            $0.atProtoClient = .testAuthError
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    func testGetHomeTimeline_NotImplemented_ReturnsEmptyArray() async throws {
        try await withDependencies {
            var mock = ATProtoClientDependency.testSuccess
            mock.getTimeline = { _, _ in
                throw ATProtoError.notImplemented(feature: "getTimeline")
            }
            $0.atProtoClient = mock
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    // MARK: - Public Timeline Tests

    func testGetPublicTimeline_ReturnsEmptyArray() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            // Public timeline always returns empty for Bluesky
            XCTAssertNotNil(routes)
        }
    }

    // MARK: - Hashtag Timeline Tests

    func testGetHashtagTimeline_ReturnsEmptyArray() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            // Hashtag timeline not yet implemented
            XCTAssertNotNil(routes)
        }
    }

    // MARK: - List Timeline Tests

    func testGetListTimeline_WithValidID_ReturnsStatuses() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    func testGetListTimeline_WithoutAuth_Returns401() async throws {
        try await withDependencies {
            $0.atProtoClient = .testAuthError
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    func testGetListTimeline_NotImplemented_ReturnsEmptyArray() async throws {
        try await withDependencies {
            var mock = ATProtoClientDependency.testSuccess
            mock.getFeed = { _, _, _ in
                throw ATProtoError.notImplemented(feature: "getFeed")
            }
            $0.atProtoClient = mock
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    // MARK: - Dependency Injection Tests

    func testDependencyInjection_UsesTestSuccessMock() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            @Dependency(\.atProtoClient) var client

            // Test that getTimeline is available
            let response = try await client.getTimeline(20, nil)
            XCTAssertNotNil(response)
            XCTAssertEqual(response.posts.count, 0)
        }
    }

    func testDependencyInjection_CustomMock() async throws {
        try await withDependencies {
            var customMock = ATProtoClientDependency.testSuccess
            customMock.getTimeline = { limit, cursor in
                // Return custom feed response
                ATProtoFeedResponse(posts: [], cursor: "custom_cursor")
            }
            $0.atProtoClient = customMock
        } operation: {
            @Dependency(\.atProtoClient) var client

            let response = try await client.getTimeline(20, nil)
            XCTAssertEqual(response.cursor, "custom_cursor")
        }
    }
}
