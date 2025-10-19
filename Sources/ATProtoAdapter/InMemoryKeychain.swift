import Foundation
import ATProtoKit

/// In-memory keychain for multi-user session management
/// Stores tokens temporarily for the duration of a request
public actor InMemoryKeychain: SecureKeychainProtocol {
    public let identifier: UUID
    
    private var accessToken: String?
    private var refreshToken: String?
    private var password: String?
    
    public init(identifier: UUID = UUID(), accessToken: String, refreshToken: String) {
        self.identifier = identifier
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
    
    public func retrieveAccessToken() async throws -> String {
        guard let token = accessToken else {
            throw ATProtoError.sessionExpired
        }
        return token
    }
    
    public func saveAccessToken(_ accessToken: String) async throws {
        self.accessToken = accessToken
    }
    
    public func deleteAccessToken() async throws {
        self.accessToken = nil
    }
    
    public func retrieveRefreshToken() async throws -> String {
        guard let token = refreshToken else {
            throw ATProtoError.sessionExpired
        }
        return token
    }
    
    public func saveRefreshToken(_ refreshToken: String) async throws {
        self.refreshToken = refreshToken
    }
    
    public func updateRefreshToken(_ newRefreshToken: String) async throws {
        self.refreshToken = newRefreshToken
    }
    
    public func deleteRefreshToken() async throws {
        self.refreshToken = nil
    }
    
    public func savePassword(_ password: String) async throws {
        self.password = password
    }
    
    public func retrievePassword() async throws -> String {
        guard let pwd = password else {
            throw ATProtoError.sessionExpired
        }
        return pwd
    }
    
    public func updatePassword(_ newPassword: String) async throws {
        self.password = newPassword
    }
    
    public func deletePassword() async throws {
        self.password = nil
    }
}
