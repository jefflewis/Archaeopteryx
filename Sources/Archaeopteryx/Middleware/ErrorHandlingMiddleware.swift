import Foundation
import Hummingbird
import HTTPTypes
import Logging

/// Middleware for consistent error handling and responses
///
/// This middleware:
/// - Catches all errors thrown by route handlers
/// - Converts errors to Mastodon-compatible JSON responses
/// - Logs errors with appropriate severity
/// - Returns proper HTTP status codes
/// - Provides helpful error messages for debugging
///
/// Error Response Format (Mastodon-compatible):
/// ```json
/// {
///   "error": "Error code or title",
///   "error_description": "Human-readable description"
/// }
/// ```
public struct ErrorHandlingMiddleware<Context: RequestContext>: RouterMiddleware {
    private let logger: Logger

    /// Create a new error handling middleware
    ///
    /// - Parameter logger: Logger instance for error logging
    public init(logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "error-handling-middleware")
    }

    public func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        do {
            return try await next(request, context)
        } catch {
            return handleError(error, request: request, context: context)
        }
    }

    // MARK: - Error Handling

    /// Handle an error and convert it to a proper HTTP response
    private func handleError(
        _ error: Error,
        request: Request,
        context: Context
    ) -> Response {
        // Determine error details
        let errorInfo = classifyError(error)

        // Log the error
        logError(error, info: errorInfo, request: request)

        // Create error response body
        let errorBody = ErrorResponse(
            error: errorInfo.code,
            errorDescription: errorInfo.description
        )

        // Encode response
        guard let bodyData = try? JSONEncoder().encode(errorBody) else {
            // Fallback if encoding fails
            return Response(
                status: .internalServerError,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: .init(string: #"{"error":"internal_server_error","error_description":"An unexpected error occurred"}"#))
            )
        }

        return Response(
            status: errorInfo.status,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: .init(data: bodyData))
        )
    }

    /// Classify an error and determine response details
    private func classifyError(_ error: Error) -> ErrorInfo {
        // Check for HTTP errors
        if let httpError = error as? HTTPError {
            return ErrorInfo(
                code: httpError.code,
                description: httpError.description,
                status: httpError.status
            )
        }

        // Check for known error types
        switch error {
        // Hummingbird errors
        case let error as HTTPResponseError:
            return handleHTTPResponseError(error)

        // Decoding errors
        case is DecodingError:
            return ErrorInfo(
                code: "invalid_request",
                description: "Invalid request format or parameters",
                status: .badRequest
            )

        // Encoding errors
        case is EncodingError:
            return ErrorInfo(
                code: "internal_server_error",
                description: "Failed to encode response",
                status: .internalServerError
            )

        // Cancellation errors
        case is CancellationError:
            return ErrorInfo(
                code: "request_cancelled",
                description: "Request was cancelled",
                status: .internalServerError
            )

        // Generic errors
        default:
            return ErrorInfo(
                code: "internal_server_error",
                description: "An unexpected error occurred: \(error.localizedDescription)",
                status: .internalServerError
            )
        }
    }

    /// Handle Hummingbird HTTPResponseError
    private func handleHTTPResponseError(_ error: HTTPResponseError) -> ErrorInfo {
        switch error.status {
        case .badRequest:
            return ErrorInfo(
                code: "invalid_request",
                description: "Bad request",
                status: .badRequest
            )
        case .unauthorized:
            return ErrorInfo(
                code: "unauthorized",
                description: "Authentication required or invalid credentials",
                status: .unauthorized
            )
        case .forbidden:
            return ErrorInfo(
                code: "forbidden",
                description: "Access denied",
                status: .forbidden
            )
        case .notFound:
            return ErrorInfo(
                code: "not_found",
                description: "Resource not found",
                status: .notFound
            )
        case .unprocessableContent:
            return ErrorInfo(
                code: "unprocessable_entity",
                description: "Validation failed",
                status: .unprocessableContent
            )
        case .tooManyRequests:
            return ErrorInfo(
                code: "rate_limit_exceeded",
                description: "Too many requests. Please try again later.",
                status: .tooManyRequests
            )
        default:
            return ErrorInfo(
                code: "http_error",
                description: "HTTP error occurred",
                status: error.status
            )
        }
    }

    /// Log an error with appropriate severity
    private func logError(
        _ error: Error,
        info: ErrorInfo,
        request: Request
    ) {
        let metadata: Logger.Metadata = [
            "error_code": "\(info.code)",
            "http_status": "\(info.status.code)",
            "http_method": "\(request.method)",
            "http_path": "\(request.uri.path)",
            "error_type": "\(type(of: error))",
        ]

        // Log based on status code
        switch info.status.code {
        case 400..<500:
            // Client errors - warning level
            logger.warning("Client error", metadata: metadata)
        case 500..<600:
            // Server errors - error level
            logger.error("Server error", metadata: metadata.merging([
                "error_message": "\(error)"
            ]) { $1 })
        default:
            logger.notice("Unexpected status code", metadata: metadata)
        }
    }
}

// MARK: - Supporting Types

/// HTTP error with code, description, and status
public struct HTTPError: Error, LocalizedError {
    public let code: String
    public let description: String
    public let status: HTTPResponse.Status

    public init(code: String, description: String, status: HTTPResponse.Status) {
        self.code = code
        self.description = description
        self.status = status
    }

    public var errorDescription: String? {
        return description
    }

    // Common HTTP errors
    public static func badRequest(_ description: String) -> HTTPError {
        HTTPError(code: "invalid_request", description: description, status: .badRequest)
    }

    public static func unauthorized(_ description: String = "Authentication required") -> HTTPError {
        HTTPError(code: "unauthorized", description: description, status: .unauthorized)
    }

    public static func forbidden(_ description: String = "Access denied") -> HTTPError {
        HTTPError(code: "forbidden", description: description, status: .forbidden)
    }

    public static func notFound(_ description: String) -> HTTPError {
        HTTPError(code: "not_found", description: description, status: .notFound)
    }

    public static func unprocessableEntity(_ description: String) -> HTTPError {
        HTTPError(code: "unprocessable_entity", description: description, status: .unprocessableContent)
    }

    public static func internalServerError(_ description: String = "Internal server error") -> HTTPError {
        HTTPError(code: "internal_server_error", description: description, status: .internalServerError)
    }
}

/// Error information for response
private struct ErrorInfo {
    let code: String
    let description: String
    let status: HTTPResponse.Status
}

/// Mastodon-compatible error response
private struct ErrorResponse: Codable {
    let error: String
    let errorDescription: String

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}
