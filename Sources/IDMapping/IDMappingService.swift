import Foundation
import CryptoKit

/// Service for mapping between Bluesky identifiers (DIDs, AT URIs, handles) and Mastodon Snowflake IDs
///
/// This service provides deterministic, bidirectional mapping between:
/// - DIDs (decentralized identifiers) ↔ Snowflake IDs
/// - AT URIs (post URIs) ↔ Snowflake IDs
/// - Handles (user handles) → Snowflake IDs (via DID resolution)
///
/// DID to Snowflake mapping is deterministic - the same DID always maps to the same Snowflake ID
/// by hashing the DID and using the first 8 bytes as the ID.
public actor IDMappingService {
    private let cache: any CacheProtocol
    private let generator: SnowflakeIDGenerator

    /// Initialize the ID mapping service
    /// - Parameters:
    ///   - cache: Cache service for storing mappings
    ///   - generator: Snowflake ID generator for creating new IDs
    public init(cache: any CacheProtocol, generator: SnowflakeIDGenerator) {
        self.cache = cache
        self.generator = generator
    }

    // MARK: - DID to Snowflake Mapping

    /// Get Snowflake ID for a DID (deterministic mapping)
    /// - Parameter did: Bluesky DID (e.g., "did:plc:abc123")
    /// - Returns: Snowflake ID mapped from the DID
    public func getSnowflakeID(forDID did: String) async -> Int64 {
        // Check cache first
        if let cached = await cache.getSnowflake(forDID: did) {
            return cached
        }

        // Generate deterministic Snowflake ID from DID hash
        let snowflake = generateDeterministicSnowflake(from: did)

        // Store mapping in cache (never expires - deterministic)
        await cache.storeMapping(did: did, snowflake: snowflake)

        return snowflake
    }

    /// Get DID for a Snowflake ID (reverse lookup)
    /// - Parameter snowflakeID: Snowflake ID
    /// - Returns: DID if mapping exists, nil otherwise
    public func getDID(forSnowflakeID snowflakeID: Int64) async -> String? {
        return await cache.getDID(forSnowflake: snowflakeID)
    }

    // MARK: - AT URI to Snowflake Mapping

    /// Get Snowflake ID for an AT URI (post identifier)
    /// - Parameter atURI: AT Protocol URI (e.g., "at://did:plc:abc/app.bsky.feed.post/xyz")
    /// - Returns: Snowflake ID mapped from the AT URI
    public func getSnowflakeID(forATURI atURI: String) async -> Int64 {
        // Check cache first
        if let cached = await cache.getSnowflake(forATURI: atURI) {
            return cached
        }

        // Generate deterministic Snowflake ID from AT URI hash
        let snowflake = generateDeterministicSnowflake(from: atURI)

        // Store mapping in cache (never expires - deterministic)
        await cache.storeMapping(atURI: atURI, snowflake: snowflake)

        return snowflake
    }

    /// Get AT URI for a Snowflake ID (reverse lookup)
    /// - Parameter snowflakeID: Snowflake ID
    /// - Returns: AT URI if mapping exists, nil otherwise
    public func getATURI(forSnowflakeID snowflakeID: Int64) async -> String? {
        return await cache.getATURI(forSnowflake: snowflakeID)
    }

    // MARK: - Handle to Snowflake Mapping

    /// Get Snowflake ID for a handle (requires DID resolution)
    /// - Parameter handle: Bluesky handle (e.g., "alice.bsky.social")
    /// - Returns: Snowflake ID if handle can be resolved, 0 otherwise
    public func getSnowflakeID(forHandle handle: String) async -> Int64 {
        // Try to resolve handle to DID via cache
        guard let did = await cache.getDID(forHandle: handle) else {
            return 0
        }

        // Get Snowflake ID for the resolved DID
        return await getSnowflakeID(forDID: did)
    }

    // MARK: - Private Helpers

    /// Generate a deterministic Snowflake ID from a string using SHA-256 hash
    /// - Parameter string: Input string (DID or AT URI)
    /// - Returns: Deterministic 64-bit Snowflake ID
    private func generateDeterministicSnowflake(from string: String) -> Int64 {
        // Hash the input string
        let hash = SHA256.hash(data: Data(string.utf8))

        // Take first 8 bytes and convert to Int64
        let bytes = hash.prefix(8)
        var snowflake: Int64 = 0

        for byte in bytes {
            snowflake = (snowflake << 8) | Int64(byte)
        }

        // Ensure positive value (clear sign bit)
        return abs(snowflake)
    }
}

// MARK: - Cache Protocol

/// Protocol for cache operations needed by IDMappingService
/// This allows for easy testing with mock implementations
public protocol CacheProtocol: Actor {
    func getSnowflake(forDID did: String) async -> Int64?
    func getDID(forSnowflake snowflake: Int64) async -> String?
    func getSnowflake(forATURI atURI: String) async -> Int64?
    func getATURI(forSnowflake snowflake: Int64) async -> String?
    func getDID(forHandle handle: String) async -> String?
    func storeMapping(did: String, snowflake: Int64) async
    func storeMapping(atURI: String, snowflake: Int64) async
}
