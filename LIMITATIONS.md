# Limitations

Known constraints from Bluesky API differences.

## Not Supported

### Bluesky Doesn't Have

- **Pinned posts** - `GET /api/v1/accounts/:id/statuses?pinned=true` → `[]`
- **Custom emojis** - `GET /api/v1/custom_emojis` → `[]`
- **Polls** - Not implemented
- **Post editing** - Delete and repost instead
- **Private posts** - All visibility levels map to public
- **Content filters** - No server-side filtering
- **Hashtag timelines** - Limited search support
- **Trending** - No trending API
- **Streaming** - No WebSocket support yet

### Read-Only

- **Lists** - Maps to Bluesky feeds, can't create/edit
- **Bookmarks** - No bookmark API

### Stub Endpoints

Return empty but don't error:

- `GET /api/v1/accounts/:id/featured_tags` → `[]`
- `GET /api/v1/accounts/:id/familiar_followers` → `[]`
- `GET /api/v1/bookmarks` → `[]`
- `GET /api/v1/suggestions` → `[]`
- `GET /api/v1/filters` → `[]`
- `GET /api/v1/trends/*` → `[]`

## Behavioral Differences

### Character Limit

- Mastodon: 500 chars
- Bluesky: 300 chars

Posts over 300 rejected with 422.

### Public Timeline

`GET /api/v1/timelines/public` returns home timeline (no global feed in Bluesky).

### Visibility

All posts are public:
- `public` ✅
- `unlisted` → public
- `private` → public
- `direct` → use Bluesky DMs

### Notification Dismissal

`POST /api/v1/notifications/:id/dismiss` returns 200 but does nothing (Bluesky doesn't support).

### Unlike/Unrepost

Requires caching record URIs from original action. Implementation tracks via cache.

## Performance

### Rate Limits

- Unauthenticated: 300 req/5min per IP
- Authenticated: 1000 req/5min per user

Bluesky upstream: ~3000 req/5min.

### Cache TTLs

- Profiles: 15 min
- Posts: 5 min
- Timelines: 2 min
- ID mappings: never expire

Changes may take up to 15min to appear.

### Search Latency

Bluesky search can be slow (1-2s). May timeout on complex queries.

## ID Mapping

Archaeopteryx generates Snowflake IDs from:
- DIDs: deterministic SHA-256 hash
- AT URIs: time-based generation

IDs not compatible with real Mastodon instances.

## OAuth Scopes

Bluesky has no scope system. All Mastodon scopes grant full access.

**Security**: Only authorize trusted apps.

## Media

- Max 4 images per post
- Image limit: 10MB
- Video limit: 40MB

Alt text works but stored in post, not media object.

## Profile Fields

No custom fields support. Only:
- Display name
- Bio
- Avatar
- Banner

## Quick Reference

| Feature | Status | Workaround |
|---------|--------|------------|
| Pinned posts | ❌ | Use bio link |
| Custom emojis | ❌ | Unicode only |
| Polls | ❌ | External poll service |
| Edit posts | ❌ | Delete + repost |
| Private posts | ❌ | Use Bluesky DMs |
| Lists | Read-only | Create in Bluesky app |
| Hashtag timeline | Limited | Use search |
| Streaming | ❌ | Poll every 30-60s |
| Content filters | ❌ | Client-side filtering |

## Client Compatibility

### Works Well

- Ivory (iOS)
- Mona (iOS)
- Ice Cubes (iOS)
- Tusky (Android)
- Elk (Web)

### May Have Issues

Clients expecting:
- Pinned posts
- Custom emojis
- Poll creation
- Advanced filters
- Streaming updates

## Recommendations

### For Client Developers

1. Check `max_toot_chars` in instance metadata (300)
2. Handle empty arrays for unsupported features
3. Implement polling (30-60s) for timeline updates
4. Warn users about public-only visibility
5. Hide UI for unsupported features

### For Users

- Keep posts under 300 characters
- Use Unicode emojis only
- All posts are public
- Poll API every 30-60s for updates
- Create lists/feeds in Bluesky app

## Future

Planned when Bluesky adds support:

- Custom emojis
- Polls
- Post editing
- Private messages
- Streaming API (via firehose)
- List creation

## Reporting

Found a limitation not listed?

1. Check existing issues
2. Report at: https://github.com/yourusername/archaeopteryx/issues
3. Include:
   - Affected endpoint
   - Expected behavior
   - Actual behavior
   - Bluesky API constraint (if known)
