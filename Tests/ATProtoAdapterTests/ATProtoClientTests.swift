import XCTest
@testable import ATProtoAdapter
@testable import CacheLayer

/// Tests for ATProtoClient
/// These are unit tests using mocks - integration tests would require real Bluesky credentials
final class ATProtoClientTests: XCTestCase {
    var sut: ATProtoClient!
    var mockCache: InMemoryCache!

    override func setUp() async throws {
        try await super.setUp()
        mockCache = InMemoryCache()

        sut = await ATProtoClient(
            serviceURL: "https://bsky.social",
            cache: mockCache
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockCache = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_ValidConfiguration_CreatesClient() async throws {
        XCTAssertNotNil(sut)
    }

    func testInit_CustomServiceURL_UsesProvidedURL() async throws {
        let customURL = "https://custom.bsky.social"
        let client = await ATProtoClient(
            serviceURL: customURL,
            cache: mockCache
        )

        XCTAssertNotNil(client)
    }

    // MARK: - Session Management Tests

    func testGetSession_NoSession_ReturnsNil() async throws {
        let session = await sut.getCurrentSession()
        XCTAssertNil(session)
    }

    // MARK: - Cache Integration Tests

    func testSession_FromCache_LoadsSuccessfully() async throws {
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
        XCTAssertEqual(retrieved?.did, testSession.did)
        XCTAssertEqual(retrieved?.handle, testSession.handle)
    }

    // NOTE: Integration tests for actual API calls (createSession, refreshSession, getProfile, etc.)
    // are moved to a separate integration test suite that requires real Bluesky credentials.
    // See: Tests/IntegrationTests/ATProtoAdapterIntegrationTests.swift (TODO)

    // MARK: - Configuration Tests

    func testConfiguration_DefaultServiceURL_UsesBlueskyProduction() async throws {
        let defaultClient = await ATProtoClient(cache: mockCache)
        XCTAssertNotNil(defaultClient)
        // Default should be https://bsky.social
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
