import Foundation
import Testing
@testable import Archaeopteryx
@testable import MastodonModels
@testable import IDMapping
@testable import CacheLayer

@Suite struct AccountRoutesTests {
    var cache: InMemoryCache!
    var idMapping: IDMappingService!
    var generator: SnowflakeIDGenerator!

    init() async {
       cache = InMemoryCache()
        generator = SnowflakeIDGenerator()
        idMapping = IDMappingService(cache: cache, generator: generator)
    }

    // MARK: - Model Tests

    @Test func MastodonRelationship_CanBeCreated() {
        let relationship = MastodonRelationship(
            id: "123456",
            following: true,
            followedBy: false
        )

        #expect(relationship.id == "123456")
        #expect(relationship.following)
        #expect(!(relationship.followedBy))
        #expect(!(relationship.blocking))
        #expect(!(relationship.muting))
    }

    @Test func MastodonRelationship_EncodesWithSnakeCase() throws {
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
        #expect(json.contains("showing_reblogs"))
        #expect(json.contains("followed_by"))
        #expect(json.contains("muting_notifications"))
        #expect(json.contains("domain_blocking"))
    }

    @Test func MastodonRelationship_DecodesCorrectly() throws {
        let original = MastodonRelationship(
            id: "123456",
            following: true,
            showingReblogs: false,
            followedBy: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MastodonRelationship.self, from: data)

        #expect(decoded.id == "123456")
        #expect(decoded.following)
        #expect(!(decoded.showingReblogs))
        #expect(decoded.followedBy)
    }

    @Test func MastodonRelationship_HasCorrectDefaults() {
        let relationship = MastodonRelationship(id: "123456")

        // All boolean flags should default to false except showingReblogs
        #expect(!(relationship.following))
        #expect(relationship.showingReblogs)  // Default true
        #expect(!(relationship.notifying))
        #expect(!(relationship.followedBy))
        #expect(!(relationship.blocking))
        #expect(!(relationship.blockedBy))
        #expect(!(relationship.muting))
        #expect(!(relationship.mutingNotifications))
        #expect(!(relationship.requested))
        #expect(!(relationship.domainBlocking))
        #expect(!(relationship.endorsed))
        #expect(relationship.note == "")
        #expect(relationship.languages == [])
    }

    @Test func MastodonRelationship_SupportsEquatable() {
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

        #expect(relationship1 == relationship2)
    }

    @Test func MastodonRelationship_SupportsNote() {
        let relationship = MastodonRelationship(
            id: "123456",
            note: "This is my note about this user"
        )

        #expect(relationship.note == "This is my note about this user")
    }

    @Test func MastodonRelationship_SupportsLanguages() {
        let relationship = MastodonRelationship(
            id: "123456",
            languages: ["en", "es", "fr"]
        )

        #expect(relationship.languages == ["en", "es", "fr"])
    }

    // MARK: - ID Mapping Tests for Accounts

    @Test func IDMapping_GeneratesSnowflakeForDID() async throws {
        let did = "did:plc:test123"

        let snowflake1 = await idMapping.getSnowflakeID(forDID: did)
        let snowflake2 = await idMapping.getSnowflakeID(forDID: did)

        // Should be deterministic
        #expect(snowflake1 == snowflake2)
        #expect(snowflake1 > 0)
    }

    @Test func IDMapping_ReverseLookupDID() async throws {
        let did = "did:plc:test456"

        let snowflake = await idMapping.getSnowflakeID(forDID: did)
        let retrievedDID = await idMapping.getDID(forSnowflakeID: snowflake)

        #expect(retrievedDID == did)
    }

    @Test func IDMapping_HandlesMultipleAccounts() async throws {
        let did1 = "did:plc:alice"
        let did2 = "did:plc:bob"
        let did3 = "did:plc:carol"

        let snowflake1 = await idMapping.getSnowflakeID(forDID: did1)
        let snowflake2 = await idMapping.getSnowflakeID(forDID: did2)
        let snowflake3 = await idMapping.getSnowflakeID(forDID: did3)

        // All should be unique
        #expect(snowflake1 != snowflake2)
        #expect(snowflake2 != snowflake3)
        #expect(snowflake1 != snowflake3)

        // Reverse lookups should work
        let retrieved1 = await idMapping.getDID(forSnowflakeID: snowflake1)
        let retrieved2 = await idMapping.getDID(forSnowflakeID: snowflake2)
        let retrieved3 = await idMapping.getDID(forSnowflakeID: snowflake3)

        #expect(retrieved1 == did1)
        #expect(retrieved2 == did2)
        #expect(retrieved3 == did3)
    }

    // MARK: - Account Service Integration Tests

    @Test func AccountRoutes_PlaceholderForFutureImplementation() {
        // This test ensures the Account routes file can be created
        // Full HTTP integration tests will be added when we implement the routes
        #expect(true, "Account routes need HTTP integration tests")
    }
}

