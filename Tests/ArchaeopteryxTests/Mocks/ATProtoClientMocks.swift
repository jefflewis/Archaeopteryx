import Foundation
import ATProtoAdapter
import Dependencies

/// Common mock implementations for ATProtoClient
///
/// This file provides reusable mock implementations for testing routes
/// without requiring a real AT Protocol connection.
///
/// ## Usage in Tests
///
/// ```swift
/// func testVerifyCredentials() async throws {
///     try await withDependencies {
///         $0.atProtoClient = .testSuccess
///     } operation: {
///         // Your test code here
///         // atProtoClient will return mock data
///     }
/// }
/// ```
extension ATProtoClientDependency {

    // MARK: - Success Mocks

    /// Mock client that returns successful responses with test data
    public static var testSuccess: Self {
        Self(
            createSession: { handle, password in
                ATProtoSession(
                    did: "did:plc:test123",
                    handle: handle,
                    accessToken: "test_access_token",
                    refreshToken: "test_refresh_token"
                )
            },
            refreshSession: {
                ATProtoSession(
                    did: "did:plc:test123",
                    handle: "test.bsky.social",
                    accessToken: "refreshed_token",
                    refreshToken: "new_refresh_token"
                )
            },
            getCurrentSession: {
                ATProtoSession(
                    did: "did:plc:test123",
                    handle: "test.bsky.social",
                    accessToken: "test_access_token",
                    refreshToken: "test_refresh_token"
                )
            },
            loadSession: { did in
                ATProtoSession(
                    did: did,
                    handle: "test.bsky.social",
                    accessToken: "loaded_token",
                    refreshToken: "loaded_refresh"
                )
            },
            clearSession: { },
            getProfile: { actor in
                ATProtoProfile(
                    did: "did:plc:\(actor)",
                    handle: "\(actor).bsky.social",
                    displayName: "Test User",
                    description: "Test user bio",
                    avatar: "https://example.com/avatar.jpg",
                    banner: "https://example.com/banner.jpg",
                    followersCount: 100,
                    followsCount: 50,
                    postsCount: 25,
                    indexedAt: "2025-01-01T00:00:00Z"
                )
            },
            followUser: { actor in
                "at://did:plc:\(actor)/app.bsky.graph.follow/test123"
            },
            unfollowUser: { _ in },
            getFollowers: { actor, limit, cursor in
                ATProtoFollowersResponse(
                    followers: [
                        ATProtoProfile(
                            did: "did:plc:follower1",
                            handle: "follower1.bsky.social",
                            displayName: "Follower One",
                            description: nil,
                            avatar: nil,
                            banner: nil,
                            followersCount: 10,
                            followsCount: 20,
                            postsCount: 5,
                            indexedAt: nil
                        )
                    ],
                    cursor: nil
                )
            },
            getFollowing: { actor, limit, cursor in
                ATProtoFollowingResponse(
                    following: [
                        ATProtoProfile(
                            did: "did:plc:following1",
                            handle: "following1.bsky.social",
                            displayName: "Following One",
                            description: nil,
                            avatar: nil,
                            banner: nil,
                            followersCount: 30,
                            followsCount: 40,
                            postsCount: 15,
                            indexedAt: nil
                        )
                    ],
                    cursor: nil
                )
            },
            searchActors: { query, limit, cursor in
                ATProtoSearchResponse(
                    actors: [
                        ATProtoProfile(
                            did: "did:plc:search1",
                            handle: "search1.bsky.social",
                            displayName: "Search Result",
                            description: "Found via search: \(query)",
                            avatar: nil,
                            banner: nil,
                            followersCount: 50,
                            followsCount: 25,
                            postsCount: 10,
                            indexedAt: nil
                        )
                    ],
                    cursor: nil
                )
            },
            getAuthorFeed: { actor, limit, cursor, filter in
                ATProtoFeedResponse(posts: [], cursor: nil)
            },
            getTimeline: { limit, cursor in
                ATProtoFeedResponse(posts: [], cursor: nil)
            },
            getFeed: { feedURI, limit, cursor in
                ATProtoFeedResponse(posts: [], cursor: nil)
            },
            getNotifications: { limit, cursor in
                ATProtoNotificationsResponse(notifications: [], cursor: nil)
            },
            updateSeenNotifications: { },
            getUnreadNotificationCount: { 0 },
            getPost: { uri in
                ATProtoPost(
                    uri: uri,
                    cid: "test_cid",
                    author: ATProtoProfile(
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
                    ),
                    text: "Test post",
                    createdAt: "2025-01-01T00:00:00Z"
                )
            },
            createPost: { text, replyTo, facets, embed in
                ATProtoPost(
                    uri: "at://did:plc:test/app.bsky.feed.post/test123",
                    cid: "test_cid",
                    author: ATProtoProfile(
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
                    ),
                    text: text,
                    createdAt: Date().ISO8601Format()
                )
            },
            deletePost: { _ in },
            getPostThread: { uri, depth in
                ATProtoThreadResponse(
                    post: ATProtoPost(
                        uri: uri,
                        cid: "test_cid",
                        author: ATProtoProfile(
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
                        ),
                        text: "Test post",
                        createdAt: "2025-01-01T00:00:00Z"
                    ),
                    parents: [],
                    replies: []
                )
            },
            likePost: { uri, cid in
                "at://did:plc:test/app.bsky.feed.like/test123"
            },
            unlikePost: { _ in },
            repost: { uri, cid in
                "at://did:plc:test/app.bsky.feed.repost/test123"
            },
            unrepost: { _ in },
            getLikedBy: { uri, limit, cursor in
                ATProtoLikesResponse(likes: [], cursor: nil)
            },
            getRepostedBy: { uri, limit, cursor in
                ATProtoRepostsResponse(reposts: [], cursor: nil)
            },
            uploadBlob: { data, filename, mimeType in
                ATProtoBlobRef(cid: "test_blob_cid", mimeType: mimeType, size: data.count)
            }
        )
    }

    // MARK: - Error Mocks

    /// Mock client that returns authentication errors
    public static var testAuthError: Self {
        Self(
            createSession: { _, _ in
                throw ATProtoError.authenticationFailed(reason: "Invalid credentials")
            },
            refreshSession: {
                throw ATProtoError.authenticationFailed(reason: "Token expired")
            },
            getCurrentSession: { nil },
            loadSession: { _ in nil },
            clearSession: { },
            getProfile: { _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            followUser: { _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            unfollowUser: { _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            getFollowers: { _, _, _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            getFollowing: { _, _, _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            searchActors: { _, _, _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            getAuthorFeed: { _, _, _, _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            getTimeline: { _, _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            getFeed: { _, _, _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            getNotifications: { _, _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            updateSeenNotifications: {
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            getUnreadNotificationCount: {
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            getPost: { _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            createPost: { _, _, _, _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            deletePost: { _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            getPostThread: { _, _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            likePost: { _, _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            unlikePost: { _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            repost: { _, _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            unrepost: { _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            getLikedBy: { _, _, _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            getRepostedBy: { _, _, _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            },
            uploadBlob: { _, _, _ in
                throw ATProtoError.authenticationFailed(reason: "Not authenticated")
            }
        )
    }

    /// Mock client where profile lookups return "not found"
    public static var testNotFound: Self {
        var mock = Self.testSuccess
        mock.getProfile = { handle in
            throw ATProtoError.profileNotFound(handle: handle)
        }
        return mock
    }
}
