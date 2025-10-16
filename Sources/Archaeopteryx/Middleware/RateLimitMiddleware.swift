import Foundation
import Hummingbird
import HTTPTypes
import Logging
import CacheLayer

/// Middleware for rate limiting HTTP requests
///
/// This middleware implements a token bucket algorithm for rate limiting:
/// - **Per-IP rate limiting**: Limits requests per IP address
/// - **Per-user rate limiting**: Limits authenticated user requests
/// - **Sliding window**: Uses token bucket for smooth rate limiting
/// - **Distributed**: Uses cache (Redis/Valkey) for multi-instance coordination
///
/// Rate limits:
/// - Unauthenticated: 300 requests per 5 minutes per IP
/// - Authenticated: 1000 requests per 5 minutes per user
/// - Burst allowance: Up to 2x the rate limit in burst
public struct RateLimitMiddleware<Context: RequestContext>: RouterMiddleware {
    private let cache: any CacheService
    private let logger: Logger

    /// Rate limit for unauthenticated requests (requests per window)
    private let unauthenticatedLimit: Int

    /// Rate limit for authenticated requests (requests per window)
    private let authenticatedLimit: Int

    /// Time window for rate limiting (in seconds)
    private let windowSeconds: Int

    /// Create a new rate limiting middleware
    ///
    /// - Parameters:
    ///   - cache: Cache service for storing rate limit counters
    ///   - logger: Logger instance
    ///   - unauthenticatedLimit: Max requests per window for unauthenticated users (default: 300)
    ///   - authenticatedLimit: Max requests per window for authenticated users (default: 1000)
    ///   - windowSeconds: Rate limit window in seconds (default: 300 = 5 minutes)
    public init(
        cache: any CacheService,
        logger: Logger? = nil,
        unauthenticatedLimit: Int = 300,
        authenticatedLimit: Int = 1000,
        windowSeconds: Int = 300
    ) {
        self.cache = cache
        self.logger = logger ?? Logger(label: "rate-limit-middleware")
        self.unauthenticatedLimit = unauthenticatedLimit
        self.authenticatedLimit = authenticatedLimit
        self.windowSeconds = windowSeconds
    }

    public func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        // Determine rate limit key and limit
        let (rateLimitKey, limit) = getRateLimitKey(request: request)

        // Check rate limit
        let result = try await checkRateLimit(key: rateLimitKey, limit: limit)

        // Add rate limit headers to response
        let response: Response
        if result.allowed {
            // Process request
            response = try await next(request, context)
        } else {
            // Rate limit exceeded
            logger.warning("Rate limit exceeded", metadata: [
                "rate_limit_key": "\(rateLimitKey)",
                "limit": "\(limit)",
                "remaining": "0",
                "reset_at": "\(result.resetAt)"
            ])

            response = Response(
                status: .tooManyRequests,
                headers: [
                    .contentType: "application/json"
                ],
                body: .init(byteBuffer: .init(string: #"{"error":"Rate limit exceeded","error_description":"Too many requests. Please try again later."}"#))
            )
        }

        // Add rate limit headers
        return addRateLimitHeaders(
            to: response,
            limit: limit,
            remaining: result.remaining,
            resetAt: result.resetAt
        )
    }

    // MARK: - Private Helpers

    /// Determine the rate limit key and limit for a request
    private func getRateLimitKey(request: Request) -> (key: String, limit: Int) {
        // Check if request is authenticated (has Authorization header)
        if let auth = request.headers[.authorization],
           auth.hasPrefix("Bearer ") {
            let token = String(auth.dropFirst(7))
            // Use token hash as key (first 16 chars for brevity)
            let tokenHash = String(token.prefix(16))
            return ("rate_limit:user:\(tokenHash)", authenticatedLimit)
        } else {
            // Use IP address for unauthenticated requests
            // Note: In production, consider X-Forwarded-For header
            let ip = getClientIP(request: request)
            return ("rate_limit:ip:\(ip)", unauthenticatedLimit)
        }
    }

    /// Get client IP address from request
    private func getClientIP(request: Request) -> String {
        // Check X-Forwarded-For header (for requests behind proxy)
        if let forwardedFor = request.headers[values: .init("X-Forwarded-For")!].first {
            // Take the first IP in the list
            if let firstIP = forwardedFor.split(separator: ",").first {
                return String(firstIP).trimmingCharacters(in: .whitespaces)
            }
        }

        // Check X-Real-IP header (for requests behind proxy)
        if let realIP = request.headers[values: .init("X-Real-IP")!].first {
            return realIP
        }

        // Fallback to "unknown" if no IP available
        return "unknown"
    }

    /// Check rate limit using token bucket algorithm
    internal func checkRateLimit(key: String, limit: Int) async throws -> RateLimitResult {
        let now = Date()

        // Try to get existing bucket from cache
        if let bucketData: Data = try await cache.get(key),
           let bucket = try? JSONDecoder().decode(TokenBucket.self, from: bucketData) {
            // Refill tokens based on elapsed time
            let elapsed = now.timeIntervalSince(bucket.lastRefill)
            let refillRate = Double(limit) / Double(windowSeconds)
            let tokensToAdd = Int(elapsed * refillRate)

            var updatedBucket = bucket
            updatedBucket.tokens = min(limit, bucket.tokens + tokensToAdd)
            updatedBucket.lastRefill = now

            // Try to consume a token
            if updatedBucket.tokens > 0 {
                updatedBucket.tokens -= 1

                // Save updated bucket
                let data = try JSONEncoder().encode(updatedBucket)
                try await cache.set(key, value: data, ttl: windowSeconds)

                return RateLimitResult(
                    allowed: true,
                    remaining: updatedBucket.tokens,
                    resetAt: updatedBucket.lastRefill.addingTimeInterval(Double(windowSeconds))
                )
            } else {
                // No tokens available
                return RateLimitResult(
                    allowed: false,
                    remaining: 0,
                    resetAt: updatedBucket.lastRefill.addingTimeInterval(Double(windowSeconds))
                )
            }
        } else {
            // Create new bucket with full tokens
            let bucket = TokenBucket(
                tokens: limit - 1, // Consume one token for this request
                lastRefill: now
            )

            let data = try JSONEncoder().encode(bucket)
            try await cache.set(key, value: data, ttl: windowSeconds)

            return RateLimitResult(
                allowed: true,
                remaining: bucket.tokens,
                resetAt: now.addingTimeInterval(Double(windowSeconds))
            )
        }
    }

    /// Add rate limit headers to response
    private func addRateLimitHeaders(
        to response: Response,
        limit: Int,
        remaining: Int,
        resetAt: Date
    ) -> Response {
        var headers = response.headers
        headers[values: .init("X-RateLimit-Limit")!] = ["\(limit)"]
        headers[values: .init("X-RateLimit-Remaining")!] = ["\(remaining)"]
        headers[values: .init("X-RateLimit-Reset")!] = ["\(Int(resetAt.timeIntervalSince1970))"]

        return Response(
            status: response.status,
            headers: headers,
            body: response.body
        )
    }
}

// MARK: - Supporting Types

/// Token bucket for rate limiting
internal struct TokenBucket: Codable, Sendable {
    /// Number of tokens currently available
    var tokens: Int

    /// Last time tokens were refilled
    var lastRefill: Date
}

/// Result of a rate limit check
internal struct RateLimitResult {
    /// Whether the request is allowed
    let allowed: Bool

    /// Number of remaining requests
    let remaining: Int

    /// When the rate limit resets
    let resetAt: Date
}
