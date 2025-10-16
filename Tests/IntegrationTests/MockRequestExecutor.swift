import Foundation
import ATProtoKit

/// Thread-safe storage for mock handlers
private actor MockHandlerStorage {
    typealias RequestHandler = @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    private var handlers: [String: RequestHandler] = [:]

    func register(pattern: String, handler: @escaping RequestHandler) {
        handlers[pattern] = handler
    }

    func clear() {
        handlers.removeAll()
    }

    func findHandler(for url: URL) -> (String, RequestHandler)? {
        for (pattern, handler) in handlers {
            if url.absoluteString.contains(pattern) {
                return (pattern, handler)
            }
        }
        return nil
    }

    func patterns() -> [String] {
        return Array(handlers.keys)
    }
}

/// Mock request executor for integration tests
/// Implements ATRequestExecutor to intercept network requests and return mock responses
final class MockRequestExecutor: ATRequestExecutor, Sendable {
    /// Type for request handlers - takes a request and returns (data, response)
    typealias RequestHandler = @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    /// Thread-safe storage for handlers
    private static let storage = MockHandlerStorage()

    // MARK: - Public API

    /// Register a mock response for a specific URL pattern
    /// - Parameters:
    ///   - pattern: URL pattern to match (e.g., "getProfile", "createSession")
    ///   - statusCode: HTTP status code to return
    ///   - data: Response body data
    static func registerMock(
        pattern: String,
        statusCode: Int = 200,
        data: Data?
    ) async {
        await storage.register(pattern: pattern) { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            guard let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            ) else {
                throw URLError(.cannotCreateFile)
            }

            return (data ?? Data(), response)
        }
    }

    /// Register a custom handler for a URL pattern
    /// - Parameters:
    ///   - pattern: URL pattern to match
    ///   - handler: Custom handler that processes the request
    static func registerHandler(
        pattern: String,
        handler: @escaping RequestHandler
    ) async {
        await storage.register(pattern: pattern, handler: handler)
    }

    /// Clear all registered mocks
    static func clearMocks() async {
        await storage.clear()
    }

    // MARK: - ATRequestExecutor Implementation

    func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }

        // Find matching handler
        if let (pattern, handler) = await Self.storage.findHandler(for: url) {
            print("✅ MockRequestExecutor: Matched pattern '\(pattern)' for URL: \(url.absoluteString)")
            return try handler(request)
        }

        // No handler found - fail with error
        let registeredPatterns = await Self.storage.patterns()
        print("❌ MockRequestExecutor: No handler found for URL: \(url.absoluteString)")
        print("   Registered patterns: \(registeredPatterns)")
        throw URLError(.resourceUnavailable)
    }
}
