# Archaeopteryx Limitations

This document describes known limitations and differences between Archaeopteryx (Bluesky via AT Protocol) and native Mastodon functionality.

## Overview

Archaeopteryx translates between the Mastodon API and Bluesky's AT Protocol. Due to fundamental differences between these platforms, some Mastodon features cannot be fully implemented or have behavioral differences.

---

## Category 1: Bluesky Platform Limitations

These limitations exist because Bluesky doesn't have equivalent features.

### 1.1 Pinned Posts

**Status**: Not supported ❌

**Reason**: Bluesky doesn't have a concept of pinned posts

**Behavior**:
- `GET /api/v1/accounts/:id/statuses?pinned=true` - Returns empty array
- Account objects always show `pinned: []`

**Workaround**: None available

---

### 1.2 Custom Emojis

**Status**: Not supported ❌

**Reason**: Bluesky doesn't support custom emojis yet

**Behavior**:
- `GET /api/v1/custom_emojis` - Returns empty array
- Account and status objects show `emojis: []`
- Unicode emojis work normally

**Workaround**: Use Unicode emojis (😀, 🎉, etc.)

**Future**: Bluesky may add custom emoji support in the future

---

### 1.3 Polls

**Status**: Not supported ❌

**Reason**: Bluesky doesn't support polls

**Behavior**:
- `POST /api/v1/statuses` with `poll` parameter - Returns error 422
- Status objects never have `poll` field

**Workaround**: Use text-based voting or external poll services

**Future**: Bluesky may add poll support in the future

---

### 1.4 Content Warnings / Spoiler Text

**Status**: Partial support ⚠️

**Reason**: Bluesky has limited content warning support

**Behavior**:
- `POST /api/v1/statuses` with `spoiler_text` - Sets post as sensitive
- Spoiler text is prepended to post content
- No expandable UI like Mastodon

**Workaround**: Clearly mark sensitive content in post text

---

### 1.5 Post Editing

**Status**: Not supported ❌

**Reason**: Bluesky doesn't support editing posts (yet)

**Behavior**:
- `PUT /api/v1/statuses/:id` - Returns error 422
- No edit history available

**Workaround**: Delete and recreate posts

**Future**: Bluesky plans to add post editing

---

### 1.6 Post Visibility Levels

**Status**: Limited support ⚠️

**Reason**: Bluesky has simpler visibility model

**Mastodon Visibility Levels**:
- `public` - Fully supported ✅
- `unlisted` - Treated as `public` ⚠️
- `private` - Not supported ❌ (treated as `public`)
- `direct` - Not supported ❌ (use DMs instead)

**Behavior**:
- All posts created via Archaeopteryx are `public`
- `visibility` parameter is accepted but has no effect
- Posts always appear in public timelines

**Workaround**: None for private posts. Use Bluesky's direct message feature for private communication.

---

### 1.7 Content Filters

**Status**: Not supported ❌

**Reason**: Bluesky doesn't have server-side content filtering

**Behavior**:
- `GET /api/v1/filters` - Returns empty array
- `POST /api/v1/filters` - Returns error 422
- No keyword filtering or hide/warning actions

**Workaround**: Use client-side filtering if your Mastodon client supports it

---

### 1.8 Featured Hashtags

**Status**: Not supported ❌

**Reason**: Bluesky doesn't have featured hashtags on profiles

**Behavior**:
- `GET /api/v1/featured_tags` - Returns empty array
- Account objects show `featured_tags: []`

**Workaround**: Include important hashtags in your bio

---

### 1.9 Account Migration

**Status**: Not supported ❌

**Reason**: Bluesky uses DIDs for identity, no migration needed

**Behavior**:
- `POST /api/v1/accounts/:id/follow?reblogs=false` - `reblogs` parameter ignored
- No account aliases or redirects
- No "moved" status on accounts

**Workaround**: DIDs are portable - change your handle or PDS without migration

---

## Category 2: API Implementation Limitations

These limitations are specific to Archaeopteryx's current implementation.

### 2.1 Lists (Read-Only)

**Status**: Read-only ⚠️

**Reason**: Implementation limitation (Bluesky feeds could be mapped)

**Behavior**:
- `GET /api/v1/lists` - Returns empty array (MVP)
- `POST /api/v1/lists` - Returns error 422
- `PUT /api/v1/lists/:id` - Returns error 404
- `DELETE /api/v1/lists/:id` - Returns error 404
- `POST /api/v1/lists/:id/accounts` - Returns error 422

**Workaround**: Use Bluesky app to manage custom feeds

**Future Enhancement**: Map Bluesky custom feeds to Mastodon lists

---

### 2.2 Single Notification Retrieval

**Status**: Not supported ❌

**Reason**: Implementation limitation (requires notification caching)

**Behavior**:
- `GET /api/v1/notifications/:id` - Always returns 404
- `GET /api/v1/notifications` works correctly (list all)

**Workaround**: Fetch all notifications and filter client-side

**Future Enhancement**: Implement notification caching

---

### 2.3 Unlike/Unrepost/Unfollow Record Tracking

**Status**: Limited ⚠️

**Reason**: AT Protocol requires record URIs for deletions

**Behavior**:
- **First like/repost/follow**: Works perfectly ✅
- **Unlike/unrepost/unfollow**: Requires record URI from previous action
- Record URIs not currently stored in user's session

**Workaround**:
- For testing: Like, then immediately unlike in same session
- For production: Fetch relationship status before attempting to unlike/unfollow

**Example Issue**:
```bash
# This works
curl -X POST /api/v1/statuses/:id/favourite  # Returns status with like

# This fails
curl -X POST /api/v1/statuses/:id/unfavourite  # Error: like record URI not found
```

**Future Enhancement**: Store like/repost/follow record URIs in cache keyed by user+post/user+target

---

### 2.4 Hashtag Timeline

**Status**: Limited support ⚠️

**Reason**: Bluesky search works differently than Mastodon

**Behavior**:
- `GET /api/v1/timelines/tag/:hashtag` - Returns empty array (MVP)
- Hashtag search via `/api/v2/search` returns basic results

**Workaround**: Use general search instead

**Future Enhancement**: Implement Bluesky's search API for hashtag posts

---

### 2.5 Status Search

**Status**: Not supported ❌

**Reason**: Bluesky API limitation (search is limited)

**Behavior**:
- `GET /api/v2/search?type=statuses` - Returns empty array
- Only account search works (`type=accounts`)

**Workaround**: Search for accounts instead, then browse their posts

**Future**: Depends on Bluesky expanding search API

---

### 2.6 Familiar Followers

**Status**: Not supported ❌

**Reason**: Implementation limitation (requires relationship graph traversal)

**Behavior**:
- `GET /api/v1/accounts/familiar_followers` - Returns empty array

**Workaround**: None

**Future Enhancement**: Implement by fetching mutual follows

---

### 2.7 Account Suggestions

**Status**: Not supported ❌

**Reason**: Implementation limitation (Bluesky has suggestions, not mapped)

**Behavior**:
- `GET /api/v2/suggestions` - Returns empty array

**Workaround**: Use Bluesky app to find suggested follows

**Future Enhancement**: Map Bluesky's suggestion algorithm

---

### 2.8 Trends (Hashtags, Links, Statuses)

**Status**: Not supported ❌

**Reason**: Bluesky doesn't expose trending data via API

**Behavior**:
- `GET /api/v1/trends/tags` - Returns empty array
- `GET /api/v1/trends/links` - Returns empty array
- `GET /api/v1/trends/statuses` - Returns empty array

**Workaround**: Browse Bluesky app for trending content

---

## Category 3: Behavioral Differences

These features work but behave differently than Mastodon.

### 3.1 Public Timeline

**Status**: Redirects to home timeline ⚠️

**Reason**: Bluesky doesn't have a global public timeline

**Behavior**:
- `GET /api/v1/timelines/public` - Returns authenticated user's home timeline
- `local` and `remote` parameters ignored
- Effectively same as `/api/v1/timelines/home`

**Workaround**: Use custom feeds for topic-based discovery

---

### 3.2 Character Limits

**Status**: Different limits ⚠️

**Reason**: Bluesky has different constraints

**Mastodon**: 500 characters (default)
**Bluesky**: 300 characters

**Behavior**:
- Instance metadata reports 300 character limit
- Posts over 300 characters rejected with error 422

**Workaround**: Keep posts under 300 characters

---

### 3.3 Media Attachments per Post

**Status**: Different limits ⚠️

**Mastodon**: 4 images
**Bluesky**: 4 images (same!)

**File Size Limits**:
- Images: 10 MB
- Videos: 40 MB

**Workaround**: None needed - limits are reasonable

---

### 3.4 Account Fields

**Status**: Partial support ⚠️

**Reason**: Bluesky profiles are simpler

**Behavior**:
- Only `displayName`, `description`, `avatar`, `banner` supported
- Custom fields (like Mastodon's "Joined", "Website", etc.) not supported
- Account objects show empty `fields: []` array

**Workaround**: Include important links in bio

---

### 3.5 Notification Dismissal

**Status**: No-op ⚠️

**Reason**: Bluesky doesn't support per-notification dismissal

**Behavior**:
- `POST /api/v1/notifications/:id/dismiss` - Returns 200 but does nothing
- `POST /api/v1/notifications/clear` - Works correctly (marks all as read)

**Workaround**: Ignore individual notifications, or clear all

---

### 3.6 Relationship Attributes

**Status**: Simplified ⚠️

**Reason**: Bluesky has simpler relationship model

**Supported**:
- `following` - Whether you follow this account ✅
- `followed_by` - Whether they follow you ✅
- `blocking` - Whether you block them ✅
- `muting` - Whether you mute them ✅

**Not Supported**:
- `requested` - Always false (Bluesky follows are instant)
- `domain_blocking` - Always false (no domain-level blocks)
- `showing_reblogs` - Always true (can't hide reposts per-user)
- `endorsed` - Always false (no endorsements)
- `note` - Always empty string (no private notes on accounts)
- `notifying` - Always false (notifications are global)

---

## Category 4: Performance Characteristics

### 4.1 Rate Limiting

**Archaeopteryx Limits**:
- Unauthenticated: 300 requests / 5 minutes per IP
- Authenticated: 1000 requests / 5 minutes per user

**Bluesky Upstream Limits**:
- Subject to Bluesky API rate limits (typically more lenient)
- Heavy usage may hit upstream limits

**Behavior**:
- 429 Too Many Requests returned when limits exceeded
- `X-RateLimit-*` headers in all responses

---

### 4.2 Caching

**Cache TTLs**:
- Profiles: 15 minutes
- Posts: 5 minutes
- Timelines: 2 minutes
- ID mappings: Never expire (deterministic)

**Implications**:
- Changes on Bluesky may take up to 15 minutes to appear
- Fresh data: use cache bypass (not yet implemented)

**Workaround**: Wait for cache to expire, or restart Archaeopteryx

---

## Category 5: Known Issues

### 5.1 Media Attachment Updates

**Status**: Working ✅ (as of v1.0)

**Behavior**:
- `PUT /api/v1/media/:id` - Updates alt text correctly
- Must be owner of media attachment

---

### 5.2 OAuth Scope Granularity

**Status**: Coarse-grained ⚠️

**Reason**: Bluesky doesn't have OAuth scopes, all access is full

**Behavior**:
- All Mastodon scopes (`read`, `write`, `follow`, etc.) accepted
- All scopes grant full access to Bluesky account
- No way to limit permissions

**Security Implication**: Apps have full account access

**Workaround**: Only authorize trusted applications

---

### 5.3 Streaming API

**Status**: Not implemented ❌

**Reason**: WebSocket support not yet added

**Behavior**:
- `GET /api/v1/streaming/*` - Returns 404
- No real-time updates

**Workaround**: Poll timelines/notifications periodically

**Future Enhancement**: Implement WebSocket streaming using Bluesky's firehose

---

## Comparison Matrix

| Feature | Mastodon | Archaeopteryx (Bluesky) | Status |
|---------|----------|------------------------|--------|
| Posts (statuses) | ✅ | ✅ | Full support |
| Likes (favourites) | ✅ | ✅ | Full support |
| Reposts (reblogs) | ✅ | ✅ | Full support |
| Replies (threads) | ✅ | ✅ | Full support |
| Follows | ✅ | ✅ | Full support |
| Notifications | ✅ | ✅ | Full support |
| Media upload | ✅ | ✅ | Full support |
| Search (accounts) | ✅ | ✅ | Full support |
| Home timeline | ✅ | ✅ | Full support |
| Public timeline | ✅ | ⚠️ | Redirects to home |
| Hashtag timeline | ✅ | ❌ | Not supported |
| Search (statuses) | ✅ | ❌ | Not supported |
| Lists | ✅ | ⚠️ | Read-only (empty in MVP) |
| Pinned posts | ✅ | ❌ | Not supported |
| Custom emojis | ✅ | ❌ | Not supported |
| Polls | ✅ | ❌ | Not supported |
| Post editing | ✅ | ❌ | Not supported |
| Content filters | ✅ | ❌ | Not supported |
| Post visibility | ✅ | ⚠️ | Only public |
| Account migration | ✅ | N/A | DIDs are portable |
| Streaming API | ✅ | ❌ | Not implemented |
| Multi-user instance | ✅ | ⚠️ | Single-user (MVP) |

---

## Recommendations for Mastodon Client Developers

If you're developing a Mastodon client that may connect to Archaeopteryx:

### 1. Handle Empty Arrays Gracefully
- Pinned posts, custom emojis, lists, and filters will be empty
- Don't show UI sections for empty features

### 2. Respect Character Limits
- Check instance metadata for `max_toot_chars` (will be 300)
- Validate before sending to avoid 422 errors

### 3. Don't Rely on Visibility Levels
- All posts are public on Bluesky
- Warn users if they try to create private posts

### 4. Implement Polling for Real-Time Updates
- No streaming API available
- Poll every 30-60 seconds for notifications and timelines

### 5. Cache Record URIs
- If implementing unlike/unrepost, store record URIs from like/repost responses
- Otherwise, users can't undo actions

### 6. Provide Fallbacks for Missing Features
- Show "Not supported on Bluesky" messages for polls, custom emojis, etc.
- Disable UI elements that won't work

---

## Getting Help

- **Report Issues**: https://github.com/yourusername/Archaeopteryx/issues
- **Discussion**: https://github.com/yourusername/Archaeopteryx/discussions
- **Bluesky**: [@archaeopteryx.dev](https://bsky.app/profile/archaeopteryx.dev)

---

## Future Enhancements

See the [Roadmap](README.md#roadmap) in the main README for planned features and improvements.

---

Last Updated: 2025-10-14
