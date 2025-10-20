import Foundation
import ATProtoKit
import ArchaeopteryxCore

/// Session-scoped AT Protocol client
/// Creates temporary ATProtoKit instances with user-specific sessions
/// This enables multi-user support without shared state
public actor SessionScopedClient {
    private let serviceURL: String

    public init(serviceURL: String = "https://bsky.social") {
        self.serviceURL = serviceURL
    }

    /// Execute an operation with a user's session
    /// Creates a temporary ATProtoKit instance configured with the user's tokens
    private func withUserSession<T>(
        _ sessionData: BlueskySessionData,
        operation: (ATProtoKit, String) async throws -> T
    ) async throws -> T {
        // Create an in-memory keychain with the user's tokens
        let keychain = await InMemoryKeychain(
            accessToken: sessionData.accessToken,
            refreshToken: sessionData.refreshToken
        )
        
        // Create a UserSession from the BlueskySessionData
        let userSession = UserSession(
            handle: sessionData.handle,
            sessionDID: sessionData.did,
            email: sessionData.email,
            isEmailConfirmed: nil,
            isEmailAuthenticationFactorEnabled: nil,
            didDocument: nil,
            isActive: nil,
            status: nil,
            serviceEndpoint: URL(string: serviceURL)!,
            pdsURL: serviceURL
        )

        // Create an ATProtocolConfiguration with the in-memory keychain
        let sessionConfig = ATProtocolConfiguration(
            pdsURL: serviceURL,
            keychainProtocol: keychain
        )
        
        // Register the user session in the registry so ATProtoKit can find it
        await UserSessionRegistry.shared.register(sessionConfig.instanceUUID, session: userSession)

        // Create ATProtoKit instance configured with the session
        let atproto = await ATProtoKit(
            sessionConfiguration: sessionConfig,
            pdsURL: serviceURL
        )

        // Execute the operation with the authenticated client
        let result = try await operation(atproto, sessionData.accessToken)
        
        // Clean up: remove the session from the registry after operation completes
        await UserSessionRegistry.shared.removeSession(for: sessionConfig.instanceUUID)
        
        return result
    }

    // MARK: - Profile Operations

    /// Get a profile by handle or DID
    public func getProfile(
        actor: String,
        session: BlueskySessionData
    ) async throws -> ATProtoProfile {
        try await withUserSession(session) { atproto, accessToken in
            // Get profile using the authenticated session
            let profile = try await atproto.getProfile(for: actor)

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
        }
    }

    // MARK: - Follow Operations

    /// Follow a user
    public func followUser(
        actor: String,
        session: BlueskySessionData
    ) async throws -> String {
        try await withUserSession(session) { atproto, accessToken in
            let atProtoBluesky = ATProtoBluesky(atProtoKitInstance: atproto)

            // Resolve handle to DID if needed
            let actorDID: String
            if actor.starts(with: "did:") {
                actorDID = actor
            } else {
                let profile = try await atproto.getProfile(for: actor)
                actorDID = profile.actorDID
            }

            // Create follow record
            let followRecord = try await atProtoBluesky.createFollowRecord(actorDID: actorDID)
            return followRecord.recordURI
        }
    }

    /// Unfollow a user
    public func unfollowUser(
        followRecordURI: String,
        session: BlueskySessionData
    ) async throws {
        try await withUserSession(session) { atproto, accessToken in
            // Parse AT URI
            let uriComponents = followRecordURI.replacingOccurrences(of: "at://", with: "").split(separator: "/")
            guard uriComponents.count == 3 else {
                throw ATProtoError.invalidURI(uri: followRecordURI)
            }

            let repo = String(uriComponents[0])
            let collection = String(uriComponents[1])
            let rkey = String(uriComponents[2])

            try await atproto.deleteRecord(
                repositoryDID: repo,
                collection: collection,
                recordKey: rkey
            )
        }
    }

    /// Get followers
    public func getFollowers(
        actor: String,
        limit: Int = 50,
        cursor: String? = nil,
        session: BlueskySessionData
    ) async throws -> ATProtoFollowersResponse {
        try await withUserSession(session) { atproto, accessToken in
            let response = try await atproto.getFollowers(by: actor, limit: limit, cursor: cursor)

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

            return ATProtoFollowersResponse(followers: followers, cursor: response.cursor)
        }
    }

    /// Get following
    public func getFollowing(
        actor: String,
        limit: Int = 50,
        cursor: String? = nil,
        session: BlueskySessionData
    ) async throws -> ATProtoFollowingResponse {
        try await withUserSession(session) { atproto, accessToken in
            let response = try await atproto.getFollows(from: actor, limit: limit, cursor: cursor)

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

            return ATProtoFollowingResponse(following: following, cursor: response.cursor)
        }
    }

    // MARK: - Search Operations

    /// Search for actors
    public func searchActors(
        query: String,
        limit: Int = 25,
        cursor: String? = nil,
        session: BlueskySessionData
    ) async throws -> ATProtoSearchResponse {
        try await withUserSession(session) { atproto, accessToken in
            let response = try await atproto.searchActors(
                matching: query,
                limit: limit,
                cursor: cursor
            )

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
        }
    }

    // MARK: - Feed Operations

    /// Get timeline feed (following feed)
    /// Returns posts from accounts the user follows via app.bsky.feed.getTimeline
    /// This is the equivalent of the Mastodon "home" timeline
    /// 
    /// Note: Bluesky's timeline may include algorithm-ranked content mixed with chronological posts
    /// This is intentional Bluesky behavior, not a bug in Archaeopteryx
    public func getTimeline(
        limit: Int = 50,
        cursor: String? = nil,
        session: BlueskySessionData
    ) async throws -> ATProtoFeedResponse {
        try await withUserSession(session) { atproto, accessToken in
            // ATProtoKit's getTimeline() calls app.bsky.feed.getTimeline
            // which returns posts from followed accounts (with potential algorithmic ranking)
            let response = try await atproto.getTimeline(limit: limit, cursor: cursor)

            let posts = try response.feed.compactMap { feedItem -> ATProtoPost? in
                try parsePostFromFeedItem(feedItem)
            }

            return ATProtoFeedResponse(posts: posts, cursor: response.cursor)
        }
    }

    /// Get author feed
    public func getAuthorFeed(
        actor: String,
        limit: Int = 50,
        cursor: String? = nil,
        filter: String? = nil,
        session: BlueskySessionData
    ) async throws -> ATProtoFeedResponse {
        try await withUserSession(session) { atproto, accessToken in
            let response = try await atproto.getAuthorFeed(
                by: actor,
                limit: limit,
                cursor: cursor,
                postFilter: nil
            )

            let posts = try response.feed.compactMap { feedItem -> ATProtoPost? in
                try parsePostFromFeedItem(feedItem)
            }

            return ATProtoFeedResponse(posts: posts, cursor: response.cursor)
        }
    }

    /// Get feed by URI (for lists/custom feeds)
    public func getFeed(
        feedURI: String,
        limit: Int = 50,
        cursor: String? = nil,
        session: BlueskySessionData
    ) async throws -> ATProtoFeedResponse {
        try await withUserSession(session) { atproto, accessToken in
            let response = try await atproto.getFeed(
                by: feedURI,
                limit: limit,
                cursor: cursor
            )

            let posts = try response.feed.compactMap { feedItem -> ATProtoPost? in
                try parsePostFromFeedItem(feedItem)
            }

            return ATProtoFeedResponse(posts: posts, cursor: response.cursor)
        }
    }

    // MARK: - Post Operations

    /// Get a single post by URI
    public func getPost(
        uri: String,
        session: BlueskySessionData
    ) async throws -> ATProtoPost {
        try await withUserSession(session) { atproto, accessToken in
            let thread = try await atproto.getPostThread(from: uri)

            // Extract the main thread post
            guard case .threadViewPost(let threadPost) = thread.thread else {
                throw ATProtoError.postNotFound(uri: uri)
            }

            let post = threadPost.post

            let author = ATProtoProfile(
                did: post.author.actorDID,
                handle: post.author.actorHandle,
                displayName: post.author.displayName,
                description: nil,
                avatar: post.author.avatarImageURL?.absoluteString,
                banner: nil,
                followersCount: 0,
                followsCount: 0,
                postsCount: 0,
                indexedAt: post.indexedAt.ISO8601Format()
            )

            let text = extractTextFromRecord(post.record) ?? ""
            let createdAt = extractCreatedAtFromRecord(post.record) ?? post.indexedAt.ISO8601Format()

            return ATProtoPost(
                uri: post.uri,
                cid: post.cid,
                author: author,
                text: text,
                facets: nil,
                embed: nil,
                replyTo: nil,
                replyRoot: nil,
                createdAt: createdAt,
                likeCount: post.likeCount ?? 0,
                repostCount: post.repostCount ?? 0,
                replyCount: post.replyCount ?? 0,
                quoteCount: post.quoteCount,
                isLiked: post.viewer?.likeURI != nil,
                isReposted: post.viewer?.repostURI != nil
            )
        }
    }

    /// Create a new post
    public func createPost(
        text: String,
        replyToURI: String? = nil,
        embedImages: [String]? = nil,
        embedExternal: [String: Any]? = nil,
        session: BlueskySessionData
    ) async throws -> ATProtoPost {
        try await withUserSession(session) { atproto, accessToken in
            let atProtoBluesky = ATProtoBluesky(atProtoKitInstance: atproto)

            // For now, simple text post (no replies or embeds)
            let postRecord = try await atProtoBluesky.createPostRecord(text: text)

            // Return a basic post representation
            // In a real implementation, we'd fetch the full post
            let author = ATProtoProfile(
                did: session.did,
                handle: session.handle,
                displayName: nil,
                description: nil,
                avatar: nil,
                banner: nil,
                followersCount: 0,
                followsCount: 0,
                postsCount: 0,
                indexedAt: nil
            )

            return ATProtoPost(
                uri: postRecord.recordURI,
                cid: postRecord.recordCID,
                author: author,
                text: text,
                facets: nil,
                embed: nil,
                replyTo: replyToURI,
                replyRoot: nil,
                createdAt: Date().ISO8601Format(),
                likeCount: 0,
                repostCount: 0,
                replyCount: 0,
                quoteCount: nil,
                isLiked: false,
                isReposted: false
            )
        }
    }

    /// Delete a post
    public func deletePost(
        uri: String,
        session: BlueskySessionData
    ) async throws {
        try await withUserSession(session) { atproto, accessToken in
            // Parse AT URI
            let uriComponents = uri.replacingOccurrences(of: "at://", with: "").split(separator: "/")
            guard uriComponents.count == 3 else {
                throw ATProtoError.invalidURI(uri: uri)
            }

            let repo = String(uriComponents[0])
            let collection = String(uriComponents[1])
            let rkey = String(uriComponents[2])

            try await atproto.deleteRecord(
                repositoryDID: repo,
                collection: collection,
                recordKey: rkey
            )
        }
    }

    /// Get post thread (ancestors and descendants)
    public func getPostThread(
        uri: String,
        depth: Int = 10,
        session: BlueskySessionData
    ) async throws -> ATProtoThreadResponse {
        try await withUserSession(session) { atproto, accessToken in
            // Get the main post first
            let post = try await self.getPost(uri: uri, session: session)

            // Parse thread - this is simplified for now
            // Real implementation would recursively parse the thread structure
            return ATProtoThreadResponse(
                post: post,
                parents: [],
                replies: []
            )
        }
    }

    /// Like a post
    public func likePost(
        uri: String,
        cid: String,
        session: BlueskySessionData
    ) async throws -> String {
        try await withUserSession(session) { atproto, accessToken in
            let atProtoBluesky = ATProtoBluesky(atProtoKitInstance: atproto)

            // Create strong reference
            let strongReference = ComAtprotoLexicon.Repository.StrongReference(
                recordURI: uri,
                cidHash: cid
            )

            let likeRecord = try await atProtoBluesky.createLikeRecord(strongReference)

            return likeRecord.recordURI
        }
    }

    /// Repost a post
    public func repost(
        uri: String,
        cid: String,
        session: BlueskySessionData
    ) async throws -> String {
        try await withUserSession(session) { atproto, accessToken in
            let atProtoBluesky = ATProtoBluesky(atProtoKitInstance: atproto)

            // Create strong reference
            let strongReference = ComAtprotoLexicon.Repository.StrongReference(
                recordURI: uri,
                cidHash: cid
            )

            let repostRecord = try await atProtoBluesky.createRepostRecord(strongReference)

            return repostRecord.recordURI
        }
    }

    /// Get users who liked a post
    public func getLikedBy(
        uri: String,
        limit: Int = 20,
        cursor: String? = nil,
        session: BlueskySessionData
    ) async throws -> ATProtoLikesResponse {
        try await withUserSession(session) { atproto, accessToken in
            let response = try await atproto.getLikes(from: uri, limit: limit, cursor: cursor)

            // Map likes to profiles - note: like.actor contains the profile
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
        }
    }

    /// Get users who reposted a post
    public func getRepostedBy(
        uri: String,
        limit: Int = 20,
        cursor: String? = nil,
        session: BlueskySessionData
    ) async throws -> ATProtoRepostsResponse {
        try await withUserSession(session) { atproto, accessToken in
            let response = try await atproto.getRepostedBy(
                uri,
                limit: limit,
                cursor: cursor
            )

            // Map reposts to profiles
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
        }
    }

    // MARK: - Notification Operations

    /// Get notifications
    public func getNotifications(
        limit: Int = 50,
        cursor: String? = nil,
        session: BlueskySessionData
    ) async throws -> ATProtoNotificationsResponse {
        try await withUserSession(session) { atproto, accessToken in
            let response = try await atproto.listNotifications(limit: limit, cursor: cursor)

            let notifications = response.notifications.compactMap { notification -> ATProtoNotification? in
                // Convert AT Proto notification to our format
                ATProtoNotification(
                    uri: notification.uri,
                    cid: notification.cid,
                    author: ATProtoProfile(
                        did: notification.author.actorDID,
                        handle: notification.author.actorHandle,
                        displayName: notification.author.displayName,
                        description: notification.author.description,
                        avatar: notification.author.avatarImageURL?.absoluteString,
                        banner: nil,
                        followersCount: 0,
                        followsCount: 0,
                        postsCount: 0,
                        indexedAt: nil
                    ),
                    reason: notification.reason.rawValue,
                    reasonSubject: nil, // ATProtoKit notification doesn't expose reasonSubject
                    record: nil,
                    isRead: notification.isRead,
                    indexedAt: notification.indexedAt.ISO8601Format()
                )
            }

            return ATProtoNotificationsResponse(
                notifications: notifications,
                cursor: response.cursor
            )
        }
    }

    /// Update seen notifications
    public func updateSeenNotifications(
        seenAt: Date = Date(),
        session: BlueskySessionData
    ) async throws {
        try await withUserSession(session) { atproto, accessToken in
            try await atproto.updateSeen(seenAt: seenAt)
        }
    }

    // MARK: - Helper Methods

    /// Parse post from feed item
    private func parsePostFromFeedItem(_ feedItem: AppBskyLexicon.Feed.FeedViewPostDefinition) throws -> ATProtoPost? {
        let post = feedItem.post

        let author = ATProtoProfile(
            did: post.author.actorDID,
            handle: post.author.actorHandle,
            displayName: post.author.displayName,
            description: nil,
            avatar: post.author.avatarImageURL?.absoluteString,
            banner: nil,
            followersCount: 0,
            followsCount: 0,
            postsCount: 0,
            indexedAt: post.indexedAt.ISO8601Format()
        )

        let text = extractTextFromRecord(post.record) ?? ""
        let createdAt = extractCreatedAtFromRecord(post.record) ?? post.indexedAt.ISO8601Format()
        
        // Parse facets from record
        let facets = extractFacetsFromRecord(post.record)
        
        // Parse embeds (images, external links, quote posts)
        let embed = parseEmbed(post.embed)
        
        // Parse reply info from record
        let (replyTo, replyRoot) = extractReplyFromRecord(post.record)
        
        // Check if this is a repost and extract repost information
        var repostedBy: ATProtoProfile? = nil
        if let reason = feedItem.reason, case .reasonRepost(let repostReason) = reason {
            repostedBy = ATProtoProfile(
                did: repostReason.by.actorDID,
                handle: repostReason.by.actorHandle,
                displayName: repostReason.by.displayName,
                description: nil,
                avatar: repostReason.by.avatarImageURL?.absoluteString,
                banner: nil,
                followersCount: 0,
                followsCount: 0,
                postsCount: 0,
                indexedAt: repostReason.indexedAt.ISO8601Format()
            )
        }

        return ATProtoPost(
            uri: post.uri,
            cid: post.cid,
            author: author,
            text: text,
            facets: facets,
            embed: embed,
            replyTo: replyTo,
            replyRoot: replyRoot,
            createdAt: createdAt,
            likeCount: post.likeCount ?? 0,
            repostCount: post.repostCount ?? 0,
            replyCount: post.replyCount ?? 0,
            quoteCount: post.quoteCount,
            isLiked: post.viewer?.likeURI != nil,
            isReposted: post.viewer?.repostURI != nil,
            repostedBy: repostedBy
        )
    }

    /// Extract text from UnknownType record
    private func extractTextFromRecord(_ record: UnknownType) -> String? {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(record)

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String {
                return text
            }
        } catch {
            // Silently fail
        }
        return nil
    }

    /// Extract createdAt from UnknownType record
    private func extractCreatedAtFromRecord(_ record: UnknownType) -> String? {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(record)

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let createdAt = json["createdAt"] as? String {
                return createdAt
            }
        } catch {
            // Silently fail
        }
        return nil
    }
    
    /// Extract facets from UnknownType record
    private func extractFacetsFromRecord(_ record: UnknownType) -> [ATProtoFacet]? {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(record)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let facetsArray = json["facets"] as? [[String: Any]] else {
                return nil
            }
            
            return facetsArray.compactMap { facetDict -> ATProtoFacet? in
                guard let indexDict = facetDict["index"] as? [String: Int],
                      let byteStart = indexDict["byteStart"],
                      let byteEnd = indexDict["byteEnd"],
                      let featuresArray = facetDict["features"] as? [[String: Any]] else {
                    return nil
                }
                
                let features = featuresArray.compactMap { featureDict -> ATProtoFeature? in
                    guard let type = featureDict["$type"] as? String else { return nil }
                    
                    switch type {
                    case "app.bsky.richtext.facet#link":
                        guard let uri = featureDict["uri"] as? String else { return nil }
                        return .link(uri: uri)
                    case "app.bsky.richtext.facet#mention":
                        guard let did = featureDict["did"] as? String else { return nil }
                        return .mention(did: did)
                    case "app.bsky.richtext.facet#tag":
                        guard let tag = featureDict["tag"] as? String else { return nil }
                        return .tag(tag: tag)
                    default:
                        return nil
                    }
                }
                
                guard !features.isEmpty else { return nil }
                
                return ATProtoFacet(
                    index: ATProtoByteSlice(byteStart: byteStart, byteEnd: byteEnd),
                    features: features
                )
            }
        } catch {
            return nil
        }
    }
    
    /// Parse embed from post
    private func parseEmbed(_ embedView: AppBskyLexicon.Feed.PostViewDefinition.EmbedUnion?) -> ATProtoEmbed? {
        guard let embedView = embedView else { return nil }

        switch embedView {
        case .embedImagesView(let imagesView):
            let images = imagesView.images.map { image in
                ATProtoImage(
                    url: image.fullSizeImageURL.absoluteString,
                    alt: image.altText,
                    aspectRatio: image.aspectRatio.map { aspectRatio in
                        ATProtoAspectRatio(width: aspectRatio.width, height: aspectRatio.height)
                    }
                )
            }
            return .images(images)

        case .embedExternalView(let externalView):
            return .external(ATProtoExternal(
                uri: externalView.external.uri,
                title: externalView.external.title,
                description: externalView.external.description,
                thumb: externalView.external.thumbnailImageURL?.absoluteString
            ))

        case .embedRecordView(let recordView):
            // Handle the different cases of RecordViewUnion
            switch recordView.record {
            case .viewRecord(let viewRecord):
                return .record(ATProtoRecordEmbed(uri: viewRecord.uri, cid: viewRecord.cid))
            default:
                return nil
            }

        case .embedRecordWithMediaView(let recordWithMedia):
            // Handle the different cases of RecordViewUnion
            switch recordWithMedia.record.record {
            case .viewRecord(let viewRecord):
                return .record(ATProtoRecordEmbed(uri: viewRecord.uri, cid: viewRecord.cid))
            default:
                return nil
            }

        case .embedVideoView:
            // TODO: Handle video embeds when fully supported
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    /// Extract reply information from record
    private func extractReplyFromRecord(_ record: UnknownType) -> (replyTo: String?, replyRoot: String?) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(record)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let replyDict = json["reply"] as? [String: Any] else {
                return (nil, nil)
            }
            
            var replyTo: String?
            var replyRoot: String?
            
            if let parentDict = replyDict["parent"] as? [String: Any],
               let parentURI = parentDict["uri"] as? String {
                replyTo = parentURI
            }
            
            if let rootDict = replyDict["root"] as? [String: Any],
               let rootURI = rootDict["uri"] as? String {
                replyRoot = rootURI
            }
            
            return (replyTo, replyRoot)
        } catch {
            return (nil, nil)
        }
    }
}
