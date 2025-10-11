import XCTest
@testable import MastodonModels

final class MastodonAccountTests: XCTestCase {

    func testAccountInitialization() throws {
        let account = MastodonAccount(
            id: "123456789",
            username: "alice",
            acct: "alice.bsky.social",
            displayName: "Alice Smith",
            note: "<p>Software developer and cat lover</p>",
            url: "https://bsky.app/profile/alice.bsky.social",
            avatar: "https://cdn.bsky.app/avatar.jpg",
            avatarStatic: "https://cdn.bsky.app/avatar.jpg",
            header: "https://cdn.bsky.app/header.jpg",
            headerStatic: "https://cdn.bsky.app/header.jpg",
            followersCount: 100,
            followingCount: 50,
            statusesCount: 250,
            createdAt: Date(timeIntervalSince1970: 1609459200), // 2021-01-01
            bot: false,
            locked: false
        )

        XCTAssertEqual(account.id, "123456789")
        XCTAssertEqual(account.username, "alice")
        XCTAssertEqual(account.acct, "alice.bsky.social")
        XCTAssertEqual(account.displayName, "Alice Smith")
        XCTAssertEqual(account.followersCount, 100)
        XCTAssertEqual(account.followingCount, 50)
        XCTAssertEqual(account.statusesCount, 250)
        XCTAssertFalse(account.bot)
        XCTAssertFalse(account.locked)
    }

    func testAccountJSONEncoding() throws {
        let account = MastodonAccount(
            id: "123",
            username: "test",
            acct: "test.bsky.social",
            displayName: "Test User",
            note: "<p>Test</p>",
            url: "https://bsky.app/profile/test.bsky.social",
            avatar: "https://cdn.bsky.app/avatar.jpg",
            avatarStatic: "https://cdn.bsky.app/avatar.jpg",
            header: "https://cdn.bsky.app/header.jpg",
            headerStatic: "https://cdn.bsky.app/header.jpg",
            followersCount: 10,
            followingCount: 5,
            statusesCount: 20,
            createdAt: Date(timeIntervalSince1970: 1609459200),
            bot: false,
            locked: false
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(account)
        XCTAssertFalse(data.isEmpty)

        // Verify it can be decoded back
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(MastodonAccount.self, from: data)
        XCTAssertEqual(decoded.id, account.id)
        XCTAssertEqual(decoded.username, account.username)
    }
}
