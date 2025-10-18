# ``Archaeopteryx``

A Bluesky-to-Mastodon API compatibility bridge written in Swift.

## Overview

**Archaeopteryx** translates Mastodon API calls to AT Protocol (Bluesky), allowing existing Mastodon client applications to connect to Bluesky without modification.

Use your favorite Mastodon client (Ivory, Mona, Ice Cubes, Tusky, Elk) to browse Bluesky!

### Key Features

- **44 Mastodon API endpoints** - Full compatibility with major Mastodon clients
- **Multi-user support** - Session isolation for multiple concurrent users
- **OAuth 2.0** - Standard password grant flow
- **Automatic session refresh** - Seamless authentication management
- **Redis/Valkey caching** - High-performance caching layer
- **OpenTelemetry observability** - Built-in metrics and tracing
- **Swift 6.0 strict concurrency** - Modern, safe Swift with actors
- **80%+ test coverage** - 252 comprehensive tests

### Architecture

```
Mastodon Client (Ivory, Mona, etc.)
         ↓ Mastodon API
Archaeopteryx (Translation Layer)
         ↓ AT Protocol
      Bluesky
```

Archaeopteryx sits between your Mastodon client and Bluesky, translating requests and responses in real-time.

## Topics

### Getting Started

- <doc:Getting-Started>
- <doc:Client-Setup>

### Deployment

- <doc:Fly-Deployment>
- <doc:Docker-Deployment>

### Guides

- <doc:API-Reference>
- <doc:Multi-User>
- <doc:Limitations>
- <doc:OpenTelemetry>

### Architecture

- ``ArchaeopteryxCore``
- ``MastodonModels``
- ``ATProtoAdapter``
- ``TranslationLayer``
- ``OAuthService``
- ``CacheLayer``
- ``IDMapping``
