# API Reference

Complete Mastodon API endpoint reference for Archaeopteryx.

## Overview

Archaeopteryx implements 44 Mastodon API endpoints that translate to AT Protocol calls. All endpoints follow the [Mastodon API specification](https://docs.joinmastodon.org/api/).

**Base URL**: `http://localhost:8080` (local) or your deployment URL

## Authentication

Most endpoints require a Bearer token:

```http
Authorization: Bearer YOUR_ACCESS_TOKEN
```

Get a token via the OAuth flow (see below).

## Quick Reference

### Endpoint Categories

- **OAuth & Apps** (5 endpoints) - App registration and authentication
- **Instance** (2 endpoints) - Server metadata
- **Accounts** (10 endpoints) - User profiles and relationships
- **Statuses** (10 endpoints) - Posts and interactions
- **Timelines** (4 endpoints) - Feed retrieval
- **Notifications** (4 endpoints) - Activity notifications
- **Media** (4 endpoints) - File uploads
- **Search** (1 endpoint) - Search across content types
- **Lists** (4 endpoints) - Custom feeds

## OAuth & Apps

### Register App

Create application credentials:

```http
POST /api/v1/apps
Content-Type: application/json

{
  "client_name": "MyApp",
  "redirect_uris": "urn:ietf:wg:oauth:2.0:oob",
  "scopes": "read write follow"
}
```

**Response**:
```json
{
  "client_id": "generated_id",
  "client_secret": "generated_secret"
}
```

### Get Access Token

Password grant flow:

```http
POST /oauth/token
Content-Type: application/json

{
  "grant_type": "password",
  "username": "alice.bsky.social",
  "password": "your-app-password",
  "client_id": "generated_id",
  "client_secret": "generated_secret"
}
```

**Response**:
```json
{
  "access_token": "token_value",
  "token_type": "Bearer",
  "scope": "read write follow"
}
```

### Revoke Token

```http
POST /oauth/revoke
Content-Type: application/json

{"token": "token_to_revoke"}
```

## Instance

### Get Instance Info (v1)

```http
GET /api/v1/instance
```

Returns server metadata including character limits and version.

### Get Instance Info (v2)

```http
GET /api/v2/instance
```

Same as v1.

## Accounts

### Verify Credentials

Get the authenticated user's account:

```http
GET /api/v1/accounts/verify_credentials
Authorization: Bearer YOUR_TOKEN
```

### Lookup Account

Find account by handle:

```http
GET /api/v1/accounts/lookup?acct=alice.bsky.social
Authorization: Bearer YOUR_TOKEN
```

### Get Account

```http
GET /api/v1/accounts/:id
Authorization: Bearer YOUR_TOKEN
```

### Get Account Statuses

```http
GET /api/v1/accounts/:id/statuses?limit=20
Authorization: Bearer YOUR_TOKEN
```

**Query parameters**:
- `limit` - Max results (default 20, max 40)
- `max_id` - Return older than this ID
- `since_id` - Return newer than this ID

### Get Followers

```http
GET /api/v1/accounts/:id/followers?limit=20
Authorization: Bearer YOUR_TOKEN
```

### Get Following

```http
GET /api/v1/accounts/:id/following?limit=20
Authorization: Bearer YOUR_TOKEN
```

### Follow Account

```http
POST /api/v1/accounts/:id/follow
Authorization: Bearer YOUR_TOKEN
```

### Unfollow Account

```http
POST /api/v1/accounts/:id/unfollow
Authorization: Bearer YOUR_TOKEN
```

### Get Relationships

```http
GET /api/v1/accounts/relationships?id[]=123&id[]=456
Authorization: Bearer YOUR_TOKEN
```

### Search Accounts

```http
GET /api/v1/accounts/search?q=alice&limit=20
Authorization: Bearer YOUR_TOKEN
```

## Statuses

### Get Status

```http
GET /api/v1/statuses/:id
Authorization: Bearer YOUR_TOKEN
```

### Create Status

```http
POST /api/v1/statuses
Authorization: Bearer YOUR_TOKEN
Content-Type: application/json

{
  "status": "Hello from Archaeopteryx!",
  "visibility": "public"
}
```

### Delete Status

```http
DELETE /api/v1/statuses/:id
Authorization: Bearer YOUR_TOKEN
```

### Get Context (Thread)

```http
GET /api/v1/statuses/:id/context
Authorization: Bearer YOUR_TOKEN
```

Returns ancestors and descendants.

### Like/Favourite

```http
POST /api/v1/statuses/:id/favourite
Authorization: Bearer YOUR_TOKEN
```

### Unlike/Unfavourite

```http
POST /api/v1/statuses/:id/unfavourite
Authorization: Bearer YOUR_TOKEN
```

### Repost/Reblog

```http
POST /api/v1/statuses/:id/reblog
Authorization: Bearer YOUR_TOKEN
```

### Unrepost/Unreblog

```http
POST /api/v1/statuses/:id/unreblog
Authorization: Bearer YOUR_TOKEN
```

### Get Favourited By

```http
GET /api/v1/statuses/:id/favourited_by?limit=20
Authorization: Bearer YOUR_TOKEN
```

### Get Reblogged By

```http
GET /api/v1/statuses/:id/reblogged_by?limit=20
Authorization: Bearer YOUR_TOKEN
```

## Timelines

### Home Timeline

```http
GET /api/v1/timelines/home?limit=20
Authorization: Bearer YOUR_TOKEN
```

### Public Timeline

```http
GET /api/v1/timelines/public?limit=20
```

> Note: Returns home timeline (Bluesky has no global public feed)

### Hashtag Timeline

```http
GET /api/v1/timelines/tag/:hashtag?limit=20
Authorization: Bearer YOUR_TOKEN
```

> Note: Limited support, often returns empty

### List Timeline

```http
GET /api/v1/timelines/list/:id?limit=20
Authorization: Bearer YOUR_TOKEN
```

## Notifications

### Get Notifications

```http
GET /api/v1/notifications?limit=20
Authorization: Bearer YOUR_TOKEN
```

**Types**: `mention`, `favourite`, `reblog`, `follow`

### Get Single Notification

```http
GET /api/v1/notifications/:id
Authorization: Bearer YOUR_TOKEN
```

### Clear All Notifications

```http
POST /api/v1/notifications/clear
Authorization: Bearer YOUR_TOKEN
```

### Dismiss Notification

```http
POST /api/v1/notifications/:id/dismiss
Authorization: Bearer YOUR_TOKEN
```

## Media

### Upload Media

```http
POST /api/v1/media
Authorization: Bearer YOUR_TOKEN
Content-Type: multipart/form-data

file=@image.jpg
```

Also available at `/api/v2/media`.

### Get Media

```http
GET /api/v1/media/:id
Authorization: Bearer YOUR_TOKEN
```

### Update Media

Add alt text:

```http
PUT /api/v1/media/:id
Authorization: Bearer YOUR_TOKEN
Content-Type: application/json

{"description": "Alt text for image"}
```

## Search

### Search

```http
GET /api/v2/search?q=alice&type=accounts&limit=20
Authorization: Bearer YOUR_TOKEN
```

**Query parameters**:
- `q` - Search query (required)
- `type` - Filter: `accounts`, `statuses`, `hashtags`
- `limit` - Max results

**Response**:
```json
{
  "accounts": [...],
  "statuses": [...],
  "hashtags": [...]
}
```

## Lists

### Get User's Lists

```http
GET /api/v1/lists
Authorization: Bearer YOUR_TOKEN
```

Returns Bluesky feeds as lists.

### Get List

```http
GET /api/v1/lists/:id
Authorization: Bearer YOUR_TOKEN
```

### Get List Accounts

```http
GET /api/v1/lists/:id/accounts?limit=20
Authorization: Bearer YOUR_TOKEN
```

### Get List Timeline

```http
GET /api/v1/timelines/list/:id?limit=20
Authorization: Bearer YOUR_TOKEN
```

## Pagination

All list endpoints support pagination:

```http
?limit=20&max_id=older_than_this&since_id=newer_than_this
```

Responses include Link headers:

```http
Link: <https://...?max_id=123>; rel="next"
```

## Rate Limits

- **Unauthenticated**: 300 requests / 5 minutes per IP
- **Authenticated**: 1000 requests / 5 minutes per user

**Response headers**:
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 995
X-RateLimit-Reset: 1234567890
```

## Error Responses

```json
{
  "error": "Error message",
  "error_description": "Detailed description"
}
```

**Status codes**:
- `400` - Bad request
- `401` - Unauthorized
- `404` - Not found
- `422` - Validation failed
- `429` - Rate limit exceeded
- `500` - Internal server error

## Testing with cURL

```bash
# Get instance info
curl http://localhost:8080/api/v1/instance

# Register app
curl -X POST http://localhost:8080/api/v1/apps \
  -d "client_name=TestApp" \
  -d "redirect_uris=urn:ietf:wg:oauth:2.0:oob" \
  -d "scopes=read write"

# Get token
curl -X POST http://localhost:8080/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "password",
    "username": "your.handle",
    "password": "your-app-password",
    "client_id": "CLIENT_ID",
    "client_secret": "CLIENT_SECRET"
  }'

# Get home timeline
curl http://localhost:8080/api/v1/timelines/home \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## See Also

- <doc:Getting-Started> - Run Archaeopteryx locally
- <doc:Client-Setup> - Connect Mastodon clients
- <doc:Limitations> - What's not supported
- [Complete API Reference](https://github.com/yourusername/archaeopteryx/blob/main/API_REFERENCE.md) - Full details with examples
