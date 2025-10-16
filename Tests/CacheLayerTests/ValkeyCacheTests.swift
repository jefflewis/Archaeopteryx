import XCTest
@testable import CacheLayer

/// Tests for ValkeyCache implementation
/// NOTE: These are integration tests that require a running Valkey/Redis instance
/// The tests will automatically skip if Redis is not available
final class ValkeyCacheTests: XCTestCase {
    var sut: ValkeyCache!
    var redisAvailable = false

    override func setUp() async throws {
        try await super.setUp()

        // Try to connect to Redis, skip tests if not available
        do {
            sut = try await ValkeyCache(
                host: "localhost",
                port: 6379,
                password: nil,
                database: 15 // Use database 15 for testing to avoid conflicts
            )
            redisAvailable = true

            // Clean up any existing test data
            try await sut.clear()
        } catch {
            throw XCTSkip("Redis/Valkey not available on localhost:6379. Start with: docker run -d -p 6379:6379 valkey/valkey:latest")
        }
    }

    override func tearDown() async throws {
        if redisAvailable, let sut = sut {
            try await sut.clear()
            try await sut.disconnect()
        }
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Connection Tests

    func testConnect_ValidConfiguration_Connects() async throws {
        // Already connected in setUp, verify we can perform operations
        let key = "connection_test"
        try await sut.set(key, value: "connected", ttl: nil)

        let value: String? = try await sut.get(key)
        XCTAssertEqual(value, "connected")
    }

    // MARK: - Basic Storage Tests

    func testSet_ValidData_StoresSuccessfully() async throws {
        let key = "test_key"
        let value = "test_value"

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: String? = try await sut.get(key)

        XCTAssertEqual(retrieved, value)
    }

    func testGet_ExistingKey_ReturnsData() async throws {
        let key = "existing_key"
        let value = 12345

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: Int? = try await sut.get(key)

        XCTAssertEqual(retrieved, value)
    }

    func testGet_NonExistentKey_ReturnsNil() async throws {
        let retrieved: String? = try await sut.get("non_existent_key")

        XCTAssertNil(retrieved)
    }

    func testDelete_ExistingKey_RemovesData() async throws {
        let key = "key_to_delete"
        let value = "temporary"

        try await sut.set(key, value: value, ttl: nil)
        try await sut.delete(key)
        let retrieved: String? = try await sut.get(key)

        XCTAssertNil(retrieved)
    }

    func testDelete_NonExistentKey_NoError() async throws {
        // Should not throw an error
        try await sut.delete("non_existent_key")
    }

    func testExists_ExistingKey_ReturnsTrue() async throws {
        let key = "existing_key"
        try await sut.set(key, value: "value", ttl: nil)

        let exists = try await sut.exists(key)

        XCTAssertTrue(exists)
    }

    func testExists_NonExistentKey_ReturnsFalse() async throws {
        let exists = try await sut.exists("non_existent_key")

        XCTAssertFalse(exists)
    }

    // MARK: - TTL Tests

    func testSetWithTTL_DataExpires_ReturnsNil() async throws {
        let key = "expiring_key"
        let value = "temporary_value"
        let ttl = 2 // 2 seconds

        try await sut.set(key, value: value, ttl: ttl)

        // Data should exist immediately
        let immediateValue: String? = try await sut.get(key)
        XCTAssertEqual(immediateValue, value)

        // Wait for expiration (2.5 seconds to be safe)
        try await Task.sleep(nanoseconds: 2_500_000_000)

        // Data should be expired
        let expiredValue: String? = try await sut.get(key)
        XCTAssertNil(expiredValue)
    }

    func testSetWithTTL_ExistsCheck_ReturnsFalseAfterExpiration() async throws {
        let key = "expiring_key_2"
        let value = "temporary"
        let ttl = 2

        try await sut.set(key, value: value, ttl: ttl)

        // Should exist immediately
        let existsBefore = try await sut.exists(key)
        XCTAssertTrue(existsBefore)

        // Wait for expiration
        try await Task.sleep(nanoseconds: 2_500_000_000)

        // Should not exist after expiration
        let existsAfter = try await sut.exists(key)
        XCTAssertFalse(existsAfter)
    }

    func testSetWithNoTTL_DataPersists() async throws {
        let key = "persistent_key"
        let value = "persistent_value"

        try await sut.set(key, value: value, ttl: nil)

        // Wait a bit
        try await Task.sleep(nanoseconds: 500_000_000)

        // Data should still exist
        let retrieved: String? = try await sut.get(key)
        XCTAssertEqual(retrieved, value)
    }

    // MARK: - Complex Data Types

    func testSet_CodableStruct_StoresAndRetrieves() async throws {
        struct TestData: Codable, Equatable {
            let id: Int
            let name: String
            let tags: [String]
        }

        let key = "struct_key"
        let value = TestData(id: 456, name: "ValkeyTest", tags: ["x", "y", "z"])

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: TestData? = try await sut.get(key)

        XCTAssertEqual(retrieved, value)
    }

    func testSet_Array_StoresAndRetrieves() async throws {
        let key = "array_key"
        let value = [10, 20, 30, 40, 50]

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: [Int]? = try await sut.get(key)

        XCTAssertEqual(retrieved, value)
    }

    func testSet_Dictionary_StoresAndRetrieves() async throws {
        let key = "dict_key"
        let value = ["country": "USA", "state": "CA"]

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: [String: String]? = try await sut.get(key)

        XCTAssertEqual(retrieved, value)
    }

    // MARK: - Overwrite Tests

    func testSet_OverwriteExistingKey_UpdatesValue() async throws {
        let key = "overwrite_key"

        try await sut.set(key, value: "original", ttl: nil)
        try await sut.set(key, value: "updated", ttl: nil)

        let retrieved: String? = try await sut.get(key)
        XCTAssertEqual(retrieved, "updated")
    }

    func testSet_OverwriteWithDifferentType_UpdatesValue() async throws {
        let key = "type_change_key"

        try await sut.set(key, value: "string_value", ttl: nil)
        try await sut.set(key, value: 99, ttl: nil)

        let retrieved: Int? = try await sut.get(key)
        XCTAssertEqual(retrieved, 99)
    }

    // MARK: - Edge Cases

    func testSet_EmptyString_StoresSuccessfully() async throws {
        let key = "empty_string_key"
        let value = ""

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: String? = try await sut.get(key)

        XCTAssertEqual(retrieved, value)
    }

    func testSet_EmptyArray_StoresSuccessfully() async throws {
        let key = "empty_array_key"
        let value: [Int] = []

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: [Int]? = try await sut.get(key)

        XCTAssertEqual(retrieved, value)
    }

    func testGet_WrongType_ReturnsNil() async throws {
        let key = "type_mismatch_key"

        try await sut.set(key, value: "string_value", ttl: nil)

        // Try to retrieve as wrong type
        let retrieved: Int? = try await sut.get(key)

        // Should return nil when type doesn't match
        XCTAssertNil(retrieved)
    }

    // MARK: - Persistence Tests

    func testDataPersists_AcrossReconnection() async throws {
        let key = "persistent_reconnect_key"
        let value = "should_persist"

        // Set value
        try await sut.set(key, value: value, ttl: nil)

        // Note: When using database 15 (as set in setUp), we need to ensure
        // the new connection uses the same database
        let currentDatabase = 15

        // Disconnect
        try await sut.disconnect()

        // Reconnect (create new instance with same database)
        sut = try await ValkeyCache(
            host: "localhost",
            port: 6379,
            password: nil,
            database: currentDatabase
        )

        // Retrieve value
        let retrieved: String? = try await sut.get(key)
        XCTAssertEqual(retrieved, value)

        // Clean up
        try await sut.delete(key)
    }

    // MARK: - Key Prefix Tests

    func testKeys_WithPrefix_Isolated() async throws {
        // Set values with different prefixes
        try await sut.set("prefix1:key", value: "value1", ttl: nil)
        try await sut.set("prefix2:key", value: "value2", ttl: nil)

        // Retrieve with correct prefixes
        let value1: String? = try await sut.get("prefix1:key")
        let value2: String? = try await sut.get("prefix2:key")

        XCTAssertEqual(value1, "value1")
        XCTAssertEqual(value2, "value2")
    }
}
