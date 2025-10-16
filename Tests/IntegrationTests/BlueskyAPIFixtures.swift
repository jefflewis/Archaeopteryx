import Foundation

/// Mock Bluesky API responses based on official API documentation
enum BlueskyAPIFixtures {
    // MARK: - Session Management

    /// Response from com.atproto.server.createSession
    /// JWT tokens are properly formatted with header.payload.signature structure
    static let createSessionResponse = """
    {
      "did": "did:plc:test123456",
      "handle": "test.bsky.social",
      "email": "test@example.com",
      "accessJwt": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkaWQiOiJkaWQ6cGxjOnRlc3QxMjM0NTYiLCJhdWQiOiJkaWQ6d2ViOmJza3kuc29jaWFsIiwiaWF0IjoxNzA1MzE1MjAwLCJleHAiOjE3MDUzMTg4MDB9.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      "refreshJwt": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkaWQiOiJkaWQ6cGxjOnRlc3QxMjM0NTYiLCJhdWQiOiJkaWQ6d2ViOmJza3kuc29jaWFsIiwiaWF0IjoxNzA1MzE1MjAwLCJleHAiOjE3MDU5MjAwMDB9.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    }
    """.data(using: .utf8)!

    /// Response from com.atproto.server.refreshSession
    static let refreshSessionResponse = """
    {
      "did": "did:plc:test123456",
      "handle": "test.bsky.social",
      "accessJwt": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.new-access",
      "refreshJwt": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.new-refresh"
    }
    """.data(using: .utf8)!

    // MARK: - Profile Operations

    /// Response from app.bsky.actor.getProfile
    static let getProfileResponse = """
    {
      "did": "did:plc:test123456",
      "handle": "test.bsky.social",
      "displayName": "Test User",
      "description": "This is a test account for integration testing",
      "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:test123456/abc@jpeg",
      "banner": "https://cdn.bsky.app/img/banner/plain/did:plc:test123456/def@jpeg",
      "followersCount": 42,
      "followsCount": 100,
      "postsCount": 256,
      "indexedAt": "2025-01-15T12:00:00.000Z",
      "createdAt": "2024-01-01T00:00:00.000Z",
      "labels": []
    }
    """.data(using: .utf8)!

    /// Response from app.bsky.actor.searchActors
    static let searchActorsResponse = """
    {
      "actors": [
        {
          "did": "did:plc:user1",
          "handle": "alice.bsky.social",
          "displayName": "Alice",
          "description": "Software engineer",
          "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:user1/abc@jpeg",
          "indexedAt": "2025-01-15T12:00:00.000Z"
        },
        {
          "did": "did:plc:user2",
          "handle": "bob.bsky.social",
          "displayName": "Bob",
          "description": "Designer",
          "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:user2/def@jpeg",
          "indexedAt": "2025-01-15T12:01:00.000Z"
        }
      ],
      "cursor": "next_page_cursor"
    }
    """.data(using: .utf8)!

    // MARK: - Follow Operations

    /// Response from app.bsky.graph.getFollowers
    static let getFollowersResponse = """
    {
      "subject": {
        "did": "did:plc:test123456",
        "handle": "test.bsky.social",
        "displayName": "Test User"
      },
      "followers": [
        {
          "did": "did:plc:follower1",
          "handle": "follower1.bsky.social",
          "displayName": "Follower One",
          "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:follower1/abc@jpeg",
          "indexedAt": "2025-01-14T10:00:00.000Z"
        },
        {
          "did": "did:plc:follower2",
          "handle": "follower2.bsky.social",
          "displayName": "Follower Two",
          "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:follower2/def@jpeg",
          "indexedAt": "2025-01-14T11:00:00.000Z"
        }
      ],
      "cursor": "followers_cursor"
    }
    """.data(using: .utf8)!

    /// Response from app.bsky.graph.getFollows
    static let getFollowsResponse = """
    {
      "subject": {
        "did": "did:plc:test123456",
        "handle": "test.bsky.social",
        "displayName": "Test User"
      },
      "follows": [
        {
          "did": "did:plc:following1",
          "handle": "following1.bsky.social",
          "displayName": "Following One",
          "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:following1/abc@jpeg",
          "indexedAt": "2025-01-13T10:00:00.000Z"
        }
      ],
      "cursor": "follows_cursor"
    }
    """.data(using: .utf8)!

    // MARK: - Feed Operations

    /// Response from app.bsky.feed.getTimeline
    static let getTimelineResponse = """
    {
      "feed": [
        {
          "post": {
            "uri": "at://did:plc:author1/app.bsky.feed.post/abc123",
            "cid": "bafyreicid123",
            "author": {
              "did": "did:plc:author1",
              "handle": "author1.bsky.social",
              "displayName": "Author One",
              "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:author1/abc@jpeg"
            },
            "record": {
              "$type": "app.bsky.feed.post",
              "text": "Hello from the timeline!",
              "createdAt": "2025-01-15T10:00:00.000Z"
            },
            "indexedAt": "2025-01-15T10:00:01.000Z",
            "likeCount": 5,
            "repostCount": 2,
            "replyCount": 1
          }
        },
        {
          "post": {
            "uri": "at://did:plc:author2/app.bsky.feed.post/def456",
            "cid": "bafyreicid456",
            "author": {
              "did": "did:plc:author2",
              "handle": "author2.bsky.social",
              "displayName": "Author Two",
              "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:author2/def@jpeg"
            },
            "record": {
              "$type": "app.bsky.feed.post",
              "text": "Another post in the feed",
              "createdAt": "2025-01-15T09:00:00.000Z"
            },
            "indexedAt": "2025-01-15T09:00:01.000Z",
            "likeCount": 10,
            "repostCount": 3,
            "replyCount": 2
          }
        }
      ],
      "cursor": "timeline_cursor"
    }
    """.data(using: .utf8)!

    /// Response from app.bsky.feed.getAuthorFeed
    static let getAuthorFeedResponse = """
    {
      "feed": [
        {
          "post": {
            "uri": "at://did:plc:test123456/app.bsky.feed.post/post1",
            "cid": "bafyreicid789",
            "author": {
              "did": "did:plc:test123456",
              "handle": "test.bsky.social",
              "displayName": "Test User",
              "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:test123456/abc@jpeg"
            },
            "record": {
              "$type": "app.bsky.feed.post",
              "text": "My first post",
              "createdAt": "2025-01-14T10:00:00.000Z"
            },
            "indexedAt": "2025-01-14T10:00:01.000Z",
            "likeCount": 15,
            "repostCount": 5,
            "replyCount": 3
          }
        }
      ],
      "cursor": "author_feed_cursor"
    }
    """.data(using: .utf8)!

    /// Response from app.bsky.feed.getPostThread
    static let getPostThreadResponse = """
    {
      "thread": {
        "$type": "app.bsky.feed.defs#threadViewPost",
        "post": {
          "uri": "at://did:plc:test123456/app.bsky.feed.post/newpost123",
          "cid": "bafyreicidnewpost",
          "author": {
            "did": "did:plc:test123456",
            "handle": "test.bsky.social",
            "displayName": "Test User",
            "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:test123456/abc@jpeg"
          },
          "record": {
            "$type": "app.bsky.feed.post",
            "text": "Hello World!",
            "createdAt": "2025-01-15T12:00:00.000Z"
          },
          "indexedAt": "2025-01-15T12:00:01.000Z",
          "likeCount": 25,
          "repostCount": 8,
          "replyCount": 5
        },
        "replies": []
      }
    }
    """.data(using: .utf8)!

    // MARK: - Post Operations

    /// Response from com.atproto.repo.createRecord (create post)
    static let createPostResponse = """
    {
      "uri": "at://did:plc:test123456/app.bsky.feed.post/newpost123",
      "cid": "bafyreicidnewpost"
    }
    """.data(using: .utf8)!

    /// Response from app.bsky.feed.post.like (like post)
    static let likePostResponse = """
    {
      "uri": "at://did:plc:test123456/app.bsky.feed.like/like123",
      "cid": "bafyreicidlike"
    }
    """.data(using: .utf8)!

    /// Response from app.bsky.feed.getLikes
    static let getLikesResponse = """
    {
      "uri": "at://did:plc:test123456/app.bsky.feed.post/post1",
      "likes": [
        {
          "createdAt": "2025-01-15T10:00:00.000Z",
          "indexedAt": "2025-01-15T10:00:01.000Z",
          "actor": {
            "did": "did:plc:liker1",
            "handle": "liker1.bsky.social",
            "displayName": "Liker One",
            "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:liker1/abc@jpeg"
          }
        }
      ],
      "cursor": "likes_cursor"
    }
    """.data(using: .utf8)!

    // MARK: - Notification Operations

    /// Response from app.bsky.notification.listNotifications
    static let listNotificationsResponse = """
    {
      "notifications": [
        {
          "uri": "at://did:plc:test123456/app.bsky.feed.post/post1",
          "cid": "bafyreicidnotif1",
          "author": {
            "did": "did:plc:liker1",
            "handle": "liker1.bsky.social",
            "displayName": "Liker One",
            "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:liker1/abc@jpeg",
            "description": "I like things"
          },
          "reason": "like",
          "reasonSubject": "at://did:plc:test123456/app.bsky.feed.post/post1",
          "record": {
            "$type": "app.bsky.feed.like"
          },
          "isRead": false,
          "indexedAt": "2025-01-15T11:00:00.000Z"
        },
        {
          "uri": "at://did:plc:follower1/app.bsky.graph.follow/follow123",
          "cid": "bafyreicidnotif2",
          "author": {
            "did": "did:plc:follower1",
            "handle": "follower1.bsky.social",
            "displayName": "Follower One",
            "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:follower1/abc@jpeg",
            "description": "New follower"
          },
          "reason": "follow",
          "record": {
            "$type": "app.bsky.graph.follow"
          },
          "isRead": false,
          "indexedAt": "2025-01-15T10:30:00.000Z"
        }
      ],
      "cursor": "notifications_cursor"
    }
    """.data(using: .utf8)!

    /// Response from app.bsky.notification.getUnreadCount
    static let getUnreadCountResponse = """
    {
      "count": 5
    }
    """.data(using: .utf8)!

    // MARK: - Repost/Reblog Operations

    /// Response from app.bsky.feed.getRepostedBy
    static let getRepostedByResponse = """
    {
      "uri": "at://did:plc:test123456/app.bsky.feed.post/post1",
      "repostedBy": [
        {
          "did": "did:plc:reposter1",
          "handle": "reposter1.bsky.social",
          "displayName": "Reposter One",
          "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:reposter1/abc@jpeg"
        }
      ],
      "cursor": "reposts_cursor"
    }
    """.data(using: .utf8)!

    /// Response from com.atproto.repo.createRecord (repost)
    static let repostResponse = """
    {
      "uri": "at://did:plc:test123456/app.bsky.feed.repost/repost123",
      "cid": "bafyreicidrepost"
    }
    """.data(using: .utf8)!

    // MARK: - Follow Operations (Record creation)

    /// Response from com.atproto.repo.createRecord (follow)
    static let createFollowResponse = """
    {
      "uri": "at://did:plc:test123456/app.bsky.graph.follow/follow123",
      "cid": "bafyreicidfollow"
    }
    """.data(using: .utf8)!

    // MARK: - Blob/Media Operations

    /// Response from com.atproto.repo.uploadBlob
    static let uploadBlobResponse = """
    {
      "blob": {
        "$type": "blob",
        "ref": {
          "$link": "bafkreiblobhash123"
        },
        "mimeType": "image/jpeg",
        "size": 123456
      }
    }
    """.data(using: .utf8)!

    // MARK: - List/Feed Operations

    /// Response from app.bsky.feed.getFeed
    static let getFeedResponse = """
    {
      "feed": [
        {
          "post": {
            "uri": "at://did:plc:author1/app.bsky.feed.post/feedpost1",
            "cid": "bafyrecidfeed1",
            "author": {
              "did": "did:plc:author1",
              "handle": "author1.bsky.social",
              "displayName": "Feed Author",
              "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:author1/abc@jpeg"
            },
            "record": {
              "$type": "app.bsky.feed.post",
              "text": "Post from custom feed",
              "createdAt": "2025-01-15T10:00:00.000Z"
            },
            "indexedAt": "2025-01-15T10:00:01.000Z",
            "likeCount": 20,
            "repostCount": 5,
            "replyCount": 3
          }
        }
      ],
      "cursor": "feed_cursor"
    }
    """.data(using: .utf8)!

    /// Response from app.bsky.graph.getList (for lists functionality)
    static let getListResponse = """
    {
      "list": {
        "uri": "at://did:plc:test123456/app.bsky.graph.list/list1",
        "cid": "bafyreicidlist",
        "name": "My Favorite People",
        "purpose": "app.bsky.graph.defs#curatelist",
        "description": "People I follow closely",
        "creator": {
          "did": "did:plc:test123456",
          "handle": "test.bsky.social",
          "displayName": "Test User"
        },
        "indexedAt": "2025-01-15T10:00:00.000Z"
      },
      "items": [
        {
          "uri": "at://did:plc:test123456/app.bsky.graph.listitem/item1",
          "subject": {
            "did": "did:plc:member1",
            "handle": "member1.bsky.social",
            "displayName": "List Member One",
            "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:member1/abc@jpeg"
          }
        }
      ],
      "cursor": "list_cursor"
    }
    """.data(using: .utf8)!

    /// Response from app.bsky.graph.getLists (user's lists)
    static let getListsResponse = """
    {
      "lists": [
        {
          "uri": "at://did:plc:test123456/app.bsky.graph.list/list1",
          "cid": "bafyreicidlist1",
          "name": "Tech People",
          "purpose": "app.bsky.graph.defs#curatelist",
          "creator": {
            "did": "did:plc:test123456",
            "handle": "test.bsky.social",
            "displayName": "Test User"
          },
          "indexedAt": "2025-01-15T10:00:00.000Z"
        }
      ],
      "cursor": "lists_cursor"
    }
    """.data(using: .utf8)!

    // MARK: - Relationship Operations

    /// Response for getting multiple relationships
    static let getRelationshipsResponse = """
    [
      {
        "did": "did:plc:user1",
        "following": "at://did:plc:test123456/app.bsky.graph.follow/follow1",
        "followedBy": "at://did:plc:user1/app.bsky.graph.follow/follow2"
      },
      {
        "did": "did:plc:user2",
        "following": null,
        "followedBy": null
      }
    ]
    """.data(using: .utf8)!

    // MARK: - Error Responses

    /// Unauthorized error (401)
    static let unauthorizedError = """
    {
      "error": "AuthenticationRequired",
      "message": "Invalid or expired token"
    }
    """.data(using: .utf8)!

    /// Not found error (404)
    static let notFoundError = """
    {
      "error": "RecordNotFound",
      "message": "The requested resource was not found"
    }
    """.data(using: .utf8)!

    /// Rate limit error (429)
    static let rateLimitError = """
    {
      "error": "RateLimitExceeded",
      "message": "Too many requests"
    }
    """.data(using: .utf8)!
}
