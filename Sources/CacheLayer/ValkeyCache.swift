import Foundation
import Dependencies

/// Valkey cache implementation using valkey-swift with dependency injection
public actor ValkeyCache: CacheService {
    /// Valkey client dependency
    @Dependency(\.redisClient) private var client

    /// JSON encoder for serialization
    private let encoder = JSONEncoder()

    /// JSON decoder for deserialization
    private let decoder = JSONDecoder()

    // MARK: - Initialization

    public init() {
        // Dependencies are injected via @Dependency property wrapper
    }

    // MARK: - Connection Management

    public func disconnect() async throws {
        try await client.disconnect()
    }

    // MARK: - CacheService Protocol

    public func get<T: Codable>(_ key: String) async throws -> T? {
        do {
            // Get returns Optional<String>
            guard let jsonString = try await client.get(key) else {
                return nil
            }

            // Convert string to Data
            guard let data = jsonString.data(using: .utf8) else {
                return nil
            }

            // Decode the JSON data
            let decoded = try decoder.decode(T.self, from: data)
            return decoded
        } catch is DecodingError {
            // Return nil if decoding fails (type mismatch)
            return nil
        } catch {
            throw CacheError.operationFailed(underlying: error)
        }
    }

    public func set<T: Codable>(_ key: String, value: T, ttl: Int?) async throws {
        do {
            // Encode the value to JSON
            let data = try encoder.encode(value)
            let jsonString = String(data: data, encoding: .utf8) ?? ""

            try await client.set(key, jsonString, ttl)
        } catch {
            throw CacheError.operationFailed(underlying: error)
        }
    }

    public func delete(_ key: String) async throws {
        do {
            try await client.delete(key)
        } catch {
            throw CacheError.operationFailed(underlying: error)
        }
    }

    public func exists(_ key: String) async throws -> Bool {
        do {
            return try await client.exists(key)
        } catch {
            throw CacheError.operationFailed(underlying: error)
        }
    }

    // MARK: - Additional Utilities

    /// Clear all keys in the current database (use with caution!)
    public func clear() async throws {
        do {
            try await client.clear()
        } catch {
            throw CacheError.operationFailed(underlying: error)
        }
    }
}

// MARK: - Cache Errors

public enum CacheError: Error, CustomStringConvertible {
    case notConnected
    case connectionFailed(underlying: Error)
    case operationFailed(underlying: Error)

    public var description: String {
        switch self {
        case .notConnected:
            return "Cache is not connected"
        case .connectionFailed(let error):
            return "Cache connection failed: \(error)"
        case .operationFailed(let error):
            return "Cache operation failed: \(error)"
        }
    }
}

// MARK: - CacheProtocol Conformance

import IDMapping

extension ValkeyCache: CacheProtocol {
    public func getSnowflake(forDID did: String) async -> Int64? {
        return try? await get("did_to_snowflake:\(did)")
    }

    public func getDID(forSnowflake snowflake: Int64) async -> String? {
        return try? await get("snowflake_to_did:\(snowflake)")
    }

    public func getSnowflake(forATURI atURI: String) async -> Int64? {
        return try? await get("at_uri_to_snowflake:\(atURI)")
    }

    public func getATURI(forSnowflake snowflake: Int64) async -> String? {
        return try? await get("snowflake_to_at_uri:\(snowflake)")
    }

    public func getDID(forHandle handle: String) async -> String? {
        return try? await get("handle_to_did:\(handle)")
    }

    public func storeMapping(did: String, snowflake: Int64) async {
        try? await set("did_to_snowflake:\(did)", value: snowflake, ttl: nil)
        try? await set("snowflake_to_did:\(snowflake)", value: did, ttl: nil)
    }

    public func storeMapping(atURI: String, snowflake: Int64) async {
        try? await set("at_uri_to_snowflake:\(atURI)", value: snowflake, ttl: nil)
        try? await set("snowflake_to_at_uri:\(snowflake)", value: atURI, ttl: nil)
    }
}
