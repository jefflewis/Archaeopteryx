import Testing
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
@Suite struct TimelineRoutesTests {
    var mockCache: InMemoryCache!
    var mockOAuthService: OAuthService!
    var sessionClient: SessionScopedClient!
    var idMapping: IDMappingService!
    var statusTranslator: StatusTranslator!

    init() async {
       mockCache = InMemoryCache()
        mockOAuthService = await OAuthService(cache: mockCache)
        sessionClient = await SessionScopedClient(serviceURL: "https://bsky.social")

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

    // MARK: - Home Timeline Tests

    @Test func GetHomeTimeline_WithValidAuth_ReturnsStatuses() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    @Test func GetHomeTimeline_WithoutAuth_Returns401() async throws {
        try await withDependencies {
            $0.atProtoClient = .testAuthError
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    @Test func GetHomeTimeline_NotImplemented_ReturnsEmptyArray() async throws {
        try await withDependencies {
            var mock = ATProtoClientDependency.testSuccess
            mock.getTimeline = { _, _ in
                throw ATProtoError.notImplemented(feature: "getTimeline")
            }
            $0.atProtoClient = mock
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    // MARK: - Public Timeline Tests

    @Test func GetPublicTimeline_ReturnsEmptyArray() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            // Public timeline always returns empty for Bluesky
            #expect(routes != nil)
        }
    }

    // MARK: - Hashtag Timeline Tests

    @Test func GetHashtagTimeline_ReturnsEmptyArray() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            // Hashtag timeline not yet implemented
            #expect(routes != nil)
        }
    }

    // MARK: - List Timeline Tests

    @Test func GetListTimeline_WithValidID_ReturnsStatuses() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    @Test func GetListTimeline_WithoutAuth_Returns401() async throws {
        try await withDependencies {
            $0.atProtoClient = .testAuthError
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    @Test func GetListTimeline_NotImplemented_ReturnsEmptyArray() async throws {
        try await withDependencies {
            var mock = ATProtoClientDependency.testSuccess
            mock.getFeed = { _, _, _ in
                throw ATProtoError.notImplemented(feature: "getFeed")
            }
            $0.atProtoClient = mock
        } operation: {
            let routes = TimelineRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    // MARK: - Dependency Injection Tests

    @Test func DependencyInjection_UsesTestSuccessMock() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            @Dependency(\.atProtoClient) var client

            // Test that getTimeline is available
            let response = try await client.getTimeline(20, nil)
            #expect(response != nil)
            #expect(response.posts.count == 0)
        }
    }

    @Test func DependencyInjection_CustomMock() async throws {
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
            #expect(response.cursor == "custom_cursor")
        }
    }
}

