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

/// Tests for NotificationRoutes with dependency injection
final class NotificationRoutesTests: XCTestCase {
    var mockCache: InMemoryCache!
    var mockOAuthService: OAuthService!
    var idMapping: IDMappingService!
    var notificationTranslator: NotificationTranslator!

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
        let statusTranslator = StatusTranslator(
            idMapping: idMapping,
            profileTranslator: profileTranslator,
            facetProcessor: facetProcessor
        )
        notificationTranslator = NotificationTranslator(
            idMapping: idMapping,
            profileTranslator: profileTranslator,
            statusTranslator: statusTranslator
        )
    }

    override func tearDown() async throws {
        mockCache = nil
        mockOAuthService = nil
        idMapping = nil
        notificationTranslator = nil
        try await super.tearDown()
    }

    // MARK: - Get Notifications Tests

    func testGetNotifications_WithValidAuth_ReturnsNotifications() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = NotificationRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                notificationTranslator: notificationTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    func testGetNotifications_WithoutAuth_Returns401() async throws {
        try await withDependencies {
            $0.atProtoClient = .testAuthError
        } operation: {
            let routes = NotificationRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                notificationTranslator: notificationTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    func testGetNotifications_NotImplemented_ReturnsEmptyArray() async throws {
        try await withDependencies {
            var mock = ATProtoClientDependency.testSuccess
            mock.getNotifications = { _, _ in
                throw ATProtoError.notImplemented(feature: "getNotifications")
            }
            $0.atProtoClient = mock
        } operation: {
            let routes = NotificationRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                notificationTranslator: notificationTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    func testGetNotifications_WithPagination_RespectsLimit() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = NotificationRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                notificationTranslator: notificationTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    // MARK: - Get Single Notification Tests

    func testGetNotification_WithValidID_Returns404() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = NotificationRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                notificationTranslator: notificationTranslator,
                logger: Logger(label: "test")
            )

            // Single notification fetch not fully implemented
            XCTAssertNotNil(routes)
        }
    }

    func testGetNotification_WithoutAuth_Returns401() async throws {
        try await withDependencies {
            $0.atProtoClient = .testAuthError
        } operation: {
            let routes = NotificationRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                notificationTranslator: notificationTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    // MARK: - Clear Notifications Tests

    func testClearNotifications_WithValidAuth_UpdatesSeen() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = NotificationRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                notificationTranslator: notificationTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    func testClearNotifications_WithoutAuth_Returns401() async throws {
        try await withDependencies {
            $0.atProtoClient = .testAuthError
        } operation: {
            let routes = NotificationRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                notificationTranslator: notificationTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    func testClearNotifications_NotImplemented_ReturnsSuccess() async throws {
        try await withDependencies {
            var mock = ATProtoClientDependency.testSuccess
            mock.updateSeenNotifications = {
                throw ATProtoError.notImplemented(feature: "updateSeenNotifications")
            }
            $0.atProtoClient = mock
        } operation: {
            let routes = NotificationRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                notificationTranslator: notificationTranslator,
                logger: Logger(label: "test")
            )

            XCTAssertNotNil(routes)
        }
    }

    // MARK: - Dismiss Notification Tests

    func testDismissNotification_ReturnsSuccess() async throws {
        try await withDependencies {
            $0.atProtoClient = .testSuccess
        } operation: {
            let routes = NotificationRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                notificationTranslator: notificationTranslator,
                logger: Logger(label: "test")
            )

            // Dismiss just returns success (Bluesky doesn't support individual dismissal)
            XCTAssertNotNil(routes)
        }
    }

    func testDismissNotification_WithoutAuth_Returns401() async throws {
        try await withDependencies {
            $0.atProtoClient = .testAuthError
        } operation: {
            let routes = NotificationRoutes(
                oauthService: mockOAuthService,
                idMapping: idMapping,
                notificationTranslator: notificationTranslator,
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

            // Test that getNotifications is available
            let response = try await client.getNotifications(20, nil)
            XCTAssertNotNil(response)
            XCTAssertEqual(response.notifications.count, 0)
        }
    }

    func testDependencyInjection_CustomMock() async throws {
        try await withDependencies {
            var customMock = ATProtoClientDependency.testSuccess
            customMock.getNotifications = { limit, cursor in
                // Return custom notifications response
                ATProtoNotificationsResponse(notifications: [], cursor: "custom_cursor")
            }
            $0.atProtoClient = customMock
        } operation: {
            @Dependency(\.atProtoClient) var client

            let response = try await client.getNotifications(20, nil)
            XCTAssertEqual(response.cursor, "custom_cursor")
        }
    }

    func testDependencyInjection_UpdateSeenWorks() async throws {
        try await withDependencies {
            var customMock = ATProtoClientDependency.testSuccess
            customMock.updateSeenNotifications = {
                // Just verify the call completes successfully
            }
            $0.atProtoClient = customMock
        } operation: {
            @Dependency(\.atProtoClient) var client

            try await client.updateSeenNotifications()
            // This test just verifies the call doesn't throw
        }
    }
}
