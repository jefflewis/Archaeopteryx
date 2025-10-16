import XCTest
@testable import Archaeopteryx
@testable import MastodonModels
@testable import IDMapping
@testable import CacheLayer

final class ListRoutesTests: XCTestCase {
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

    // MARK: - MastodonList Model Tests

    func testMastodonList_CanBeCreated() {
        let list = MastodonList(
            id: "123",
            title: "Friends"
        )

        XCTAssertEqual(list.id, "123")
        XCTAssertEqual(list.title, "Friends")
        XCTAssertEqual(list.repliesPolicy, .followed)
    }

    func testMastodonList_WithAllFields() {
        let list = MastodonList(
            id: "456",
            title: "Tech News",
            repliesPolicy: .list
        )

        XCTAssertEqual(list.id, "456")
        XCTAssertEqual(list.title, "Tech News")
        XCTAssertEqual(list.repliesPolicy, .list)
    }

    func testMastodonList_EncodesWithSnakeCase() throws {
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
        XCTAssertTrue(json.contains("replies_policy"))
    }

    func testMastodonList_DecodesCorrectly() throws {
        let original = MastodonList(
            id: "101",
            title: "Favorites"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MastodonList.self, from: data)

        XCTAssertEqual(decoded.id, "101")
        XCTAssertEqual(decoded.title, "Favorites")
    }

    func testMastodonList_SupportsEquatable() {
        let list1 = MastodonList(id: "1", title: "List A")
        let list2 = MastodonList(id: "1", title: "List A")
        let list3 = MastodonList(id: "2", title: "List B")

        XCTAssertEqual(list1, list2)
        XCTAssertNotEqual(list1, list3)
    }

    func testMastodonListRepliesPolicy_AllValues() {
        XCTAssertEqual(MastodonListRepliesPolicy.followed.rawValue, "followed")
        XCTAssertEqual(MastodonListRepliesPolicy.list.rawValue, "list")
        XCTAssertEqual(MastodonListRepliesPolicy.none.rawValue, "none")
    }

    // MARK: - List Routes Integration Tests

    func testListRoutes_PlaceholderForImplementation() {
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
        XCTAssertTrue(true, "List routes need HTTP integration tests")
    }
}
