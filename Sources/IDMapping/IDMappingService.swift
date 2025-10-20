import Foundation
import Crypto

// MARK: - ID Mapping Protocol

/// Protocol for ID mapping services
/// Allows for easy testing with mock implementations
public protocol IDMappingProtocol: Actor {
    func getSnowflakeID(forDID did: String) async -> Int64
    func getDID(forSnowflakeID snowflakeID: Int64) async -> String?
    func getSnowflakeID(forATURI atURI: String) async -> Int64
    func getATURI(forSnowflakeID snowflakeID: Int64) async -> String?
    func getSnowflakeID(forHandle handle: String) async -> Int64
}

// MARK: - ID Mapping Service Implementation

/// Service for mapping between Bluesky identifiers (DIDs, AT URIs, handles) and Mastodon Snowflake IDs
///
/// This service provides deterministic, bidirectional mapping between:
/// - DIDs (decentralized identifiers) ↔ Snowflake IDs
/// - AT URIs (post URIs) ↔ Snowflake IDs
/// - Handles (user handles) → Snowflake IDs (via DID resolution)
///
/// DID to Snowflake mapping is deterministic - the same DID always maps to the same Snowflake ID
/// by hashing the DID and using the first 8 bytes as the ID.
public actor IDMappingService: IDMappingProtocol {
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

        // Generate time-based Snowflake ID from AT URI's TID
        // This ensures IDs are time-ordered for proper timeline pagination
        let snowflake = generateTimeBasedSnowflake(from: atURI)

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
    /// Used for DIDs where time ordering is not required
    /// - Parameter string: Input string (DID)
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

    /// Generate a time-based Snowflake ID from an AT URI
    /// Extracts timestamp from the TID and uses it to create a sortable ID
    /// - Parameter atURI: AT Protocol URI containing a TID
    /// - Returns: Time-ordered Snowflake ID
    private func generateTimeBasedSnowflake(from atURI: String) -> Int64 {
        // AT URI format: at://did:plc:abc123/app.bsky.feed.post/3lbpyzzzzzzz
        // The last component is a TID (Timestamp ID)
        
        // Try to extract timestamp from TID
        if let timestamp = extractTimestampFromTID(atURI) {
            // Use the generator to create a time-based Snowflake ID
            // We'll synthesize it using the timestamp
            let epoch: Int64 = 1577836800000 // 2020-01-01 00:00:00 UTC (same as SnowflakeIDGenerator)
            let timestampMillis = Int64(timestamp * 1000)
            
            // Create a deterministic worker ID from the URI to ensure uniqueness
            let workerID = abs(Int64(atURI.hashValue)) % 1024 // 10 bits = 0-1023
            
            // Simplified Snowflake format: timestamp (41 bits) | workerID (10 bits) | sequence (12 bits)
            // We use a hash-based sequence to make it deterministic
            let sequence = abs(Int64(atURI.hashValue >> 10)) % 4096 // 12 bits = 0-4095
            
            let snowflake = ((timestampMillis - epoch) << 22) | (workerID << 12) | sequence
            return abs(snowflake)
        }
        
        // Fallback to hash-based ID if TID extraction fails
        return generateDeterministicSnowflake(from: atURI)
    }

    /// Extract timestamp from an AT URI's TID component
    /// TIDs are base32-sortable timestamps in microseconds since Unix epoch
    /// - Parameter atURI: AT Protocol URI
    /// - Returns: Unix timestamp in seconds, or nil if extraction fails
    private func extractTimestampFromTID(_ atURI: String) -> TimeInterval? {
        // Extract the TID from the URI (last component)
        let components = atURI.split(separator: "/")
        guard components.count >= 3 else { return nil }
        
        let tid = String(components[components.count - 1])
        
        // Decode TID (base32-sortable encoding)
        // TIDs are 13 characters encoding 64 bits: timestamp (53 bits) + clock ID (10 bits) + sequence (10 bits)
        // Simplified: we'll try to decode it as a base32 value
        
        let tidTimestamp = decodeTIDTimestamp(tid)
        return tidTimestamp
    }

    /// Decode timestamp from TID string
    /// TIDs encode microseconds since Unix epoch in the first 53 bits
    /// - Parameter tid: The TID string (13 characters, base32-sortable)
    /// - Returns: Unix timestamp in seconds
    private func decodeTIDTimestamp(_ tid: String) -> TimeInterval? {
        // Base32-sortable alphabet used by AT Protocol
        let alphabet = "234567abcdefghijklmnopqrstuvwxyz"
        
        var value: UInt64 = 0
        for char in tid.lowercased() {
            guard let index = alphabet.firstIndex(of: char) else {
                return nil
            }
            let digit = alphabet.distance(from: alphabet.startIndex, to: index)
            value = value * 32 + UInt64(digit)
        }
        
        // Extract timestamp (first 53 bits) and convert from microseconds to seconds
        let microseconds = value >> 10 // Remove the last 10 bits (clock ID + sequence)
        return Double(microseconds) / 1_000_000.0
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
