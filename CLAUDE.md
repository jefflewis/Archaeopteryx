# Archaeopteryx Development Guide for Claude

This document provides architectural guidelines, coding practices, and high-level responsibilities for the Archaeopteryx project. Use this as a reference when working on the codebase.

---

## Project Overview

**Archaeopteryx** is a Bluesky-to-Mastodon API compatibility bridge written in Swift. It translates Mastodon API calls to AT Protocol (Bluesky) calls, allowing existing Mastodon client applications to connect to Bluesky without modification.

**Key Technologies**:
- **Language**: Swift 6.0
- **Web Framework**: Hummingbird 2.0
- **Cache**: RediStack (Valkey/Redis)
- **AT Protocol SDK**: ATProtoKit
- **Methodology**: Test-Driven Development (TDD)

---

## Architecture: Multi-Package Monorepo

The project is organized as a monorepo with multiple Swift packages for modularity, testability, and reusability.

### Directory Structure

```
Archaeopteryx/
├── Package.swift                      # Package manifest (defines all targets)
├── IMPLEMENTATION_PLAN.md             # Detailed implementation roadmap
├── CLAUDE.md                          # This file
├── Sources/
│   ├── Archaeopteryx/                 # Main executable (HTTP server, routing)
│   │   ├── App.swift                  # Application entry point
│   │   ├── Routes/                    # API endpoint handlers
│   │   └── Middleware/                # Request/response middleware
│   │
│   ├── ArchaeopteryxCore/             # Core types, protocols, utilities
│   │   ├── ArchaeopteryxError.swift   # Common error types
│   │   ├── Configuration.swift        # App configuration
│   │   ├── Protocols/                 # Shared protocols
│   │   └── Extensions/                # Foundation extensions
│   │
│   ├── MastodonModels/                # Mastodon API data models
│   │   ├── MastodonAccount.swift
│   │   ├── MastodonStatus.swift
│   │   ├── MastodonNotification.swift
│   │   ├── MastodonRelationship.swift
│   │   ├── MastodonList.swift
│   │   ├── Instance.swift
│   │   └── OAuth.swift
│   │
│   ├── IDMapping/                     # ID generation and mapping
│   │   ├── SnowflakeIDGenerator.swift # Twitter-style 64-bit IDs
│   │   └── IDMappingService.swift     # DID ↔ Snowflake mapping
│   │
│   ├── CacheLayer/                    # Cache abstraction
│   │   ├── CacheService.swift         # Protocol
│   │   ├── ValkeyCache.swift          # Redis/Valkey impl
│   │   └── InMemoryCache.swift        # Test mock
│   │
│   ├── ATProtoAdapter/                # AT Protocol client wrapper
│   │   ├── ATProtoClient.swift        # Convenience methods
│   │   ├── SessionManager.swift       # Session handling
│   │   └── ATProtoError.swift         # Error mapping
│   │
│   ├── TranslationLayer/              # Bluesky ↔ Mastodon translation
│   │   ├── TranslationService.swift   # Main translator
│   │   ├── FacetProcessor.swift       # Rich text → HTML
│   │   ├── ProfileTranslator.swift    # Profile conversion
│   │   └── StatusTranslator.swift     # Post conversion
│   │
│   └── OAuthService/                  # OAuth 2.0 implementation
│       ├── OAuthService.swift         # OAuth flow logic
│       ├── TokenManager.swift         # Token lifecycle
│       └── ScopeValidator.swift       # Scope handling
│
└── Tests/                             # Mirror structure of Sources/
    ├── ArchaeopteryxTests/
    ├── ArchaeopteryxCoreTests/
    ├── MastodonModelsTests/
    ├── IDMappingTests/
    ├── CacheLayerTests/
    ├── ATProtoAdapterTests/
    ├── TranslationLayerTests/
    └── OAuthServiceTests/
```

---

## Package Responsibilities

### 1. **ArchaeopteryxCore** (Foundation)
**Purpose**: Shared types, protocols, and utilities used across all packages

**Responsibilities**:
- Define common error types (`ArchaeopteryxError`)
- Configuration management (environment variables, config files)
- Shared protocols (`Cacheable`, `Translatable`, `Identifiable`)
- Foundation extensions (Date, String, etc.)
- Logging utilities

**Dependencies**: Foundation only

**Key Principle**: No business logic. Pure utilities and infrastructure.

---

### 2. **MastodonModels** (Data Models)
**Purpose**: Mastodon API data models compliant with official spec

**Responsibilities**:
- Define all Mastodon API response types
- JSON encoding/decoding with snake_case conversion
- Equatable/Hashable/Sendable conformance
- Documentation of field meanings

**Dependencies**: ArchaeopteryxCore

**Key Principle**: Models should be dumb data containers with no logic beyond serialization.

---

### 3. **IDMapping** (Service)
**Purpose**: Generate and map identifiers between systems

**Responsibilities**:
- Generate time-sortable Snowflake IDs (64-bit, Twitter-style)
- Deterministically map Bluesky DIDs → Snowflake IDs (via hash)
- Bidirectional lookup (DID ↔ Snowflake, AT URI ↔ Snowflake)
- Handle resolution (handle → DID → Snowflake)
- Cache mappings for performance

**Dependencies**: ArchaeopteryxCore, CryptoKit

**Key Principle**: IDs must be deterministic and stable across restarts.

---

### 4. **CacheLayer** (Service)
**Purpose**: Abstract cache interface with multiple implementations

**Responsibilities**:
- Define `CacheService` protocol
- Implement Valkey/Redis cache (production)
- Implement in-memory cache (testing)
- Handle serialization/deserialization
- Manage TTLs and expiration
- Connection pooling and error recovery

**Dependencies**: ArchaeopteryxCore, RediStack

**Key Principle**: Always code against `CacheService` protocol, not concrete types.

---

### 5. **ATProtoAdapter** (Integration)
**Purpose**: Wrapper around ATProtoKit with convenience methods

**Responsibilities**:
- Session management (login, refresh, storage)
- Profile retrieval (by handle or DID)
- Post operations (create, delete, like, repost)
- Feed operations (timeline, user posts)
- Follow operations
- Notification retrieval
- Error mapping (AT Protocol → internal errors)

**Dependencies**: ArchaeopteryxCore, CacheLayer, ATProtoKit

**Key Principle**: Hide ATProtoKit complexity. Present clean, focused API to translation layer.

---

### 6. **TranslationLayer** (Service)
**Purpose**: Translate between Bluesky and Mastodon formats

**Responsibilities**:
- Convert AT Protocol profiles → MastodonAccount
- Convert AT Protocol posts → MastodonStatus
- Convert AT Protocol notifications → MastodonNotification
- Process rich text facets → HTML
- Handle mentions, links, hashtags
- Map visibility settings
- Provide fallbacks for missing fields
- Extract and translate embedded media

**Dependencies**: ArchaeopteryxCore, MastodonModels, ATProtoAdapter, IDMapping

**Key Principle**: Translations should be pure functions. No side effects.

---

### 7. **OAuthService** (Service)
**Purpose**: OAuth 2.0 flow for Mastodon API compatibility

**Responsibilities**:
- App registration (generate client credentials)
- Authorization code generation
- Token exchange (code → access token)
- Token validation and refresh
- Token revocation
- Scope validation and mapping
- Store tokens securely in cache

**Dependencies**: ArchaeopteryxCore, MastodonModels, CacheLayer, ATProtoAdapter, CryptoKit

**Key Principle**: OAuth tokens are just wrappers around Bluesky sessions.

---

### 8. **Archaeopteryx** (Main App)
**Purpose**: HTTP server, routing, middleware orchestration

**Responsibilities**:
- Start HTTP server (Hummingbird)
- Define all API routes
- Apply middleware (auth, rate limiting, logging, errors)
- Orchestrate calls to services
- Return properly formatted responses
- Handle HTTP-specific concerns (status codes, headers)

**Routes**:
- `/api/v1/accounts/*` - Account operations
- `/api/v1/statuses/*` - Post operations
- `/api/v1/timelines/*` - Timeline feeds
- `/api/v1/notifications` - Notifications
- `/api/v1/media` - Media uploads
- `/api/v2/search` - Search
- `/api/v1/lists/*` - Lists (Bluesky feeds)
- `/api/v1/instance` - Instance metadata
- `/oauth/*` - OAuth flow
- `/api/v1/apps` - App registration

**Middleware**:
- `AuthMiddleware` - Extract and validate bearer tokens
- `RateLimitMiddleware` - Prevent abuse
- `LoggingMiddleware` - Request/response logging
- `ErrorMiddleware` - Global error handling

**Dependencies**: All other packages + Hummingbird

**Key Principle**: Routes should be thin. Delegate logic to services.

---

## Coding Practices

### Test-Driven Development (TDD)

**Mandatory workflow for all new code**:

1. **RED**: Write a failing test
   ```swift
   func testGetProfile_ValidHandle_ReturnsProfile() async throws {
       let client = ATProtoClient(config: testConfig)
       let profile = try await client.getProfile(handle: "test.bsky.social")
       XCTAssertEqual(profile.handle, "test.bsky.social")
       XCTAssertNotNil(profile.displayName)
   }
   ```

2. **GREEN**: Write minimal code to pass
   ```swift
   func getProfile(handle: String) async throws -> Profile {
       // Simplest possible implementation
       return try await atProtoKit.getProfile(actor: handle)
   }
   ```

3. **REFACTOR**: Clean up while keeping tests green
   ```swift
   func getProfile(handle: String) async throws -> Profile {
       // Check cache first
       if let cached = await cache.getProfile(forHandle: handle) {
           return cached
       }

       // Fetch from API
       let profile = try await atProtoKit.getProfile(actor: handle)

       // Cache for 15 minutes
       await cache.setProfile(profile, forHandle: handle, ttl: 900)

       return profile
   }
   ```

4. **REPEAT**: Add next test

**Test Naming Convention**:
```swift
func test{Component}_{Condition}_{ExpectedBehavior}()

// Examples:
func testGetAccount_ValidID_ReturnsAccount()
func testGetAccount_InvalidID_ThrowsNotFoundError()
func testCreateStatus_NoAuth_Returns401()
```

---

### Swift Best Practices

#### Use Swift 6.0 Concurrency

**Good**:
```swift
actor IDMappingService {
    private var cache: [String: Int64] = [:]

    func getSnowflake(forDID did: String) async -> Int64? {
        return cache[did]
    }
}
```

**Bad**:
```swift
class IDMappingService {
    private var cache: [String: Int64] = [:]
    private let lock = NSLock()

    func getSnowflake(forDID did: String) -> Int64? {
        lock.lock()
        defer { lock.unlock() }
        return cache[did]
    }
}
```

#### Explicit Error Handling

**Good**:
```swift
enum ATProtoError: Error {
    case sessionExpired
    case networkError(underlying: Error)
    case invalidResponse(statusCode: Int)
    case rateLimited(retryAfter: TimeInterval)
}

func getProfile(handle: String) async throws -> Profile {
    do {
        return try await atProtoKit.getProfile(actor: handle)
    } catch let error as NetworkError {
        throw ATProtoError.networkError(underlying: error)
    }
}
```

**Bad**:
```swift
func getProfile(handle: String) async throws -> Profile {
    return try await atProtoKit.getProfile(actor: handle)
    // Errors bubble up raw - hard to handle
}
```

#### Protocol-Oriented Design

**Good**:
```swift
protocol CacheService: Actor {
    func get<T: Codable>(_ key: String) async throws -> T?
    func set<T: Codable>(_ key: String, value: T, ttl: Int?) async throws
    func delete(_ key: String) async throws
}

actor ValkeyCache: CacheService {
    // Implementation
}

actor InMemoryCache: CacheService {
    // Implementation
}
```

**Bad**:
```swift
actor ValkeyCache {
    func get(_ key: String) async throws -> Data? { }
    func set(_ key: String, value: Data) async throws { }
}

// Hard to swap implementations or mock
```

#### Dependency Injection

**Good**:
```swift
struct TranslationService {
    private let idMapping: IDMappingService
    private let facetProcessor: FacetProcessor

    init(idMapping: IDMappingService, facetProcessor: FacetProcessor) {
        self.idMapping = idMapping
        self.facetProcessor = facetProcessor
    }
}
```

**Bad**:
```swift
struct TranslationService {
    private let idMapping = IDMappingService()
    private let facetProcessor = FacetProcessor()
    // Hard to test with mocks
}
```

---

### Package Import Rules

Each package should only import what it needs:

```swift
// ArchaeopteryxCore - No external imports
import Foundation

// MastodonModels
import Foundation
import ArchaeopteryxCore

// IDMapping
import Foundation
import CryptoKit
import ArchaeopteryxCore

// CacheLayer
import Foundation
import RediStack
import ArchaeopteryxCore

// ATProtoAdapter
import Foundation
import ATProtoKit
import ArchaeopteryxCore
import CacheLayer

// TranslationLayer
import Foundation
import ArchaeopteryxCore
import MastodonModels
import ATProtoAdapter
import IDMapping

// OAuthService
import Foundation
import CryptoKit
import ArchaeopteryxCore
import MastodonModels
import CacheLayer
import ATProtoAdapter

// Archaeopteryx (main)
import Hummingbird
import Logging
import ArchaeopteryxCore
import MastodonModels
import ATProtoAdapter
import TranslationLayer
import CacheLayer
import IDMapping
import OAuthService
```

**Rule**: Never import a package you don't need. Keep dependencies minimal.

---

## ID Mapping Strategy

### Problem
Mastodon uses Snowflake IDs (Int64). Bluesky uses DIDs (strings) and AT URIs.

### Solution
```
DID (did:plc:abc123)
    ↓ (deterministic hash)
Snowflake ID (1234567890)
    ↓ (cached mapping)
DID (did:plc:abc123)
```

**Implementation**:
1. Hash DID using SHA-256
2. Take first 8 bytes → Int64
3. Store mapping in cache (never expires, deterministic)
4. For AT URIs, generate new Snowflake IDs (time-based)

**Cache Keys**:
```
did_to_snowflake:{did} → snowflake_id
snowflake_to_did:{snowflake_id} → did
at_uri_to_snowflake:{at_uri} → snowflake_id
snowflake_to_at_uri:{snowflake_id} → at_uri
```

---

## Translation Guidelines

### Profile Translation (Bluesky → Mastodon)

```swift
ATProto Profile → MastodonAccount

handle          → username (without .bsky.social)
handle          → acct (full handle)
displayName     → displayName (fallback to handle)
description     → note (convert facets to HTML)
avatar          → avatar / avatarStatic
banner          → header / headerStatic
followersCount  → followersCount
followingCount  → followingCount
postsCount      → statusesCount
createdAt       → createdAt (from DID if available)
```

**Fallbacks**:
- No avatar? Use default gravatar
- No display name? Use handle
- No bio? Empty string

---

### Post Translation (Bluesky → Mastodon)

```swift
ATProto Post → MastodonStatus

uri             → id (via Snowflake mapping)
text            → content (process facets to HTML)
author          → account (translate profile)
createdAt       → createdAt
likeCount       → favouritesCount
repostCount     → reblogsCount
replyCount      → repliesCount
embed.images    → mediaAttachments
embed.external  → card
reply.parent    → inReplyToId (via Snowflake mapping)
```

**Facet Processing**:
```
Input:  "Hello @alice.bsky.social! Check out https://bsky.app #bluesky"
Output: "<p>Hello <span class=\"h-card\"><a href=\"https://bsky.app/profile/alice.bsky.social\" class=\"u-url mention\">@alice.bsky.social</a></span>! Check out <a href=\"https://bsky.app\" target=\"_blank\" rel=\"nofollow noopener noreferrer\">https://bsky.app</a> <a href=\"https://bsky.app/hashtag/bluesky\" class=\"mention hashtag\">#bluesky</a></p>"
```

---

## Error Handling Strategy

### Error Types Hierarchy

```swift
// ArchaeopteryxCore
enum ArchaeopteryxError: Error {
    case notFound(resource: String)
    case unauthorized
    case forbidden
    case validationFailed(field: String, message: String)
    case rateLimited(retryAfter: TimeInterval)
    case internalError(underlying: Error)
}

// ATProtoAdapter
enum ATProtoError: Error {
    case sessionExpired
    case invalidHandle
    case postNotFound
    case networkError(underlying: Error)
}

// OAuthService
enum OAuthError: Error {
    case invalidClient
    case invalidGrant
    case invalidToken
    case unsupportedGrantType
}
```

### HTTP Status Code Mapping

```swift
ArchaeopteryxError.notFound           → 404 Not Found
ArchaeopteryxError.unauthorized       → 401 Unauthorized
ArchaeopteryxError.forbidden          → 403 Forbidden
ArchaeopteryxError.validationFailed   → 422 Unprocessable Entity
ArchaeopteryxError.rateLimited        → 429 Too Many Requests
ArchaeopteryxError.internalError      → 500 Internal Server Error

OAuthError.invalidClient              → 401 Unauthorized
OAuthError.invalidGrant               → 400 Bad Request
```

### Error Response Format (Mastodon-compatible)

```json
{
  "error": "Record not found",
  "error_description": "The account with ID 123456 does not exist"
}
```

---

## Caching Strategy

### Cache TTLs

```swift
Profile cache:           15 minutes (900s)
Post cache:              5 minutes (300s)
Timeline cache:          2 minutes (120s)
ID mappings (DID):       Never expire (deterministic)
ID mappings (AT URI):    Never expire (created once)
OAuth tokens:            Match token expiration (7 days)
Session data:            7 days
Rate limit counters:     1 hour (sliding window)
```

### Cache Key Prefixes

```
profile:{did}
post:{at_uri}
timeline:{user_did}:{type}
did_to_snowflake:{did}
snowflake_to_did:{snowflake}
at_uri_to_snowflake:{at_uri}
oauth_token:{token}
session:{session_id}
rate_limit:{ip}:{endpoint}
```

---

## Testing Guidelines

### Test Structure

```swift
import XCTest
@testable import PackageName

final class ServiceNameTests: XCTestCase {
    var sut: ServiceName!  // System Under Test
    var mockCache: MockCacheService!
    var mockClient: MockATProtoClient!

    override func setUp() async throws {
        try await super.setUp()
        mockCache = MockCacheService()
        mockClient = MockATProtoClient()
        sut = ServiceName(cache: mockCache, client: mockClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockCache = nil
        mockClient = nil
        try await super.tearDown()
    }

    // Tests go here
}
```

### Test Coverage Goals

- **Unit tests**: 80% minimum per package
- **Critical paths**: 100% (auth, translation, ID mapping)
- **Integration tests**: All route handlers
- **Edge cases**: Invalid input, network failures, cache misses

### Mock Objects

Create mocks in test targets:

```swift
// Tests/ATProtoAdapterTests/Mocks/MockATProtoClient.swift
actor MockATProtoClient: ATProtoClientProtocol {
    var getProfileResult: Result<Profile, Error> = .failure(TestError.notSet)

    func getProfile(handle: String) async throws -> Profile {
        return try getProfileResult.get()
    }
}
```

---

## Performance Targets

### Response Times (p95)
- `GET /api/v1/timelines/home`: < 500ms
- `GET /api/v1/accounts/:id`: < 200ms
- `POST /api/v1/statuses`: < 1000ms
- `GET /api/v1/statuses/:id`: < 200ms

### Throughput
- 100 requests/second per instance minimum
- Scale horizontally by adding instances

### Cache Hit Ratios
- Profile lookups: > 90%
- Post lookups: > 80%
- Timeline: > 70%

---

## Development Workflow

### Starting a New Feature

1. **Read the spec**: Understand Mastodon API requirements
2. **Write test**: Start with failing test
3. **Implement**: Make test pass
4. **Refactor**: Clean up code
5. **Integration test**: Test with real dependencies (optional)
6. **Document**: Update this file if needed

### Running Tests

```bash
# All tests
swift test

# Specific package
swift test --filter MastodonModelsTests

# Specific test
swift test --filter testGetProfile_ValidHandle_ReturnsProfile

# With coverage
swift test --enable-code-coverage
```

### Building and Running

```bash
# Build
swift build

# Run
swift run Archaeopteryx

# With environment variables
PORT=8080 LOG_LEVEL=debug swift run Archaeopteryx
```

---

## Common Patterns

### Pagination

```swift
struct PaginationParams {
    let maxID: String?      // Return results older than this ID
    let sinceID: String?    // Return results newer than this ID
    let minID: String?      // Return results immediately newer than this ID
    let limit: Int          // Max results (default 20, max 40)
}

// Link header format
Link: <https://example.com/api/v1/accounts/1/statuses?max_id=103>; rel="next",
      <https://example.com/api/v1/accounts/1/statuses?since_id=105>; rel="prev"
```

### Request Context

```swift
// Store authenticated user in request context
extension Request {
    var authenticatedDID: String? {
        get { context.get("authenticated_did") }
        set { context.set("authenticated_did", newValue) }
    }

    var blueskyCient: ATProtoClient? {
        get { context.get("bluesky_client") }
        set { context.set("bluesky_client", newValue) }
    }
}
```

---

## Debugging Tips

### Enable Verbose Logging

```bash
LOG_LEVEL=trace swift run Archaeopteryx
```

### Inspect Cache

```bash
redis-cli -h localhost -p 6379
> KEYS profile:*
> GET profile:did:plc:abc123
> TTL profile:did:plc:abc123
```

### Test with curl

```bash
# Get instance info
curl http://localhost:8080/api/v1/instance

# Verify credentials (with token)
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:8080/api/v1/accounts/verify_credentials

# Create post
curl -X POST \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"status":"Hello from Archaeopteryx!"}' \
     http://localhost:8080/api/v1/statuses
```

---

## Known Limitations

1. **No Pinned Posts**: Bluesky doesn't support pinning → return empty array
2. **No Familiar Followers**: Not implemented → return empty array
3. **Public Timeline**: Delegates to home timeline (Bluesky has no global feed)
4. **Lists are Read-Only**: Mapped from Bluesky feeds, can't create/edit via API
5. **No Custom Emojis**: Bluesky doesn't have custom emojis yet
6. **No Polls**: Bluesky doesn't support polls yet
7. **Limited Filters**: Implemented client-side only

---

## Security Considerations

### Secrets Management
- Never commit secrets to git
- Use environment variables for sensitive config
- Rotate OAuth secrets periodically

### Rate Limiting
- 300 requests per 5 minutes per IP (default)
- 100 requests per 5 minutes per user (authenticated)
- Configurable via environment variables

### Input Validation
- Always validate and sanitize user input
- Check length limits (status: 300 chars, bio: 256 chars)
- Escape HTML in user-generated content

---

## Deployment

### Environment Variables

```bash
# Server
PORT=8080
HOSTNAME=0.0.0.0

# Cache
VALKEY_HOST=localhost
VALKEY_PORT=6379
VALKEY_PASSWORD=
VALKEY_DATABASE=0

# AT Protocol
ATPROTO_SERVICE_URL=https://bsky.social
ATPROTO_PDS_URL=

# Logging
LOG_LEVEL=info
```

### Docker

```dockerfile
FROM swift:6.0
WORKDIR /app
COPY . .
RUN swift build -c release
EXPOSE 8080
CMD [".build/release/Archaeopteryx"]
```

---

## Resources

- [Mastodon API Documentation](https://docs.joinmastodon.org/api/)
- [AT Protocol Specification](https://atproto.com/specs/atp)
- [Hummingbird Documentation](https://docs.hummingbird.codes/)
- [Swift Concurrency Guide](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

---

Last Updated: 2025-10-11
