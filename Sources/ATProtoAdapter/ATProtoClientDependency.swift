import Dependencies
import DependenciesMacros
import Foundation

/// Struct-based protocol witness for AT Protocol client operations
/// Uses swift-dependencies for dependency injection
@DependencyClient
public struct ATProtoClientDependency: Sendable {
    // MARK: - Session Management
    public var createSession: @Sendable (String, String) async throws -> ATProtoSession
    public var refreshSession: @Sendable () async throws -> ATProtoSession
    public var getCurrentSession: @Sendable () async -> ATProtoSession?
    public var loadSession: @Sendable (String) async throws -> ATProtoSession?
    public var clearSession: @Sendable () async throws -> Void

    // MARK: - Profile Operations
    public var getProfile: @Sendable (String) async throws -> ATProtoProfile

    // MARK: - Follow Operations
    public var followUser: @Sendable (String) async throws -> String
    public var unfollowUser: @Sendable (String) async throws -> Void
    public var getFollowers: @Sendable (String, Int, String?) async throws -> ATProtoFollowersResponse
    public var getFollowing: @Sendable (String, Int, String?) async throws -> ATProtoFollowingResponse

    // MARK: - Search Operations
    public var searchActors: @Sendable (String, Int, String?) async throws -> ATProtoSearchResponse

    // MARK: - Feed Operations
    public var getAuthorFeed: @Sendable (String, Int, String?, String?) async throws -> ATProtoFeedResponse
    public var getTimeline: @Sendable (Int, String?) async throws -> ATProtoFeedResponse
    public var getFeed: @Sendable (String, Int, String?) async throws -> ATProtoFeedResponse

    // MARK: - Notification Operations
    public var getNotifications: @Sendable (Int, String?) async throws -> ATProtoNotificationsResponse
    public var updateSeenNotifications: @Sendable () async throws -> Void
    public var getUnreadNotificationCount: @Sendable () async throws -> Int

    // MARK: - Post Operations
    public var getPost: @Sendable (String) async throws -> ATProtoPost
    public var createPost: @Sendable (String, String?, [ATProtoFacet]?, ATProtoEmbed?) async throws -> ATProtoPost
    public var deletePost: @Sendable (String) async throws -> Void
    public var getPostThread: @Sendable (String, Int) async throws -> ATProtoThreadResponse

    // MARK: - Interaction Operations
    public var likePost: @Sendable (String, String) async throws -> String
    public var unlikePost: @Sendable (String) async throws -> Void
    public var repost: @Sendable (String, String) async throws -> String
    public var unrepost: @Sendable (String) async throws -> Void
    public var getLikedBy: @Sendable (String, Int, String?) async throws -> ATProtoLikesResponse
    public var getRepostedBy: @Sendable (String, Int, String?) async throws -> ATProtoRepostsResponse

    // MARK: - Blob Operations
    public var uploadBlob: @Sendable (Data, String, String) async throws -> ATProtoBlobRef
}

// MARK: - Live Implementation

extension ATProtoClientDependency {
    /// Creates a live dependency from an ATProtoClient actor
    public static func live(client: ATProtoClient) -> ATProtoClientDependency {
        ATProtoClientDependency(
            createSession: { handle, password in
                try await client.createSession(handle: handle, password: password)
            },
            refreshSession: {
                try await client.refreshSession()
            },
            getCurrentSession: {
                await client.getCurrentSession()
            },
            loadSession: { did in
                try await client.loadSession(for: did)
            },
            clearSession: {
                try await client.clearSession()
            },
            getProfile: { actor in
                try await client.getProfile(actor: actor)
            },
            followUser: { actor in
                try await client.followUser(actor: actor)
            },
            unfollowUser: { followRecordURI in
                try await client.unfollowUser(followRecordURI: followRecordURI)
            },
            getFollowers: { actor, limit, cursor in
                try await client.getFollowers(actor: actor, limit: limit, cursor: cursor)
            },
            getFollowing: { actor, limit, cursor in
                try await client.getFollowing(actor: actor, limit: limit, cursor: cursor)
            },
            searchActors: { query, limit, cursor in
                try await client.searchActors(query: query, limit: limit, cursor: cursor)
            },
            getAuthorFeed: { actor, limit, cursor, filter in
                try await client.getAuthorFeed(actor: actor, limit: limit, cursor: cursor, filter: filter)
            },
            getTimeline: { limit, cursor in
                try await client.getTimeline(limit: limit, cursor: cursor)
            },
            getFeed: { feedURI, limit, cursor in
                try await client.getFeed(feedURI: feedURI, limit: limit, cursor: cursor)
            },
            getNotifications: { limit, cursor in
                try await client.getNotifications(limit: limit, cursor: cursor)
            },
            updateSeenNotifications: {
                try await client.updateSeenNotifications()
            },
            getUnreadNotificationCount: {
                try await client.getUnreadNotificationCount()
            },
            getPost: { uri in
                try await client.getPost(uri: uri)
            },
            createPost: { text, replyTo, facets, embed in
                try await client.createPost(text: text, replyTo: replyTo, facets: facets, embed: embed)
            },
            deletePost: { uri in
                try await client.deletePost(uri: uri)
            },
            getPostThread: { uri, depth in
                try await client.getPostThread(uri: uri, depth: depth)
            },
            likePost: { uri, cid in
                try await client.likePost(uri: uri, cid: cid)
            },
            unlikePost: { likeRecordURI in
                try await client.unlikePost(likeRecordURI: likeRecordURI)
            },
            repost: { uri, cid in
                try await client.repost(uri: uri, cid: cid)
            },
            unrepost: { repostRecordURI in
                try await client.unrepost(repostRecordURI: repostRecordURI)
            },
            getLikedBy: { uri, limit, cursor in
                try await client.getLikedBy(uri: uri, limit: limit, cursor: cursor)
            },
            getRepostedBy: { uri, limit, cursor in
                try await client.getRepostedBy(uri: uri, limit: limit, cursor: cursor)
            },
            uploadBlob: { data, filename, mimeType in
                try await client.uploadBlob(data: data, filename: filename, mimeType: mimeType)
            }
        )
    }
}

// MARK: - Dependency Key

extension ATProtoClientDependency: DependencyKey {
    /// Live implementation using real ATProtoClient actor
    /// Note: This must be overridden at app startup using DependencyValues
    public static var liveValue: ATProtoClientDependency {
        // Will be set at app startup
        fatalError("Live ATProtoClientDependency must be provided at app startup. Use ATProtoClientDependency.live(client:) to create one.")
    }

    /// Test implementation that throws unimplemented errors
    /// The @DependencyClient macro automatically generates implementations
    /// that trigger XCTest failures when called
    public static var testValue: ATProtoClientDependency {
        Self()
    }
}

// MARK: - Dependency Values Extension

extension DependencyValues {
    public var atProtoClient: ATProtoClientDependency {
        get { self[ATProtoClientDependency.self] }
        set { self[ATProtoClientDependency.self] = newValue }
    }
}

// MARK: - Test Helpers

extension ATProtoClientDependency {
    /// Creates a failing test implementation
    public static var failing: ATProtoClientDependency {
        testValue
    }

    /// Creates a noop implementation that returns empty/default values
    public static var noop: ATProtoClientDependency {
        ATProtoClientDependency(
            createSession: { _, _ in
                ATProtoSession(
                    did: "did:plc:test",
                    handle: "test.bsky.social",
                    accessToken: "test_token",
                    refreshToken: "test_refresh"
                )
            },
            refreshSession: {
                ATProtoSession(
                    did: "did:plc:test",
                    handle: "test.bsky.social",
                    accessToken: "test_token",
                    refreshToken: "test_refresh"
                )
            },
            getCurrentSession: { await Task.yield(); return nil },
            loadSession: { _ in nil },
            clearSession: { },
            getProfile: { _ in
                ATProtoProfile(
                    did: "did:plc:test",
                    handle: "test.bsky.social",
                    displayName: "Test User",
                    description: nil,
                    avatar: nil,
                    banner: nil,
                    followersCount: 0,
                    followsCount: 0,
                    postsCount: 0,
                    indexedAt: nil
                )
            },
            followUser: { _ in "at://did:plc:test/app.bsky.graph.follow/test" },
            unfollowUser: { _ in },
            getFollowers: { _, _, _ in ATProtoFollowersResponse(followers: [], cursor: nil) },
            getFollowing: { _, _, _ in ATProtoFollowingResponse(following: [], cursor: nil) },
            searchActors: { _, _, _ in ATProtoSearchResponse(actors: [], cursor: nil) },
            getAuthorFeed: { _, _, _, _ in ATProtoFeedResponse(posts: [], cursor: nil) },
            getTimeline: { _, _ in ATProtoFeedResponse(posts: [], cursor: nil) },
            getFeed: { _, _, _ in ATProtoFeedResponse(posts: [], cursor: nil) },
            getNotifications: { _, _ in ATProtoNotificationsResponse(notifications: [], cursor: nil) },
            updateSeenNotifications: { },
            getUnreadNotificationCount: { 0 },
            getPost: { _ in
                ATProtoPost(
                    uri: "at://did:plc:test/app.bsky.feed.post/test",
                    cid: "test_cid",
                    author: ATProtoProfile(
                        did: "did:plc:test",
                        handle: "test.bsky.social",
                        displayName: nil,
                        description: nil,
                        avatar: nil,
                        banner: nil,
                        followersCount: 0,
                        followsCount: 0,
                        postsCount: 0,
                        indexedAt: nil
                    ),
                    text: "Test post",
                    createdAt: Date().ISO8601Format()
                )
            },
            createPost: { text, _, _, _ in
                ATProtoPost(
                    uri: "at://did:plc:test/app.bsky.feed.post/test",
                    cid: "test_cid",
                    author: ATProtoProfile(
                        did: "did:plc:test",
                        handle: "test.bsky.social",
                        displayName: nil,
                        description: nil,
                        avatar: nil,
                        banner: nil,
                        followersCount: 0,
                        followsCount: 0,
                        postsCount: 0,
                        indexedAt: nil
                    ),
                    text: text,
                    createdAt: Date().ISO8601Format()
                )
            },
            deletePost: { _ in },
            getPostThread: { _, _ in
                ATProtoThreadResponse(
                    post: ATProtoPost(
                        uri: "at://did:plc:test/app.bsky.feed.post/test",
                        cid: "test_cid",
                        author: ATProtoProfile(
                            did: "did:plc:test",
                            handle: "test.bsky.social",
                            displayName: nil,
                            description: nil,
                            avatar: nil,
                            banner: nil,
                            followersCount: 0,
                            followsCount: 0,
                            postsCount: 0,
                            indexedAt: nil
                        ),
                        text: "Test post",
                        createdAt: Date().ISO8601Format()
                    ),
                    parents: [],
                    replies: []
                )
            },
            likePost: { _, _ in "at://did:plc:test/app.bsky.feed.like/test" },
            unlikePost: { _ in },
            repost: { _, _ in "at://did:plc:test/app.bsky.feed.repost/test" },
            unrepost: { _ in },
            getLikedBy: { _, _, _ in ATProtoLikesResponse(likes: [], cursor: nil) },
            getRepostedBy: { _, _, _ in ATProtoRepostsResponse(reposts: [], cursor: nil) },
            uploadBlob: { _, _, mimeType in
                ATProtoBlobRef(cid: "test_cid", mimeType: mimeType, size: 1024)
            }
        )
    }
}
