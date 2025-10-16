import Foundation

/// Custom URLProtocol that intercepts network requests and returns mock responses
/// This allows integration tests to use the real HTTP stack while mocking Bluesky API responses
final class MockURLProtocol: URLProtocol {
    /// Type for request handlers - takes a request and returns (response, data, error)
    typealias RequestHandler = (URLRequest) throws -> (HTTPURLResponse, Data?)

    /// Static registry of mock request handlers
    private static nonisolated(unsafe) var requestHandlers: [String: RequestHandler] = [:]

    /// Lock for thread-safe access to handlers
    private static let lock = NSLock()

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
    ) {
        lock.lock()
        defer { lock.unlock() }

        requestHandlers[pattern] = { request in
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

            return (response, data)
        }
    }

    /// Register a custom handler for a URL pattern
    /// - Parameters:
    ///   - pattern: URL pattern to match
    ///   - handler: Custom handler that processes the request
    static func registerHandler(
        pattern: String,
        handler: @escaping RequestHandler
    ) {
        lock.lock()
        defer { lock.unlock() }

        requestHandlers[pattern] = handler
    }

    /// Clear all registered mocks
    static func clearMocks() {
        lock.lock()
        defer { lock.unlock() }

        requestHandlers.removeAll()
    }

    // MARK: - URLProtocol Implementation

    override class func canInit(with request: URLRequest) -> Bool {
        // Only handle requests to bsky.social domains
        guard let url = request.url,
              let host = url.host,
              host.contains("bsky.social") || host.contains("bsky.app") else {
            return false
        }

        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Self.lock.lock()
        let handlers = Self.requestHandlers
        Self.lock.unlock()

        // Find matching handler
        for (pattern, handler) in handlers {
            if url.absoluteString.contains(pattern) {
                do {
                    let (response, data) = try handler(request)

                    // Send response to client
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

                    if let data = data {
                        client?.urlProtocol(self, didLoad: data)
                    }

                    client?.urlProtocolDidFinishLoading(self)
                    return
                } catch {
                    client?.urlProtocol(self, didFailWithError: error)
                    return
                }
            }
        }

        // No handler found - fail with error
        client?.urlProtocol(
            self,
            didFailWithError: URLError(.resourceUnavailable)
        )
    }

    override func stopLoading() {
        // Nothing to clean up
    }
}
