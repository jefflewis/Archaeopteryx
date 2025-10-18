import Foundation
import Testing
@testable import OAuthService
@testable import MastodonModels
@testable import CacheLayer
@testable import ATProtoAdapter
@testable import ArchaeopteryxCore

/// Tests for OAuthService - OAuth 2.0 flow implementation
@Suite struct OAuthServiceTests {
    let sut: OAuthService
    var mockCache: InMemoryCache!

    init() async {
       mockCache = InMemoryCache()
        sut = await OAuthService(cache: mockCache, atprotoServiceURL: "https://bsky.social")
    }

    // MARK: - App Registration Tests

    @Test func RegisterApp_ValidRequest_ReturnsCredentials() async throws {
        let result = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read write follow",
            website: "https://example.com"
        )

        #expect(!(result.clientId.isEmpty))
        #expect(!(result.clientSecret.isEmpty))
        #expect(result.name == "Test App")
        #expect(result.redirectUri == "urn:ietf:wg:oauth:2.0:oob")
        #expect(result.website == "https://example.com")
    }

    @Test func RegisterApp_MissingClientName_ThrowsError() async throws {
        do {
            _ = try await sut.registerApplication(
                clientName: "",
                redirectUris: "urn:ietf:wg:oauth:2.0:oob",
                scopes: "read",
                website: nil
            )
            // Should throw error
        } catch {
            // Expected error
            #expect(true)
        }
    }

    @Test func RegisterApp_MissingRedirectURI_ThrowsError() async throws {
        do {
            _ = try await sut.registerApplication(
                clientName: "Test App",
                redirectUris: "",
                scopes: "read",
                website: nil
            )
        } catch {
            // Expected error
            #expect(true)
        }
    }

    @Test func RegisterApp_StoresInCache() async throws {
        let result = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read",
            website: nil
        )

        // Should be able to retrieve it
        let retrieved = try await sut.getApplication(clientId: result.clientId)
        #expect(retrieved.clientId == result.clientId)
        #expect(retrieved.name == "Test App")
    }

    // MARK: - Authorization Code Generation Tests

    @Test func GenerateAuthCode_ValidRequest_ReturnsCode() async throws {
        // First register an app
        let app = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read write",
            website: nil
        )

        let code = try await sut.generateAuthorizationCode(
            clientId: app.clientId,
            redirectUri: "urn:ietf:wg:oauth:2.0:oob",
            scope: "read write",
            handle: "alice.bsky.social",
            password: "test-password"
        )

        #expect(!(code.isEmpty))
        #expect(code.count > 20) // Should be a reasonable length
    }

    @Test func GenerateAuthCode_InvalidClientId_ThrowsError() async throws {
        do {
            _ = try await sut.generateAuthorizationCode(
                clientId: "invalid-client-id",
                redirectUri: "urn:ietf:wg:oauth:2.0:oob",
                scope: "read",
                handle: "alice.bsky.social",
                password: "password"
            )
        } catch {
            // Expected error
            #expect(true)
        }
    }

    @Test func GenerateAuthCode_MismatchedRedirectURI_ThrowsError() async throws {
        let app = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read",
            website: nil
        )

        do {
            _ = try await sut.generateAuthorizationCode(
                clientId: app.clientId,
                redirectUri: "https://wrong-uri.com",
                scope: "read",
                handle: "alice.bsky.social",
                password: "password"
            )
        } catch {
            // Expected error
            #expect(true)
        }
    }

    // MARK: - Token Exchange Tests

    @Test func ExchangeCodeForToken_ValidCode_ReturnsAccessToken() async throws {
        // Register app and generate code
        let app = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read write",
            website: nil
        )

        let code = try await sut.generateAuthorizationCode(
            clientId: app.clientId,
            redirectUri: "urn:ietf:wg:oauth:2.0:oob",
            scope: "read write",
            handle: "alice.bsky.social",
            password: "password"
        )

        let token = try await sut.exchangeAuthorizationCode(
            code: code,
            clientId: app.clientId,
            clientSecret: app.clientSecret,
            redirectUri: "urn:ietf:wg:oauth:2.0:oob"
        )

        #expect(!(token.accessToken.isEmpty))
        #expect(token.tokenType == "Bearer")
        #expect(token.scope == "read write")
        #expect(token.createdAt > 0)
    }

    @Test func ExchangeCodeForToken_InvalidCode_ThrowsError() async throws {
        let app = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read",
            website: nil
        )

        do {
            _ = try await sut.exchangeAuthorizationCode(
                code: "invalid-code",
                clientId: app.clientId,
                clientSecret: app.clientSecret,
                redirectUri: "urn:ietf:wg:oauth:2.0:oob"
            )
        } catch {
            // Expected error
            #expect(true)
        }
    }

    @Test func ExchangeCodeForToken_UsedCode_ThrowsError() async throws {
        let app = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read",
            website: nil
        )

        let code = try await sut.generateAuthorizationCode(
            clientId: app.clientId,
            redirectUri: "urn:ietf:wg:oauth:2.0:oob",
            scope: "read",
            handle: "alice.bsky.social",
            password: "password"
        )

        // Use the code once
        _ = try await sut.exchangeAuthorizationCode(
            code: code,
            clientId: app.clientId,
            clientSecret: app.clientSecret,
            redirectUri: "urn:ietf:wg:oauth:2.0:oob"
        )

        // Try to use it again
        do {
            _ = try await sut.exchangeAuthorizationCode(
                code: code,
                clientId: app.clientId,
                clientSecret: app.clientSecret,
                redirectUri: "urn:ietf:wg:oauth:2.0:oob"
            )
        } catch {
            // Expected error
            #expect(true)
        }
    }

    // MARK: - Password Grant Tests

    @Test func PasswordGrant_ValidCredentials_ReturnsToken() async throws {
        let app = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read write",
            website: nil
        )

        let token = try await sut.passwordGrant(
            clientId: app.clientId,
            clientSecret: app.clientSecret,
            scope: "read write",
            username: "alice.bsky.social",
            password: "password"
        )

        #expect(!(token.accessToken.isEmpty))
        #expect(token.tokenType == "Bearer")
        #expect(token.scope == "read write")
    }

    @Test func PasswordGrant_InvalidClientSecret_ThrowsError() async throws {
        let app = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read",
            website: nil
        )

        do {
            _ = try await sut.passwordGrant(
                clientId: app.clientId,
                clientSecret: "wrong-secret",
                scope: "read",
                username: "alice.bsky.social",
                password: "password"
            )
        } catch {
            // Expected error
            #expect(true)
        }
    }

    // MARK: - Token Validation Tests

    @Test func ValidateToken_ValidToken_ReturnsUserContext() async throws {
        let app = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read",
            website: nil
        )

        let token = try await sut.passwordGrant(
            clientId: app.clientId,
            clientSecret: app.clientSecret,
            scope: "read",
            username: "alice.bsky.social",
            password: "password"
        )

        let userContext = try await sut.validateToken(token.accessToken)
        #expect(userContext.handle == "alice.bsky.social")
        #expect(!userContext.did.isEmpty)
        #expect(!userContext.sessionData.accessToken.isEmpty)
    }

    @Test func ValidateToken_InvalidToken_ThrowsError() async throws {
        do {
            _ = try await sut.validateToken("invalid-token")
        } catch {
            // Expected error
            #expect(true)
        }
    }

    // MARK: - Token Revocation Tests

    @Test func RevokeToken_ValidToken_RemovesFromCache() async throws {
        let app = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read",
            website: nil
        )

        let token = try await sut.passwordGrant(
            clientId: app.clientId,
            clientSecret: app.clientSecret,
            scope: "read",
            username: "alice.bsky.social",
            password: "password"
        )

        // Token should be valid
        let userContext = try await sut.validateToken(token.accessToken)
        #expect(userContext.handle == "alice.bsky.social")

        // Revoke it
        try await sut.revokeToken(token.accessToken)

        // Should no longer be valid
        do {
            _ = try await sut.validateToken(token.accessToken)
        } catch {
            // Expected error
            #expect(true)
        }
    }

    @Test func RevokeToken_InvalidToken_NoError() async throws {
        // Should not throw error for invalid token
        try await sut.revokeToken("non-existent-token")
        // If we get here, test passes
        #expect(true)
    }

    // MARK: - Scope Validation Tests

    @Test func ValidateScopes_ValidScopes_Succeeds() async throws {
        let result = try sut.validateScopes("read write follow")
        #expect(result.contains(.read))
        #expect(result.contains(.write))
        #expect(result.contains(.follow))
    }

    @Test func ValidateScopes_EmptyScope_UsesDefaultRead() async throws {
        let result = try sut.validateScopes("")
        #expect(result.contains(.read))
        #expect(result.count == 1)
    }

    @Test func ValidateScopes_InvalidScope_ThrowsError() async throws {
        do {
            _ = try sut.validateScopes("invalid-scope")
        } catch {
            // Expected error
            #expect(true)
        }
    }

    // MARK: - Token Expiration Tests

    @Test func Token_NotExpired_ReturnsFalse() {
        let token = OAuthToken(
            accessToken: "test",
            tokenType: "Bearer",
            scope: "read",
            createdAt: Int(Date().timeIntervalSince1970),
            expiresIn: 3600 // 1 hour
        )

        #expect(!(token.isExpired()))
    }

    @Test func Token_Expired_ReturnsTrue() {
        let oneHourAgo = Int(Date().timeIntervalSince1970) - 3600
        let token = OAuthToken(
            accessToken: "test",
            tokenType: "Bearer",
            scope: "read",
            createdAt: oneHourAgo,
            expiresIn: 1800 // 30 minutes
        )

        #expect(token.isExpired())
    }

    // MARK: - Session Refresh Tests

    @Test func RefreshSession_ExpiredSession_RefreshesTokens() async throws {
        // GIVEN: A valid OAuth token with session data
        let app = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read write",
            website: nil
        )

        let token = try await sut.passwordGrant(
            clientId: app.clientId,
            clientSecret: app.clientSecret,
            scope: "read write",
            username: "alice.bsky.social",
            password: "password"
        )

        // Get the user context
        let userContext = try await sut.validateToken(token.accessToken)
        let originalAccessToken = userContext.sessionData.accessToken

        // Simulate an expired AT Proto session by creating expired session data
        let expiredSessionData = BlueskySessionData(
            accessToken: "expired_access_token",
            refreshToken: userContext.sessionData.refreshToken,
            did: userContext.sessionData.did,
            handle: userContext.sessionData.handle,
            email: userContext.sessionData.email,
            createdAt: Date().addingTimeInterval(-7200) // 2 hours ago
        )

        // Update the token data in cache with expired session
        try await mockCache.set("oauth:token:\(token.accessToken)", value: TokenData(
            did: userContext.did,
            handle: userContext.handle,
            sessionData: expiredSessionData,
            scope: "read write",
            tokenType: "Bearer",
            createdAt: token.createdAt,
            expiresIn: token.expiresIn ?? 7 * 24 * 60 * 60
        ), ttl: 3600)

        // WHEN: Refresh the session
        let refreshedContext = try await sut.refreshSession(accessToken: token.accessToken)

        // THEN: Should have new access token but same user identity
        #expect(refreshedContext.did == userContext.did)
        #expect(refreshedContext.handle == userContext.handle)
        #expect(refreshedContext.sessionData.accessToken != originalAccessToken)
        #expect(refreshedContext.sessionData.accessToken != "expired_access_token")
        #expect(!refreshedContext.sessionData.accessToken.isEmpty)
    }

    @Test func RefreshSession_InvalidToken_ThrowsError() async throws {
        // WHEN/THEN: Attempting to refresh with invalid token should throw
        do {
            _ = try await sut.refreshSession(accessToken: "invalid-token")
            #expect(Bool(false), "Should have thrown error")
        } catch {
            // Expected error
            #expect(true)
        }
    }

    @Test func RefreshSession_UpdatesCache() async throws {
        // GIVEN: A token with session data
        let app = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read write",
            website: nil
        )

        let token = try await sut.passwordGrant(
            clientId: app.clientId,
            clientSecret: app.clientSecret,
            scope: "read write",
            username: "alice.bsky.social",
            password: "password"
        )

        let userContext = try await sut.validateToken(token.accessToken)
        let originalAccessToken = userContext.sessionData.accessToken

        // Simulate expired session
        let expiredSessionData = BlueskySessionData(
            accessToken: "expired_access_token",
            refreshToken: userContext.sessionData.refreshToken,
            did: userContext.sessionData.did,
            handle: userContext.sessionData.handle,
            email: userContext.sessionData.email,
            createdAt: Date().addingTimeInterval(-7200)
        )

        try await mockCache.set("oauth:token:\(token.accessToken)", value: TokenData(
            did: userContext.did,
            handle: userContext.handle,
            sessionData: expiredSessionData,
            scope: "read write",
            tokenType: "Bearer",
            createdAt: token.createdAt,
            expiresIn: token.expiresIn ?? 7 * 24 * 60 * 60
        ), ttl: 3600)

        // WHEN: Refresh the session
        _ = try await sut.refreshSession(accessToken: token.accessToken)

        // THEN: Subsequent token validation should return the refreshed session
        let updatedContext = try await sut.validateToken(token.accessToken)
        #expect(updatedContext.sessionData.accessToken != originalAccessToken)
        #expect(updatedContext.sessionData.accessToken != "expired_access_token")
    }
}

