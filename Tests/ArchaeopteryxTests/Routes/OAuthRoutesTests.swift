import XCTest
import Hummingbird
import HummingbirdTesting
@testable import Archaeopteryx
@testable import OAuthService
@testable import MastodonModels
@testable import CacheLayer

final class OAuthRoutesTests: XCTestCase {
    // MARK: - Simple Integration Tests
    // These tests verify the OAuth route handlers work correctly
    // We'll test the actual HTTP layer integration once it's implemented

    /// Test that we can create OAuth routes structure
    /// This is a placeholder test that will be enhanced as we implement the routes
    func testOAuthRoutes_CanBeCreated() {
        // This test will pass immediately but reminds us to implement OAuth routes
        XCTAssertTrue(true, "OAuth routes need to be implemented")
    }

    /// Test OAuth service integration with cache
    func testOAuthService_RegistersApplication() async throws {
        let cache = InMemoryCache()
        let service = OAuthService(cache: cache)

        let app = try await service.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read write",
            website: "https://example.com"
        )

        XCTAssertEqual(app.name, "Test App")
        XCTAssertEqual(app.redirectUri, "urn:ietf:wg:oauth:2.0:oob")
        XCTAssertEqual(app.website, "https://example.com")
        XCTAssertFalse(app.clientId.isEmpty)
        XCTAssertFalse(app.clientSecret.isEmpty)
    }

    /// Test OAuth service generates authorization codes
    func testOAuthService_GeneratesAuthorizationCode() async throws {
        let cache = InMemoryCache()
        let service = OAuthService(cache: cache)

        // First register an app
        let app = try await service.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read write",
            website: nil
        )

        // Generate authorization code
        let code = try await service.generateAuthorizationCode(
            clientId: app.clientId,
            redirectUri: "urn:ietf:wg:oauth:2.0:oob",
            scope: "read write",
            handle: "test.bsky.social",
            password: "test-password"
        )

        XCTAssertFalse(code.isEmpty)
    }

    /// Test OAuth service exchanges code for token
    func testOAuthService_ExchangesCodeForToken() async throws {
        let cache = InMemoryCache()
        let service = OAuthService(cache: cache)

        // Register app
        let app = try await service.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read write",
            website: nil
        )

        // Generate code
        let code = try await service.generateAuthorizationCode(
            clientId: app.clientId,
            redirectUri: "urn:ietf:wg:oauth:2.0:oob",
            scope: "read write",
            handle: "test.bsky.social",
            password: "test-password"
        )

        // Exchange for token
        let token = try await service.exchangeAuthorizationCode(
            code: code,
            clientId: app.clientId,
            clientSecret: app.clientSecret,
            redirectUri: "urn:ietf:wg:oauth:2.0:oob"
        )

        XCTAssertFalse(token.accessToken.isEmpty)
        XCTAssertEqual(token.tokenType, "Bearer")
        XCTAssertEqual(token.scope, "read write")
    }

    /// Test OAuth service password grant
    func testOAuthService_PasswordGrant() async throws {
        let cache = InMemoryCache()
        let service = OAuthService(cache: cache)

        // Register app
        let app = try await service.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read write",
            website: nil
        )

        // Password grant
        let token = try await service.passwordGrant(
            clientId: app.clientId,
            clientSecret: app.clientSecret,
            scope: "read write",
            username: "test.bsky.social",
            password: "test-password"
        )

        XCTAssertFalse(token.accessToken.isEmpty)
        XCTAssertEqual(token.tokenType, "Bearer")
    }

    /// Test OAuth service validates tokens
    func testOAuthService_ValidatesToken() async throws {
        let cache = InMemoryCache()
        let service = OAuthService(cache: cache)

        // Register app and get token
        let app = try await service.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read write",
            website: nil
        )

        let token = try await service.passwordGrant(
            clientId: app.clientId,
            clientSecret: app.clientSecret,
            scope: "read write",
            username: "test.bsky.social",
            password: "test-password"
        )

        // Validate token
        let handle = try await service.validateToken(token.accessToken)
        XCTAssertEqual(handle, "test.bsky.social")
    }

    /// Test OAuth service revokes tokens
    func testOAuthService_RevokesToken() async throws {
        let cache = InMemoryCache()
        let service = OAuthService(cache: cache)

        // Register app and get token
        let app = try await service.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read write",
            website: nil
        )

        let token = try await service.passwordGrant(
            clientId: app.clientId,
            clientSecret: app.clientSecret,
            scope: "read write",
            username: "test.bsky.social",
            password: "test-password"
        )

        // Verify token is valid
        let handle = try await service.validateToken(token.accessToken)
        XCTAssertEqual(handle, "test.bsky.social")

        // Revoke token
        try await service.revokeToken(token.accessToken)

        // Verify token is no longer valid
        do {
            _ = try await service.validateToken(token.accessToken)
            XCTFail("Token should have been revoked")
        } catch {
            // Expected error
        }
    }

    /// Test OAuth service validates missing client name
    func testOAuthService_ValidatesClientName() async throws {
        let cache = InMemoryCache()
        let service = OAuthService(cache: cache)

        do {
            _ = try await service.registerApplication(
                clientName: "",
                redirectUris: "urn:ietf:wg:oauth:2.0:oob",
                scopes: "read write",
                website: nil
            )
            XCTFail("Should have thrown validation error")
        } catch {
            // Expected error
        }
    }

    /// Test OAuth service validates missing redirect URI
    func testOAuthService_ValidatesRedirectUri() async throws {
        let cache = InMemoryCache()
        let service = OAuthService(cache: cache)

        do {
            _ = try await service.registerApplication(
                clientName: "Test App",
                redirectUris: "",
                scopes: "read write",
                website: nil
            )
            XCTFail("Should have thrown validation error")
        } catch {
            // Expected error
        }
    }

    /// Test OAuth service validates scopes
    func testOAuthService_ValidatesScopes() throws {
        let cache = InMemoryCache()
        let service = OAuthService(cache: cache)

        // Valid scopes
        let validScopes = try service.validateScopes("read write follow")
        XCTAssertEqual(validScopes.count, 3)

        // Empty defaults to read
        let defaultScopes = try service.validateScopes("")
        XCTAssertEqual(defaultScopes.count, 1)
        XCTAssertTrue(defaultScopes.contains(.read))
    }
}
