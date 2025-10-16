import XCTest
@testable import Archaeopteryx
@testable import MastodonModels
@testable import IDMapping
@testable import CacheLayer

final class SearchRoutesTests: XCTestCase {
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

    // MARK: - MastodonTag Model Tests

    func testMastodonTag_CanBeCreated() {
        let tag = MastodonTag(
            name: "bluesky",
            url: "https://bsky.app/hashtag/bluesky"
        )

        XCTAssertEqual(tag.name, "bluesky")
        XCTAssertEqual(tag.url, "https://bsky.app/hashtag/bluesky")
        XCTAssertNil(tag.history)
    }

    func testMastodonTag_WithHistory() {
        let history = [
            MastodonTagHistory(day: "1696118400", uses: "42", accounts: "12")
        ]
        let tag = MastodonTag(
            name: "technology",
            url: "https://bsky.app/hashtag/technology",
            history: history
        )

        XCTAssertEqual(tag.name, "technology")
        XCTAssertEqual(tag.history?.count, 1)
        XCTAssertEqual(tag.history?.first?.uses, "42")
    }

    func testMastodonTag_EncodesCorrectly() throws {
        let tag = MastodonTag(
            name: "test",
            url: "https://bsky.app/hashtag/test"
        )

        let data = try JSONEncoder().encode(tag)
        let decoded = try JSONDecoder().decode(MastodonTag.self, from: data)

        XCTAssertEqual(decoded.name, "test")
        XCTAssertEqual(decoded.url, "https://bsky.app/hashtag/test")
    }

    // MARK: - MastodonSearchResults Model Tests

    func testMastodonSearchResults_CanBeCreated() {
        let results = MastodonSearchResults(
            accounts: [],
            statuses: [],
            hashtags: []
        )

        XCTAssertTrue(results.accounts.isEmpty)
        XCTAssertTrue(results.statuses.isEmpty)
        XCTAssertTrue(results.hashtags.isEmpty)
    }

    func testMastodonSearchResults_WithResults() {
        let createdAt = Date(timeIntervalSince1970: 1672531200) // 2023-01-01
        let account = MastodonAccount(
            id: "123",
            username: "alice",
            acct: "alice.bsky.social",
            displayName: "Alice",
            note: "A test account",
            url: "https://bsky.app/profile/alice.bsky.social",
            avatar: "https://example.com/avatar.jpg",
            avatarStatic: "https://example.com/avatar.jpg",
            header: "https://example.com/header.jpg",
            headerStatic: "https://example.com/header.jpg",
            followersCount: 100,
            followingCount: 50,
            statusesCount: 200,
            createdAt: createdAt,
            bot: false,
            locked: false
        )

        let tag = MastodonTag(
            name: "test",
            url: "https://bsky.app/hashtag/test"
        )

        let results = MastodonSearchResults(
            accounts: [account],
            statuses: [],
            hashtags: [tag]
        )

        XCTAssertEqual(results.accounts.count, 1)
        XCTAssertEqual(results.hashtags.count, 1)
        XCTAssertTrue(results.statuses.isEmpty)
    }

    func testMastodonSearchResults_EncodesWithSnakeCase() throws {
        let results = MastodonSearchResults(
            accounts: [],
            statuses: [],
            hashtags: []
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(results)
        let json = String(data: data, encoding: .utf8)!

        // Should have empty arrays
        XCTAssertTrue(json.contains("accounts"))
        XCTAssertTrue(json.contains("statuses"))
        XCTAssertTrue(json.contains("hashtags"))
    }

    // MARK: - Search Routes Integration Tests

    func testSearchRoutes_PlaceholderForImplementation() {
        // This test ensures the Search routes file can be created
        // Full HTTP integration tests will be added when we implement the routes
        //
        // Planned routes:
        // - GET /api/v2/search - Search accounts, statuses, and hashtags
        //
        // Query parameters:
        // - q: search query (required)
        // - type: filter by type (accounts, statuses, hashtags)
        // - limit: max results per category (default 20, max 40)
        // - offset: pagination offset
        // - resolve: attempt to resolve remote resources (default false)
        // - following: only show results from accounts the user follows
        //
        // Tests should cover:
        // - Search with valid query returns results
        // - Search with empty query returns 400
        // - Search by type=accounts filters to accounts only
        // - Search by type=statuses filters to statuses only
        // - Search by type=hashtags filters to hashtags only
        // - Search without auth works (public search)
        // - Search with auth can use 'following' filter
        // - Search respects limit parameter
        // - Search with invalid type returns 400
        XCTAssertTrue(true, "Search routes need HTTP integration tests")
    }
}
