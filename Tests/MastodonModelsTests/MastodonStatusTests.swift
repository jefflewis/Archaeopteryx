import XCTest
@testable import MastodonModels

final class MastodonStatusTests: XCTestCase {

    func testStatusInitialization() throws {
        let account = MastodonAccount(
            id: "123",
            username: "alice",
            acct: "alice.bsky.social",
            displayName: "Alice",
            note: "",
            url: "https://bsky.app/profile/alice.bsky.social",
            avatar: "https://cdn.bsky.app/avatar.jpg",
            avatarStatic: "https://cdn.bsky.app/avatar.jpg",
            header: "",
            headerStatic: "",
            followersCount: 100,
            followingCount: 50,
            statusesCount: 250,
            createdAt: Date(),
            bot: false,
            locked: false
        )

        let status = MastodonStatus(
            id: "987654321",
            uri: "at://did:plc:xyz/app.bsky.feed.post/abc123",
            createdAt: Date(timeIntervalSince1970: 1609459200),
            account: account,
            content: "<p>Hello, world!</p>",
            visibility: .public,
            repliesCount: 5,
            reblogsCount: 10,
            favouritesCount: 15,
            reblogged: false,
            favourited: false,
            sensitive: false,
            spoilerText: ""
        )

        XCTAssertEqual(status.id, "987654321")
        XCTAssertEqual(status.content, "<p>Hello, world!</p>")
        XCTAssertEqual(status.visibility, .public)
        XCTAssertEqual(status.repliesCount, 5)
        XCTAssertEqual(status.reblogsCount, 10)
        XCTAssertEqual(status.favouritesCount, 15)
        XCTAssertFalse(status.reblogged)
        XCTAssertFalse(status.favourited)
        XCTAssertFalse(status.sensitive)
    }

    func testStatusWithReply() throws {
        let account = MastodonAccount(
            id: "123",
            username: "alice",
            acct: "alice.bsky.social",
            displayName: "Alice",
            note: "",
            url: "https://bsky.app/profile/alice.bsky.social",
            avatar: "",
            avatarStatic: "",
            header: "",
            headerStatic: "",
            followersCount: 0,
            followingCount: 0,
            statusesCount: 0,
            createdAt: Date(),
            bot: false,
            locked: false
        )

        let status = MastodonStatus(
            id: "999",
            uri: "at://did:plc:xyz/app.bsky.feed.post/reply",
            createdAt: Date(),
            account: account,
            content: "<p>This is a reply</p>",
            visibility: .public,
            repliesCount: 0,
            reblogsCount: 0,
            favouritesCount: 0,
            reblogged: false,
            favourited: false,
            sensitive: false,
            spoilerText: "",
            inReplyToId: "123456",
            inReplyToAccountId: "789"
        )

        XCTAssertEqual(status.inReplyToId, "123456")
        XCTAssertEqual(status.inReplyToAccountId, "789")
    }

    func testStatusJSONEncoding() throws {
        let account = MastodonAccount(
            id: "123",
            username: "test",
            acct: "test.bsky.social",
            displayName: "Test",
            note: "",
            url: "https://bsky.app/profile/test.bsky.social",
            avatar: "",
            avatarStatic: "",
            header: "",
            headerStatic: "",
            followersCount: 0,
            followingCount: 0,
            statusesCount: 0,
            createdAt: Date(),
            bot: false,
            locked: false
        )

        let status = MastodonStatus(
            id: "456",
            uri: "at://did:plc:xyz/app.bsky.feed.post/test",
            createdAt: Date(timeIntervalSince1970: 1609459200),
            account: account,
            content: "<p>Test post</p>",
            visibility: .public,
            repliesCount: 0,
            reblogsCount: 0,
            favouritesCount: 0,
            reblogged: false,
            favourited: false,
            sensitive: false,
            spoilerText: ""
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(status)
        XCTAssertFalse(data.isEmpty)

        // Verify it can be decoded back
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(MastodonStatus.self, from: data)
        XCTAssertEqual(decoded.id, status.id)
        XCTAssertEqual(decoded.content, status.content)
    }
}
