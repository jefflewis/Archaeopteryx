# Limitations

Known constraints from Bluesky API differences.

## Overview

Archaeopteryx bridges Mastodon's API to Bluesky's AT Protocol. Some Mastodon features don't have Bluesky equivalents and can't be fully supported.

## Unsupported Features

### Bluesky Doesn't Have

| Feature | Status | Workaround |
|---------|--------|------------|
| Pinned posts | ❌ Returns empty array | Use bio link |
| Custom emojis | ❌ Returns empty array | Unicode emojis only |
| Polls | ❌ Not implemented | External poll service |
| Post editing | ❌ Can't edit | Delete and repost |
| Private posts | ⚠️ Maps to public | Use Bluesky DMs |
| Content filters | ❌ No server-side | Client-side filtering |
| Hashtag timelines | ⚠️ Limited | Use search instead |
| Trending | ❌ No API | N/A |
| Streaming | ❌ No WebSocket | Poll every 30-60s |

### Read-Only Features

- **Lists** - Maps to Bluesky feeds, can view but not create/edit
- **Bookmarks** - No bookmark API in Bluesky

### Stub Endpoints

These endpoints return empty arrays but don't error:

```
GET /api/v1/accounts/:id/featured_tags    → []
GET /api/v1/accounts/:id/familiar_followers → []
GET /api/v1/bookmarks                     → []
GET /api/v1/suggestions                   → []
GET /api/v1/filters                       → []
GET /api/v1/trends/*                      → []
```

## Behavioral Differences

### Character Limit

- **Mastodon**: 500 characters
- **Bluesky**: 300 characters

Posts over 300 characters are rejected with `422 Unprocessable Entity`.

### Public Timeline

`GET /api/v1/timelines/public` returns the authenticated user's home timeline because Bluesky doesn't have a global public feed.

### Visibility Levels

All posts are public on Bluesky:

- `public` ✅ Works as expected
- `unlisted` → Treated as public
- `private` → Treated as public
- `direct` → Use Bluesky direct messages

### Notification Dismissal

`POST /api/v1/notifications/:id/dismiss` returns `200 OK` but doesn't actually dismiss the notification (Bluesky doesn't support this).

## Performance Characteristics

### Rate Limits

- **Unauthenticated**: 300 requests per 5 minutes per IP
- **Authenticated**: 1000 requests per 5 minutes per user
- **Bluesky upstream**: ~3000 requests per 5 minutes

### Cache TTLs

Response caching delays:

- **Profiles**: 15 minutes
- **Posts**: 5 minutes
- **Timelines**: 2 minutes
- **ID mappings**: Never expire (deterministic)

Changes you make may take up to 15 minutes to appear.

### Search Latency

Bluesky search can be slow (1-2 seconds). Complex queries may timeout.

## ID Mapping

Archaeopteryx generates Mastodon-compatible Snowflake IDs:

- **DIDs**: Deterministic SHA-256 hash → Int64
- **AT URIs**: Time-based Snowflake generation

> Important: IDs are not compatible with real Mastodon instances.

## OAuth Scopes

Bluesky doesn't have a scope system. All Mastodon scopes (`read`, `write`, `follow`) grant full access to your Bluesky account.

> Security: Only authorize apps you trust.

## Media Limitations

- Maximum 4 images per post
- Image size limit: 10MB
- Video size limit: 40MB
- Alt text supported (stored in post, not media object)

## Profile Fields

No custom fields support. Only these profile elements work:

- Display name
- Bio/description
- Avatar image
- Banner image

## Client Compatibility

### Works Well

- ✅ Ivory (iOS/macOS)
- ✅ Mona (iOS/macOS)
- ✅ Ice Cubes (iOS/macOS)
- ✅ Tusky (Android)
- ✅ Elk (Web)

### May Have Issues

Clients that rely heavily on:
- Pinned posts display
- Custom emoji reactions
- Poll creation/voting
- Advanced content filters
- Real-time streaming updates

## Recommendations

### For Client Developers

1. Check `max_toot_chars` in instance metadata (returns 300)
2. Handle empty arrays gracefully for unsupported features
3. Implement polling (30-60 seconds) instead of streaming
4. Warn users that all posts are public
5. Hide UI elements for unsupported features

### For Users

- Keep posts under 300 characters
- Use Unicode emojis (😊) not custom emojis
- Remember all posts are public
- Refresh timeline manually or every 30-60 seconds
- Create lists/feeds in the Bluesky app

## Future Improvements

These features may be added when Bluesky supports them:

- Custom emojis
- Polls
- Post editing
- Private/unlisted visibility
- Streaming API (via Bluesky firehose)
- List creation and management

## Reporting Issues

Found a limitation not listed here?

1. Check [existing issues](https://github.com/yourusername/archaeopteryx/issues)
2. Report with:
   - Affected endpoint
   - Expected behavior
   - Actual behavior
   - Bluesky API constraint (if known)

## See Also

- <doc:API-Reference> - Complete API documentation
- <doc:Client-Setup> - Setting up compatible clients
- <doc:Getting-Started> - Running Archaeopteryx locally
