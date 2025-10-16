import XCTest
@testable import CacheLayer

final class InMemoryCacheTests: XCTestCase {
    var sut: InMemoryCache!

    override func setUp() async throws {
        try await super.setUp()
        sut = InMemoryCache()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
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
        let value = 42

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
        let ttl = 1 // 1 second

        try await sut.set(key, value: value, ttl: ttl)

        // Data should exist immediately
        let immediateValue: String? = try await sut.get(key)
        XCTAssertEqual(immediateValue, value)

        // Wait for expiration (1.5 seconds to be safe)
        try await Task.sleep(nanoseconds: 1_500_000_000)

        // Data should be expired
        let expiredValue: String? = try await sut.get(key)
        XCTAssertNil(expiredValue)
    }

    func testSetWithTTL_ExistsCheck_ReturnsFalseAfterExpiration() async throws {
        let key = "expiring_key_2"
        let value = "temporary"
        let ttl = 1

        try await sut.set(key, value: value, ttl: ttl)

        // Should exist immediately
        let existsBefore = try await sut.exists(key)
        XCTAssertTrue(existsBefore)

        // Wait for expiration
        try await Task.sleep(nanoseconds: 1_500_000_000)

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
        let value = TestData(id: 123, name: "Test", tags: ["a", "b", "c"])

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: TestData? = try await sut.get(key)

        XCTAssertEqual(retrieved, value)
    }

    func testSet_Array_StoresAndRetrieves() async throws {
        let key = "array_key"
        let value = [1, 2, 3, 4, 5]

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: [Int]? = try await sut.get(key)

        XCTAssertEqual(retrieved, value)
    }

    func testSet_Dictionary_StoresAndRetrieves() async throws {
        let key = "dict_key"
        let value = ["name": "Alice", "city": "NYC"]

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: [String: String]? = try await sut.get(key)

        XCTAssertEqual(retrieved, value)
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentWrites_NoDataLoss() async throws {
        let iterations = 100
        let cache = sut!

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    try? await cache.set("key_\(i)", value: i, ttl: nil)
                }
            }
        }

        // Verify all values were written
        var successCount = 0
        for i in 0..<iterations {
            if let value: Int = try await cache.get("key_\(i)"), value == i {
                successCount += 1
            }
        }

        XCTAssertEqual(successCount, iterations)
    }

    func testConcurrentReads_ConsistentData() async throws {
        let key = "concurrent_read_key"
        let value = "consistent_value"
        let cache = sut!
        try await cache.set(key, value: value, ttl: nil)

        let iterations = 50
        var results: [String] = []

        await withTaskGroup(of: String?.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    try? await cache.get(key)
                }
            }

            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
        }

        XCTAssertEqual(results.count, iterations)
        XCTAssertTrue(results.allSatisfy { $0 == value })
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
        try await sut.set(key, value: 42, ttl: nil)

        let retrieved: Int? = try await sut.get(key)
        XCTAssertEqual(retrieved, 42)
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
}
