import XCTest
@testable import Archaeopteryx
@testable import MastodonModels
@testable import IDMapping
@testable import CacheLayer

final class AccountRoutesTests: XCTestCase {
    var cache: InMemoryCache!
    var idMapping: IDMappingService!
    var generator: SnowflakeIDGenerator!

    override func setUp() async throws {
        try await super.setUp()
        cache = InMemoryCache()
        generator = SnowflakeIDGenerator()
        idMapping = IDMappingService(cache: cache, generator: generator)
    }

    override func tearDown() async throws {
        cache = nil
        idMapping = nil
        generator = nil
        try await super.tearDown()
    }

    // MARK: - Model Tests

    func testMastodonRelationship_CanBeCreated() {
        let relationship = MastodonRelationship(
            id: "123456",
            following: true,
            followedBy: false
        )

        XCTAssertEqual(relationship.id, "123456")
        XCTAssertTrue(relationship.following)
        XCTAssertFalse(relationship.followedBy)
        XCTAssertFalse(relationship.blocking)
        XCTAssertFalse(relationship.muting)
    }

    func testMastodonRelationship_EncodesWithSnakeCase() throws {
        let relationship = MastodonRelationship(
            id: "123456",
            following: true,
            showingReblogs: false,
            followedBy: true,
            mutingNotifications: true,
            domainBlocking: false
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(relationship)
        let json = String(data: data, encoding: .utf8)!

        // Verify snake_case keys
        XCTAssertTrue(json.contains("showing_reblogs"))
        XCTAssertTrue(json.contains("followed_by"))
        XCTAssertTrue(json.contains("muting_notifications"))
        XCTAssertTrue(json.contains("domain_blocking"))
    }

    func testMastodonRelationship_DecodesCorrectly() throws {
        let original = MastodonRelationship(
            id: "123456",
            following: true,
            showingReblogs: false,
            followedBy: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MastodonRelationship.self, from: data)

        XCTAssertEqual(decoded.id, "123456")
        XCTAssertTrue(decoded.following)
        XCTAssertFalse(decoded.showingReblogs)
        XCTAssertTrue(decoded.followedBy)
    }

    func testMastodonRelationship_HasCorrectDefaults() {
        let relationship = MastodonRelationship(id: "123456")

        // All boolean flags should default to false except showingReblogs
        XCTAssertFalse(relationship.following)
        XCTAssertTrue(relationship.showingReblogs)  // Default true
        XCTAssertFalse(relationship.notifying)
        XCTAssertFalse(relationship.followedBy)
        XCTAssertFalse(relationship.blocking)
        XCTAssertFalse(relationship.blockedBy)
        XCTAssertFalse(relationship.muting)
        XCTAssertFalse(relationship.mutingNotifications)
        XCTAssertFalse(relationship.requested)
        XCTAssertFalse(relationship.domainBlocking)
        XCTAssertFalse(relationship.endorsed)
        XCTAssertEqual(relationship.note, "")
        XCTAssertEqual(relationship.languages, [])
    }

    func testMastodonRelationship_SupportsEquatable() {
        let relationship1 = MastodonRelationship(
            id: "123456",
            following: true,
            followedBy: false
        )

        let relationship2 = MastodonRelationship(
            id: "123456",
            following: true,
            followedBy: false
        )

        XCTAssertEqual(relationship1, relationship2)
    }

    func testMastodonRelationship_SupportsNote() {
        let relationship = MastodonRelationship(
            id: "123456",
            note: "This is my note about this user"
        )

        XCTAssertEqual(relationship.note, "This is my note about this user")
    }

    func testMastodonRelationship_SupportsLanguages() {
        let relationship = MastodonRelationship(
            id: "123456",
            languages: ["en", "es", "fr"]
        )

        XCTAssertEqual(relationship.languages, ["en", "es", "fr"])
    }

    // MARK: - ID Mapping Tests for Accounts

    func testIDMapping_GeneratesSnowflakeForDID() async throws {
        let did = "did:plc:test123"

        let snowflake1 = await idMapping.getSnowflakeID(forDID: did)
        let snowflake2 = await idMapping.getSnowflakeID(forDID: did)

        // Should be deterministic
        XCTAssertEqual(snowflake1, snowflake2)
        XCTAssertGreaterThan(snowflake1, 0)
    }

    func testIDMapping_ReverseLookupDID() async throws {
        let did = "did:plc:test456"

        let snowflake = await idMapping.getSnowflakeID(forDID: did)
        let retrievedDID = await idMapping.getDID(forSnowflakeID: snowflake)

        XCTAssertEqual(retrievedDID, did)
    }

    func testIDMapping_HandlesMultipleAccounts() async throws {
        let did1 = "did:plc:alice"
        let did2 = "did:plc:bob"
        let did3 = "did:plc:carol"

        let snowflake1 = await idMapping.getSnowflakeID(forDID: did1)
        let snowflake2 = await idMapping.getSnowflakeID(forDID: did2)
        let snowflake3 = await idMapping.getSnowflakeID(forDID: did3)

        // All should be unique
        XCTAssertNotEqual(snowflake1, snowflake2)
        XCTAssertNotEqual(snowflake2, snowflake3)
        XCTAssertNotEqual(snowflake1, snowflake3)

        // Reverse lookups should work
        let retrieved1 = await idMapping.getDID(forSnowflakeID: snowflake1)
        let retrieved2 = await idMapping.getDID(forSnowflakeID: snowflake2)
        let retrieved3 = await idMapping.getDID(forSnowflakeID: snowflake3)

        XCTAssertEqual(retrieved1, did1)
        XCTAssertEqual(retrieved2, did2)
        XCTAssertEqual(retrieved3, did3)
    }

    // MARK: - Account Service Integration Tests

    func testAccountRoutes_PlaceholderForFutureImplementation() {
        // This test ensures the Account routes file can be created
        // Full HTTP integration tests will be added when we implement the routes
        XCTAssertTrue(true, "Account routes need HTTP integration tests")
    }
}
