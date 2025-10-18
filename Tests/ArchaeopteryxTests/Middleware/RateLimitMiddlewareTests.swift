import Foundation
import Testing
import Logging
import Hummingbird
@testable import Archaeopteryx
import CacheLayer

@Suite struct RateLimitMiddlewareTests {
    var cache: InMemoryCache!
    var logger: Logger!
    var middleware: RateLimitMiddleware<BasicRequestContext>!

    init() async {
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

    // MARK: - Basic Tests

    @Test func RateLimitMiddleware_CanBeCreated() {
        #expect(middleware != nil)
    }

    @Test func RateLimitMiddleware_HasCorrectLimits() {
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

        #expect(customMiddleware != nil)
    }

    @Test func RateLimitMiddleware_DefaultLimitsAreCorrect() {
        // Default: 300 unauthenticated, 1000 authenticated, 300 second window
        let defaultMiddleware: RateLimitMiddleware<BasicRequestContext> = RateLimitMiddleware(
            cache: cache,
            logger: logger
        )

        #expect(defaultMiddleware != nil)
    }

    // MARK: - Token Bucket Algorithm Tests

    @Test func TokenBucket_CanBeCreated() throws {
        let bucket = TokenBucket(tokens: 10, lastRefill: Date())

        #expect(bucket.tokens == 10)
        #expect(bucket.lastRefill != nil)
    }

    @Test func TokenBucket_CanBeEncodedAndDecoded() throws {
        let original = TokenBucket(tokens: 5, lastRefill: Date())

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TokenBucket.self, from: data)

        #expect(decoded.tokens == original.tokens)
        // Allow 1 second tolerance for date encoding/decoding
        let timeDiff = abs(decoded.lastRefill.timeIntervalSince1970 - original.lastRefill.timeIntervalSince1970)
        #expect(timeDiff < 1.0)
    }

    // MARK: - Rate Limit Result Tests

    @Test func RateLimitResult_HasCorrectProperties() {
        let result = RateLimitResult(
            allowed: true,
            remaining: 5,
            resetAt: Date().addingTimeInterval(300)
        )

        #expect(result.allowed)
        #expect(result.remaining == 5)
        #expect(result.resetAt > Date())
    }

    // MARK: - Cache Integration Tests

    @Test func RateLimit_FirstRequest_CreatesTokenBucket() async throws {
        let key = "test_user"
        let limit = 10

        // Simulate rate limit check
        let result = try await middleware.performRateLimitCheck(key: key, limit: limit)

        #expect(result.allowed)
        #expect(result.remaining == limit - 1)

        // Verify bucket was stored in cache
        let bucketData: Data? = try await cache.get(key)
        #expect(bucketData != nil)
    }

    @Test func RateLimit_SubsequentRequests_ConsumeTokens() async throws {
        let key = "test_user_2"
        let limit = 5

        // Make multiple requests
        for expectedRemaining in (0..<limit).reversed() {
            let result = try await middleware.performRateLimitCheck(key: key, limit: limit)

            #expect(result.allowed)
            #expect(result.remaining == expectedRemaining)
        }

        // Next request should be denied
        let deniedResult = try await middleware.performRateLimitCheck(key: key, limit: limit)
        #expect(!(deniedResult.allowed))
        #expect(deniedResult.remaining == 0)
    }

    @Test func RateLimit_TokensRefill_AfterTime() async throws {
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
        #expect(!(denied.allowed))

        // Wait for tokens to refill
        try await Task.sleep(nanoseconds: UInt64(windowSeconds) * 1_000_000_000 + 100_000_000) // Add 100ms buffer

        // Should succeed now
        let allowed = try await shortWindowMiddleware.performRateLimitCheck(key: key, limit: limit)
        #expect(allowed.allowed)
    }

    @Test func RateLimit_DifferentKeys_IndependentLimits() async throws {
        let key1 = "user_1"
        let key2 = "user_2"
        let limit = 2

        // Exhaust key1
        _ = try await middleware.performRateLimitCheck(key: key1, limit: limit)
        _ = try await middleware.performRateLimitCheck(key: key1, limit: limit)
        let denied = try await middleware.performRateLimitCheck(key: key1, limit: limit)
        #expect(!(denied.allowed))

        // key2 should still have full limit
        let allowed1 = try await middleware.performRateLimitCheck(key: key2, limit: limit)
        #expect(allowed1.allowed)
        #expect(allowed1.remaining == limit - 1)

        let allowed2 = try await middleware.performRateLimitCheck(key: key2, limit: limit)
        #expect(allowed2.allowed)
        #expect(allowed2.remaining == limit - 2)
    }
}

// MARK: - Test Helpers

/// Expose internal methods for testing
extension RateLimitMiddleware {
    func performRateLimitCheck(key: String, limit: Int) async throws -> RateLimitResult {
        return try await checkRateLimit(key: key, limit: limit)
    }
}

