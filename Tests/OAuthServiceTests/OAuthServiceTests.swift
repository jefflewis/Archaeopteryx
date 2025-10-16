import XCTest
@testable import OAuthService
@testable import MastodonModels
@testable import CacheLayer
@testable import ATProtoAdapter

/// Tests for OAuthService - OAuth 2.0 flow implementation
final class OAuthServiceTests: XCTestCase {
    var sut: OAuthService!
    var mockCache: InMemoryCache!

    override func setUp() async throws {
        try await super.setUp()
        mockCache = InMemoryCache()
        sut = await OAuthService(cache: mockCache)
    }

    override func tearDown() async throws {
        sut = nil
        mockCache = nil
        try await super.tearDown()
    }

    // MARK: - App Registration Tests

    func testRegisterApp_ValidRequest_ReturnsCredentials() async throws {
        let result = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read write follow",
            website: "https://example.com"
        )

        XCTAssertFalse(result.clientId.isEmpty)
        XCTAssertFalse(result.clientSecret.isEmpty)
        XCTAssertEqual(result.name, "Test App")
        XCTAssertEqual(result.redirectUri, "urn:ietf:wg:oauth:2.0:oob")
        XCTAssertEqual(result.website, "https://example.com")
    }

    func testRegisterApp_MissingClientName_ThrowsError() async throws {
        do {
            _ = try await sut.registerApplication(
                clientName: "",
                redirectUris: "urn:ietf:wg:oauth:2.0:oob",
                scopes: "read",
                website: nil
            )
            XCTFail("Should throw error for empty client name")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    func testRegisterApp_MissingRedirectURI_ThrowsError() async throws {
        do {
            _ = try await sut.registerApplication(
                clientName: "Test App",
                redirectUris: "",
                scopes: "read",
                website: nil
            )
            XCTFail("Should throw error for empty redirect URI")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    func testRegisterApp_StoresInCache() async throws {
        let result = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read",
            website: nil
        )

        // Should be able to retrieve it
        let retrieved = try await sut.getApplication(clientId: result.clientId)
        XCTAssertEqual(retrieved.clientId, result.clientId)
        XCTAssertEqual(retrieved.name, "Test App")
    }

    // MARK: - Authorization Code Generation Tests

    func testGenerateAuthCode_ValidRequest_ReturnsCode() async throws {
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

        XCTAssertFalse(code.isEmpty)
        XCTAssertGreaterThan(code.count, 20) // Should be a reasonable length
    }

    func testGenerateAuthCode_InvalidClientId_ThrowsError() async throws {
        do {
            _ = try await sut.generateAuthorizationCode(
                clientId: "invalid-client-id",
                redirectUri: "urn:ietf:wg:oauth:2.0:oob",
                scope: "read",
                handle: "alice.bsky.social",
                password: "password"
            )
            XCTFail("Should throw error for invalid client ID")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    func testGenerateAuthCode_MismatchedRedirectURI_ThrowsError() async throws {
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
            XCTFail("Should throw error for mismatched redirect URI")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    // MARK: - Token Exchange Tests

    func testExchangeCodeForToken_ValidCode_ReturnsAccessToken() async throws {
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

        XCTAssertFalse(token.accessToken.isEmpty)
        XCTAssertEqual(token.tokenType, "Bearer")
        XCTAssertEqual(token.scope, "read write")
        XCTAssertGreaterThan(token.createdAt, 0)
    }

    func testExchangeCodeForToken_InvalidCode_ThrowsError() async throws {
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
            XCTFail("Should throw error for invalid code")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    func testExchangeCodeForToken_UsedCode_ThrowsError() async throws {
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
            XCTFail("Should throw error for already-used code")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    // MARK: - Password Grant Tests

    func testPasswordGrant_ValidCredentials_ReturnsToken() async throws {
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

        XCTAssertFalse(token.accessToken.isEmpty)
        XCTAssertEqual(token.tokenType, "Bearer")
        XCTAssertEqual(token.scope, "read write")
    }

    func testPasswordGrant_InvalidClientSecret_ThrowsError() async throws {
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
            XCTFail("Should throw error for invalid client secret")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    // MARK: - Token Validation Tests

    func testValidateToken_ValidToken_ReturnsHandle() async throws {
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

        let handle = try await sut.validateToken(token.accessToken)
        XCTAssertEqual(handle, "alice.bsky.social")
    }

    func testValidateToken_InvalidToken_ThrowsError() async throws {
        do {
            _ = try await sut.validateToken("invalid-token")
            XCTFail("Should throw error for invalid token")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    // MARK: - Token Revocation Tests

    func testRevokeToken_ValidToken_RemovesFromCache() async throws {
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
        let handle = try await sut.validateToken(token.accessToken)
        XCTAssertEqual(handle, "alice.bsky.social")

        // Revoke it
        try await sut.revokeToken(token.accessToken)

        // Should no longer be valid
        do {
            _ = try await sut.validateToken(token.accessToken)
            XCTFail("Token should be invalid after revocation")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    func testRevokeToken_InvalidToken_NoError() async throws {
        // Should not throw error for invalid token
        try await sut.revokeToken("non-existent-token")
        // If we get here, test passes
        XCTAssertTrue(true)
    }

    // MARK: - Scope Validation Tests

    func testValidateScopes_ValidScopes_Succeeds() async throws {
        let result = try sut.validateScopes("read write follow")
        XCTAssertTrue(result.contains(.read))
        XCTAssertTrue(result.contains(.write))
        XCTAssertTrue(result.contains(.follow))
    }

    func testValidateScopes_EmptyScope_UsesDefaultRead() async throws {
        let result = try sut.validateScopes("")
        XCTAssertTrue(result.contains(.read))
        XCTAssertEqual(result.count, 1)
    }

    func testValidateScopes_InvalidScope_ThrowsError() async throws {
        do {
            _ = try sut.validateScopes("invalid-scope")
            XCTFail("Should throw error for invalid scope")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    // MARK: - Token Expiration Tests

    func testToken_NotExpired_ReturnsFalse() {
        let token = OAuthToken(
            accessToken: "test",
            tokenType: "Bearer",
            scope: "read",
            createdAt: Int(Date().timeIntervalSince1970),
            expiresIn: 3600 // 1 hour
        )

        XCTAssertFalse(token.isExpired())
    }

    func testToken_Expired_ReturnsTrue() {
        let oneHourAgo = Int(Date().timeIntervalSince1970) - 3600
        let token = OAuthToken(
            accessToken: "test",
            tokenType: "Bearer",
            scope: "read",
            createdAt: oneHourAgo,
            expiresIn: 1800 // 30 minutes
        )

        XCTAssertTrue(token.isExpired())
    }
}
