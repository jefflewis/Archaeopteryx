import Foundation

/// Errors that can occur when interacting with AT Protocol services
public enum ATProtoError: Error, CustomStringConvertible, Sendable {
    /// Session has expired and needs to be refreshed
    case sessionExpired

    /// Invalid handle or DID format
    case invalidHandle(String)

    /// Profile not found
    case profileNotFound(handle: String)

    /// Post not found
    case postNotFound(uri: String)

    /// Network error occurred
    case networkError(underlying: Error)

    /// Authentication failed
    case authenticationFailed(reason: String)

    /// Rate limit exceeded
    case rateLimited(retryAfter: TimeInterval?)

    /// Invalid response from server
    case invalidResponse(statusCode: Int)

    /// Generic API error
    case apiError(message: String)

    /// Unknown error
    case unknown(underlying: Error)

    /// Feature not implemented yet
    case notImplemented(feature: String)

    /// Invalid AT URI format
    case invalidURI(uri: String)

    public var description: String {
        switch self {
        case .sessionExpired:
            return "Session has expired"
        case .invalidHandle(let handle):
            return "Invalid handle: \(handle)"
        case .profileNotFound(let handle):
            return "Profile not found: \(handle)"
        case .postNotFound(let uri):
            return "Post not found: \(uri)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited. Retry after \(retryAfter) seconds"
            }
            return "Rate limited"
        case .invalidResponse(let statusCode):
            return "Invalid response: HTTP \(statusCode)"
        case .apiError(let message):
            return "API error: \(message)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        case .notImplemented(let feature):
            return "Feature not implemented: \(feature)"
        case .invalidURI(let uri):
            return "Invalid AT URI format: \(uri)"
        }
    }
}
