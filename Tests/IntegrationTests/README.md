# Integration Tests

This directory contains integration tests that test the **complete HTTP stack** (Hummingbird routes, middleware, translation layer, etc.) while **mocking Bluesky API responses** to avoid real network calls.

## Architecture

### How It Works

```
Test Request → Hummingbird Router (REAL) → Middleware (REAL) → Route Handlers (REAL)
    → ATProtoClient (REAL) → ATProtoKit (REAL) → URLSession with MockURLProtocol (MOCKED)
    → Bluesky API Response (MOCKED)
```

**Key Insight**: We use `URLProtocol` subclassing to intercept HTTP requests at the URLSession level.

### Components

1. **MockURLProtocol.swift** - Intercepts network requests and returns mock data
2. **BlueskyAPIFixtures.swift** - Realistic Bluesky API response fixtures
3. **IntegrationTestCase.swift** - Base test class with helper methods
4. ***IntegrationTests.swift** - Actual test files

## Running Tests

```bash
swift test --filter IntegrationTests
```

See full documentation in the file for more details.
