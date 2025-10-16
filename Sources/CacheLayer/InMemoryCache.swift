import Foundation
import IDMapping

/// In-memory cache implementation for testing purposes
public actor InMemoryCache: CacheService {
    /// Cached entry with expiration support
    private struct CacheEntry {
        let data: Data
        let expiresAt: Date?

        var isExpired: Bool {
            guard let expiresAt = expiresAt else {
                return false // No expiration
            }
            return Date() > expiresAt
        }
    }

    /// Internal storage
    private var storage: [String: CacheEntry] = [:]

    /// JSON encoder for serialization
    private let encoder = JSONEncoder()

    /// JSON decoder for deserialization
    private let decoder = JSONDecoder()

    public init() {}

    // MARK: - CacheService Protocol

    public func get<T: Codable>(_ key: String) async throws -> T? {
        // Clean up expired entries during read
        if let entry = storage[key] {
            if entry.isExpired {
                storage.removeValue(forKey: key)
                return nil
            }

            // Decode the data
            do {
                return try decoder.decode(T.self, from: entry.data)
            } catch {
                // If decoding fails (type mismatch), return nil
                return nil
            }
        }

        return nil
    }

    public func set<T: Codable>(_ key: String, value: T, ttl: Int?) async throws {
        // Encode the value
        let data = try encoder.encode(value)

        // Calculate expiration
        let expiresAt: Date?
        if let ttl = ttl {
            expiresAt = Date().addingTimeInterval(TimeInterval(ttl))
        } else {
            expiresAt = nil
        }

        // Store the entry
        storage[key] = CacheEntry(data: data, expiresAt: expiresAt)
    }

    public func delete(_ key: String) async throws {
        storage.removeValue(forKey: key)
    }

    public func exists(_ key: String) async throws -> Bool {
        guard let entry = storage[key] else {
            return false
        }

        // Check if expired
        if entry.isExpired {
            storage.removeValue(forKey: key)
            return false
        }

        return true
    }

    // MARK: - Additional Utilities

    /// Clear all entries from cache
    public func clear() async {
        storage.removeAll()
    }

    /// Remove all expired entries
    public func cleanupExpired() async {
        let expiredKeys = storage.filter { $0.value.isExpired }.map { $0.key }
        for key in expiredKeys {
            storage.removeValue(forKey: key)
        }
    }

    /// Get the number of entries in cache (for testing)
    public func count() async -> Int {
        return storage.count
    }
}

// MARK: - CacheProtocol Conformance

extension InMemoryCache: CacheProtocol {
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
