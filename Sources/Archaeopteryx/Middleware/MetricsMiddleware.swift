import Foundation
import Hummingbird
import HTTPTypes
import Logging
import Metrics

/// Middleware for collecting HTTP metrics
///
/// This middleware records:
/// - **Request counter**: Total HTTP requests by method, route, and status
/// - **Request duration**: Response time (using Timer)
/// - **Active requests**: Gauge of concurrent requests
public struct MetricsMiddleware<Context: RequestContext>: RouterMiddleware {
    private let logger: Logger

    /// Create a new metrics middleware
    ///
    /// - Parameter logger: Logger instance for metrics-related logging
    public init(logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "metrics-middleware")
    }

    public func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        let startTime = Date()
        let method = "\(request.method)"
        let path = "\(request.uri.path)"

        // Increment active requests gauge
        let activeRequestsGauge = Gauge(label: "http_server_active_requests")
        activeRequestsGauge.record(1)

        defer {
            // Decrement active requests gauge
            activeRequestsGauge.record(-1)
        }

        do {
            // Process request
            let response = try await next(request, context)

            // Calculate duration
            let duration = Date().timeIntervalSince(startTime)

            // Record metrics
            recordMetrics(
                method: method,
                path: path,
                statusCode: response.status.code,
                duration: duration,
                error: nil
            )

            return response
        } catch {
            // Calculate duration
            let duration = Date().timeIntervalSince(startTime)

            // Record metrics with error
            recordMetrics(
                method: method,
                path: path,
                statusCode: 500,
                duration: duration,
                error: error
            )

            throw error
        }
    }

    // MARK: - Private Helpers

    private func recordMetrics(
        method: String,
        path: String,
        statusCode: Int,
        duration: TimeInterval,
        error: Error?
    ) {
        let labels: [(String, String)] = [
            ("http_method", method),
            ("http_route", path),
            ("http_status_code", "\(statusCode)"),
        ]

        // Increment request counter
        let requestCounter = Counter(label: "http_server_requests_total", dimensions: labels)
        requestCounter.increment()

        // Record request duration (in nanoseconds for swift-metrics Timer)
        let durationTimer = Timer(label: "http_server_request_duration_seconds", dimensions: labels)
        durationTimer.recordNanoseconds(Int64(duration * 1_000_000_000))

        // If error, increment error counter
        if error != nil {
            let errorCounter = Counter(label: "http_server_errors_total", dimensions: labels)
            errorCounter.increment()
        }
    }
}
