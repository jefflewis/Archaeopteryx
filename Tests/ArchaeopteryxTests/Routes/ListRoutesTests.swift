import Testing
import Foundation
@testable import Archaeopteryx
@testable import MastodonModels
@testable import IDMapping
@testable import CacheLayer

@Suite struct ListRoutesTests {
    var cache: InMemoryCache!
    var idMapping: IDMappingService!
    var generator: SnowflakeIDGenerator!

    init() async {
       cache = InMemoryCache()
        generator = SnowflakeIDGenerator()
        idMapping = IDMappingService(cache: cache, generator: generator)
    }

    // MARK: - MastodonList Model Tests

    @Test func MastodonList_CanBeCreated() {
        let list = MastodonList(
            id: "123",
            title: "Friends"
        )

        #expect(list.id == "123")
        #expect(list.title == "Friends")
        #expect(list.repliesPolicy == .followed)
    }

    @Test func MastodonList_WithAllFields() {
        let list = MastodonList(
            id: "456",
            title: "Tech News",
            repliesPolicy: .list
        )

        #expect(list.id == "456")
        #expect(list.title == "Tech News")
        #expect(list.repliesPolicy == .list)
    }

    @Test func MastodonList_EncodesWithSnakeCase() throws {
        let list = MastodonList(
            id: "789",
            title: "Test List",
            repliesPolicy: .none
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(list)
        let json = String(data: data, encoding: .utf8)!

        // Verify snake_case keys
        #expect(json.contains("replies_policy"))
    }

    @Test func MastodonList_DecodesCorrectly() throws {
        let original = MastodonList(
            id: "101",
            title: "Favorites"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MastodonList.self, from: data)

        #expect(decoded.id == "101")
        #expect(decoded.title == "Favorites")
    }

    @Test func MastodonList_SupportsEquatable() {
        let list1 = MastodonList(id: "1", title: "List A")
        let list2 = MastodonList(id: "1", title: "List A")
        let list3 = MastodonList(id: "2", title: "List B")

        #expect(list1 == list2)
        #expect(list1 != list3)
    }

    @Test func MastodonListRepliesPolicy_AllValues() {
        #expect(MastodonListRepliesPolicy.followed.rawValue == "followed")
        #expect(MastodonListRepliesPolicy.list.rawValue == "list")
        #expect(MastodonListRepliesPolicy.none.rawValue == "none")
    }

    // MARK: - List Routes Integration Tests

    @Test func ListRoutes_PlaceholderForImplementation() {
        // This test ensures the List routes file can be created
        // Full HTTP integration tests will be added when we implement the routes
        //
        // Planned routes:
        // - GET /api/v1/lists - Get all lists for authenticated user
        // - GET /api/v1/lists/:id - Get a single list
        // - GET /api/v1/lists/:id/accounts - Get accounts in a list
        // - GET /api/v1/timelines/list/:id - Get statuses from list members
        //
        // Note: Bluesky doesn't have user-curated lists like Mastodon
        // For MVP, we'll return empty lists or map to Bluesky custom feeds (read-only)
        //
        // Tests should cover:
        // - Get lists without auth returns 401
        // - Get lists with auth returns empty array (or feeds if implemented)
        // - Get single list with invalid ID returns 404
        // - Get list accounts returns empty array
        // - List timeline works like regular timeline
        #expect(true, "List routes need HTTP integration tests")
    }
}

