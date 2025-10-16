import XCTest
import Hummingbird
import HummingbirdTesting
import Dependencies
@testable import Archaeopteryx
@testable import ATProtoAdapter
@testable import OAuthService
@testable import CacheLayer

/// Example tests for AccountRoutes showing dependency injection patterns
///
/// These tests demonstrate how to use mocked ATProtoClient dependencies
/// to test route handlers in isolation without requiring real AT Protocol connections.
final class AccountRoutesTestsExample: XCTestCase {

    // MARK: - Example Tests

    /// Example: Test verifying credentials with a valid token
    func testExample_VerifyCredentials_Success() async throws {
        // Set up mock dependencies
        try await withDependencies {
            // Mock ATProtoClient to return test data
            $0.atProtoClient = .testSuccess
        } operation: {
            // Your test code here
            // The AccountRoutes will use the mocked client
            XCTAssert(true, "This example shows the testing pattern")
        }
    }

    /// Example: Test with authentication errors
    func testExample_AuthError() async throws {
        try await withDependencies {
            // Use the authentication error mock
            $0.atProtoClient = .testAuthError
        } operation: {
            // Test code that expects auth failures
            XCTAssert(true, "This example shows testing auth errors")
        }
    }

    /// Example: Test with custom mock behavior
    func testExample_CustomMock() async throws {
        try await withDependencies {
            // Create a custom mock for specific behavior
            var customMock = ATProtoClientDependency.testSuccess
            customMock.getProfile = { actor in
                // Custom response for this test
                ATProtoProfile(
                    did: "did:plc:custom",
                    handle: "custom.bsky.social",
                    displayName: "Custom Test User",
                    description: "Custom bio for test",
                    avatar: nil,
                    banner: nil,
                    followersCount: 999,
                    followsCount: 888,
                    postsCount: 777,
                    indexedAt: nil
                )
            }
            $0.atProtoClient = customMock
        } operation: {
            // Test with custom mock behavior
            XCTAssert(true, "This example shows custom mocks")
        }
    }
}
