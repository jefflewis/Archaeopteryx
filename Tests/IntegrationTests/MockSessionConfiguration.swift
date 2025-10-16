import Foundation
import ATProtoKit

/// Mock session configuration for integration tests
/// Provides in-memory session management without requiring keychain access
final class MockSessionConfiguration: SessionConfiguration, Sendable {
    public let instanceUUID: UUID
    public let pdsURL: String
    public let codeStream: AsyncStream<String>
    public let codeContinuation: AsyncStream<String>.Continuation
    public let keychainProtocol: SecureKeychainProtocol
    public let configuration: URLSessionConfiguration
    public let canResolve: Bool

    init(
        pdsURL: String = "https://bsky.social",
        accessToken: String,
        refreshToken: String
    ) {
        self.pdsURL = pdsURL
        self.instanceUUID = UUID()

        let (stream, continuation) = AsyncStream<String>.makeStream()
        self.codeStream = stream
        self.codeContinuation = continuation

        self.keychainProtocol = MockKeychain(
            identifier: self.instanceUUID,
            accessToken: accessToken,
            refreshToken: refreshToken
        )

        self.configuration = .default
        self.canResolve = false
    }
}

/// Mock keychain for tests - stores tokens in memory
final class MockKeychain: SecureKeychainProtocol, Sendable {
    let identifier: UUID
    private let accessToken: String
    private let refreshToken: String

    init(identifier: UUID, accessToken: String, refreshToken: String) {
        self.identifier = identifier
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    func saveAccessToken(_ accessToken: String) async throws {
        // No-op for tests
    }

    func retrieveAccessToken() async throws -> String {
        return accessToken
    }

    func updateAccessToken(_ newAccessToken: String) async throws {
        // No-op for tests
    }

    func deleteAccessToken() async throws {
        // No-op for tests
    }

    func saveRefreshToken(_ refreshToken: String) async throws {
        // No-op for tests
    }

    func retrieveRefreshToken() async throws -> String {
        return refreshToken
    }

    func updateRefreshToken(_ newRefreshToken: String) async throws {
        // No-op for tests
    }

    func deleteRefreshToken() async throws {
        // No-op for tests
    }

    func savePassword(_ password: String) async throws {
        // No-op for tests
    }

    func retrievePassword() async throws -> String {
        return "mock_password"
    }

    func updatePassword(_ newPassword: String) async throws {
        // No-op for tests
    }

    func deletePassword() async throws {
        // No-op for tests
    }
}
