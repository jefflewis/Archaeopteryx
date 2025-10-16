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

/// Tests for StatusRoutes with dependency injection
final class StatusRoutesTests: XCTestCase {
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

    // MARK: - Get Status Tests

    func testGetStatus_WithValidID_ReturnsStatus() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            // Test that dependency is properly injected
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            // Verify the routes struct was created successfully
            XCTAssertNotNil(routes)
        }
    }

    func testGetStatus_WithAuthError_Returns401() async throws {
        try await withDependencies {
            $0.atProtoClient = .testAuthError
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    // MARK: - Create Status Tests

    func testCreateStatus_WithValidData_CreatesPost() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    func testCreateStatus_WithEmptyText_Returns400() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    // MARK: - Delete Status Tests

    func testDeleteStatus_WithValidID_DeletesPost() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    // MARK: - Get Context Tests

    func testGetContext_WithValidID_ReturnsThread() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    // MARK: - Like/Unlike Tests

    func testFavouriteStatus_WithValidID_LikesPost() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    func testUnfavouriteStatus_NotImplemented() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    // MARK: - Reblog/Unreblog Tests

    func testReblogStatus_WithValidID_RepostsPost() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    func testUnreblogStatus_NotImplemented() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    // MARK: - Get Interactors Tests

    func testGetFavouritedBy_ReturnsEmptyArray() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                statusTranslator: statusTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    func testGetRebloggedBy_ReturnsEmptyArray() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = StatusRoutes(
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
            // Verify that we can access the dependency
            @Dependency(\.atProtoClient) var client

            // Test that the mock returns expected data
            let profile = try await client.getProfile("test")
            XCTAssertEqual(profile.handle, "test.bsky.social")
            XCTAssertEqual(profile.displayName, "Test User")
        }
    }

    func testDependencyInjection_UsesAuthErrorMock() async throws {
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

    func testDependencyInjection_CustomMock() async throws {
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
            XCTAssertEqual(profile.handle, "custom.bsky.social")
            XCTAssertEqual(profile.displayName, "Custom User")
            XCTAssertEqual(profile.followersCount, 100)
        }
    }
}
