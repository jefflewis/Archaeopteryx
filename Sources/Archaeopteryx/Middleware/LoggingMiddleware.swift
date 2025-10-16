import Foundation
import Hummingbird
import HTTPTypes
import Logging

/// Middleware for structured logging of HTTP requests and responses
///
/// This middleware logs:
/// - Request method, path, headers, and query parameters
/// - Response status code and duration
/// - Error conditions with full details
///
/// When used with OpenTelemetry (swift-otel), these logs are automatically
/// exported to an OTLP collector with proper trace correlation.
///
/// Log levels are determined by response status:
/// - 2xx: info
/// - 3xx: info
/// - 4xx: warning
/// - 5xx: error
public struct LoggingMiddleware<Context: RequestContext>: RouterMiddleware {
    private let logger: Logger

    /// Create a new logging middleware
    ///
    /// - Parameter logger: Logger instance to use (will be exported to OTLP if configured)
    public init(logger: Logger) {
        self.logger = logger
    }

    public func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        let startTime = Date()

        // Log incoming request
        logRequest(request, context: context)

        do {
            // Process request
            let response = try await next(request, context)

            // Calculate duration
            let duration = Date().timeIntervalSince(startTime)

            // Log response
            logResponse(response, duration: duration, request: request, context: context)

            return response
        } catch {
            // Calculate duration
            let duration = Date().timeIntervalSince(startTime)

            // Log error
            logError(error, duration: duration, request: request, context: context)

            throw error
        }
    }

    // MARK: - Private Helpers

    private func logRequest(_ request: Request, context: Context) {
        var metadata: Logger.Metadata = [
            "http.method": "\(request.method)",
            "http.target": "\(request.uri.path)",
            "http.scheme": "\(request.uri.scheme?.rawValue ?? "http")",
        ]

        // Add query parameters if present
        if let query = request.uri.query, !query.isEmpty {
            metadata["http.query"] = "\(query)"
        }

        // Add user agent if present
        if let userAgent = request.headers[.userAgent] {
            metadata["http.user_agent"] = "\(userAgent)"
        }

        // Add request ID if present (for tracing correlation)
        if let requestID = request.headers[values: .init("X-Request-ID")!].first {
            metadata["request.id"] = "\(requestID)"
        }

        // Add authorization type (but not the actual token)
        if let auth = request.headers[.authorization] {
            let authType = auth.split(separator: " ").first.map(String.init) ?? "unknown"
            metadata["http.auth.type"] = "\(authType)"
        }

        logger.info("Incoming request", metadata: metadata)
    }

    private func logResponse(
        _ response: Response,
        duration: TimeInterval,
        request: Request,
        context: Context
    ) {
        var metadata: Logger.Metadata = [
            "http.method": "\(request.method)",
            "http.target": "\(request.uri.path)",
            "http.status_code": "\(response.status.code)",
            "http.duration_ms": "\(Int(duration * 1000))",
        ]

        // Add request ID if present
        if let requestID = request.headers[values: .init("X-Request-ID")!].first {
            metadata["request.id"] = "\(requestID)"
        }

        // Add response size if available
        if let contentLength = response.headers[.contentLength] {
            metadata["http.response.size"] = "\(contentLength)"
        }

        // Determine log level based on status code
        let statusCode = response.status.code
        let message: Logger.Message = "Request completed"

        switch statusCode {
        case 200..<300:
            logger.info(message, metadata: metadata)
        case 300..<400:
            logger.info(message, metadata: metadata)
        case 400..<500:
            metadata["http.status.category"] = "client_error"
            logger.warning(message, metadata: metadata)
        case 500..<600:
            metadata["http.status.category"] = "server_error"
            logger.error(message, metadata: metadata)
        default:
            logger.info(message, metadata: metadata)
        }
    }

    private func logError(
        _ error: Error,
        duration: TimeInterval,
        request: Request,
        context: Context
    ) {
        var metadata: Logger.Metadata = [
            "http.method": "\(request.method)",
            "http.target": "\(request.uri.path)",
            "error.message": "\(error)",
            "error.type": "\(type(of: error))",
            "http.duration_ms": "\(Int(duration * 1000))",
        ]

        // Add request ID if present
        if let requestID = request.headers[values: .init("X-Request-ID")!].first {
            metadata["request.id"] = "\(requestID)"
        }

        // Add error details for known error types
        if let localizedError = error as? LocalizedError {
            if let description = localizedError.errorDescription {
                metadata["error.description"] = "\(description)"
            }
            if let reason = localizedError.failureReason {
                metadata["error.reason"] = "\(reason)"
            }
        }

        logger.error("Request failed with error", metadata: metadata)
    }
}
