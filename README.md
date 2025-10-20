# Archaeopteryx

![Archaeopteryx](https://upload.wikimedia.org/wikipedia/commons/thumb/3/32/Archaeopteryx_TD.png/800px-Archaeopteryx_TD.png)

*[Archaeopteryx illustration](https://commons.wikimedia.org/wiki/File:Archaeopteryx_TD.png) by [TotalDino](https://commons.wikimedia.org/wiki/User:TotalDino), [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)*

**Use Mastodon clients with Bluesky.** HTTP bridge that translates Mastodon API → AT Protocol.

## Quick Start

```bash
# Requirements: Swift 6.0+, Redis/Valkey
brew install swift redis
redis-server &

# Run
git clone https://github.com/yourusername/archaeopteryx.git
cd archaeopteryx
swift run Archaeopteryx
```

Server starts on `http://localhost:8080`

## Client Setup

1. Add instance: `http://localhost:8080`
2. Login with Bluesky handle + app password
3. Browse Bluesky through your Mastodon client

**Tested**: Ivory, Mona, Ice Cubes, Tusky, Elk

## Features

- 44 Mastodon API endpoints
- Multi-user with session isolation
- OAuth 2.0 password grant
- Automatic session refresh
- Redis/Valkey caching
- OpenTelemetry observability
- Swift 6.0 strict concurrency
- 252 tests, 80%+ coverage

## Environment

```bash
PORT=8080                              # Server port
VALKEY_HOST=localhost                  # Cache host
VALKEY_PORT=6379                      # Cache port
ATPROTO_SERVICE_URL=https://bsky.social
LOG_LEVEL=info                         # trace|debug|info|warning|error
```

## API Endpoints

### OAuth (5)
- App registration, authorization, token exchange, revocation

### Accounts (10)
- Verify credentials, lookup, follow/unfollow, followers, following, search

### Statuses (10)
- Get, create, delete, context, like, repost, favourited_by, reblogged_by

### Timelines (4)
- Home, public, hashtag, list

### Notifications (4)
- List, get, clear, dismiss

### Media (4)
- Upload, get, update

### Search (1)
- Search accounts/statuses/hashtags

### Lists (4)
- Get lists, list details, members, timeline

### Instance (2)
- Instance metadata v1/v2

See **[API_REFERENCE.md](API_REFERENCE.md)** for request/response examples.

## Architecture

```
Mastodon Client
       ↓ Mastodon API
Archaeopteryx (Translation Layer)
       ↓ AT Protocol
    Bluesky
```

**Packages**: Core, Models, IDMapping, Cache, ATProtoAdapter, Translation, OAuth, Routes

See **[CLAUDE.md](CLAUDE.md)** for architecture details.

## Documentation

**📚 Interactive Documentation**: https://\<username\>.github.io/Archaeopteryx/documentation/archaeopteryx

### Local Preview

```bash
./scripts/preview-docs.sh
```

Documentation covers:
- Getting started guide
- Client setup (Ivory, Mona, Ice Cubes, Tusky, Elk)
- Complete API reference
- Deployment guides (Fly.io, Docker)
- Multi-user architecture
- OpenTelemetry observability
- Known limitations

### Additional Guides

- **[FLY_QUICKSTART.md](FLY_QUICKSTART.md)** - Deploy to Fly.io (quick reference)
- **[DOCUMENTATION_SETUP.md](DOCUMENTATION_SETUP.md)** - Documentation system guide
- **[CLAUDE.md](CLAUDE.md)** - Dev guide, architecture, TDD workflow

## Testing

```bash
swift test                              # All 252 tests
swift test --filter AccountRoutesTests  # Specific suite
swift test --enable-code-coverage       # With coverage
```

## Deployment

### Fly.io (Recommended)

```bash
# One-time setup
fly auth login
fly apps create your-app-name
fly secrets set VALKEY_HOST=... VALKEY_PASSWORD=...

# Deploy
./scripts/build-linux.sh
fly deploy
```

See **[FLY_QUICKSTART.md](FLY_QUICKSTART.md)** for complete guide.

### Docker Compose

```bash
# Includes Valkey + Grafana stack
docker-compose up -d
```

See **[DEPLOYMENT.md](DEPLOYMENT.md)** for production config.

## Performance

- Account endpoints: p95 < 200ms
- Timeline endpoints: p95 < 500ms
- Throughput: 100+ req/sec
- Cache hit: >90% profiles, >80% posts

## Limitations

- No pinned posts (Bluesky doesn't support)
- No custom emojis (not yet in Bluesky)
- No polls (not yet in Bluesky)
- Lists read-only (mapped from feeds)
- Limited hashtag timeline

See **[LIMITATIONS.md](LIMITATIONS.md)** for full list + workarounds.

## Tech Stack

- [Hummingbird 2.0](https://github.com/hummingbird-project/hummingbird) - HTTP server
- [ATProtoKit](https://github.com/MasterJ93/ATProtoKit) - Bluesky SDK
- [RediStack](https://github.com/swift-server/RediStack) - Cache client
- [OpenTelemetry](https://github.com/open-telemetry/opentelemetry-swift) - Observability
- [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) - DI

## Contributing

1. Read **[CLAUDE.md](CLAUDE.md)**
2. Follow TDD (test → implement → refactor)
3. Maintain 80%+ coverage
4. Swift 6.0 strict concurrency

## License

MIT

## Credits

- ATProtoKit by [@MasterJ93](https://github.com/MasterJ93)
- Inspired by [SkyBridge](https://github.com/videah/SkyBridge)
