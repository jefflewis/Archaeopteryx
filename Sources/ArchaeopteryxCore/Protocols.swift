import Foundation

/// Protocol for types that can be cached
public protocol Cacheable: Codable, Sendable {
    /// Cache key for this instance
    var cacheKey: String { get }

    /// TTL (time to live) in seconds for this instance in cache
    /// Return nil for no expiration
    var cacheTTL: Int? { get }
}

/// Protocol for types that can be translated between different API formats
public protocol Translatable {
    associatedtype Source
    associatedtype Destination

    /// Translate from source format to destination format
    static func translate(from source: Source) throws -> Destination
}

/// Protocol for types that have a unique identifier
public protocol Identifiable: Sendable {
    associatedtype ID: Hashable, Sendable

    /// Unique identifier
    var id: ID { get }
}
