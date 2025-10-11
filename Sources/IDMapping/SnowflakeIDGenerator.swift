import Foundation

/// Snowflake ID generator for creating time-sortable unique 64-bit identifiers
/// Based on Twitter's Snowflake algorithm
///
/// ID Structure (64 bits):
/// - 1 bit: unused (always 0)
/// - 41 bits: timestamp in milliseconds since epoch
/// - 10 bits: worker ID (for distributed systems)
/// - 12 bits: sequence number (for multiple IDs in same millisecond)
public actor SnowflakeIDGenerator {
    // Default epoch: January 1, 2020 (similar to Discord/Twitter approach)
    private static let defaultEpoch: Int64 = 1577836800000 // 2020-01-01 00:00:00 UTC

    private let epoch: Int64
    private let workerID: Int64
    private var sequence: Int64 = 0
    private var lastTimestamp: Int64 = 0

    // Bit lengths
    private let timestampBits = 41
    private let workerIDBits = 10
    private let sequenceBits = 12

    // Maximum values
    private let maxWorkerID: Int64
    private let maxSequence: Int64

    // Bit shifts
    private let timestampShift: Int64
    private let workerIDShift: Int64

    /// Initialize Snowflake ID generator
    /// - Parameters:
    ///   - epoch: Custom epoch in milliseconds since Unix epoch (default: 2020-01-01)
    ///   - workerID: Worker ID for distributed systems (default: 0)
    public init(epoch: Int64? = nil, workerID: Int64 = 0) {
        self.epoch = epoch ?? Self.defaultEpoch

        // Calculate maximum values
        self.maxWorkerID = (1 << workerIDBits) - 1
        self.maxSequence = (1 << sequenceBits) - 1

        // Calculate bit shifts
        self.timestampShift = Int64(workerIDBits + sequenceBits)
        self.workerIDShift = Int64(sequenceBits)

        // Validate and set worker ID
        assert(workerID >= 0 && workerID <= maxWorkerID, "Worker ID must be between 0 and \(maxWorkerID)")
        self.workerID = workerID
    }

    /// Generate a new Snowflake ID
    /// - Returns: A unique 64-bit identifier
    public func generate() -> Int64 {
        var timestamp = currentTimestamp()

        // Handle clock moving backwards
        if timestamp < lastTimestamp {
            // Wait until clock catches up
            while timestamp <= lastTimestamp {
                timestamp = currentTimestamp()
            }
        }

        if timestamp == lastTimestamp {
            // Same millisecond - increment sequence
            sequence = (sequence + 1) & maxSequence

            if sequence == 0 {
                // Sequence overflow - wait for next millisecond
                timestamp = waitForNextMillisecond(timestamp)
            }
        } else {
            // New millisecond - reset sequence
            sequence = 0
        }

        lastTimestamp = timestamp

        // Construct the ID
        let id = ((timestamp - epoch) << timestampShift)
            | (workerID << workerIDShift)
            | sequence

        return id
    }

    /// Extract timestamp from a Snowflake ID
    /// - Parameter id: The Snowflake ID
    /// - Returns: Unix timestamp in seconds
    public func extractTimestamp(from id: Int64) -> TimeInterval {
        let millisecondsSinceEpoch = (id >> timestampShift) + epoch
        return Double(millisecondsSinceEpoch) / 1000.0
    }

    /// Extract worker ID from a Snowflake ID
    /// - Parameter id: The Snowflake ID
    /// - Returns: Worker ID
    func extractWorkerID(from id: Int64) -> Int64 {
        return (id >> workerIDShift) & maxWorkerID
    }

    /// Extract sequence number from a Snowflake ID
    /// - Parameter id: The Snowflake ID
    /// - Returns: Sequence number
    func extractSequence(from id: Int64) -> Int64 {
        return id & maxSequence
    }

    // MARK: - Private Helpers

    private func currentTimestamp() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func waitForNextMillisecond(_ timestamp: Int64) -> Int64 {
        var current = currentTimestamp()
        while current <= timestamp {
            current = currentTimestamp()
        }
        return current
    }
}

