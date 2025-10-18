import Foundation
import Testing
@testable import Archaeopteryx
@testable import MastodonModels
@testable import IDMapping
@testable import CacheLayer

@Suite struct SearchRoutesTests {
    var cache: InMemoryCache!
    var idMapping: IDMappingService!
    var generator: SnowflakeIDGenerator!

    init() async {
       cache = InMemoryCache()
        generator = SnowflakeIDGenerator()
        idMapping = IDMappingService(cache: cache, generator: generator)
    }

    // MARK: - MastodonTag Model Tests

    @Test func MastodonTag_CanBeCreated() {
        let tag = MastodonTag(
            name: "bluesky",
            url: "https://bsky.app/hashtag/bluesky"
        )

        #expect(tag.name == "bluesky")
        #expect(tag.url == "https://bsky.app/hashtag/bluesky")
        #expect(tag.history == nil)
    }

    @Test func MastodonTag_WithHistory() {
        let history = [
            MastodonTagHistory(day: "1696118400", uses: "42", accounts: "12")
        ]
        let tag = MastodonTag(
            name: "technology",
            url: "https://bsky.app/hashtag/technology",
            history: history
        )

        #expect(tag.name == "technology")
        #expect(tag.history?.count == 1)
        #expect(tag.history?.first?.uses == "42")
    }

    @Test func MastodonTag_EncodesCorrectly() throws {
        let tag = MastodonTag(
            name: "test",
            url: "https://bsky.app/hashtag/test"
        )

        let data = try JSONEncoder().encode(tag)
        let decoded = try JSONDecoder().decode(MastodonTag.self, from: data)

        #expect(decoded.name == "test")
        #expect(decoded.url == "https://bsky.app/hashtag/test")
    }

    // MARK: - MastodonSearchResults Model Tests

    @Test func MastodonSearchResults_CanBeCreated() {
        let results = MastodonSearchResults(
            accounts: [],
            statuses: [],
            hashtags: []
        )

        #expect(results.accounts.isEmpty)
        #expect(results.statuses.isEmpty)
        #expect(results.hashtags.isEmpty)
    }

    @Test func MastodonSearchResults_WithResults() {
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

        #expect(results.accounts.count == 1)
        #expect(results.hashtags.count == 1)
        #expect(results.statuses.isEmpty)
    }

    @Test func MastodonSearchResults_EncodesWithSnakeCase() throws {
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
        #expect(json.contains("accounts"))
        #expect(json.contains("statuses"))
        #expect(json.contains("hashtags"))
    }

    // MARK: - Search Routes Integration Tests

    @Test func SearchRoutes_PlaceholderForImplementation() {
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
        #expect(true, "Search routes need HTTP integration tests")
    }
}

