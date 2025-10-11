# Archaeopteryx

A Swift-based bridge/proxy that allows Mastodon apps to connect to Bluesky by translating Mastodon API calls to AT Protocol calls.

## Overview

Archaeopteryx (named after the famous transitional prehistoric bird) acts as a translation layer between the Mastodon API and Bluesky's AT Protocol, enabling Mastodon clients to work seamlessly with Bluesky accounts.

## Features

- Mastodon API compatibility layer
- AT Protocol / Bluesky backend integration
- Redis/Valkey caching for improved performance
- Built with modern Swift server technologies

## Tech Stack

- **[Hummingbird](https://github.com/hummingbird-project/hummingbird)** - Modern, lightweight Swift web framework
- **[swift-valkey](https://github.com/swift-server/swift-valkey)** - Redis-compatible client for caching
- **[ATProtoKit](https://github.com/MasterJ93/ATProtoKit)** - Swift SDK for AT Protocol / Bluesky
- **[swift-configuration](https://github.com/apple/swift-configuration)** - Apple's native configuration management

## Requirements

- Swift 6.0+
- macOS 14+ or Linux
- Redis/Valkey instance (for caching)

## Installation

### Clone the repository

```bash
git clone https://github.com/yourusername/Archaeopteryx.git
cd Archaeopteryx
```

### Build

```bash
swift build
```

### Run

```bash
swift run Archaeopteryx
```

## Configuration

Configuration is handled using Apple's **swift-configuration** library with support for environment variables and configuration files.

### Environment Variables

#### Server Configuration
- `HOSTNAME` - Server hostname (default: `0.0.0.0`)
- `PORT` - Server port (default: `8080`)

#### Valkey/Redis Configuration
- `VALKEY_HOST` - Valkey/Redis host (default: `localhost`)
- `VALKEY_PORT` - Valkey/Redis port (default: `6379`)
- `VALKEY_PASSWORD` - Optional password for Valkey/Redis
- `VALKEY_DATABASE` - Database number (default: `0`)

#### AT Protocol Configuration
- `ATPROTO_SERVICE_URL` - AT Protocol service URL (default: `https://bsky.social`)
- `ATPROTO_PDS_URL` - Optional custom PDS URL

#### Logging Configuration
- `LOG_LEVEL` - Logging level: `trace`, `debug`, `info`, `notice`, `warning`, `error`, `critical` (default: `info`)

### Example Configuration

```bash
export PORT=8080
export VALKEY_HOST=localhost
export VALKEY_PORT=6379
export LOG_LEVEL=debug
export ATPROTO_SERVICE_URL=https://bsky.social

swift run Archaeopteryx
```

## Usage

Once running, configure your Mastodon client to use the Archaeopteryx instance URL as the server.

## Project Status

This project is in early development. Functionality is basic and under active development.

## Inspiration

Inspired by [SkyBridge](https://github.com/videah/SkyBridge), which provides similar functionality using Dart.

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.
