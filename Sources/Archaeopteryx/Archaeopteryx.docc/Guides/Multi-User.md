# Multi-User Support

How Archaeopteryx handles multiple concurrent users with session isolation.

## Overview

Archaeopteryx supports **multiple concurrent users**, each with their own isolated Bluesky session. Sessions are stored in Redis/Valkey, enabling stateless, horizontally-scalable deployments.

## Architecture

### Session Flow

```
User A Login → Bluesky Session A → Stored in Redis → Token A
User B Login → Bluesky Session B → Stored in Redis → Token B

Request with Token A → Retrieve Session A → Use Session A for AT Proto calls
Request with Token B → Retrieve Session B → Use Session B for AT Proto calls
```

### Key Components

**UserContext** - Contains user identity and session data:

```swift
struct UserContext {
    let did: String                      // User's DID
    let handle: String                   // User's handle
    let sessionData: BlueskySessionData  // User's session
}
```

**BlueskySessionData** - Stored in Redis:

```swift
struct BlueskySessionData {
    let accessToken: String    // AT Proto access token
    let refreshToken: String   // AT Proto refresh token
    let did: String           // User's DID
    let handle: String        // User's handle
    let createdAt: Date       // Session creation time
}
```

**SessionScopedClient** - Executes AT Proto operations with user-specific sessions:

```swift
actor SessionScopedClient {
    func getProfile(actor: String, session: BlueskySessionData) async throws -> ATProtoProfile
    func followUser(actor: String, session: BlueskySessionData) async throws -> String
    func getTimeline(limit: Int, cursor: String?, session: BlueskySessionData) async throws -> ATProtoFeedResponse
}
```

## OAuth Flow

### 1. User Logs In

```http
POST /oauth/token
{
  "grant_type": "password",
  "username": "alice.bsky.social",
  "password": "app-password",
  "client_id": "...",
  "client_secret": "..."
}
```

Archaeopteryx:
1. Creates real Bluesky session via AT Protocol
2. Stores session data in Redis
3. Returns OAuth token

### 2. Authenticated Requests

```http
GET /api/v1/accounts/verify_credentials
Authorization: Bearer token_A
```

Archaeopteryx:
1. Validates token
2. Retrieves user's session from Redis
3. Uses session for AT Proto call
4. Returns response

### 3. Session Storage

Redis keys:

```
oauth:token:{token} → TokenData {
    did, handle, sessionData, scope
}

session:{did} → BlueskySessionData {
    accessToken, refreshToken, ...
}
```

TTL: 7 days

## Benefits

### True Multi-Tenant

- Multiple users can use the bridge simultaneously
- Each user has isolated Bluesky session
- No cross-user data leakage

### Scalable

- Session data in distributed cache (Redis/Valkey)
- Stateless server instances
- Horizontal scaling supported

### Secure

- Each token maps to specific user session
- Session isolation prevents unauthorized access
- Proper ownership validation

## Implementation Details

### Route Pattern

All authenticated routes follow this pattern:

```swift
// 1. Validate token and get user context
let userContext = try await oauthService.validateToken(token)

// 2. Use session-scoped client
let profile = try await sessionClient.getProfile(
    actor: userContext.did,
    session: userContext.sessionData
)

// 3. Return response
return profile
```

### Session Refresh

Sessions expire after a period. Refresh logic:

1. Check if access token expired
2. Use refresh token to get new access token
3. Update session in Redis
4. Continue request

## Testing

Multi-user isolation is tested:

```swift
// Test: Different tokens return different user contexts
func testMultiUserIsolation() async throws {
    let contextA = try await oauthService.validateToken(tokenA)
    let contextB = try await oauthService.validateToken(tokenB)

    XCTAssertNotEqual(contextA.did, contextB.did)
    XCTAssertNotEqual(contextA.sessionData, contextB.sessionData)
}
```

## Deployment Considerations

### Redis Requirements

- Must be shared across all server instances
- Recommend Redis/Valkey with persistence enabled
- Consider Redis Cluster for high availability

### Session Security

- Sessions stored with encryption at rest (Redis TLS)
- Use secure Redis passwords
- Enable Redis AUTH

### Performance

- Redis lookups are fast (~1ms)
- Session data cached in memory where possible
- No significant overhead per request

## Limitations

### Session Expiry

- Sessions expire after 7 days by default
- Users must re-authenticate when expired
- No automatic session refresh yet (planned)

### ATProtoKit Integration

- ATProtoKit doesn't expose session injection
- We create new instances per request
- Performance impact minimal but not ideal

## Future Improvements

- Automatic session refresh before expiry
- Session pooling for performance
- WebSocket support for real-time updates per user
- Session analytics and monitoring

## See Also

- <doc:Getting-Started> - Run Archaeopteryx locally
- <doc:Fly-Deployment> - Deploy to production
- <doc:API-Reference> - OAuth endpoints
- Complete implementation details: `MULTI_USER_IMPLEMENTATION.md` in repository
