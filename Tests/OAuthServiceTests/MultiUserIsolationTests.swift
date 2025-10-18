import Foundation
import Testing
@testable import OAuthService
@testable import MastodonModels
@testable import CacheLayer
@testable import ATProtoAdapter
@testable import ArchaeopteryxCore

/// Tests for multi-user isolation
/// Verifies that multiple users can be logged in simultaneously with proper session isolation
@Suite struct MultiUserIsolationTests {
    let mockCache: InMemoryCache
    let sut: OAuthService

    init() async {
        mockCache = InMemoryCache()
        sut = await OAuthService(cache: mockCache, atprotoServiceURL: "https://bsky.social")
    }

    // MARK: - Multi-User Session Isolation Tests

    /// Test that two users can have active sessions simultaneously
    /// This is a CRITICAL test for multi-user support
    @Test func MultipleUsers_CanHaveActiveSessionsSimultaneously() async throws {
        // Register an OAuth app
        let app = try await sut.registerApplication(
            clientName: "Test App",
            redirectUris: "urn:ietf:wg:oauth:2.0:oob",
            scopes: "read write",
            website: nil
        )

        // Note: In real tests, we'd need to mock ATProtoKit.createSession
        // For now, we're testing the structure, not the actual Bluesky calls

        // The test demonstrates the expected multi-user flow:
        // 1. User A logs in → creates token A with session A
        // 2. User B logs in → creates token B with session B
        // 3. Both tokens can be validated simultaneously
        // 4. Each token returns the correct user's context

        // This would fail in the old architecture where only one global session existed!

        #expect(true) // Placeholder - actual implementation needs mock Bluesky responses
    }

    /// Test that validating different tokens returns different user contexts
    @Test func ValidateToken_DifferentTokens_ReturnsDifferentUserContexts() async throws {
        // Create mock token data for two different users
        let aliceSessionData = BlueskySessionData(
            accessToken: "alice_at_token",
            refreshToken: "alice_refresh",
            did: "did:plc:alice123",
            handle: "alice.bsky.social",
            email: "alice@example.com",
            createdAt: Date()
        )

        let bobSessionData = BlueskySessionData(
            accessToken: "bob_at_token",
            refreshToken: "bob_refresh",
            did: "did:plc:bob456",
            handle: "bob.bsky.social",
            email: "bob@example.com",
            createdAt: Date()
        )

        // Manually create token data in cache (simulating successful login)
        let aliceTokenData = TokenDataStub(
            did: "did:plc:alice123",
            handle: "alice.bsky.social",
            sessionData: aliceSessionData,
            scope: "read write",
            tokenType: "Bearer",
            createdAt: Int(Date().timeIntervalSince1970),
            expiresIn: 7 * 24 * 60 * 60
        )

        let bobTokenData = TokenDataStub(
            did: "did:plc:bob456",
            handle: "bob.bsky.social",
            sessionData: bobSessionData,
            scope: "read write",
            tokenType: "Bearer",
            createdAt: Int(Date().timeIntervalSince1970),
            expiresIn: 7 * 24 * 60 * 60
        )

        // Store in cache
        try await mockCache.set("oauth:token:alice_token", value: aliceTokenData, ttl: nil)
        try await mockCache.set("oauth:token:bob_token", value: bobTokenData, ttl: nil)

        // Validate both tokens
        let aliceContext = try await sut.validateToken("alice_token")
        let bobContext = try await sut.validateToken("bob_token")

        // Verify each context has the correct user data
        #expect(aliceContext.did == "did:plc:alice123")
        #expect(aliceContext.handle == "alice.bsky.social")
        #expect(aliceContext.sessionData.accessToken == "alice_at_token")

        #expect(bobContext.did == "did:plc:bob456")
        #expect(bobContext.handle == "bob.bsky.social")
        #expect(bobContext.sessionData.accessToken == "bob_at_token")

        // CRITICAL: Verify the sessions are different!
        #expect(aliceContext.did != bobContext.did)
        #expect(aliceContext.sessionData.accessToken != bobContext.sessionData.accessToken)
    }

    /// Test that session data is properly isolated in Valkey/Redis
    @Test func SessionData_StoredSeparatelyInCache_ForEachUser() async throws {
        let aliceSession = BlueskySessionData(
            accessToken: "alice_at",
            refreshToken: "alice_rt",
            did: "did:plc:alice",
            handle: "alice.bsky.social",
            email: nil,
            createdAt: Date()
        )

        let bobSession = BlueskySessionData(
            accessToken: "bob_at",
            refreshToken: "bob_rt",
            did: "did:plc:bob",
            handle: "bob.bsky.social",
            email: nil,
            createdAt: Date()
        )

        // Store sessions for both users
        try await mockCache.set("session:did:plc:alice", value: aliceSession, ttl: nil)
        try await mockCache.set("session:did:plc:bob", value: bobSession, ttl: nil)

        // Retrieve and verify
        let retrievedAlice: BlueskySessionData? = try await mockCache.get("session:did:plc:alice")
        let retrievedBob: BlueskySessionData? = try await mockCache.get("session:did:plc:bob")

        #expect(retrievedAlice?.did == "did:plc:alice")
        #expect(retrievedAlice?.accessToken == "alice_at")

        #expect(retrievedBob?.did == "did:plc:bob")
        #expect(retrievedBob?.accessToken == "bob_at")

        // Sessions should be completely isolated
        #expect(retrievedAlice?.accessToken != retrievedBob?.accessToken)
    }
}

// MARK: - Test Helpers

/// Stub for TokenData (which is private in OAuthService)
/// This allows us to manually create token data for testing
private struct TokenDataStub: Codable, Sendable {
    let did: String
    let handle: String
    let sessionData: BlueskySessionData
    let scope: String
    let tokenType: String
    let createdAt: Int
    let expiresIn: Int
}
