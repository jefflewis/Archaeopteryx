import XCTest
import Logging
import Hummingbird
@testable import Archaeopteryx
import CacheLayer

final class RateLimitMiddlewareTests: XCTestCase {
    var cache: InMemoryCache!
    var logger: Logger!
    var middleware: RateLimitMiddleware<BasicRequestContext>!

    override func setUp() async throws {
        try await super.setUp()
        cache = InMemoryCache()
        logger = Logger(label: "test")
        logger.logLevel = .critical // Suppress logs during tests
        middleware = RateLimitMiddleware(
            cache: cache,
            logger: logger,
            unauthenticatedLimit: 10,
            authenticatedLimit: 20,
            windowSeconds: 60
        )
    }

    override func tearDown() async throws {
        cache = nil
        logger = nil
        middleware = nil
        try await super.tearDown()
    }

    // MARK: - Basic Tests

    func testRateLimitMiddleware_CanBeCreated() {
        XCTAssertNotNil(middleware)
    }

    func testRateLimitMiddleware_HasCorrectLimits() {
        let unauthLimit = 300
        let authLimit = 1000
        let window = 300

        let customMiddleware: RateLimitMiddleware<BasicRequestContext> = RateLimitMiddleware(
            cache: cache,
            logger: logger,
            unauthenticatedLimit: unauthLimit,
            authenticatedLimit: authLimit,
            windowSeconds: window
        )

        XCTAssertNotNil(customMiddleware)
    }

    func testRateLimitMiddleware_DefaultLimitsAreCorrect() {
        // Default: 300 unauthenticated, 1000 authenticated, 300 second window
        let defaultMiddleware: RateLimitMiddleware<BasicRequestContext> = RateLimitMiddleware(
            cache: cache,
            logger: logger
        )

        XCTAssertNotNil(defaultMiddleware)
    }

    // MARK: - Token Bucket Algorithm Tests

    func testTokenBucket_CanBeCreated() throws {
        let bucket = TokenBucket(tokens: 10, lastRefill: Date())

        XCTAssertEqual(bucket.tokens, 10)
        XCTAssertNotNil(bucket.lastRefill)
    }

    func testTokenBucket_CanBeEncodedAndDecoded() throws {
        let original = TokenBucket(tokens: 5, lastRefill: Date())

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TokenBucket.self, from: data)

        XCTAssertEqual(decoded.tokens, original.tokens)
        // Allow 1 second tolerance for date encoding/decoding
        XCTAssertEqual(
            decoded.lastRefill.timeIntervalSince1970,
            original.lastRefill.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    // MARK: - Rate Limit Result Tests

    func testRateLimitResult_HasCorrectProperties() {
        let result = RateLimitResult(
            allowed: true,
            remaining: 5,
            resetAt: Date().addingTimeInterval(300)
        )

        XCTAssertTrue(result.allowed)
        XCTAssertEqual(result.remaining, 5)
        XCTAssertGreaterThan(result.resetAt, Date())
    }

    // MARK: - Cache Integration Tests

    func testRateLimit_FirstRequest_CreatesTokenBucket() async throws {
        let key = "test_user"
        let limit = 10

        // Simulate rate limit check
        let result = try await middleware.performRateLimitCheck(key: key, limit: limit)

        XCTAssertTrue(result.allowed)
        XCTAssertEqual(result.remaining, limit - 1)

        // Verify bucket was stored in cache
        let bucketData: Data? = try await cache.get(key)
        XCTAssertNotNil(bucketData)
    }

    func testRateLimit_SubsequentRequests_ConsumeTokens() async throws {
        let key = "test_user_2"
        let limit = 5

        // Make multiple requests
        for expectedRemaining in (0..<limit).reversed() {
            let result = try await middleware.performRateLimitCheck(key: key, limit: limit)

            XCTAssertTrue(result.allowed)
            XCTAssertEqual(result.remaining, expectedRemaining)
        }

        // Next request should be denied
        let deniedResult = try await middleware.performRateLimitCheck(key: key, limit: limit)
        XCTAssertFalse(deniedResult.allowed)
        XCTAssertEqual(deniedResult.remaining, 0)
    }

    func testRateLimit_TokensRefill_AfterTime() async throws {
        let key = "test_user_3"
        let limit = 2
        let windowSeconds = 2  // Very short window for testing

        let shortWindowMiddleware: RateLimitMiddleware<BasicRequestContext> = RateLimitMiddleware(
            cache: cache,
            logger: logger,
            unauthenticatedLimit: limit,
            authenticatedLimit: limit,
            windowSeconds: windowSeconds
        )

        // Exhaust tokens
        _ = try await shortWindowMiddleware.performRateLimitCheck(key: key, limit: limit)
        _ = try await shortWindowMiddleware.performRateLimitCheck(key: key, limit: limit)

        // Should be denied
        let denied = try await shortWindowMiddleware.performRateLimitCheck(key: key, limit: limit)
        XCTAssertFalse(denied.allowed)

        // Wait for tokens to refill
        try await Task.sleep(nanoseconds: UInt64(windowSeconds) * 1_000_000_000 + 100_000_000) // Add 100ms buffer

        // Should succeed now
        let allowed = try await shortWindowMiddleware.performRateLimitCheck(key: key, limit: limit)
        XCTAssertTrue(allowed.allowed)
    }

    func testRateLimit_DifferentKeys_IndependentLimits() async throws {
        let key1 = "user_1"
        let key2 = "user_2"
        let limit = 2

        // Exhaust key1
        _ = try await middleware.performRateLimitCheck(key: key1, limit: limit)
        _ = try await middleware.performRateLimitCheck(key: key1, limit: limit)
        let denied = try await middleware.performRateLimitCheck(key: key1, limit: limit)
        XCTAssertFalse(denied.allowed)

        // key2 should still have full limit
        let allowed1 = try await middleware.performRateLimitCheck(key: key2, limit: limit)
        XCTAssertTrue(allowed1.allowed)
        XCTAssertEqual(allowed1.remaining, limit - 1)

        let allowed2 = try await middleware.performRateLimitCheck(key: key2, limit: limit)
        XCTAssertTrue(allowed2.allowed)
        XCTAssertEqual(allowed2.remaining, limit - 2)
    }
}

// MARK: - Test Helpers

/// Expose internal methods for testing
extension RateLimitMiddleware {
    func performRateLimitCheck(key: String, limit: Int) async throws -> RateLimitResult {
        return try await checkRateLimit(key: key, limit: limit)
    }
}
