import Foundation
import ATProtoKit
import CacheLayer

/// Wrapper around ATProtoKit with convenience methods and session management
public actor ATProtoClient {
    /// AT Protocol service URL
    private let serviceURL: String

    /// Cache for sessions and responses
    private let cache: CacheService

    /// Current authenticated session
    private var currentSession: ATProtoSession?

    /// ATProtoKit instance
    private var atProtoKit: ATProtoKit

    // MARK: - Initialization

    public init(
        serviceURL: String = "https://bsky.social",
        cache: CacheService,
        sessionConfiguration: SessionConfiguration? = nil,
        apiClientConfiguration: APIClientConfiguration? = nil
    ) async {
        self.serviceURL = serviceURL
        self.cache = cache

        // Initialize ATProtoKit with optional API client configuration and session configuration
        // This allows tests to inject custom URLSessionConfiguration (e.g., for mocking) and sessions
        self.atProtoKit = await ATProtoKit(
            sessionConfiguration: sessionConfiguration,
            apiClientConfiguration: apiClientConfiguration,
            pdsURL: serviceURL
        )
    }

    // MARK: - Session Management

    /// Create a new session with handle and password
    public func createSession(handle: String, password: String) async throws -> ATProtoSession {
        do {
            // Create session using ATProtoKit
            let output = try await atProtoKit.createSession(
                with: handle,
                and: password
            )

            // Convert to our session model
            let atProtoSession = ATProtoSession(
                did: output.did,
                handle: output.handle,
                accessToken: output.accessToken,
                refreshToken: output.refreshToken,
                email: output.email,
                createdAt: Date()
            )

            // Store in cache
            try await cacheSession(atProtoSession)

            // Update current session
            self.currentSession = atProtoSession

            return atProtoSession
        } catch {
            throw mapError(error)
        }
    }

    /// Refresh an existing session
    public func refreshSession() async throws -> ATProtoSession {
        guard let session = currentSession else {
            throw ATProtoError.sessionExpired
        }

        do {
            // Refresh session using ATProtoKit
            let output = try await atProtoKit.refreshSession(refreshToken: session.refreshToken)

            // Create updated session
            let newSession = ATProtoSession(
                did: output.did,
                handle: output.handle,
                accessToken: output.accessToken,
                refreshToken: output.refreshToken,
                email: session.email, // Keep existing email
                createdAt: Date()
            )

            // Cache and update
            try await cacheSession(newSession)
            self.currentSession = newSession

            return newSession
        } catch {
            throw mapError(error)
        }
    }

    /// Get the current session
    public func getCurrentSession() -> ATProtoSession? {
        return currentSession
    }

    /// Load session from cache
    public func loadSession(for did: String) async throws -> ATProtoSession? {
        let key = "session:\(did)"
        return try await cache.get(key)
    }

    /// Set the current session (for testing)
    public func setSession(_ session: ATProtoSession) {
        self.currentSession = session
    }

    /// Cache a session
    private func cacheSession(_ session: ATProtoSession) async throws {
        let key = "session:\(session.did)"
        // Cache for 7 days
        try await cache.set(key, value: session, ttl: 7 * 24 * 60 * 60)
    }

    /// Clear the current session
    public func clearSession() async throws {
        if let session = currentSession {
            let key = "session:\(session.did)"
            try await cache.delete(key)
        }
        currentSession = nil
    }

    // MARK: - Profile Operations

    /// Get a profile by handle or DID
    public func getProfile(actor: String) async throws -> ATProtoProfile {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            let profile = try await atProtoKit.getProfile(for: actor)

            return ATProtoProfile(
                did: profile.actorDID,
                handle: profile.actorHandle,
                displayName: profile.displayName,
                description: profile.description,
                avatar: profile.avatarImageURL?.absoluteString,
                banner: profile.bannerImageURL?.absoluteString,
                followersCount: profile.followerCount ?? 0,
                followsCount: profile.followCount ?? 0,
                postsCount: profile.postCount ?? 0,
                indexedAt: profile.indexedAt?.ISO8601Format()
            )
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Follow Operations

    /// Follow a user
    /// Returns the AT URI of the follow record
    public func followUser(actor: String) async throws -> String {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Create ATProtoBluesky instance for convenience methods
            let atProtoBluesky = ATProtoBluesky(atProtoKitInstance: atProtoKit)

            // If actor is a handle, resolve it to a DID first
            let actorDID: String
            if actor.starts(with: "did:") {
                actorDID = actor
            } else {
                // Resolve handle to DID using getProfile
                let profile = try await getProfile(actor: actor)
                actorDID = profile.did
            }

            // Create the follow record
            let followRecord = try await atProtoBluesky.createFollowRecord(actorDID: actorDID)

            // Return the URI of the follow record
            return followRecord.recordURI
        } catch {
            throw mapError(error)
        }
    }

    /// Unfollow a user
    /// Requires the AT URI of the follow record
    public func unfollowUser(followRecordURI: String) async throws {
        guard let session = currentSession else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Parse the AT URI to extract components
            let uriComponents = followRecordURI.replacingOccurrences(of: "at://", with: "").split(separator: "/")
            guard uriComponents.count == 3 else {
                throw ATProtoError.invalidURI(uri: followRecordURI)
            }

            let repo = String(uriComponents[0])
            let collection = String(uriComponents[1])
            let rkey = String(uriComponents[2])

            // Use ATProtoKit's direct deleteRecord method
            try await atProtoKit.deleteRecord(
                repositoryDID: repo,
                collection: collection,
                recordKey: rkey
            )
        } catch {
            throw mapError(error)
        }
    }

    /// Get followers for an actor
    public func getFollowers(actor: String, limit: Int = 50, cursor: String? = nil) async throws -> ATProtoFollowersResponse {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            let response = try await atProtoKit.getFollowers(by: actor, limit: limit, cursor: cursor)

            let followers = response.followers.map { follower in
                ATProtoProfile(
                    did: follower.actorDID,
                    handle: follower.actorHandle,
                    displayName: follower.displayName,
                    description: follower.description,
                    avatar: follower.avatarImageURL?.absoluteString,
                    banner: nil,
                    followersCount: 0,
                    followsCount: 0,
                    postsCount: 0,
                    indexedAt: nil
                )
            }

            return ATProtoFollowersResponse(
                followers: followers,
                cursor: response.cursor
            )
        } catch {
            throw mapError(error)
        }
    }

    /// Get following for an actor
    public func getFollowing(actor: String, limit: Int = 50, cursor: String? = nil) async throws -> ATProtoFollowingResponse {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            let response = try await atProtoKit.getFollows(from: actor, limit: limit, cursor: cursor)

            let following = response.follows.map { follow in
                ATProtoProfile(
                    did: follow.actorDID,
                    handle: follow.actorHandle,
                    displayName: follow.displayName,
                    description: follow.description,
                    avatar: follow.avatarImageURL?.absoluteString,
                    banner: nil,
                    followersCount: 0,
                    followsCount: 0,
                    postsCount: 0,
                    indexedAt: nil
                )
            }

            return ATProtoFollowingResponse(
                following: following,
                cursor: response.cursor
            )
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Search Operations

    /// Search for actors/users
    public func searchActors(query: String, limit: Int = 25, cursor: String? = nil) async throws -> ATProtoSearchResponse {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Use ATProtoKit's searchActors method (correct parameter name is 'matching')
            let response = try await atProtoKit.searchActors(
                matching: query,
                limit: limit,
                cursor: cursor
            )

            // Convert actors to our profile format
            let actors = response.actors.map { actor in
                ATProtoProfile(
                    did: actor.actorDID,
                    handle: actor.actorHandle,
                    displayName: actor.displayName,
                    description: actor.description,
                    avatar: actor.avatarImageURL?.absoluteString,
                    banner: nil,
                    followersCount: 0,
                    followsCount: 0,
                    postsCount: 0,
                    indexedAt: nil
                )
            }

            return ATProtoSearchResponse(actors: actors, cursor: response.cursor)
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Feed Operations

    /// Get author feed (posts by a specific user)
    public func getAuthorFeed(actor: String, limit: Int = 50, cursor: String? = nil, filter: String? = nil) async throws -> ATProtoFeedResponse {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Use ATProtoKit's getAuthorFeed method (correct parameter name is 'by')
            // Note: filter parameter would need to be converted to AppBskyLexicon.Feed.GetAuthorFeed.Filter enum
            // For now, we pass nil and ignore the filter parameter
            let response = try await atProtoKit.getAuthorFeed(
                by: actor,
                limit: limit,
                cursor: cursor,
                postFilter: nil  // TODO: Convert string filter to enum when needed
            )

            // Parse posts from the author feed
            let posts = try response.feed.compactMap { feedItem -> ATProtoPost? in
                try parsePostFromFeedItem(feedItem)
            }

            return ATProtoFeedResponse(posts: posts, cursor: response.cursor)
        } catch {
            throw mapError(error)
        }
    }

    /// Get timeline feed
    public func getTimeline(limit: Int = 50, cursor: String? = nil) async throws -> ATProtoFeedResponse {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Use ATProtoKit's getTimeline method
            let response = try await atProtoKit.getTimeline(
                limit: limit,
                cursor: cursor
            )

            // Parse posts from the timeline
            let posts = try response.feed.compactMap { feedItem -> ATProtoPost? in
                try parsePostFromFeedItem(feedItem)
            }

            return ATProtoFeedResponse(posts: posts, cursor: response.cursor)
        } catch {
            throw mapError(error)
        }
    }

    /// Get feed by URI (for lists/custom feeds)
    public func getFeed(feedURI: String, limit: Int = 50, cursor: String? = nil) async throws -> ATProtoFeedResponse {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Use ATProtoKit's getFeed method for custom feeds (parameter name is 'by')
            let response = try await atProtoKit.getFeed(
                by: feedURI,
                limit: limit,
                cursor: cursor
            )

            // Parse posts from the feed
            let posts = try response.feed.compactMap { feedItem -> ATProtoPost? in
                try parsePostFromFeedItem(feedItem)
            }

            return ATProtoFeedResponse(posts: posts, cursor: response.cursor)
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Notification Operations

    /// Get notifications for authenticated user
    public func getNotifications(limit: Int = 50, cursor: String? = nil) async throws -> ATProtoNotificationsResponse {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Use ATProtoKit's listNotifications method
            let response = try await atProtoKit.listNotifications(
                with: nil,  // reasons filter (optional)
                limit: limit,
                isPriority: nil,  // priority filter (optional)
                cursor: cursor,
                seenAt: nil  // seenAt parameter (has known bugs per ATProtoKit docs)
            )

            // Parse notifications
            let notifications = try response.notifications.compactMap { notif -> ATProtoNotification? in
                try parseNotification(notif)
            }

            return ATProtoNotificationsResponse(
                notifications: notifications,
                cursor: response.cursor
            )
        } catch {
            throw mapError(error)
        }
    }

    /// Mark notifications as read
    public func updateSeenNotifications() async throws {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Use ATProtoKit's updateSeen method with current timestamp
            try await atProtoKit.updateSeen(seenAt: Date())
        } catch {
            throw mapError(error)
        }
    }

    /// Get unread notification count
    public func getUnreadNotificationCount() async throws -> Int {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Use ATProtoKit's getUnreadCount method
            let response = try await atProtoKit.getUnreadCount(
                priority: nil,  // priority filter (optional)
                seenAt: nil  // seenAt parameter (has known bugs per ATProtoKit docs)
            )

            return response.count
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Post Operations

    /// Get a single post by AT URI
    public func getPost(uri: String) async throws -> ATProtoPost {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Use getPostThread to get a single post (parameter name is 'from')
            let thread = try await atProtoKit.getPostThread(from: uri)

            // Parse the main post from the thread
            guard let post = try parsePostFromThread(thread) else {
                throw ATProtoError.postNotFound(uri: uri)
            }

            return post
        } catch {
            throw mapError(error)
        }
    }

    /// Create a new post
    public func createPost(
        text: String,
        replyTo: String? = nil,
        facets: [ATProtoFacet]? = nil,
        embed: ATProtoEmbed? = nil
    ) async throws -> ATProtoPost {
        guard let session = currentSession else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Create ATProtoBluesky instance for convenience methods
            let atProtoBluesky = ATProtoBluesky(atProtoKitInstance: atProtoKit)

            // TODO: Convert our facets and embed types to ATProtoKit types
            // For now, create a simple text post
            let strongReference = try await atProtoBluesky.createPostRecord(text: text)

            // Fetch the created post to return full post data
            return try await getPost(uri: strongReference.recordURI)
        } catch {
            throw mapError(error)
        }
    }

    /// Delete a post
    public func deletePost(uri: String) async throws {
        guard let session = currentSession else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Parse the AT URI to extract repo, collection, and record key
            // Format: at://did:plc:xyz/app.bsky.feed.post/recordkey
            let uriComponents = uri.replacingOccurrences(of: "at://", with: "").split(separator: "/")
            guard uriComponents.count == 3 else {
                throw ATProtoError.invalidURI(uri: uri)
            }

            let repo = String(uriComponents[0])  // The DID
            let collection = String(uriComponents[1])  // e.g., "app.bsky.feed.post"
            let rkey = String(uriComponents[2])  // The record key

            // Use ATProtoKit's direct deleteRecord method
            try await atProtoKit.deleteRecord(
                repositoryDID: repo,
                collection: collection,
                recordKey: rkey
            )
        } catch {
            throw mapError(error)
        }
    }

    /// Get post thread (context with parents and replies)
    public func getPostThread(uri: String, depth: Int = 10) async throws -> ATProtoThreadResponse {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Use ATProtoKit's getPostThread method (parameter name is 'from')
            let thread = try await atProtoKit.getPostThread(from: uri, depth: depth)

            // Parse the main post
            guard let mainPost = try parsePostFromThread(thread) else {
                throw ATProtoError.postNotFound(uri: uri)
            }

            // Parse parent and reply posts
            // ATProtoKit's thread structure is complex, for now return empty arrays
            // TODO: Implement full thread parsing when structure is better understood
            let parents: [ATProtoPost] = []
            let replies: [ATProtoPost] = []

            return ATProtoThreadResponse(
                post: mainPost,
                parents: parents,
                replies: replies
            )
        } catch {
            throw mapError(error)
        }
    }

    /// Like a post
    public func likePost(uri: String, cid: String) async throws -> String {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Create ATProtoBluesky instance for convenience methods
            let atProtoBluesky = ATProtoBluesky(atProtoKitInstance: atProtoKit)

            // Create strong reference from URI and CID
            let strongReference = ComAtprotoLexicon.Repository.StrongReference(
                recordURI: uri,
                cidHash: cid
            )

            // Create the like record
            let likeRecord = try await atProtoBluesky.createLikeRecord(strongReference)

            // Return the URI of the like record
            return likeRecord.recordURI
        } catch {
            throw mapError(error)
        }
    }

    /// Unlike a post
    public func unlikePost(likeRecordURI: String) async throws {
        guard let session = currentSession else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Parse the AT URI to extract components
            let uriComponents = likeRecordURI.replacingOccurrences(of: "at://", with: "").split(separator: "/")
            guard uriComponents.count == 3 else {
                throw ATProtoError.invalidURI(uri: likeRecordURI)
            }

            let repo = String(uriComponents[0])
            let collection = String(uriComponents[1])
            let rkey = String(uriComponents[2])

            // Use ATProtoKit's direct deleteRecord method
            try await atProtoKit.deleteRecord(
                repositoryDID: repo,
                collection: collection,
                recordKey: rkey
            )
        } catch {
            throw mapError(error)
        }
    }

    /// Repost a post
    public func repost(uri: String, cid: String) async throws -> String {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Create ATProtoBluesky instance for convenience methods
            let atProtoBluesky = ATProtoBluesky(atProtoKitInstance: atProtoKit)

            // Create strong reference from URI and CID
            let strongReference = ComAtprotoLexicon.Repository.StrongReference(
                recordURI: uri,
                cidHash: cid
            )

            // Create the repost record
            let repostRecord = try await atProtoBluesky.createRepostRecord(strongReference)

            // Return the URI of the repost record
            return repostRecord.recordURI
        } catch {
            throw mapError(error)
        }
    }

    /// Unrepost a post
    public func unrepost(repostRecordURI: String) async throws {
        guard let session = currentSession else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Parse the AT URI to extract components
            let uriComponents = repostRecordURI.replacingOccurrences(of: "at://", with: "").split(separator: "/")
            guard uriComponents.count == 3 else {
                throw ATProtoError.invalidURI(uri: repostRecordURI)
            }

            let repo = String(uriComponents[0])
            let collection = String(uriComponents[1])
            let rkey = String(uriComponents[2])

            // Use ATProtoKit's direct deleteRecord method
            try await atProtoKit.deleteRecord(
                repositoryDID: repo,
                collection: collection,
                recordKey: rkey
            )
        } catch {
            throw mapError(error)
        }
    }

    /// Get who liked a post
    public func getLikedBy(uri: String, limit: Int = 50, cursor: String? = nil) async throws -> ATProtoLikesResponse {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Use ATProtoKit's getLikes method
            let response = try await atProtoKit.getLikes(
                from: uri,
                limit: limit,
                cursor: cursor
            )

            // Parse likes into profiles
            let likes = response.likes.map { like in
                ATProtoProfile(
                    did: like.actor.actorDID,
                    handle: like.actor.actorHandle,
                    displayName: like.actor.displayName,
                    description: like.actor.description,
                    avatar: like.actor.avatarImageURL?.absoluteString,
                    banner: nil,
                    followersCount: 0,
                    followsCount: 0,
                    postsCount: 0,
                    indexedAt: like.createdAt.ISO8601Format()
                )
            }

            return ATProtoLikesResponse(likes: likes, cursor: response.cursor)
        } catch {
            throw mapError(error)
        }
    }

    /// Get who reposted a post
    public func getRepostedBy(uri: String, limit: Int = 50, cursor: String? = nil) async throws -> ATProtoRepostsResponse {
        guard currentSession != nil else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Use ATProtoKit's getRepostedBy method
            let response = try await atProtoKit.getRepostedBy(
                uri,
                limit: limit,
                cursor: cursor
            )

            // Parse reposts into profiles
            let reposts = response.repostedBy.map { actor in
                ATProtoProfile(
                    did: actor.actorDID,
                    handle: actor.actorHandle,
                    displayName: actor.displayName,
                    description: actor.description,
                    avatar: actor.avatarImageURL?.absoluteString,
                    banner: nil,
                    followersCount: 0,
                    followsCount: 0,
                    postsCount: 0,
                    indexedAt: nil
                )
            }

            return ATProtoRepostsResponse(reposts: reposts, cursor: response.cursor)
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Blob Operations

    /// Upload a blob (image, video, etc.)
    /// Returns a blob reference that can be used in posts
    public func uploadBlob(data: Data, filename: String, mimeType: String) async throws -> ATProtoBlobRef {
        guard let session = currentSession else {
            throw ATProtoError.authenticationFailed(reason: "No active session")
        }

        do {
            // Use ATProtoKit's blob upload
            let output = try await atProtoKit.uploadBlob(
                pdsURL: serviceURL,
                accessToken: session.accessToken,
                filename: filename,
                imageData: data
            )

            // Extract the CID from the blob reference
            // The output.blob structure contains the blob metadata
            return ATProtoBlobRef(
                cid: output.blob.reference.link,
                mimeType: output.blob.mimeType,
                size: output.blob.size
            )
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Parsing Helpers

    /// Parse a feed item from ATProtoKit into our ATProtoPost type
    private func parsePostFromFeedItem(_ feedItem: AppBskyLexicon.Feed.FeedViewPostDefinition) throws -> ATProtoPost? {
        let post = feedItem.post

        // Parse author profile (ProfileViewBasicDefinition doesn't have description field)
        let author = ATProtoProfile(
            did: post.author.actorDID,
            handle: post.author.actorHandle,
            displayName: post.author.displayName,
            description: nil,  // ProfileViewBasicDefinition doesn't include bio
            avatar: post.author.avatarImageURL?.absoluteString,
            banner: nil,
            followersCount: 0,
            followsCount: 0,
            postsCount: 0,
            indexedAt: post.indexedAt.ISO8601Format()
        )

        // Extract text from the record (it's stored as UnknownType)
        // We'll decode it as JSON to extract the text field
        let text = extractTextFromRecord(post.record) ?? ""

        return ATProtoPost(
            uri: post.uri,
            cid: post.cid,
            author: author,
            text: text,
            facets: nil, // TODO: Parse facets when needed
            embed: nil, // TODO: Parse embeds when needed
            replyTo: nil, // TODO: Extract from record when needed
            replyRoot: nil, // TODO: Extract from record when needed
            createdAt: post.indexedAt.ISO8601Format(),
            likeCount: post.likeCount ?? 0,
            repostCount: post.repostCount ?? 0,
            replyCount: post.replyCount ?? 0,
            quoteCount: post.quoteCount,
            isLiked: post.viewer?.likeURI != nil,  // Check if likeURI field exists
            isReposted: post.viewer?.repostURI != nil  // Check if repostURI field exists
        )
    }

    /// Parse a thread from ATProtoKit into our ATProtoPost type
    private func parsePostFromThread(_ thread: AppBskyLexicon.Feed.GetPostThreadOutput) throws -> ATProtoPost? {
        // Extract the main thread post
        guard case .threadViewPost(let threadPost) = thread.thread else {
            return nil
        }

        let post = threadPost.post

        // Parse author profile (ProfileViewBasicDefinition doesn't have description field)
        let author = ATProtoProfile(
            did: post.author.actorDID,
            handle: post.author.actorHandle,
            displayName: post.author.displayName,
            description: nil,  // ProfileViewBasicDefinition doesn't include bio
            avatar: post.author.avatarImageURL?.absoluteString,
            banner: nil,
            followersCount: 0,
            followsCount: 0,
            postsCount: 0,
            indexedAt: post.indexedAt.ISO8601Format()
        )

        // Extract text from the record
        let text = extractTextFromRecord(post.record) ?? ""

        return ATProtoPost(
            uri: post.uri,
            cid: post.cid,
            author: author,
            text: text,
            facets: nil, // TODO: Parse facets when needed
            embed: nil, // TODO: Parse embeds when needed
            replyTo: nil, // TODO: Extract from record when needed
            replyRoot: nil, // TODO: Extract from record when needed
            createdAt: post.indexedAt.ISO8601Format(),
            likeCount: post.likeCount ?? 0,
            repostCount: post.repostCount ?? 0,
            replyCount: post.replyCount ?? 0,
            quoteCount: post.quoteCount,
            isLiked: post.viewer?.likeURI != nil,  // Check if likeURI field exists
            isReposted: post.viewer?.repostURI != nil  // Check if repostURI field exists
        )
    }

    /// Parse a notification from ATProtoKit into our ATProtoNotification type
    private func parseNotification(_ notif: AppBskyLexicon.Notification.Notification) throws -> ATProtoNotification? {
        // Parse author profile
        let author = ATProtoProfile(
            did: notif.author.actorDID,
            handle: notif.author.actorHandle,
            displayName: notif.author.displayName,
            description: notif.author.description,
            avatar: notif.author.avatarImageURL?.absoluteString,
            banner: nil,
            followersCount: 0,
            followsCount: 0,
            postsCount: 0,
            indexedAt: nil
        )

        return ATProtoNotification(
            uri: notif.uri,
            cid: notif.cid,
            author: author,
            reason: notif.reason.rawValue,
            reasonSubject: notif.reasonSubjectURI,
            record: nil, // TODO: Parse record when needed
            isRead: notif.isRead,
            indexedAt: notif.indexedAt.ISO8601Format()
        )
    }

    /// Helper to extract text from UnknownType record
    private func extractTextFromRecord(_ record: UnknownType) -> String? {
        // UnknownType is a property wrapper around the raw JSON value
        // We need to decode it to extract the text field from app.bsky.feed.post records
        do {
            // Try to encode the UnknownType back to JSON data
            let encoder = JSONEncoder()
            let data = try encoder.encode(record)

            // Decode as a dictionary to extract the text field
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String {
                return text
            }
        } catch {
            // If extraction fails, return nil
        }
        return nil
    }

    // MARK: - Error Mapping

    /// Map ATProtoKit errors to our error types
    private func mapError(_ error: Error) -> ATProtoError {
        // Check if it's already our error type
        if let atProtoError = error as? ATProtoError {
            return atProtoError
        }

        // Map common error types
        let errorDescription = error.localizedDescription.lowercased()

        if errorDescription.contains("unauthorized") || errorDescription.contains("authentication") {
            return .authenticationFailed(reason: error.localizedDescription)
        }

        if errorDescription.contains("not found") {
            return .apiError(message: error.localizedDescription)
        }

        if errorDescription.contains("network") || errorDescription.contains("connection") {
            return .networkError(underlying: error)
        }

        if errorDescription.contains("rate limit") {
            return .rateLimited(retryAfter: nil)
        }

        // Default to unknown
        return .unknown(underlying: error)
    }
}

// MARK: - Supporting Types

/// Profile information from AT Protocol
public struct ATProtoProfile: Codable, Sendable {
    public let did: String
    public let handle: String
    public let displayName: String?
    public let description: String?
    public let avatar: String?
    public let banner: String?
    public let followersCount: Int
    public let followsCount: Int
    public let postsCount: Int
    public let indexedAt: String?

    public init(
        did: String,
        handle: String,
        displayName: String?,
        description: String?,
        avatar: String?,
        banner: String?,
        followersCount: Int,
        followsCount: Int,
        postsCount: Int,
        indexedAt: String?
    ) {
        self.did = did
        self.handle = handle
        self.displayName = displayName
        self.description = description
        self.avatar = avatar
        self.banner = banner
        self.followersCount = followersCount
        self.followsCount = followsCount
        self.postsCount = postsCount
        self.indexedAt = indexedAt
    }
}

/// Post/Status information from AT Protocol
public struct ATProtoPost: Codable, Sendable {
    public let uri: String
    public let cid: String
    public let author: ATProtoProfile
    public let text: String
    public let facets: [ATProtoFacet]?
    public let embed: ATProtoEmbed?
    public let replyTo: String?
    public let replyRoot: String?
    public let createdAt: String
    public let likeCount: Int
    public let repostCount: Int
    public let replyCount: Int
    public let quoteCount: Int?
    public let isLiked: Bool
    public let isReposted: Bool

    public init(
        uri: String,
        cid: String,
        author: ATProtoProfile,
        text: String,
        facets: [ATProtoFacet]? = nil,
        embed: ATProtoEmbed? = nil,
        replyTo: String? = nil,
        replyRoot: String? = nil,
        createdAt: String,
        likeCount: Int = 0,
        repostCount: Int = 0,
        replyCount: Int = 0,
        quoteCount: Int? = nil,
        isLiked: Bool = false,
        isReposted: Bool = false
    ) {
        self.uri = uri
        self.cid = cid
        self.author = author
        self.text = text
        self.facets = facets
        self.embed = embed
        self.replyTo = replyTo
        self.replyRoot = replyRoot
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.repostCount = repostCount
        self.replyCount = replyCount
        self.quoteCount = quoteCount
        self.isLiked = isLiked
        self.isReposted = isReposted
    }
}

/// Facet information for rich text
public struct ATProtoFacet: Codable, Sendable {
    public let index: ATProtoByteSlice
    public let features: [ATProtoFeature]

    public init(index: ATProtoByteSlice, features: [ATProtoFeature]) {
        self.index = index
        self.features = features
    }
}

/// Byte slice for facet positioning
public struct ATProtoByteSlice: Codable, Sendable {
    public let byteStart: Int
    public let byteEnd: Int

    public init(byteStart: Int, byteEnd: Int) {
        self.byteStart = byteStart
        self.byteEnd = byteEnd
    }
}

/// Feature types for facets
public enum ATProtoFeature: Codable, Sendable {
    case link(uri: String)
    case mention(did: String)
    case tag(tag: String)

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case uri
        case did
        case tag
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "app.bsky.richtext.facet#link":
            let uri = try container.decode(String.self, forKey: .uri)
            self = .link(uri: uri)
        case "app.bsky.richtext.facet#mention":
            let did = try container.decode(String.self, forKey: .did)
            self = .mention(did: did)
        case "app.bsky.richtext.facet#tag":
            let tag = try container.decode(String.self, forKey: .tag)
            self = .tag(tag: tag)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown facet type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .link(let uri):
            try container.encode("app.bsky.richtext.facet#link", forKey: .type)
            try container.encode(uri, forKey: .uri)
        case .mention(let did):
            try container.encode("app.bsky.richtext.facet#mention", forKey: .type)
            try container.encode(did, forKey: .did)
        case .tag(let tag):
            try container.encode("app.bsky.richtext.facet#tag", forKey: .type)
            try container.encode(tag, forKey: .tag)
        }
    }
}

/// Embed types for posts
public enum ATProtoEmbed: Codable, Sendable {
    case images([ATProtoImage])
    case external(ATProtoExternal)
    case record(ATProtoRecordEmbed)

    public init(from decoder: Decoder) throws {
        // For now, just provide placeholder implementation
        // Will be properly implemented when needed
        self = .images([])
    }

    public func encode(to encoder: Encoder) throws {
        // Placeholder
    }
}

/// Image embed
public struct ATProtoImage: Codable, Sendable {
    public let url: String
    public let alt: String?
    public let aspectRatio: ATProtoAspectRatio?

    public init(url: String, alt: String? = nil, aspectRatio: ATProtoAspectRatio? = nil) {
        self.url = url
        self.alt = alt
        self.aspectRatio = aspectRatio
    }
}

/// External link embed
public struct ATProtoExternal: Codable, Sendable {
    public let uri: String
    public let title: String
    public let description: String
    public let thumb: String?

    public init(uri: String, title: String, description: String, thumb: String? = nil) {
        self.uri = uri
        self.title = title
        self.description = description
        self.thumb = thumb
    }
}

/// Record embed (quote posts)
public struct ATProtoRecordEmbed: Codable, Sendable {
    public let uri: String
    public let cid: String

    public init(uri: String, cid: String) {
        self.uri = uri
        self.cid = cid
    }
}

/// Aspect ratio for images
public struct ATProtoAspectRatio: Codable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

// MARK: - Response Types

/// Response for followers list
public struct ATProtoFollowersResponse: Codable, Sendable {
    public let followers: [ATProtoProfile]
    public let cursor: String?

    public init(followers: [ATProtoProfile], cursor: String?) {
        self.followers = followers
        self.cursor = cursor
    }
}

/// Response for following list
public struct ATProtoFollowingResponse: Codable, Sendable {
    public let following: [ATProtoProfile]
    public let cursor: String?

    public init(following: [ATProtoProfile], cursor: String?) {
        self.following = following
        self.cursor = cursor
    }
}

/// Response for actor search
public struct ATProtoSearchResponse: Codable, Sendable {
    public let actors: [ATProtoProfile]
    public let cursor: String?

    public init(actors: [ATProtoProfile], cursor: String?) {
        self.actors = actors
        self.cursor = cursor
    }
}

/// Response for feed/timeline
public struct ATProtoFeedResponse: Codable, Sendable {
    public let posts: [ATProtoPost]
    public let cursor: String?

    public init(posts: [ATProtoPost], cursor: String?) {
        self.posts = posts
        self.cursor = cursor
    }
}

/// Response for post thread (context)
public struct ATProtoThreadResponse: Codable, Sendable {
    public let post: ATProtoPost
    public let parents: [ATProtoPost]
    public let replies: [ATProtoPost]

    public init(post: ATProtoPost, parents: [ATProtoPost], replies: [ATProtoPost]) {
        self.post = post
        self.parents = parents
        self.replies = replies
    }
}

/// Response for likes list
public struct ATProtoLikesResponse: Codable, Sendable {
    public let likes: [ATProtoProfile]
    public let cursor: String?

    public init(likes: [ATProtoProfile], cursor: String?) {
        self.likes = likes
        self.cursor = cursor
    }
}

/// Response for reposts list
public struct ATProtoRepostsResponse: Codable, Sendable {
    public let reposts: [ATProtoProfile]
    public let cursor: String?

    public init(reposts: [ATProtoProfile], cursor: String?) {
        self.reposts = reposts
        self.cursor = cursor
    }
}

/// Notification from AT Protocol
public struct ATProtoNotification: Codable, Sendable {
    public let uri: String
    public let cid: String
    public let author: ATProtoProfile
    public let reason: String // "like", "repost", "follow", "mention", "reply", "quote"
    public let reasonSubject: String? // URI of the subject (post that was liked, etc.)
    public let record: String? // Placeholder for actual record data
    public let isRead: Bool
    public let indexedAt: String

    public init(
        uri: String,
        cid: String,
        author: ATProtoProfile,
        reason: String,
        reasonSubject: String? = nil,
        record: String? = nil,
        isRead: Bool,
        indexedAt: String
    ) {
        self.uri = uri
        self.cid = cid
        self.author = author
        self.reason = reason
        self.reasonSubject = reasonSubject
        self.record = record
        self.isRead = isRead
        self.indexedAt = indexedAt
    }
}

/// Response for notifications list
public struct ATProtoNotificationsResponse: Codable, Sendable {
    public let notifications: [ATProtoNotification]
    public let cursor: String?

    public init(notifications: [ATProtoNotification], cursor: String?) {
        self.notifications = notifications
        self.cursor = cursor
    }
}

// MARK: - Blob Types

/// Reference to an uploaded blob
public struct ATProtoBlobRef: Codable, Sendable {
    /// The CID (Content Identifier) of the uploaded blob
    public let cid: String
    /// The MIME type of the blob
    public let mimeType: String
    /// The size of the blob in bytes
    public let size: Int

    public init(cid: String, mimeType: String, size: Int) {
        self.cid = cid
        self.mimeType = mimeType
        self.size = size
    }
}
