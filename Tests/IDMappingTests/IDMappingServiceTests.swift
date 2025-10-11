import XCTest
@testable import IDMapping

/// Tests for IDMappingService
/// Following TDD methodology - these tests should fail until we implement the service
final class IDMappingServiceTests: XCTestCase {
    var sut: IDMappingService!
    var mockCache: MockCacheService!
    var generator: SnowflakeIDGenerator!

    override func setUp() async throws {
        try await super.setUp()
        mockCache = MockCacheService()
        generator = SnowflakeIDGenerator()
        sut = IDMappingService(cache: mockCache, generator: generator)
    }

    override func tearDown() async throws {
        sut = nil
        mockCache = nil
        generator = nil
        try await super.tearDown()
    }

    // MARK: - DID to Snowflake Mapping Tests

    func testGetSnowflakeForDID_NewDID_GeneratesConsistentID() async throws {
        // Given
        let did = "did:plc:abc123xyz"

        // When
        let snowflake1 = await sut.getSnowflakeID(forDID: did)
        let snowflake2 = await sut.getSnowflakeID(forDID: did)

        // Then
        XCTAssertNotEqual(snowflake1, 0, "Snowflake ID should not be zero")
        XCTAssertEqual(snowflake1, snowflake2, "Same DID should always return same Snowflake ID (deterministic)")
    }

    func testGetSnowflakeForDID_DifferentDIDs_GenerateDifferentIDs() async throws {
        // Given
        let did1 = "did:plc:abc123"
        let did2 = "did:plc:xyz789"

        // When
        let snowflake1 = await sut.getSnowflakeID(forDID: did1)
        let snowflake2 = await sut.getSnowflakeID(forDID: did2)

        // Then
        XCTAssertNotEqual(snowflake1, snowflake2, "Different DIDs should generate different Snowflake IDs")
    }

    func testGetSnowflakeForDID_ExistingDID_ReturnsCachedID() async throws {
        // Given
        let did = "did:plc:cached123"
        let cachedSnowflake: Int64 = 999888777666

        // Pre-populate cache
        await mockCache.setCachedSnowflake(cachedSnowflake, forDID: did)

        // When
        let snowflake = await sut.getSnowflakeID(forDID: did)

        // Then
        XCTAssertEqual(snowflake, cachedSnowflake, "Should return cached Snowflake ID")
    }

    // MARK: - Reverse Lookup Tests

    func testGetDIDForSnowflake_ExistingMapping_ReturnsDID() async throws {
        // Given
        let did = "did:plc:reverse123"
        let snowflake = await sut.getSnowflakeID(forDID: did)

        // When
        let retrievedDID = await sut.getDID(forSnowflakeID: snowflake)

        // Then
        XCTAssertEqual(retrievedDID, did, "Should retrieve original DID from Snowflake ID")
    }

    func testGetDIDForSnowflake_NonExistent_ReturnsNil() async throws {
        // Given
        let nonExistentSnowflake: Int64 = 123456789

        // When
        let retrievedDID = await sut.getDID(forSnowflakeID: nonExistentSnowflake)

        // Then
        XCTAssertNil(retrievedDID, "Should return nil for non-existent Snowflake ID")
    }

    // MARK: - AT URI to Snowflake Tests

    func testGetSnowflakeForATURI_NewURI_GeneratesID() async throws {
        // Given
        let atURI = "at://did:plc:abc123/app.bsky.feed.post/3k2ykhz4lks2x"

        // When
        let snowflake = await sut.getSnowflakeID(forATURI: atURI)

        // Then
        XCTAssertNotEqual(snowflake, 0, "Should generate non-zero Snowflake ID for AT URI")
    }

    func testGetSnowflakeForATURI_SameURI_ReturnsConsistentID() async throws {
        // Given
        let atURI = "at://did:plc:test/app.bsky.feed.post/abc"

        // When
        let snowflake1 = await sut.getSnowflakeID(forATURI: atURI)
        let snowflake2 = await sut.getSnowflakeID(forATURI: atURI)

        // Then
        XCTAssertEqual(snowflake1, snowflake2, "Same AT URI should return same Snowflake ID")
    }

    func testGetSnowflakeForATURI_ExistingURI_ReturnsCachedID() async throws {
        // Given
        let atURI = "at://did:plc:cached/app.bsky.feed.post/xyz"
        let cachedSnowflake: Int64 = 555444333222

        // Pre-populate cache
        await mockCache.setCachedSnowflake(cachedSnowflake, forATURI: atURI)

        // When
        let snowflake = await sut.getSnowflakeID(forATURI: atURI)

        // Then
        XCTAssertEqual(snowflake, cachedSnowflake, "Should return cached Snowflake ID for AT URI")
    }

    func testGetATURIForSnowflake_ExistingMapping_ReturnsATURI() async throws {
        // Given
        let atURI = "at://did:plc:reverse/app.bsky.feed.post/123"
        let snowflake = await sut.getSnowflakeID(forATURI: atURI)

        // When
        let retrievedURI = await sut.getATURI(forSnowflakeID: snowflake)

        // Then
        XCTAssertEqual(retrievedURI, atURI, "Should retrieve original AT URI from Snowflake ID")
    }

    // MARK: - Handle to Snowflake Tests

    func testGetSnowflakeForHandle_ValidHandle_ResolvesToDID() async throws {
        // Given
        let handle = "alice.bsky.social"
        let did = "did:plc:alice123"

        // Mock the handle resolution
        await mockCache.setResolvedDID(did, forHandle: handle)

        // When
        let snowflake = await sut.getSnowflakeID(forHandle: handle)

        // Then
        XCTAssertNotNil(snowflake, "Should resolve handle to Snowflake ID")
        XCTAssertNotEqual(snowflake, 0, "Snowflake ID should not be zero")
    }

    func testGetSnowflakeForHandle_UnresolvableHandle_ReturnsZero() async throws {
        // Given
        let handle = "nonexistent.handle"

        // When (no DID resolution mocked)
        let snowflake = await sut.getSnowflakeID(forHandle: handle)

        // Then
        XCTAssertEqual(snowflake, 0, "Should return zero for unresolvable handle")
    }

    // MARK: - Cache Integration Tests

    func testIDMapping_StoresInCache_PersistsAcrossLookups() async throws {
        // Given
        let did = "did:plc:persist123"

        // When - First call generates and caches
        let snowflake1 = await sut.getSnowflakeID(forDID: did)

        // Create new service instance with same cache
        let newService = IDMappingService(cache: mockCache, generator: generator)

        // Second call from new service instance
        let snowflake2 = await newService.getSnowflakeID(forDID: did)

        // Then
        XCTAssertEqual(snowflake1, snowflake2, "Snowflake ID should persist across service instances via cache")
    }
}

// MARK: - Mock Cache Service

/// Mock cache service for testing
actor MockCacheService: CacheProtocol {
    private var didToSnowflake: [String: Int64] = [:]
    private var snowflakeToDID: [Int64: String] = [:]
    private var atURIToSnowflake: [String: Int64] = [:]
    private var snowflakeToATURI: [Int64: String] = [:]
    private var handleToDID: [String: String] = [:]

    func setCachedSnowflake(_ snowflake: Int64, forDID did: String) {
        didToSnowflake[did] = snowflake
        snowflakeToDID[snowflake] = did
    }

    func setCachedSnowflake(_ snowflake: Int64, forATURI atURI: String) {
        atURIToSnowflake[atURI] = snowflake
        snowflakeToATURI[snowflake] = atURI
    }

    func setResolvedDID(_ did: String, forHandle handle: String) {
        handleToDID[handle] = did
    }

    func getSnowflake(forDID did: String) async -> Int64? {
        return didToSnowflake[did]
    }

    func getDID(forSnowflake snowflake: Int64) async -> String? {
        return snowflakeToDID[snowflake]
    }

    func getSnowflake(forATURI atURI: String) async -> Int64? {
        return atURIToSnowflake[atURI]
    }

    func getATURI(forSnowflake snowflake: Int64) async -> String? {
        return snowflakeToATURI[snowflake]
    }

    func getDID(forHandle handle: String) async -> String? {
        return handleToDID[handle]
    }

    func storeMapping(did: String, snowflake: Int64) async {
        didToSnowflake[did] = snowflake
        snowflakeToDID[snowflake] = did
    }

    func storeMapping(atURI: String, snowflake: Int64) async {
        atURIToSnowflake[atURI] = snowflake
        snowflakeToATURI[snowflake] = atURI
    }
}
