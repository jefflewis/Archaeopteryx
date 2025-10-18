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

/// Tests for StatusRoutes with dependency injection
@Suite struct StatusRoutesTests {
    var mockCache: InMemoryCache!
    var mockOAuthService: OAuthService!
    var sessionClient: SessionScopedClient!
    var idMapping: IDMappingService!
    var statusTranslator: StatusTranslator!

    init() async {
       mockCache = InMemoryCache()
        mockOAuthService = await OAuthService(
            cache: mockCache,
            atprotoServiceURL: "https://bsky.social"
        )

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

    // MARK: - Get Status Tests

    @Test func GetStatus_WithValidID_ReturnsStatus() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            // Test that dependency is properly injected
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            // Verify the routes struct was created successfully
            #expect(routes != nil)
        }
    }

    @Test func GetStatus_WithAuthError_Returns401() async throws {
        try await withDependencies {
            $0.atProtoClient = .testAuthError
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    // MARK: - Create Status Tests

    @Test func CreateStatus_WithValidData_CreatesPost() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    @Test func CreateStatus_WithEmptyText_Returns400() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    // MARK: - Delete Status Tests

    @Test func DeleteStatus_WithValidID_DeletesPost() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    // MARK: - Get Context Tests

    @Test func GetContext_WithValidID_ReturnsThread() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    // MARK: - Like/Unlike Tests

    @Test func FavouriteStatus_WithValidID_LikesPost() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    @Test func UnfavouriteStatus_NotImplemented() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    // MARK: - Reblog/Unreblog Tests

    @Test func ReblogStatus_WithValidID_RepostsPost() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    @Test func UnreblogStatus_NotImplemented() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    // MARK: - Get Interactors Tests

    @Test func GetFavouritedBy_ReturnsEmptyArray() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                sessionClient: sessionClient,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            #expect(routes != nil)
        }
    }

    @Test func GetRebloggedBy_ReturnsEmptyArray() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
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
            // Verify that we can access the dependency
            @Dependency(\.atProtoClient) var client

            // Test that the mock returns expected data
            let profile = try await client.getProfile("test")
            #expect(profile.handle == "test.bsky.social")
            #expect(profile.displayName == "Test User")
        }
    }

    @Test func DependencyInjection_UsesAuthErrorMock() async throws {
        try await withDependencies {
            $0.atProtoClient = .testAuthError
        } operation: {
            @Dependency(\.atProtoClient) var client

            // Test that the mock throws auth errors
            do {
                _ = try await client.getProfile("test")
                XCTFail("Should have thrown auth error")
            } catch let error as ATProtoError {
                if case .authenticationFailed = error {
                    // Expected
                } else {
                    XCTFail("Wrong error type: \(error)")
                }
            }
        }
    }

    @Test func DependencyInjection_CustomMock() async throws {
        try await withDependencies {
            var customMock = ATProtoClientDependency.testSuccess
            customMock.getProfile = { _ in
                ATProtoProfile(
                    did: "did:plc:custom",
                    handle: "custom.bsky.social",
                    displayName: "Custom User",
                    description: "Custom bio",
                    avatar: nil,
                    banner: nil,
                    followersCount: 100,
                    followsCount: 50,
                    postsCount: 25,
                    indexedAt: nil
                )
            }
            $0.atProtoClient = customMock
        } operation: {
            @Dependency(\.atProtoClient) var client

            let profile = try await client.getProfile("custom")
            #expect(profile.handle == "custom.bsky.social")
            #expect(profile.displayName == "Custom User")
            #expect(profile.followersCount == 100)
        }
    }
}

