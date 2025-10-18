import Foundation
import Dependencies
import DependenciesMacros
import Valkey
import Logging

/// Dependency wrapper for Valkey client operations
@DependencyClient
public struct RedisClientDependency: Sendable {
    /// Get a value from Valkey (returns nil if key doesn't exist)
    public var get: @Sendable (String) async throws -> String? = { _ in nil }

    /// Set a value in Redis
    public var set: @Sendable (String, String, Int?) async throws -> Void

    /// Delete a key from Redis
    public var delete: @Sendable (String) async throws -> Void

    /// Check if a key exists in Redis
    public var exists: @Sendable (String) async throws -> Bool = { _ in false }

    /// Clear all keys in the current database
    public var clear: @Sendable () async throws -> Void

    /// Close the connection
    public var disconnect: @Sendable () async throws -> Void
}

// MARK: - Dependency Key

extension RedisClientDependency: DependencyKey {
    /// Default live value - will use unimplemented stubs
    /// Actual live client should be injected via withDependencies in App.swift
    public static let liveValue = RedisClientDependency()

    public static let testValue = RedisClientDependency.mock()
}

extension DependencyValues {
    public var redisClient: RedisClientDependency {
        get { self[RedisClientDependency.self] }
        set { self[RedisClientDependency.self] = newValue }
    }
}

// MARK: - Live Implementation

extension RedisClientDependency {
    /// Create a live Valkey client dependency wrapping a ValkeyClient instance
    /// The ValkeyClient should be managed by ValkeyService in the application lifecycle
    public static func live(client: ValkeyClient) -> Self {
        return Self(
            get: { key in
                // GET returns Optional<ByteBuffer> according to API
                // We need to convert it to String
                let valkeyKey = ValkeyKey(key)
                if let buffer = try await client.get(valkeyKey) {
                    return String(buffer: buffer)
                }
                return nil
            },
            set: { key, value, ttl in
                let valkeyKey = ValkeyKey(key)

                if let ttl = ttl {
                    // SET with EXAT (expire at unix timestamp) or EX (expire in seconds)
                    // Using EX for seconds
                    _ = try await client.setex(valkeyKey, seconds: ttl, value: value)
                } else {
                    _ = try await client.set(valkeyKey, value: value)
                }
            },
            delete: { key in
                let valkeyKey = ValkeyKey(key)
                _ = try await client.del(keys: [valkeyKey])
            },
            exists: { key in
                let valkeyKey = ValkeyKey(key)
                let count = try await client.exists(keys: [valkeyKey])
                return count > 0
            },
            clear: {
                _ = try await client.flushdb()
            },
            disconnect: {
                // No-op - lifecycle is managed by ValkeyService
            }
        )
    }
}

// MARK: - Mock Implementation

extension RedisClientDependency {
    /// Create a mock Valkey client for testing
    public static func mock() -> Self {
        let storage = MockValkeyStorage()

        return Self(
            get: { key in
                await storage.get(key)
            },
            set: { key, value, ttl in
                await storage.set(key, value: value, ttl: ttl)
            },
            delete: { key in
                await storage.delete(key)
            },
            exists: { key in
                await storage.exists(key)
            },
            clear: {
                await storage.clear()
            },
            disconnect: {
                // No-op for mock
            }
        )
    }
}

// MARK: - Mock Storage

/// In-memory storage for mock Valkey client
private actor MockValkeyStorage {
    private var storage: [String: (value: String, expiry: Date?)] = [:]

    func get(_ key: String) -> String? {
        // Remove expired keys
        cleanExpired()

        guard let entry = storage[key] else {
            return nil
        }

        // Check if expired
        if let expiry = entry.expiry, expiry < Date() {
            storage.removeValue(forKey: key)
            return nil
        }

        return entry.value
    }

    func set(_ key: String, value: String, ttl: Int?) {
        let expiry = ttl.map { Date().addingTimeInterval(TimeInterval($0)) }
        storage[key] = (value, expiry)
    }

    func delete(_ key: String) {
        storage.removeValue(forKey: key)
    }

    func exists(_ key: String) -> Bool {
        cleanExpired()

        guard let entry = storage[key] else {
            return false
        }

        // Check if expired
        if let expiry = entry.expiry, expiry < Date() {
            storage.removeValue(forKey: key)
            return false
        }

        return true
    }

    func clear() {
        storage.removeAll()
    }

    private func cleanExpired() {
        let now = Date()
        storage = storage.filter { _, entry in
            guard let expiry = entry.expiry else { return true }
            return expiry >= now
        }
    }
}
