# Client Setup

Connect your favorite Mastodon client to Bluesky via Archaeopteryx.

## Overview

Archaeopteryx allows you to use any Mastodon client to browse Bluesky. This guide shows you how to set up various popular clients.

## Tested Clients

The following clients have been tested and work well with Archaeopteryx:

- **Ivory** (iOS/macOS) - Premium Mastodon client
- **Mona** (iOS/macOS) - Feature-rich client
- **Ice Cubes** (iOS/macOS) - Open source, fast
- **Tusky** (Android) - Popular Android client
- **Elk** (Web) - Modern web interface

## General Setup Steps

All Mastodon clients follow a similar setup process:

1. **Add Instance**: Enter your Archaeopteryx server URL
2. **Login**: Use your Bluesky credentials
3. **Browse**: Start using Bluesky through the Mastodon interface

## Detailed Instructions

### Ivory (iOS/macOS)

1. Open Ivory
2. Tap/click "Add Account"
3. Enter instance URL:
   - Local: `http://localhost:8080`
   - Remote: `https://your-server.fly.dev`
4. Tap "Next"
5. Enter your Bluesky credentials:
   - **Username**: Your full Bluesky handle (e.g., `alice.bsky.social`)
   - **Password**: Your Bluesky app password
6. Tap "Login"

> Important: Use an [app password](https://bsky.app/settings/app-passwords), not your main password.

### Mona (iOS/macOS)

1. Open Mona
2. Tap "Add Account"
3. Select "Other Instance"
4. Enter instance URL (e.g., `http://localhost:8080`)
5. Tap "Continue"
6. Login with Bluesky credentials
7. Authorize the app

### Ice Cubes (iOS/macOS)

1. Open Ice Cubes
2. Tap the profile icon
3. Tap "Add Account"
4. Enter instance URL: `http://localhost:8080`
5. Tap "Next"
6. Enter Bluesky handle and app password
7. Tap "Sign In"

### Tusky (Android)

1. Open Tusky
2. Tap "Add Account"
3. Enter instance URL in the text field
4. Tap "Next"
5. Login with Bluesky credentials
6. Approve authorization

### Elk (Web)

1. Visit [elk.zone](https://elk.zone)
2. Click "Sign in"
3. Enter your Archaeopteryx server URL
4. Click "Sign in to Mastodon"
5. Enter Bluesky credentials
6. Authorize

## Creating Bluesky App Passwords

For security, always use app passwords instead of your main Bluesky password:

1. Go to [Bluesky Settings → App Passwords](https://bsky.app/settings/app-passwords)
2. Click "Add App Password"
3. Give it a name (e.g., "Archaeopteryx")
4. Click "Create"
5. Copy the generated password
6. Use this password when logging in through clients

> Note: App passwords can be revoked at any time from Bluesky settings.

## Local Development

When running Archaeopteryx locally:

**Instance URL**: `http://localhost:8080`

### iOS Simulator Gotcha

If using iOS Simulator and Archaeopteryx on the same Mac:

**Don't use**: `http://localhost:8080`
**Use instead**: `http://127.0.0.1:8080`

### Real iOS Device

If running on a physical iOS device and Archaeopteryx on your computer:

1. Find your computer's local IP:
   ```bash
   ifconfig | grep "inet "
   ```

2. Use that IP in the client:
   ```
   http://192.168.1.100:8080
   ```

3. Make sure firewall allows connections on port 8080

## Production Deployment

When deploying to production (e.g., Fly.io):

**Instance URL**: `https://your-app.fly.dev`

Always use HTTPS for production deployments.

## Troubleshooting

### "Instance not found"

- Verify the server is running: `curl http://localhost:8080/api/v1/instance`
- Check you entered the correct URL
- Ensure no typos in the URL

### "Login failed"

- Verify you're using a Bluesky **app password**, not your main password
- Check your handle is complete (e.g., `alice.bsky.social`, not just `alice`)
- Ensure Archaeopteryx can reach `bsky.social` (check internet connection)

### "Can't load timeline"

- Check server logs: `swift run Archaeopteryx` output
- Verify Redis is running: `redis-cli ping`
- Try logging out and back in

### Features Not Working

Some Mastodon features aren't available on Bluesky. See <doc:Limitations> for details.

## What You Can Do

Once connected, you can:

- ✅ View your home timeline
- ✅ Post new messages
- ✅ Reply to posts
- ✅ Like and repost
- ✅ Follow and unfollow users
- ✅ Search for accounts and posts
- ✅ View notifications
- ✅ Upload media (images)

## What Doesn't Work

Some Mastodon features aren't supported:

- ❌ Custom emojis (Bluesky doesn't have them)
- ❌ Polls (not yet in Bluesky)
- ❌ Content warnings (no Bluesky equivalent)
- ❌ Pinned posts (Bluesky doesn't support)

See <doc:Limitations> for the complete list and workarounds.

## Next Steps

- <doc:API-Reference> - Explore available API endpoints
- <doc:Limitations> - Understand what's supported
- <doc:Fly-Deployment> - Deploy your own instance
