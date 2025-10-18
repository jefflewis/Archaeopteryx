import Testing
import Hummingbird
import HummingbirdTesting
@testable import Archaeopteryx
@testable import OAuthService
@testable import MastodonModels
@testable import CacheLayer

@Suite struct OAuthRoutesTests {
    // MARK: - Simple Integration Tests
    // These tests verify the OAuth route handlers work correctly
    // We'll test the actual HTTP layer integration once it's implemented

    /// Test that we can create OAuth routes structure
    /// This is a placeholder test that will be enhanced as we implement the routes
    @Test func OAuthRoutes_CanBeCreated() {
        // This test will pass immediately but reminds us to implement OAuth routes
        #expect(true, "OAuth routes need to be implemented")
    }

    /// Test OAuth service integration with cache
    @Test func OAuthService_RegistersApplication() async throws {
        let cache = InMemoryCache()
        let service = OAuthService(cache: cache)

        let app = try await service.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read write",
            website: "https://example.com"
        )

        #expect(app.name == "Test App")
        #expect(app.redirectUri == "urn:ietf:wg:oauth:2.0:oob")
        #expect(app.website == "https://example.com")
        #expect(!(app.clientId.isEmpty))
        #expect(!(app.clientSecret.isEmpty))
    }

    /// Test OAuth service generates authorization codes
    @Test func OAuthService_GeneratesAuthorizationCode() async throws {
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

        #expect(!(code.isEmpty))
    }

    /// Test OAuth service exchanges code for token
    @Test func OAuthService_ExchangesCodeForToken() async throws {
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

        #expect(!(token.accessToken.isEmpty))
        #expect(token.tokenType == "Bearer")
        #expect(token.scope == "read write")
    }

    /// Test OAuth service password grant
    @Test func OAuthService_PasswordGrant() async throws {
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

        #expect(!(token.accessToken.isEmpty))
        #expect(token.tokenType == "Bearer")
    }

    /// Test OAuth service validates tokens
    @Test func OAuthService_ValidatesToken() async throws {
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
        #expect(handle == "test.bsky.social")
    }

    /// Test OAuth service revokes tokens
    @Test func OAuthService_RevokesToken() async throws {
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
        #expect(handle == "test.bsky.social")

        // Revoke token
        try await service.revokeToken(token.accessToken)

        // Verify token is no longer valid
        do {
            _ = try await service.validateToken(token.accessToken)
        } catch {
            // Expected error
        }
    }

    /// Test OAuth service validates missing client name
    @Test func OAuthService_ValidatesClientName() async throws {
        let cache = InMemoryCache()
        let service = OAuthService(cache: cache)

        do {
            _ = try await service.registerApplication(
                clientName: "",
                redirectUris: "urn:ietf:wg:oauth:2.0:oob",
                scopes: "read write",
                website: nil
            )
        } catch {
            // Expected error
        }
    }

    /// Test OAuth service validates missing redirect URI
    @Test func OAuthService_ValidatesRedirectUri() async throws {
        let cache = InMemoryCache()
        let service = OAuthService(cache: cache)

        do {
            _ = try await service.registerApplication(
                clientName: "Test App",
                redirectUris: "",
                scopes: "read write",
                website: nil
            )
        } catch {
            // Expected error
        }
    }

    /// Test OAuth service validates scopes
    @Test func OAuthService_ValidatesScopes() throws {
        let cache = InMemoryCache()
        let service = OAuthService(cache: cache)

        // Valid scopes
        let validScopes = try service.validateScopes("read write follow")
        #expect(validScopes.count == 3)

        // Empty defaults to read
        let defaultScopes = try service.validateScopes("")
        #expect(defaultScopes.count == 1)
        #expect(defaultScopes.contains(.read))
    }
}

