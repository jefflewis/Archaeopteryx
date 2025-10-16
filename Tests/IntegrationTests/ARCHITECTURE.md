# Integration Testing Architecture

## Overview

This document explains how integration tests work in Archaeopteryx, specifically how we test the **complete HTTP stack** while **mocking Bluesky API responses**.

## The Challenge

We need integration tests that:
1. ✅ Use the real HTTP stack (Hummingbird routes, middleware, translation layer)
2. ✅ Mock Bluesky API responses (no real network calls)
3. ✅ Don't require modifications to ATProtoClient or ATProtoKit
4. ✅ Provide full control over API responses for testing edge cases

## The Solution: URLProtocol Interception

### Key Insight

**ATProtoKit uses URLSession**, not AsyncHTTPClient/SwiftNIO. This was confirmed by inspecting the source:

```swift
// From ATProtoKit/Sources/ATProtoKit/Utilities/APIClientService.swift
public private(set) var urlSession: URLSession = URLSession(configuration: .default)
```

This is **perfect** for testing because URLSession supports custom URLProtocols!

### Architecture Diagram

```
Test Request
    ↓
Hummingbird Router (REAL)
    ↓
Middleware (REAL)
    ↓
Route Handlers (REAL)
    ↓
ATProtoClient (REAL)
    ↓
ATProtoKit (REAL)
    ↓
URLSession (REAL)
    ↓
MockURLProtocol (INTERCEPTS HERE!) ← Custom URLProtocol
    ↓
Returns Mocked Response (MOCKED)
```

**Everything runs as it would in production except the final network call.**

## How URLProtocol Mocking Works

### Step 1: Custom URLProtocol

We created `MockURLProtocol` that intercepts network requests:

```swift
final class MockURLProtocol: URLProtocol {
    // Intercepts requests to *.bsky.social and *.bsky.app
    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url,
              let host = url.host,
              host.contains("bsky.social") || host.contains("bsky.app") else {
            return false
        }
        return true
    }

    // Returns mock data instead of making real network call
    override func startLoading() {
        // Find matching mock for this URL pattern
        // Return mock response data
    }
}
```

### Step 2: Inject Into URLSession

ATProtoKit accepts `APIClientConfiguration` which includes `URLSessionConfiguration`:

```swift
// From ATProtoKit initialization
public init(
    sessionConfiguration: SessionConfiguration? = nil,
    apiClientConfiguration: APIClientConfiguration? = nil,
    pdsURL: String = APIHostname.bskyAppView,
    canUseBlueskyRecords: Bool = true
) async {
    var finalConfiguration = apiClientConfiguration ?? APIClientConfiguration()
    finalConfiguration.urlSessionConfiguration =
        apiClientConfiguration?.urlSessionConfiguration ??
        sessionConfiguration?.configuration ??
        .default
    // ...
}
```

### Step 3: Wire It Together in Tests

Our `IntegrationTestCase` sets up the mock:

```swift
// Create URLSessionConfiguration with MockURLProtocol
let urlSessionConfig = URLSessionConfiguration.ephemeral
urlSessionConfig.protocolClasses = [MockURLProtocol.self]

// Inject into ATProtoKit via APIClientConfiguration
let apiClientConfig = APIClientConfiguration(
    urlSessionConfiguration: urlSessionConfig
)

// Create ATProtoClient with mocked transport
let atProtoClient = await ATProtoClient(
    serviceURL: "https://bsky.social",
    cache: cache,
    apiClientConfiguration: apiClientConfig  // ← Injects mock!
)
```

### Step 4: Register Mock Responses

Tests register mock responses for specific endpoints:

```swift
// Mock successful profile response
MockURLProtocol.registerMock(
    pattern: "app.bsky.actor.getProfile",
    statusCode: 200,
    data: BlueskyAPIFixtures.getProfileResponse
)

// Mock authentication error
MockURLProtocol.registerMock(
    pattern: "app.bsky.actor.getProfile",
    statusCode: 401,
    data: BlueskyAPIFixtures.unauthorizedError
)
```

## Changes Made to Support This

### 1. Updated ATProtoClient

**Before:**
```swift
public init(
    serviceURL: String = "https://bsky.social",
    cache: CacheService
) async {
    self.serviceURL = serviceURL
    self.cache = cache
    self.atProtoKit = await ATProtoKit(pdsURL: serviceURL)
}
```

**After:**
```swift
public init(
    serviceURL: String = "https://bsky.social",
    cache: CacheService,
    apiClientConfiguration: APIClientConfiguration? = nil  // ← NEW!
) async {
    self.serviceURL = serviceURL
    self.cache = cache

    // Pass configuration to ATProtoKit
    self.atProtoKit = await ATProtoKit(
        apiClientConfiguration: apiClientConfiguration,
        pdsURL: serviceURL
    )
}
```

This change:
- ✅ Is **backward compatible** (parameter is optional)
- ✅ Only affects **tests** (production code passes `nil`)
- ✅ Enables **dependency injection** for testing

### 2. Created Testing Infrastructure

- **MockURLProtocol.swift** - Custom URLProtocol for interception
- **BlueskyAPIFixtures.swift** - Realistic API responses from official docs
- **IntegrationTestCase.swift** - Base test class with helpers
- **AccountVerificationIntegrationTests.swift** - Example tests

## Why This Approach is Superior

### ❌ Alternative: Dependency Injection at ATProtoClient Level

We could have created a protocol for ATProtoClient and mocked the entire thing:

```swift
protocol ATProtoClientProtocol {
    func getProfile(actor: String) async throws -> ATProtoProfile
    // ... 28 methods
}
```

**Problems:**
- 📝 Tons of boilerplate for 28+ methods
- 🔧 Doesn't test the real ATProtoClient code
- 🐛 Mocks can drift from reality
- 🎭 Tests verify mocks, not actual code

### ✅ Our Approach: URLProtocol Interception

**Advantages:**
- ✅ Tests **real production code** (ATProtoClient, ATProtoKit, URLSession)
- ✅ Only mocks the **network boundary** (minimal surface area)
- ✅ Easy to add new endpoints (just add fixtures)
- ✅ Realistic responses from official API docs
- ✅ Tests can verify exact HTTP requests being made

## Verifying It Works

### ATProtoKit Uses URLSession ✅

```bash
$ grep -r "URLSession" .build/checkouts/ATProtoKit --include="*.swift"
.../APIClientService.swift:    public private(set) var urlSession: URLSession
.../APIClientService.swift:        self.urlSession = URLSession(configuration: config, ...)
```

### ATProtoKit Supports Configuration Injection ✅

```bash
$ grep -A 10 "public init" .build/checkouts/ATProtoKit/Sources/ATProtoKit/ATProtoKit.swift
public init(
    sessionConfiguration: SessionConfiguration? = nil,
    apiClientConfiguration: APIClientConfiguration? = nil,  ← HERE
    pdsURL: String = APIHostname.bskyAppView,
    canUseBlueskyRecords: Bool = true
) async { ... }
```

### Build Passes ✅

```bash
$ swift build
Build complete! (12.79s)
```

## Common Misconceptions Addressed

### "ATProtoKit uses SwiftNIO/AsyncHTTPClient"

**FALSE**. While it's common for server-side Swift libraries to use AsyncHTTPClient, ATProtoKit uses URLSession. This was verified by:
1. Searching the source code
2. Checking Package.swift dependencies (no AsyncHTTPClient)
3. Finding `urlSession` property in APIClientService

### "URLProtocol mocking is fragile"

**FALSE** when used correctly. Our approach is solid because:
- URLProtocol is part of Foundation (stable API)
- We only intercept Bluesky domains (won't affect other traffic)
- Pattern matching is simple (URL contains "getProfile")
- Mocks are cleared between tests (no state leakage)

### "We should mock at a higher level"

**DISAGREE**. Mocking at the ATProtoClient level would:
- Skip testing the real ATProtoClient implementation
- Require maintaining parallel mock implementations
- Not catch integration bugs between layers

URLProtocol interception is the **lowest level** we can mock while still having **full control**.

## Future Enhancements

### 1. Request Verification

Currently we just return mock responses. We could verify requests:

```swift
MockURLProtocol.registerHandler(pattern: "searchActors") { request in
    // Verify request has correct headers
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertNotNil(request.value(forHTTPHeaderField: "Authorization"))

    // Verify query parameters
    guard let url = request.url,
          let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
        throw URLError(.badURL)
    }

    XCTAssertNotNil(query.first { $0.name == "q" })

    return (mockResponse, mockData)
}
```

### 2. Response Delays

Simulate network latency:

```swift
MockURLProtocol.registerHandler(pattern: "getProfile") { request in
    // Simulate 100ms network delay
    try await Task.sleep(nanoseconds: 100_000_000)
    return (response, data)
}
```

### 3. Flaky Network Conditions

Test retries and error handling:

```swift
var callCount = 0
MockURLProtocol.registerHandler(pattern: "getProfile") { request in
    callCount += 1

    // Fail first 2 attempts, succeed on 3rd
    if callCount < 3 {
        throw URLError(.networkConnectionLost)
    }

    return (response, data)
}
```

## Conclusion

The integration testing architecture is:
- ✅ **Production-realistic** - Uses real code paths
- ✅ **Fast** - No real network calls
- ✅ **Reliable** - Consistent mock responses
- ✅ **Maintainable** - Easy to add new tests
- ✅ **Flexible** - Can test edge cases and errors

The key insight was recognizing that **ATProtoKit uses URLSession**, which enables URLProtocol-based mocking. This gives us the best of both worlds: testing the real stack while controlling external dependencies.
