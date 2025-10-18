# Getting Started

Quick start guide to run Archaeopteryx locally.

## Overview

This guide walks you through setting up and running Archaeopteryx on your local machine for development or testing.

## Prerequisites

- **Swift 6.0 or later** - [Download from Swift.org](https://swift.org/download/)
- **Redis or Valkey** - For caching
- **macOS 14+** or **Linux** (Ubuntu 22.04+)

### Installing Swift (macOS)

```bash
# Install via Homebrew
brew install swift

# Verify installation
swift --version
```

### Installing Redis (macOS)

```bash
# Install via Homebrew
brew install redis

# Start Redis in the background
brew services start redis

# Or run Redis in foreground
redis-server
```

### Installing Redis (Linux)

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install redis-server

# Start Redis
sudo systemctl start redis
sudo systemctl enable redis
```

## Clone and Build

1. Clone the repository:

```bash
git clone https://github.com/yourusername/archaeopteryx.git
cd archaeopteryx
```

2. Build the project:

```bash
swift build
```

This will download all dependencies and compile the project.

## Run the Server

Start the server with default settings:

```bash
swift run Archaeopteryx
```

The server will start on `http://localhost:8080`.

### Environment Variables

Configure the server with environment variables:

```bash
# Server configuration
export PORT=8080
export HOSTNAME=0.0.0.0
export LOG_LEVEL=info

# Cache configuration
export VALKEY_HOST=localhost
export VALKEY_PORT=6379

# AT Protocol configuration
export ATPROTO_SERVICE_URL=https://bsky.social

# Run the server
swift run Archaeopteryx
```

## Verify Installation

Test the server is running:

```bash
curl http://localhost:8080/api/v1/instance
```

You should see a JSON response with instance information.

## Next Steps

- <doc:Client-Setup> - Connect a Mastodon client
- <doc:API-Reference> - Explore available endpoints
- <doc:Fly-Deployment> - Deploy to production

## Troubleshooting

### "Port already in use"

If port 8080 is already in use:

```bash
export PORT=8081
swift run Archaeopteryx
```

### "Can't connect to Redis"

Verify Redis is running:

```bash
redis-cli ping
# Should return: PONG
```

If Redis isn't running:

```bash
# macOS
brew services start redis

# Linux
sudo systemctl start redis
```

### Build Errors

Clean and rebuild:

```bash
swift package clean
swift build
```

## Development

### Running Tests

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter AccountRoutesTests

# Run with code coverage
swift test --enable-code-coverage
```

### Log Levels

Control logging verbosity:

- `trace` - Very detailed (includes request/response bodies)
- `debug` - Detailed debugging information
- `info` - General information (default)
- `warning` - Warnings only
- `error` - Errors only

```bash
export LOG_LEVEL=debug
swift run Archaeopteryx
```
