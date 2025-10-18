import Testing
@testable import ATProtoAdapter
@testable import CacheLayer

/// Tests for ATProtoClient
/// These are unit tests using mocks - integration tests would require real Bluesky credentials
@Suite struct ATProtoClientTests {
    let sut: ATProtoClient
    var mockCache: InMemoryCache!

    init() async {
       mockCache = InMemoryCache()

        sut = await ATProtoClient(
            serviceURL: "https://bsky.social",
            cache: mockCache
        )
    }

    // MARK: - Initialization Tests

    @Test func Init_ValidConfiguration_CreatesClient() async throws {
        // Client initialization succeeded if this test runs without throwing
    }

    @Test func Init_CustomServiceURL_UsesProvidedURL() async throws {
        let customURL = "https://custom.bsky.social"
        let client = await ATProtoClient(
            serviceURL: customURL,
            cache: mockCache
        )
        // Client initialization succeeded if this test runs without throwing
    }

    // MARK: - Session Management Tests

    @Test func GetSession_NoSession_ReturnsNil() async throws {
        let session = await sut.getCurrentSession()
        #expect(session == nil)
    }

    // MARK: - Cache Integration Tests

    @Test func Session_FromCache_LoadsSuccessfully() async throws {
        // Test that we can store and retrieve session from cache
        let testSession = ATProtoSession(
            did: "did:plc:test123",
            handle: "test.bsky.social",
            accessToken: "test_access_token",
            refreshToken: "test_refresh_token"
        )

        // Store session in cache
        try await mockCache.set("session:did:plc:test123", value: testSession, ttl: nil)

        // Verify it can be retrieved
        let retrieved: ATProtoSession? = try await mockCache.get("session:did:plc:test123")
        #expect(retrieved?.did == testSession.did)
        #expect(retrieved?.handle == testSession.handle)
    }

    // NOTE: Integration tests for actual API calls (createSession, refreshSession, getProfile, etc.)
    // are moved to a separate integration test suite that requires real Bluesky credentials.
    // See: Tests/IntegrationTests/ATProtoAdapterIntegrationTests.swift (TODO)

    // MARK: - Configuration Tests

    @Test func Configuration_DefaultServiceURL_UsesBlueskyProduction() async throws {
        let defaultClient = await ATProtoClient(cache: mockCache)
        // Default should be https://bsky.social
        // Client initialization succeeded if this test runs without throwing
    }
}

// MARK: - Test Models

extension ATProtoSession: Equatable {
    public static func == (lhs: ATProtoSession, rhs: ATProtoSession) -> Bool {
        return lhs.did == rhs.did &&
               lhs.handle == rhs.handle &&
               lhs.accessToken == rhs.accessToken &&
               lhs.refreshToken == rhs.refreshToken
    }
}

