# Archaeopteryx Implementation Plan

## Project Overview
Archaeopteryx is a Swift-based bridge/proxy that allows Mastodon apps to connect to Bluesky by translating Mastodon API calls to AT Protocol calls. This is a Swift implementation inspired by [SkyBridge](https://github.com/videah/SkyBridge).

## Technology Stack
- **Framework**: Hummingbird 2.0 (Modern Swift web framework)
- **Cache**: RediStack (Redis/Valkey client)
- **AT Protocol SDK**: ATProtoKit
- **Language**: Swift 6.0
- **Methodology**: Test-Driven Development (TDD)

## Current Progress

### ✅ Completed Tasks

1. **Project Structure Setup** ✅
   - Created multi-package monorepo structure (8 packages)
   - Set up test structure for all packages
   - Configured Package.swift with modular architecture
   - All dependencies properly configured

2. **Snowflake ID Generator** ✅ (6/6 tests passing)
   - Time-sortable 64-bit unique IDs
   - Thread-safe actor-based implementation
   - Custom epoch support (2020-01-01 default)
   - Timestamp extraction functionality
   - Tests: uniqueness, monotonic ordering, timestamp accuracy, custom epoch, sequence numbers, thread safety
   - **Moved to IDMapping package**

3. **Mastodon Model Types** ✅ (5/5 tests passing)
   - `MastodonAccount` - User profile representation
   - `MastodonStatus` - Post/status representation
   - Supporting types: `Field`, `CustomEmoji`, `Visibility`, `MediaAttachment`, `Mention`, `Tag`, `Card`, `ClientApplication`
   - `Box<T>` class for handling recursive reblog references
   - Full JSON encoding/decoding with snake_case conversion
   - **Moved to MastodonModels package**

4. **ArchaeopteryxCore Package** ✅
   - `ArchaeopteryxError` - Common error types with Codable support
   - `Protocols.swift` - Cacheable, Translatable, Identifiable protocols
   - `Configuration.swift` - Environment-based configuration (moved from main)

5. **IDMapping Package** ✅ (18/18 tests passing)
   - `SnowflakeIDGenerator.swift` - Time-sortable 64-bit IDs
   - `IDMappingService.swift` - **NEW!** Deterministic DID/AT URI mapping
     - DID → Snowflake ID mapping (SHA-256 based)
     - AT URI → Snowflake ID mapping
     - Handle → Snowflake ID resolution
     - Bidirectional lookups
     - Cache protocol integration
   - Full test coverage with mock cache

### 🔄 Next Phase: Core Transformation Layer (TDD Order)

#### Step 1: Write Tests for ATProtoClient Service
**Test File**: `Tests/ArchaeopteryxTests/Services/ATProtoClientTests.swift`

**Tests to write (RED phase)**:
```swift
// Authentication tests
func testCreateSession_ValidCredentials_ReturnsSession()
func testCreateSession_InvalidCredentials_ThrowsError()
func testRefreshSession_ValidToken_ReturnsNewSession()

// Profile retrieval tests
func testGetProfile_ValidHandle_ReturnsProfile()
func testGetProfile_ValidDID_ReturnsProfile()
func testGetProfile_InvalidHandle_ThrowsNotFoundError()

// Post retrieval tests
func testGetPost_ValidATURI_ReturnsPost()
func testGetPost_InvalidATURI_ThrowsError()

// Feed tests
func testGetTimeline_ValidSession_ReturnsPosts()
func testGetTimeline_WithPagination_ReturnsCorrectPosts()

// Follow operations
func testFollowUser_ValidDID_SuccessfullyFollows()
func testUnfollowUser_ValidDID_SuccessfullyUnfollows()
```

**Then implement**: `Sources/Archaeopteryx/Services/ATProtoClient.swift` (GREEN phase)

---

#### Step 2: Write Tests for Cache Service
**Test File**: `Tests/ArchaeopteryxTests/Services/CacheServiceTests.swift`

**Tests to write (RED phase)**:
```swift
// Connection tests
func testConnect_ValidConfiguration_Connects()
func testConnect_InvalidHost_ThrowsError()

// Storage tests
func testSet_ValidData_StoresSuccessfully()
func testGet_ExistingKey_ReturnsData()
func testGet_NonExistentKey_ReturnsNil()

// TTL tests
func testSetWithTTL_DataExpires_ReturnsNil()

// ID Mapping tests
func testStoreDIDToSnowflake_ValidMapping_StoresAndRetrieves()
func testStoreATURIToSnowflake_ValidMapping_StoresAndRetrieves()
func testGetDIDFromSnowflake_ValidID_ReturnsDID()

// Session storage tests
func testStoreSession_ValidSession_StoresAndRetrieves()
func testStoreOAuthToken_ValidToken_StoresAndRetrieves()
```

**Then implement**: `Sources/Archaeopteryx/Services/CacheService.swift` (GREEN phase)

---

#### Step 3: Write Tests for ID Mapping Service
**Test File**: `Tests/ArchaeopteryxTests/Services/IDMappingServiceTests.swift`

**Tests to write (RED phase)**:
```swift
// DID to Snowflake mapping
func testGetSnowflakeForDID_NewDID_GeneratesConsistentID()
func testGetSnowflakeForDID_ExistingDID_ReturnsCachedID()
func testGetSnowflakeForDID_SameDID_AlwaysReturnsSameID() // Deterministic

// Reverse lookup
func testGetDIDForSnowflake_ExistingMapping_ReturnsDID()
func testGetDIDForSnowflake_NonExistent_ReturnsNil()

// AT URI to Snowflake
func testGetSnowflakeForATURI_NewURI_GeneratesID()
func testGetSnowflakeForATURI_ExistingURI_ReturnsCachedID()

// Handle to Snowflake
func testGetSnowflakeForHandle_ResolvesToDID_ReturnsSnowflake()
```

**Then implement**: `Sources/Archaeopteryx/Services/IDMappingService.swift` (GREEN phase)

---

#### Step 4: Write Tests for Facet Processor
**Test File**: `Tests/ArchaeopteryxTests/Services/FacetProcessorTests.swift`

**Tests to write (RED phase)**:
```swift
// Basic text processing
func testProcessText_PlainText_WrapsInParagraph()
func testProcessText_EmptyText_ReturnsEmptyParagraph()

// Link processing
func testProcessFacets_WithLink_CreatesAnchorTag()
func testProcessFacets_WithMultipleLinks_CreatesMultipleTags()

// Mention processing
func testProcessFacets_WithMention_CreatesSpanAndAnchor()
func testProcessFacets_WithMention_IncludesProperClasses()

// Hashtag processing
func testProcessFacets_WithHashtag_CreatesProperLink()

// Complex scenarios
func testProcessFacets_OverlappingFacets_HandlesCorrectly()
func testProcessFacets_MixedFacets_ProcessesInOrder()
func testProcessFacets_NoFacets_ReturnsPlainTextInParagraph()

// Edge cases
func testProcessFacets_FacetAtStartOfText_ProcessesCorrectly()
func testProcessFacets_FacetAtEndOfText_ProcessesCorrectly()
func testProcessText_SpecialCharacters_EscapesHTML()
```

**Then implement**: `Sources/Archaeopteryx/Services/FacetProcessor.swift` (GREEN phase)

---

#### Step 5: Write Tests for Translation Service
**Test File**: `Tests/ArchaeopteryxTests/Services/TranslationServiceTests.swift`

**Tests to write (RED phase)**:
```swift
// Profile translation
func testTranslateProfile_CompleteProfile_AllFieldsMapped()
func testTranslateProfile_MinimalProfile_UsesDefaults()
func testTranslateProfile_MissingAvatar_UsesFallback()
func testTranslateProfile_MissingDisplayName_UsesHandle()
func testTranslateProfile_Bio_ConvertedToHTML()

// Status translation
func testTranslatePost_TextOnly_CreatesBasicStatus()
func testTranslatePost_WithImages_IncludesMediaAttachments()
func testTranslatePost_WithFacets_ConvertsToHTML()
func testTranslatePost_Reply_SetsInReplyToFields()
func testTranslatePost_QuotePost_CreatesReblogStructure()
func testTranslatePost_WithMentions_ExtractsMentions()
func testTranslatePost_WithHashtags_ExtractsTags()

// Notification translation
func testTranslateNotification_LikeNotification_CreatesCorrectType()
func testTranslateNotification_RepostNotification_CreatesCorrectType()
func testTranslateNotification_FollowNotification_CreatesCorrectType()
func testTranslateNotification_ReplyNotification_CreatesMentionType()
func testTranslateNotification_MentionNotification_CreatesMentionType()
```

**Create notification model first**: `Sources/Archaeopteryx/Models/MastodonNotification.swift`

**Then implement**: `Sources/Archaeopteryx/Services/TranslationService.swift` (GREEN phase)

---

#### TDD Workflow for Each Component

**RED → GREEN → REFACTOR Cycle:**

1. **RED Phase**:
   - Write failing test that describes desired behavior
   - Test should fail compilation or assertions
   - Run test to confirm it fails: `swift test`

2. **GREEN Phase**:
   - Write minimal code to make test pass
   - Don't worry about elegance yet
   - Run test to confirm it passes: `swift test`

3. **REFACTOR Phase**:
   - Clean up code while keeping tests green
   - Extract common logic
   - Improve naming
   - Re-run tests after each refactor: `swift test`

4. **Repeat** for next test

**Example TDD Iteration**:
```swift
// 1. RED: Write test
func testGetSnowflakeForDID_NewDID_GeneratesID() async throws {
    let service = IDMappingService(
        cache: mockCache,
        generator: mockGenerator
    )

    let did = "did:plc:abc123"
    let snowflake = await service.getSnowflakeID(forDID: did)

    XCTAssertNotNil(snowflake)
    XCTAssertGreaterThan(snowflake, 0)
}

// Run test - it fails ❌

// 2. GREEN: Implement minimal code
actor IDMappingService {
    func getSnowflakeID(forDID did: String) -> Int64 {
        return 123456789 // Hardcoded - but test passes!
    }
}

// Run test - it passes ✅

// 3. REFACTOR: Make it actually work
actor IDMappingService {
    private let cache: CacheService
    private let generator: SnowflakeIDGenerator

    func getSnowflakeID(forDID did: String) async -> Int64 {
        // Check cache first
        if let cached = await cache.getSnowflake(forDID: did) {
            return cached
        }

        // Generate deterministically from DID hash
        let hash = SHA256.hash(data: Data(did.utf8))
        let snowflake = Int64(hash.prefix(8).reduce(0) { $0 << 8 + Int64($1) })

        // Cache it
        await cache.storeMapping(did: did, snowflake: snowflake)

        return snowflake
    }
}

// Run test - still passes ✅
// Add more tests and repeat
```

---


---

### 🔜 Authentication & Authorization Phase (TDD Order)

#### Step 6: Write Tests for OAuth Models
**Test File**: `Tests/ArchaeopteryxTests/Models/OAuthTests.swift`

**Tests to write (RED phase)**:
```swift
// OAuth Application tests
func testOAuthApplication_Encoding_ProducesValidJSON()
func testOAuthApplication_Decoding_ParsesValidJSON()

// OAuth Token tests
func testOAuthToken_Creation_GeneratesValidToken()
func testOAuthToken_IsExpired_ReturnsTrueAfterExpiration()
func testOAuthToken_IsExpired_ReturnsFalseBeforeExpiration()

// Authorization Code tests
func testAuthorizationCode_Creation_GeneratesUniqueCode()
func testAuthorizationCode_IsExpired_ReturnsTrueAfter10Minutes()
```

**Then create models**: `Sources/Archaeopteryx/Models/OAuth.swift` (GREEN phase)

---

#### Step 7: Write Tests for OAuth Service
**Test File**: `Tests/ArchaeopteryxTests/Services/OAuthServiceTests.swift`

**Tests to write (RED phase)**:
```swift
// App registration
func testRegisterApp_ValidRequest_ReturnsCredentials()
func testRegisterApp_MissingName_ThrowsValidationError()
func testRegisterApp_MissingRedirectURI_ThrowsValidationError()

// Authorization code generation
func testGenerateAuthCode_ValidRequest_ReturnsCode()
func testGenerateAuthCode_StoresInCache_CanRetrieve()

// Token exchange
func testExchangeCodeForToken_ValidCode_ReturnsAccessToken()
func testExchangeCodeForToken_ExpiredCode_ThrowsError()
func testExchangeCodeForToken_InvalidCode_ThrowsError()
func testExchangeCodeForToken_UsedCode_ThrowsError() // One-time use

// Password grant (Bluesky login)
func testPasswordGrant_ValidCredentials_CreatesSessionAndToken()
func testPasswordGrant_InvalidCredentials_ThrowsError()

// Token validation
func testValidateToken_ValidToken_ReturnsSession()
func testValidateToken_ExpiredToken_ThrowsError()
func testValidateToken_InvalidToken_ThrowsError()

// Token revocation
func testRevokeToken_ValidToken_RemovesFromCache()
func testRevokeToken_InvalidToken_NoError()

// Scope handling
func testValidateScopes_ValidMastodonScopes_MapsToBlueskyCaps()
func testValidateScopes_InvalidScopes_ThrowsError()
```

**Then implement**: `Sources/Archaeopteryx/Services/OAuthService.swift` (GREEN phase)

---

#### Step 8: Write Tests for OAuth Routes
**Test File**: `Tests/ArchaeopteryxTests/Routes/OAuthRoutesTests.swift`

**Tests to write (RED phase)**:
```swift
// App registration endpoint
func testPostApps_ValidRequest_ReturnsClientCredentials()
func testPostApps_MissingClientName_Returns422()
func testPostApps_MissingRedirectURIs_Returns422()

// Authorization endpoint
func testGetAuthorize_ValidParams_ReturnsAuthPage()
func testGetAuthorize_MissingClientId_Returns400()
func testPostAuthorize_ValidCredentials_RedirectsWithCode()
func testPostAuthorize_InvalidCredentials_ReturnsError()

// Token endpoint
func testPostToken_AuthorizationCodeGrant_ReturnsAccessToken()
func testPostToken_PasswordGrant_ReturnsAccessToken()
func testPostToken_InvalidGrant_Returns400()
func testPostToken_ExpiredCode_Returns401()
func testPostToken_InvalidClient_Returns401()

// Revoke endpoint
func testPostRevoke_ValidToken_Returns200()
func testPostRevoke_InvalidToken_Returns200() // Should not error
```

**Then implement**: `Sources/Archaeopteryx/Routes/OAuthRoutes.swift` (GREEN phase)

---

#### Step 9: Write Tests for Authentication Middleware
**Test File**: `Tests/ArchaeopteryxTests/Middleware/AuthMiddlewareTests.swift`

**Tests to write (RED phase)**:
```swift
// Token extraction
func testAuthMiddleware_ValidBearerToken_ExtractsToken()
func testAuthMiddleware_MissingAuthHeader_Returns401()
func testAuthMiddleware_InvalidAuthFormat_Returns401()

// Token validation
func testAuthMiddleware_ValidToken_LoadsSession()
func testAuthMiddleware_ExpiredToken_AttemptsRefresh()
func testAuthMiddleware_InvalidToken_Returns401()

// Context population
func testAuthMiddleware_ValidAuth_AddsUserToContext()
func testAuthMiddleware_ValidAuth_AddsBlueskyCl ientToContext()

// Optional auth
func testAuthMiddleware_OptionalAuth_MissingToken_Continues()
func testAuthMiddleware_RequiredAuth_MissingToken_Returns401()

// Rate limiting
func testAuthMiddleware_TooManyFailures_Returns429()
func testAuthMiddleware_RateLimitExpires_AllowsNewAttempts()
```

**Then implement**: `Sources/Archaeopteryx/Middleware/AuthMiddleware.swift` (GREEN phase)

---

### 🔜 API Endpoints Phase (TDD Order)

#### Step 10: Write Tests for Account Routes
**Test File**: `Tests/ArchaeopteryxTests/Routes/AccountRoutesTests.swift`

**Tests to write (RED phase)**:
```swift
// Verify credentials
func testVerifyCredentials_ValidAuth_ReturnsCurrentUser()
func testVerifyCredentials_NoAuth_Returns401()

// Account lookup
func testLookupAccount_ValidHandle_ReturnsAccount()
func testLookupAccount_InvalidHandle_Returns404()
func testLookupAccount_MissingQuery_Returns400()

// Get account by ID
func testGetAccount_ValidSnowflakeID_ReturnsAccount()
func testGetAccount_InvalidID_Returns404()
func testGetAccount_UnmappedSnowflake_Returns404()

// Account search
func testSearchAccounts_ValidQuery_ReturnsResults()
func testSearchAccounts_NoResults_ReturnsEmptyArray()
func testSearchAccounts_WithLimit_RespectsLimit()

// Account statuses
func testGetAccountStatuses_ValidID_ReturnsPosts()
func testGetAccountStatuses_WithPagination_WorksCorrectly()
func testGetAccountStatuses_ExcludeReplies_FiltersReplies()
func testGetAccountStatuses_OnlyMedia_FiltersMediaPosts()

// Followers/Following
func testGetFollowers_ValidID_ReturnsFollowerList()
func testGetFollowers_WithPagination_WorksCorrectly()
func testGetFollowing_ValidID_ReturnsFollowingList()

// Follow operations
func testFollowAccount_ValidID_FollowsAndReturnsRelationship()
func testFollowAccount_AlreadyFollowing_ReturnsRelationship()
func testFollowAccount_NoAuth_Returns401()
func testUnfollowAccount_ValidID_UnfollowsSuccessfully()

// Relationships
func testGetRelationships_ValidIDs_ReturnsRelationships()
func testGetRelationships_MissingIDs_Returns400()
func testGetRelationships_NoAuth_Returns401()
```

**Then implement**: `Sources/Archaeopteryx/Routes/AccountRoutes.swift` (GREEN phase)

**Create relationship model**: `Sources/Archaeopteryx/Models/MastodonRelationship.swift`

---

#### Step 11: Write Tests for Status Routes
**Test File**: `Tests/ArchaeopteryxTests/Routes/StatusRoutesTests.swift`

**Tests to write (RED phase)**:
```swift
// Get status
func testGetStatus_ValidID_ReturnsStatus()
func testGetStatus_InvalidID_Returns404()
func testGetStatus_UnmappedSnowflake_Returns404()

// Create status
func testCreateStatus_TextOnly_CreatesPost()
func testCreateStatus_WithMediaIDs_AttachesMedia()
func testCreateStatus_AsReply_SetsReplyFields()
func testCreateStatus_WithSpoiler_SetsSensitiveFlag()
func testCreateStatus_WithVisibility_MapsCorrectly()
func testCreateStatus_NoAuth_Returns401()
func testCreateStatus_EmptyContent_Returns422()

// Delete status (if supported)
func testDeleteStatus_ValidID_DeletesPost()
func testDeleteStatus_NotOwned_Returns403()
func testDeleteStatus_NoAuth_Returns401()

// Get context (thread)
func testGetContext_ValidID_ReturnsAncestorsAndDescendants()
func testGetContext_RootPost_ReturnsOnlyDescendants()
func testGetContext_LeafPost_ReturnsOnlyAncestors()

// Favourite operations
func testFavouriteStatus_ValidID_LikesPost()
func testFavouriteStatus_AlreadyLiked_Idempotent()
func testFavouriteStatus_NoAuth_Returns401()
func testUnfavouriteStatus_ValidID_UnlikesPost()

// Reblog operations
func testReblogStatus_ValidID_RepostsPost()
func testReblogStatus_AlreadyReblogged_Idempotent()
func testReblogStatus_NoAuth_Returns401()
func testUnreblogStatus_ValidID_UnrepostsPost()

// Get interactions
func testGetFavouritedBy_ValidID_ReturnsLikers()
func testGetFavouritedBy_WithPagination_WorksCorrectly()
func testGetRebloggedBy_ValidID_ReturnsReposters()
```

**Then implement**: `Sources/Archaeopteryx/Routes/StatusRoutes.swift` (GREEN phase)

---

#### Step 12: Write Tests for Timeline Routes
**Test File**: `Tests/ArchaeopteryxTests/Routes/TimelineRoutesTests.swift`

**Tests to write (RED phase)**:
```swift
// Home timeline
func testHomeTimeline_ValidAuth_ReturnsPosts()
func testHomeTimeline_NoAuth_Returns401()
func testHomeTimeline_EmptyFeed_ReturnsEmptyArray()
func testHomeTimeline_WithMaxID_ReturnsPaginatedResults()
func testHomeTimeline_WithSinceID_ReturnsNewerPosts()
func testHomeTimeline_WithLimit_RespectsLimit()

// Public timeline
func testPublicTimeline_ReturnsPublicPosts()
func testPublicTimeline_LocalOnly_FiltersRemote()

// List/Feed timeline
func testListTimeline_ValidListID_ReturnsFeedPosts()
func testListTimeline_InvalidListID_Returns404()
func testListTimeline_NoAuth_Returns401()

// Pagination headers
func testTimeline_PaginationHeaders_IncludeLinkHeader()
func testTimeline_PaginationHeaders_CorrectMaxID()
```

**Then implement**: `Sources/Archaeopteryx/Routes/TimelineRoutes.swift` (GREEN phase)

---

#### Step 13: Write Tests for Notification Routes
**Test File**: `Tests/ArchaeopteryxTests/Routes/NotificationRoutesTests.swift`

**Tests to write (RED phase)**:
```swift
// Get notifications
func testGetNotifications_ValidAuth_ReturnsNotifications()
func testGetNotifications_NoAuth_Returns401()
func testGetNotifications_EmptyNotifications_ReturnsEmptyArray()
func testGetNotifications_WithPagination_WorksCorrectly()

// Filter by type
func testGetNotifications_FilterByFavourite_ReturnsOnlyLikes()
func testGetNotifications_FilterByReblog_ReturnsOnlyReposts()
func testGetNotifications_FilterByFollow_ReturnsOnlyFollows()
func testGetNotifications_FilterByMention_ReturnsOnlyMentions()

// Notification type mapping
func testNotifications_BlueskyLike_TranslatedToFavourite()
func testNotifications_BlueskyRepost_TranslatedToReblog()
func testNotifications_BlueskyFollow_TranslatedToFollow()
func testNotifications_BlueskyReply_TranslatedToMention()
func testNotifications_BlueskyMention_TranslatedToMention()
func testNotifications_BlueskyQuote_TranslatedToStatus()

// Get single notification
func testGetNotification_ValidID_ReturnsNotification()
func testGetNotification_InvalidID_Returns404()

// Clear/Dismiss
func testClearNotifications_ValidAuth_ClearsAll()
func testDismissNotification_ValidID_DismissesOne()
```

**Create notification model first**: `Sources/Archaeopteryx/Models/MastodonNotification.swift`

**Then implement**: `Sources/Archaeopteryx/Routes/NotificationRoutes.swift` (GREEN phase)

---

#### Step 14: Write Tests for Media Routes
**Test File**: `Tests/ArchaeopteryxTests/Routes/MediaRoutesTests.swift`

**Tests to write (RED phase)**:
```swift
// Upload media
func testUploadMedia_ValidImage_ReturnsMediaAttachment()
func testUploadMedia_WithAltText_StoresDescription()
func testUploadMedia_NoAuth_Returns401()
func testUploadMedia_InvalidFormat_Returns422()
func testUploadMedia_FileTooLarge_Returns422()

// Get media
func testGetMedia_ValidID_ReturnsMediaInfo()
func testGetMedia_InvalidID_Returns404()

// Update media
func testUpdateMedia_ValidID_UpdatesDescription()
func testUpdateMedia_NotOwned_Returns403()

// Supported formats
func testUploadMedia_JPEG_Succeeds()
func testUploadMedia_PNG_Succeeds()
func testUploadMedia_GIF_Succeeds()
func testUploadMedia_WebP_Succeeds()
func testUploadMedia_MP4_Succeeds()
```

**Then implement**: `Sources/Archaeopteryx/Routes/MediaRoutes.swift` (GREEN phase)

---

#### Step 15: Write Tests for Search Routes
**Test File**: `Tests/ArchaeopteryxTests/Routes/SearchRoutesTests.swift`

**Tests to write (RED phase)**:
```swift
// General search
func testSearch_ValidQuery_ReturnsResults()
func testSearch_EmptyQuery_Returns400()

// Account search
func testSearch_TypeAccounts_ReturnsOnlyAccounts()
func testSearch_AccountByHandle_FindsAccount()
func testSearch_AccountByDisplayName_FindsAccount()

// Status search
func testSearch_TypeStatuses_ReturnsOnlyStatuses()
func testSearch_StatusByContent_FindsPosts()

// Hashtag search
func testSearch_TypeHashtags_ReturnsOnlyHashtags()
func testSearch_HashtagQuery_FindsTags()

// Pagination and limits
func testSearch_WithLimit_RespectsLimit()
func testSearch_WithOffset_SkipsResults()

// Combined results
func testSearch_NoTypeFilter_ReturnsAllTypes()
```

**Then implement**: `Sources/Archaeopteryx/Routes/SearchRoutes.swift` (GREEN phase)

---

#### Step 16: Write Tests for List Routes
**Test File**: `Tests/ArchaeopteryxTests/Routes/ListRoutesTests.swift`

**Tests to write (RED phase)**:
```swift
// Get lists
func testGetLists_ValidAuth_ReturnsUserFeeds()
func testGetLists_NoAuth_Returns401()
func testGetLists_NoSavedFeeds_ReturnsEmptyArray()

// Get list details
func testGetList_ValidID_ReturnsFeedInfo()
func testGetList_InvalidID_Returns404()

// List accounts (feed members)
func testGetListAccounts_ValidID_ReturnsMembers()

// Feed to list mapping
func testLists_BlueskySavedFeeds_MappedToLists()
func testLists_FeedNames_PreservedAsListTitles()
```

**Create list model**: `Sources/Archaeopteryx/Models/MastodonList.swift`

**Then implement**: `Sources/Archaeopteryx/Routes/ListRoutes.swift` (GREEN phase)

---

#### Step 17: Write Tests for Instance Routes
**Test File**: `Tests/ArchaeopteryxTests/Routes/InstanceRoutesTests.swift`

**Tests to write (RED phase)**:
```swift
// Instance info v1
func testGetInstanceV1_ReturnsValidInstanceInfo()
func testGetInstanceV1_IncludesTitle()
func testGetInstanceV1_IncludesVersion()
func testGetInstanceV1_IncludesStats()
func testGetInstanceV1_IncludesContactInfo()

// Instance info v2
func testGetInstanceV2_ReturnsValidInstanceInfo()
func testGetInstanceV2_IncludesDomain()
func testGetInstanceV2_IncludesConfiguration()

// Node info
func testGetNodeInfo_ReturnsValidNodeInfo()
func testGetNodeInfo_IncludesProtocols()

// Extended description
func testGetExtendedDescription_ReturnsInfo()

// Rules
func testGetRules_ReturnsInstanceRules()
```

**Create instance models**: `Sources/Archaeopteryx/Models/Instance.swift`

**Then implement**: `Sources/Archaeopteryx/Routes/InstanceRoutes.swift` (GREEN phase)

---

---

## Modular Architecture with Swift Packages

### Strategy: Multi-Package Monorepo

**Goal**: Break Archaeopteryx into smaller, reusable Swift packages for better separation of concerns, testability, and potential reuse.

**Structure**:
```
Archaeopteryx/                    # Main executable package
├── Package.swift                 # Defines all local packages
├── Sources/
│   ├── Archaeopteryx/            # Main app (orchestration)
│   ├── ArchaeopteryxCore/        # Core models and protocols
│   ├── MastodonModels/           # Mastodon API models
│   ├── ATProtoAdapter/           # AT Protocol client wrapper
│   ├── TranslationLayer/         # Bluesky ↔ Mastodon translation
│   ├── CacheLayer/               # Valkey/Redis cache abstraction
│   ├── IDMapping/                # Snowflake ID generation & mapping
│   └── OAuthService/             # OAuth flow implementation
└── Tests/
    ├── ArchaeopteryxTests/
    ├── ArchaeopteryxCoreTests/
    ├── MastodonModelsTests/
    ├── ATProtoAdapterTests/
    ├── TranslationLayerTests/
    ├── CacheLayerTests/
    ├── IDMappingTests/
    └── OAuthServiceTests/
```

---

### Package Breakdown

#### 1. **ArchaeopteryxCore** (Foundation)
**Purpose**: Shared types, protocols, and utilities used across all packages

**Contents**:
- `ArchaeopteryxError` - Common error types
- `Configuration` - Configuration models
- `Protocols/` - Shared protocols
  - `Cacheable`
  - `Translatable`
  - `Identifiable` (custom)
- `Extensions/` - Foundation extensions
- `Logger` - Logging utilities

**Dependencies**: Foundation only

**Test Strategy**:
```swift
// CoreTests
func testError_Encoding_ProducesValidJSON()
func testConfiguration_LoadFromEnvironment_ParsesCorrectly()
```

---

#### 2. **MastodonModels** (Models)
**Purpose**: All Mastodon API data models (already partially implemented)

**Contents**:
- `MastodonAccount.swift`
- `MastodonStatus.swift`
- `MastodonNotification.swift`
- `MastodonRelationship.swift`
- `MastodonList.swift`
- `Instance.swift`
- `OAuth.swift` - OAuth models
- Supporting types (Field, CustomEmoji, MediaAttachment, etc.)

**Dependencies**: ArchaeopteryxCore

**Test Strategy**:
```swift
// Already have tests for Account and Status
// Add tests for all other models
func testModel_Encoding_ProducesValidJSON()
func testModel_Decoding_ParsesValidJSON()
func testModel_Equatable_ComparesCorrectly()
```

---

#### 3. **IDMapping** (Service)
**Purpose**: Snowflake ID generation and DID/AT URI mapping

**Contents**:
- `SnowflakeIDGenerator.swift` (already implemented)
- `IDMappingService.swift`
- `IDMapper` protocol

**Dependencies**:
- ArchaeopteryxCore
- CryptoKit (for DID hashing)

**Test Strategy**: As defined in Step 3 above

---

#### 4. **CacheLayer** (Service)
**Purpose**: Abstract cache interface with Valkey/Redis implementation

**Contents**:
- `CacheService` protocol
- `ValkeyCache.swift` - RediStack implementation
- `InMemoryCache.swift` - Testing mock
- Cache key management
- Serialization helpers

**Dependencies**:
- ArchaeopteryxCore
- RediStack

**Test Strategy**: As defined in Step 2 above

---

#### 5. **ATProtoAdapter** (Integration)
**Purpose**: Wrapper around ATProtoKit with convenience methods

**Contents**:
- `ATProtoClient.swift`
- `SessionManager.swift`
- `ATProtoError` - Error mapping
- Lightweight response models (if needed)

**Dependencies**:
- ArchaeopteryxCore
- ATProtoKit
- CacheLayer (for session caching)

**Test Strategy**: As defined in Step 1 above

---

#### 6. **TranslationLayer** (Service)
**Purpose**: Bidirectional translation between Bluesky and Mastodon formats

**Contents**:
- `TranslationService.swift`
- `FacetProcessor.swift` - Rich text to HTML
- `ProfileTranslator.swift`
- `StatusTranslator.swift`
- `NotificationTranslator.swift`

**Dependencies**:
- ArchaeopteryxCore
- MastodonModels
- ATProtoAdapter
- IDMapping

**Test Strategy**: As defined in Steps 4-5 above

---

#### 7. **OAuthService** (Service)
**Purpose**: OAuth 2.0 flow implementation for Mastodon compatibility

**Contents**:
- `OAuthService.swift`
- `TokenManager.swift`
- `AuthorizationCodeGenerator.swift`
- `ScopeValidator.swift`

**Dependencies**:
- ArchaeopteryxCore
- MastodonModels (OAuth models)
- CacheLayer
- ATProtoAdapter
- CryptoKit (for token generation)

**Test Strategy**: As defined in Steps 6-7 above

---

#### 8. **Archaeopteryx** (Main App)
**Purpose**: HTTP server, routing, middleware, and orchestration

**Contents**:
- `App.swift` - Main entry point
- `Routes/` - All route handlers
  - `AccountRoutes.swift`
  - `StatusRoutes.swift`
  - `TimelineRoutes.swift`
  - `NotificationRoutes.swift`
  - `MediaRoutes.swift`
  - `SearchRoutes.swift`
  - `ListRoutes.swift`
  - `InstanceRoutes.swift`
  - `OAuthRoutes.swift`
- `Middleware/`
  - `AuthMiddleware.swift`
  - `RateLimitMiddleware.swift`
  - `LoggingMiddleware.swift`
  - `ErrorMiddleware.swift`

**Dependencies**:
- ArchaeopteryxCore
- MastodonModels
- ATProtoAdapter
- TranslationLayer
- CacheLayer
- IDMapping
- OAuthService
- Hummingbird

**Test Strategy**: As defined in Steps 8-17 above (route tests)

---

### Updated Package.swift Structure

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Archaeopteryx",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "Archaeopteryx",
            targets: ["Archaeopteryx"]
        ),
        // Optional: Expose libraries for reuse
        .library(name: "MastodonModels", targets: ["MastodonModels"]),
        .library(name: "TranslationLayer", targets: ["TranslationLayer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/RediStack.git", from: "1.6.0"),
        .package(url: "https://github.com/MasterJ93/ATProtoKit.git", from: "0.1.0"),
    ],
    targets: [
        // Core
        .target(
            name: "ArchaeopteryxCore",
            dependencies: []
        ),
        .testTarget(
            name: "ArchaeopteryxCoreTests",
            dependencies: ["ArchaeopteryxCore"]
        ),

        // Models
        .target(
            name: "MastodonModels",
            dependencies: ["ArchaeopteryxCore"]
        ),
        .testTarget(
            name: "MastodonModelsTests",
            dependencies: ["MastodonModels"]
        ),

        // ID Mapping
        .target(
            name: "IDMapping",
            dependencies: ["ArchaeopteryxCore"]
        ),
        .testTarget(
            name: "IDMappingTests",
            dependencies: ["IDMapping"]
        ),

        // Cache Layer
        .target(
            name: "CacheLayer",
            dependencies: [
                "ArchaeopteryxCore",
                .product(name: "RediStack", package: "RediStack"),
            ]
        ),
        .testTarget(
            name: "CacheLayerTests",
            dependencies: ["CacheLayer"]
        ),

        // AT Proto Adapter
        .target(
            name: "ATProtoAdapter",
            dependencies: [
                "ArchaeopteryxCore",
                "CacheLayer",
                .product(name: "ATProtoKit", package: "ATProtoKit"),
            ]
        ),
        .testTarget(
            name: "ATProtoAdapterTests",
            dependencies: ["ATProtoAdapter"]
        ),

        // Translation Layer
        .target(
            name: "TranslationLayer",
            dependencies: [
                "ArchaeopteryxCore",
                "MastodonModels",
                "ATProtoAdapter",
                "IDMapping",
            ]
        ),
        .testTarget(
            name: "TranslationLayerTests",
            dependencies: ["TranslationLayer"]
        ),

        // OAuth Service
        .target(
            name: "OAuthService",
            dependencies: [
                "ArchaeopteryxCore",
                "MastodonModels",
                "CacheLayer",
                "ATProtoAdapter",
            ]
        ),
        .testTarget(
            name: "OAuthServiceTests",
            dependencies: ["OAuthService"]
        ),

        // Main Application
        .executableTarget(
            name: "Archaeopteryx",
            dependencies: [
                "ArchaeopteryxCore",
                "MastodonModels",
                "ATProtoAdapter",
                "TranslationLayer",
                "CacheLayer",
                "IDMapping",
                "OAuthService",
                .product(name: "Hummingbird", package: "hummingbird"),
            ]
        ),
        .testTarget(
            name: "ArchaeopteryxTests",
            dependencies: ["Archaeopteryx"]
        ),
    ]
)
```

---

### Benefits of Modular Architecture

1. **Separation of Concerns**
   - Each package has a single, well-defined responsibility
   - Clear boundaries between layers

2. **Independent Testing**
   - Test each package in isolation
   - Mock dependencies easily
   - Faster test cycles (only rebuild affected packages)

3. **Reusability**
   - `MastodonModels` could be used by other Mastodon clients
   - `TranslationLayer` could be extracted as a standalone library
   - `IDMapping` useful for any Snowflake ID needs

4. **Parallel Development**
   - Multiple developers can work on different packages simultaneously
   - Reduced merge conflicts

5. **Dependency Management**
   - Explicit, compile-time dependency graph
   - Prevents circular dependencies
   - Only import what you need

6. **Build Performance**
   - Swift Package Manager caches individual package builds
   - Only rebuild changed packages

7. **Future Extensibility**
   - Easy to add new translation targets (e.g., Mastodon → Nostr)
   - Swap implementations (e.g., Redis → PostgreSQL cache)

---

### Migration Strategy (Refactoring Existing Code)

**Phase 1: Create Package Structure** (TDD: Write tests first!)
1. Create new package directories in `Sources/`
2. Write tests for `ArchaeopteryxCore` utilities
3. Implement `ArchaeopteryxCore`
4. Move existing `Configuration.swift` to `ArchaeopteryxCore`

**Phase 2: Extract Models** (Already mostly done)
1. Create `MastodonModels` package
2. Move `MastodonAccount.swift`, `MastodonStatus.swift`
3. Tests already exist, verify they pass

**Phase 3: Extract ID Mapping**
1. Create `IDMapping` package
2. Move `SnowflakeIDGenerator.swift`
3. Write tests for `IDMappingService` (Step 3)
4. Implement `IDMappingService`
5. Tests already exist for generator, verify they pass

**Phase 4: Build Each Package Following TDD Steps 1-9**
- Follow the TDD steps outlined earlier
- Each package tested independently before integration

**Phase 5: Main App Integration**
- Wire up all packages in main `App.swift`
- Integration tests across packages

---

## Testing Strategy

### Unit Tests (Per Package)
- All services and transformers tested in isolation within their package
- Mock external dependencies
- Mock ATProtoKit responses
- Mock cache layer

### Integration Tests (Cross-Package)
- Full request/response cycle in main app
- Real cache interactions (test Redis instance)
- Authentication flow end-to-end
- Verify package boundaries work correctly

### Test Coverage Goals
- Minimum 80% code coverage per package
- 100% coverage for critical paths (auth, translation)
- All public APIs of each package tested

---

## Deployment Considerations

### Environment Variables
```bash
# Server
PORT=8080
HOSTNAME=0.0.0.0

# Redis/Valkey
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

### Docker Support
- [ ] Create Dockerfile
- [ ] Docker Compose with Redis
- [ ] Health check endpoint

### Performance Targets
- API response time: < 200ms (p95)
- Timeline load: < 500ms
- Cache hit ratio: > 90%
- Concurrent users: 100+

---

## Known Limitations (from SkyBridge)

1. **No Pinned Posts** - Bluesky doesn't support pinned posts (return empty array)
2. **No Familiar Followers** - Not implemented (return empty array)
3. **Public Timeline** - Delegates to home timeline (Bluesky doesn't have global public feed)
4. **Basic Functionality** - This is an MVP, expect bugs and missing features
5. **Rate Limiting** - Subject to Bluesky API rate limits

---

## Future Enhancements

- [ ] Database support (SQLite/PostgreSQL) for persistent storage
- [ ] Backfilling old posts
- [ ] WebSocket support for streaming API
- [ ] Metrics and observability (Prometheus)
- [ ] Admin dashboard
- [ ] Multi-user support with proper isolation
- [ ] Custom emoji support
- [ ] Poll support (if Bluesky adds it)

---

## Contributing Guidelines

1. Follow TDD methodology - write tests first
2. Maintain 80%+ test coverage
3. Use Swift 6.0 concurrency features (async/await, actors)
4. Follow Swift API Design Guidelines
5. Document public APIs with DocC comments
6. Run `swift test` before committing
7. Update this plan as implementation progresses

---

## Timeline Estimate (Modular TDD Approach)

### Phase 0: Package Structure Setup ✅ (COMPLETED)
- [x] Initial project structure ✅
- [x] Create all package directories ✅
- [x] Update Package.swift with all targets ✅
- [x] Set up test structure for each package ✅

### Phase 1: Core Packages (3-4 days) - IN PROGRESS
- [x] **ArchaeopteryxCore** ✅
  - [x] Write tests for error types, configuration
  - [x] Implement core utilities (errors, protocols)
  - [x] Move existing Configuration.swift

- [x] **MastodonModels** ✅ (Partial - Account and Status done)
  - [x] Move existing models (Account, Status)
  - [ ] Write tests for new models (Notification, Relationship, List, Instance, OAuth)
  - [ ] Implement new models
  - [x] Verify all model tests pass (5/5 tests passing)

- [x] **IDMapping** ✅
  - [x] Move SnowflakeIDGenerator
  - [x] Write tests for IDMappingService (12 tests)
  - [x] Implement IDMappingService with deterministic DID hashing (SHA-256)
  - [x] Integration with CacheProtocol

- [ ] **CacheLayer** - NEXT UP
  - [ ] Write tests for CacheService protocol
  - [ ] Implement ValkeyCache with RediStack
  - [ ] Implement InMemoryCache for testing
  - [ ] Test TTL, serialization, connection handling

### Phase 2: Integration Packages (3-4 days)
- [ ] **ATProtoAdapter** (1.5-2 days)
  - Write tests for ATProtoClient
  - Implement session management
  - Implement convenience methods around ATProtoKit
  - Error mapping from AT Protocol to internal errors

- [ ] **TranslationLayer** (1.5-2 days)
  - Write tests for FacetProcessor (rich text → HTML)
  - Implement FacetProcessor
  - Write tests for TranslationService (profiles, posts, notifications)
  - Implement TranslationService
  - Handle edge cases (missing fields, fallbacks)

### Phase 3: Authentication (2-3 days)
- [ ] **OAuthService** (2-3 days)
  - Write tests for OAuth models
  - Implement OAuth models
  - Write tests for OAuthService (app registration, token exchange, validation)
  - Implement OAuthService
  - Write tests for OAuth routes
  - Implement OAuth routes
  - Write tests for AuthMiddleware
  - Implement AuthMiddleware

### Phase 4: API Endpoints (5-7 days)
- [ ] **Instance Routes** (0.5 day) - Low complexity, static data
- [ ] **Account Routes** (1-1.5 days) - Core functionality
- [ ] **Status Routes** (1.5-2 days) - Complex with media, threads
- [ ] **Timeline Routes** (1 day) - Pagination, feed logic
- [ ] **Notification Routes** (0.5-1 day) - Type mapping
- [ ] **Media Routes** (1 day) - Upload handling, blob storage
- [ ] **Search Routes** (0.5-1 day) - Query translation
- [ ] **List Routes** (0.5 day) - Feed mapping

### Phase 5: Production Readiness (2-3 days)
- [ ] Rate limiting middleware (0.5 day)
- [ ] Error handling middleware (0.5 day)
- [ ] Logging middleware (0.5 day)
- [ ] Integration tests across all packages (1 day)
- [ ] Performance testing and optimization (0.5 day)
- [ ] Documentation (README, API docs, deployment guide) (0.5 day)

### Phase 6: Optional Enhancements (If time permits)
- [ ] WebSocket streaming support (2-3 days)
- [ ] Admin dashboard (2-3 days)
- [ ] Metrics/observability (1-2 days)

---

**Total Estimated Time for MVP**: 16-22 days

**Timeline Breakdown**:
- Package setup: 1 day
- Core packages: 3-4 days
- Integration packages: 3-4 days
- Authentication: 2-3 days
- API endpoints: 5-7 days
- Production readiness: 2-3 days

**Critical Path**:
1. ArchaeopteryxCore → MastodonModels → IDMapping → CacheLayer
2. ATProtoAdapter → TranslationLayer
3. OAuthService → AuthMiddleware
4. All Routes (can be parallelized to some degree)

---

## Getting Started - Next Immediate Steps

### Step 1: Package Structure (Today)
```bash
# Create package directories
mkdir -p Sources/{ArchaeopteryxCore,MastodonModels,IDMapping,CacheLayer,ATProtoAdapter,TranslationLayer,OAuthService}
mkdir -p Tests/{ArchaeopteryxCoreTests,MastodonModelsTests,IDMappingTests,CacheLayerTests,ATProtoAdapterTests,TranslationLayerTests,OAuthServiceTests}

# Update Package.swift with new structure (use the template above)
```

### Step 2: Start with ArchaeopteryxCore (TDD)
```bash
# 1. Write tests
touch Tests/ArchaeopteryxCoreTests/ArchaeopteryxCoreTests.swift

# 2. Run tests (they should fail)
swift test --filter ArchaeopteryxCoreTests

# 3. Implement
touch Sources/ArchaeopteryxCore/ArchaeopteryxError.swift

# 4. Repeat until green
```

### Step 3: Extract Existing Code
```bash
# Move Configuration to Core
mv Sources/Archaeopteryx/Configuration.swift Sources/ArchaeopteryxCore/

# Move Models to MastodonModels package
mv Sources/Archaeopteryx/Models/MastodonAccount.swift Sources/MastodonModels/
mv Sources/Archaeopteryx/Models/MastodonStatus.swift Sources/MastodonModels/
mv Tests/ArchaeopteryxTests/Models/* Tests/MastodonModelsTests/

# Move SnowflakeIDGenerator to IDMapping
mv Sources/Archaeopteryx/Services/SnowflakeIDGenerator.swift Sources/IDMapping/
mv Tests/ArchaeopteryxTests/Services/SnowflakeIDGeneratorTests.swift Tests/IDMappingTests/

# Verify tests still pass
swift test
```

### Step 4: Follow TDD Steps 1-17
Proceed with the detailed TDD steps outlined earlier in this document.

---

Last Updated: 2025-10-11
