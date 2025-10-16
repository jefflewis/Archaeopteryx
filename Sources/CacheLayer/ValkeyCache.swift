import Foundation
@preconcurrency import RediStack
import NIOCore
import NIOPosix

/// Redis/Valkey cache implementation using RediStack
public actor ValkeyCache: CacheService {
    /// Redis connection
    private var connection: RedisConnection?

    /// Event loop group for NIO
    private let eventLoopGroup: EventLoopGroup

    /// Connection configuration
    private let host: String
    private let port: Int
    private let password: String?
    private let database: Int

    /// JSON encoder for serialization
    private let encoder = JSONEncoder()

    /// JSON decoder for deserialization
    private let decoder = JSONDecoder()

    // MARK: - Initialization

    public init(
        host: String = "localhost",
        port: Int = 6379,
        password: String? = nil,
        database: Int = 0
    ) async throws {
        self.host = host
        self.port = port
        self.password = password
        self.database = database
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        try await connect()
    }

    // MARK: - Connection Management

    private func connect() async throws {
        do {
            let eventLoop = eventLoopGroup.next()

            let connection = try await RedisConnection.make(
                configuration: .init(
                    hostname: host,
                    port: port,
                    password: password,
                    initialDatabase: database
                ),
                boundEventLoop: eventLoop
            ).get()

            self.connection = connection
        } catch {
            throw CacheError.connectionFailed(underlying: error)
        }
    }

    public func disconnect() async throws {
        _ = try await connection?.close().get()
        connection = nil
        try await eventLoopGroup.shutdownGracefully()
    }

    // MARK: - CacheService Protocol

    public func get<T: Codable>(_ key: String) async throws -> T? {
        guard let connection = connection else {
            throw CacheError.notConnected
        }

        do {
            let redisKey = RedisKey(key)
            let value: RESPValue = try await connection.get(redisKey).get()

            // Check if key exists
            guard case .bulkString(let buffer) = value, let buffer = buffer else {
                return nil
            }

            // Convert ByteBuffer to Data
            let data = Data(buffer.readableBytesView)

            // Decode the JSON data
            let decoded = try decoder.decode(T.self, from: data)
            return decoded
        } catch let error as DecodingError {
            // Return nil if decoding fails (type mismatch)
            return nil
        } catch {
            throw CacheError.operationFailed(underlying: error)
        }
    }

    public func set<T: Codable>(_ key: String, value: T, ttl: Int?) async throws {
        guard let connection = connection else {
            throw CacheError.notConnected
        }

        do {
            // Encode the value to JSON
            let data = try encoder.encode(value)
            let jsonString = String(data: data, encoding: .utf8) ?? ""

            let redisKey = RedisKey(key)

            // Set with or without TTL
            if let ttl = ttl {
                let expiration = RedisSetCommandExpiration.seconds(ttl)
                _ = try await connection.set(redisKey, to: jsonString, onCondition: .none, expiration: expiration).get()
            } else {
                _ = try await connection.set(redisKey, to: jsonString).get()
            }
        } catch {
            throw CacheError.operationFailed(underlying: error)
        }
    }

    public func delete(_ key: String) async throws {
        guard let connection = connection else {
            throw CacheError.notConnected
        }

        do {
            let redisKey = RedisKey(key)
            _ = try await connection.delete([redisKey]).get()
        } catch {
            throw CacheError.operationFailed(underlying: error)
        }
    }

    public func exists(_ key: String) async throws -> Bool {
        guard let connection = connection else {
            throw CacheError.notConnected
        }

        do {
            let redisKey = RedisKey(key)
            let count = try await connection.exists([redisKey]).get()
            return count > 0
        } catch {
            throw CacheError.operationFailed(underlying: error)
        }
    }

    // MARK: - Additional Utilities

    /// Clear all keys in the current database (use with caution!)
    public func clear() async throws {
        guard let connection = connection else {
            throw CacheError.notConnected
        }

        do {
            _ = try await connection.send(command: "FLUSHDB").get()
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
