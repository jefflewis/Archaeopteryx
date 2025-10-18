import Testing
import Foundation
@testable import MastodonModels

@Suite struct MastodonStatusTests {

    @Test func StatusInitialization() throws {
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

        #expect(status.id == "987654321")
        #expect(status.content == "<p>Hello, world!</p>")
        #expect(status.visibility == .public)
        #expect(status.repliesCount == 5)
        #expect(status.reblogsCount == 10)
        #expect(status.favouritesCount == 15)
        #expect(!(status.reblogged))
        #expect(!(status.favourited))
        #expect(!(status.sensitive))
    }

    @Test func StatusWithReply() throws {
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

        #expect(status.inReplyToId == "123456")
        #expect(status.inReplyToAccountId == "789")
    }

    @Test func StatusJSONEncoding() throws {
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
        #expect(!(data.isEmpty))

        // Verify it can be decoded back
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(MastodonStatus.self, from: data)
        #expect(decoded.id == status.id)
        #expect(decoded.content == status.content)
    }
}

