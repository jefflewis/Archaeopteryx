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

Configuration is handled through environment variables:

- `PORT` - Server port (default: 8080)
- `VALKEY_URL` - Valkey/Redis connection URL
- `LOG_LEVEL` - Logging level (debug, info, warning, error)

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
