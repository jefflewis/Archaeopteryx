import Foundation

/// Protocol for cache service implementations
public protocol CacheService: Actor {
    /// Get a value from cache
    func get<T: Codable>(_ key: String) async throws -> T?

    /// Set a value in cache with optional TTL (time to live) in seconds
    func set<T: Codable>(_ key: String, value: T, ttl: Int?) async throws

    /// Delete a value from cache
    func delete(_ key: String) async throws

    /// Check if a key exists in cache
    func exists(_ key: String) async throws -> Bool
}
