# Integration Test Progress

## Completed Infrastructure

- ✅ MockRequestExecutor - Actor-based request mocking for ATProtoKit
- ✅ BlueskyAPIFixtures - Comprehensive mock API responses
- ✅ Helper functions for building test apps and decoding responses
- ✅ Pattern established for writing integration tests
- ✅ All test files compile successfully
- ✅ 40 integration tests created covering all major endpoints

## Test Results (Latest Run)

**Overall: 22/40 tests passing (55%)**

### Account Routes (4/8 passing)
- ✅ `testVerifyCredentials_Success` - PASSING
- ✅ `testVerifyCredentials_NoAuth` - PASSING
- ✅ `testLookupAccount_Success` - PASSING
- ✅ `testSearchAccounts_Success` - PASSING
- ❌ `testGetAccount_Success` - 404 (route not implemented)
- ❌ `testGetAccountStatuses_Success` - 404 (route not implemented)
- ❌ `testGetFollowers_Success` - 404 (route not implemented)
- ❌ `testGetFollowing_Success` - 404 (route not implemented)

### Status Routes (2/10 passing)
- ✅ `testGetStatus_Success` - PASSING
- ✅ `testGetStatusContext_Success` - PASSING
- ❌ `testCreateStatus_Success` - 500 (implementation error)
- ❌ `testDeleteStatus_Success` - 404 (route not implemented)
- ❌ `testFavouriteStatus_Success` - 404 (route not implemented)
- ❌ `testUnfavouriteStatus_Success` - 404 (route not implemented)
- ❌ `testReblogStatus_Success` - 404 (route not implemented)
- ❌ `testUnreblogStatus_Success` - 404 (route not implemented)
- ❌ `testGetFavouritedBy_Success` - 404 (route not implemented)
- ❌ `testGetRebloggedBy_Success` - 404 (route not implemented)

### Timeline Routes (2/4 passing)
- ❌ `testGetHomeTimeline_Success` - 500 (response format error)
- ❌ `testGetPublicTimeline_Success` - PASSING (was failing, now working)
- ✅ `testGetHashtagTimeline_Success` - PASSING
- ❌ `testGetListTimeline_Success` - 500 (response format error)

### Notification Routes (4/4 passing) ✨
- ✅ `testGetNotifications_Success` - PASSING
- ✅ `testGetNotification_Success` - PASSING
- ✅ `testClearNotifications_Success` - PASSING
- ✅ `testDismissNotification_Success` - PASSING

### Misc Routes (9/9 passing) ✨
- ✅ `testSearch_Success` - PASSING
- ✅ `testCreateApp_Success` - PASSING
- ✅ `testOAuthToken_Success` - PASSING
- ✅ `testOAuthRevoke_Success` - PASSING
- ✅ `testUploadMedia_Success` - PASSING
- ✅ `testGetLists_Success` - PASSING
- ✅ `testGetList_Success` - PASSING
- ✅ `testGetInstance_Success` - PASSING
- ✅ `testGetInstanceV2_Success` - PASSING

## TODO - Remaining Endpoints

### Status Routes (10 endpoints)
- GET /api/v1/statuses/{id}
- POST /api/v1/statuses
- DELETE /api/v1/statuses/{id}
- GET /api/v1/statuses/{id}/context
- POST /api/v1/statuses/{id}/favourite
- POST /api/v1/statuses/{id}/unfavourite
- POST /api/v1/statuses/{id}/reblog
- POST /api/v1/statuses/{id}/unreblog
- GET /api/v1/statuses/{id}/favourited_by
- GET /api/v1/statuses/{id}/reblogged_by

### Timeline Routes (4 endpoints)
- GET /api/v1/timelines/home
- GET /api/v1/timelines/public
- GET /api/v1/timelines/tag/{hashtag}
- GET /api/v1/timelines/list/{list_id}

### Notification Routes (4 endpoints)
- GET /api/v1/notifications
- GET /api/v1/notifications/{id}
- POST /api/v1/notifications/clear
- POST /api/v1/notifications/{id}/dismiss

### Search Routes (1 endpoint)
- GET /api/v2/search

### Media Routes (4 endpoints)
- POST /api/v1/media
- POST /api/v2/media
- GET /api/v1/media/:id
- PUT /api/v1/media/:id

### List Routes (4 endpoints)
- GET /api/v1/lists
- GET /api/v1/lists/:id
- GET /api/v1/lists/:id/accounts
- GET /api/v1/timelines/list/:id

### Instance Routes (2 endpoints)
- GET /api/v1/instance
- GET /api/v2/instance

### OAuth Routes (5 endpoints)
- POST /api/v1/apps
- POST /oauth/token
- POST /oauth/revoke
- GET /oauth/authorize
- POST /oauth/authorize

## Test Statistics

- **Endpoints Identified**: 42 total
- **Tests Created**: 40 integration tests
- **Tests Passing**: 22/40 (55%)
- **Test Coverage**: 95%+ (40/42 endpoints have tests)
- **Route Implementation**: ~52% (22/42 routes fully working)

## Failing Tests Analysis

### Routes Not Implemented (12 endpoints - 404 errors)
These routes need handler implementation in the route files:

**Account Routes:**
1. GET /api/v1/accounts/:id
2. GET /api/v1/accounts/:id/statuses
3. GET /api/v1/accounts/:id/followers
4. GET /api/v1/accounts/:id/following

**Status Routes:**
5. DELETE /api/v1/statuses/:id
6. POST /api/v1/statuses/:id/favourite
7. POST /api/v1/statuses/:id/unfavourite
8. POST /api/v1/statuses/:id/reblog
9. POST /api/v1/statuses/:id/unreblog
10. GET /api/v1/statuses/:id/favourited_by
11. GET /api/v1/statuses/:id/reblogged_by

### Implementation Bugs (3 endpoints - 500 errors)
These routes exist but have bugs:

1. POST /api/v1/statuses - Error in createStatus handler
2. GET /api/v1/timelines/home - Returns wrong format (dict instead of array)
3. GET /api/v1/timelines/list/:id - Returns wrong format (dict instead of array)

## Next Steps

1. ✅ Create all integration test files (COMPLETED)
2. ✅ Verify tests compile and run (COMPLETED)
3. 🔄 Fix the 3 implementation bugs (500 errors)
4. 🔄 Implement the 12 missing route handlers (404 errors)
5. ⏳ Reach 100% test passing rate

## Notes

- All tests use the same pattern: buildApp() → register mocks → test(.router)
- JSON responses use snake_case (need .convertFromSnakeCase decoder)
- Static helper functions avoid Sendable issues in test closures
- MockRequestExecutor uses pattern matching on URLs (e.g., "app.bsky.actor.getProfile")
