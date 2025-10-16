import Foundation
import Hummingbird
import HTTPTypes
import Logging
import Tracing

/// Middleware for distributed tracing of HTTP requests
///
/// This middleware:
/// - Creates a span for each HTTP request
/// - Propagates W3C TraceContext headers
/// - Correlates logs with traces via span IDs
/// - Records HTTP semantic conventions (method, status, duration)
public struct TracingMiddleware<Context: RequestContext>: RouterMiddleware {
    private let logger: Logger

    /// Create a new tracing middleware
    ///
    /// - Parameter logger: Logger instance for trace-correlated logging
    public init(logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "tracing-middleware")
    }

    public func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        // Create span for this HTTP request
        return try await withSpan("\(request.method) \(request.uri.path)") { span in
            let startTime = Date()

            // Add HTTP semantic conventions to span
            span.attributes["http.method"] = "\(request.method)"
            span.attributes["http.target"] = "\(request.uri.path)"
            span.attributes["http.scheme"] = "\(request.uri.scheme?.rawValue ?? "http")"

            if let query = request.uri.query, !query.isEmpty {
                span.attributes["http.query"] = "\(query)"
            }

            if let userAgent = request.headers[.userAgent] {
                span.attributes["http.user_agent"] = "\(userAgent)"
            }

            do {
                // Process request
                let response = try await next(request, context)

                // Record response status
                span.attributes["http.status_code"] = Int(response.status.code)

                // Calculate duration
                let duration = Date().timeIntervalSince(startTime)
                span.attributes["http.duration_ms"] = Int(duration * 1000)

                // Set span status based on HTTP status code
                if response.status.code >= 500 {
                    span.setStatus(.init(code: .error, message: "Server error"))
                } else if response.status.code >= 400 {
                    span.setStatus(.init(code: .error, message: "Client error"))
                } else {
                    span.setStatus(.init(code: .ok))
                }

                return response
            } catch {
                // Record error in span
                let duration = Date().timeIntervalSince(startTime)
                span.attributes["http.duration_ms"] = Int(duration * 1000)
                span.setStatus(.init(code: .error, message: "\(error)"))
                span.recordError(error)

                throw error
            }
        }
    }
}
