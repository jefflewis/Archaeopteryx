import Foundation
import Testing
import Dependencies
@testable import CacheLayer

/// Tests for ValkeyCache implementation using mock Redis client
/// These tests run without requiring a real Valkey/Redis instance
@Suite struct ValkeyCacheTests {
    let sut: ValkeyCache

    init() async throws {
        // Use mock Redis client for testing - set up dependency globally for these tests
        sut = await withDependencies {
            $0.redisClient = .mock()
        } operation: {
            await ValkeyCache()
        }

        // Clean up any existing test data
        try await sut.clear()
    }

    // MARK: - Basic Storage Tests

    @Test func Set_ValidData_StoresSuccessfully() async throws {
        let key = "test_key"
        let value = "test_value"

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: String? = try await sut.get(key)

        #expect(retrieved == value)
    }

    @Test func Get_ExistingKey_ReturnsData() async throws {
        let key = "existing_key"
        let value = 12345

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: Int? = try await sut.get(key)

        #expect(retrieved == value)
    }

    @Test func Get_NonExistentKey_ReturnsNil() async throws {
        let retrieved: String? = try await sut.get("non_existent_key")

        #expect(retrieved == nil)
    }

    @Test func Delete_ExistingKey_RemovesData() async throws {
        let key = "key_to_delete"
        let value = "temporary"

        try await sut.set(key, value: value, ttl: nil)
        try await sut.delete(key)
        let retrieved: String? = try await sut.get(key)

        #expect(retrieved == nil)
    }

    @Test func Delete_NonExistentKey_NoError() async throws {
        // Should not throw an error
        try await sut.delete("non_existent_key")
    }

    @Test func Exists_ExistingKey_ReturnsTrue() async throws {
        let key = "existing_key"
        try await sut.set(key, value: "value", ttl: nil)

        let exists = try await sut.exists(key)

        #expect(exists)
    }

    @Test func Exists_NonExistentKey_ReturnsFalse() async throws {
        let exists = try await sut.exists("non_existent_key")

        #expect(!(exists))
    }

    // MARK: - TTL Tests

    @Test func SetWithTTL_DataExpires_ReturnsNil() async throws {
        let key = "expiring_key"
        let value = "temporary_value"
        let ttl = 2 // 2 seconds

        try await sut.set(key, value: value, ttl: ttl)

        // Data should exist immediately
        let immediateValue: String? = try await sut.get(key)
        #expect(immediateValue == value)

        // Wait for expiration (2.5 seconds to be safe)
        try await Task.sleep(nanoseconds: 2_500_000_000)

        // Data should be expired
        let expiredValue: String? = try await sut.get(key)
        #expect(expiredValue == nil)
    }

    @Test func SetWithTTL_ExistsCheck_ReturnsFalseAfterExpiration() async throws {
        let key = "expiring_key_2"
        let value = "temporary"
        let ttl = 2

        try await sut.set(key, value: value, ttl: ttl)

        // Should exist immediately
        let existsBefore = try await sut.exists(key)
        #expect(existsBefore)

        // Wait for expiration
        try await Task.sleep(nanoseconds: 2_500_000_000)

        // Should not exist after expiration
        let existsAfter = try await sut.exists(key)
        #expect(!(existsAfter))
    }

    @Test func SetWithNoTTL_DataPersists() async throws {
        let key = "persistent_key"
        let value = "persistent_value"

        try await sut.set(key, value: value, ttl: nil)

        // Wait a bit
        try await Task.sleep(nanoseconds: 500_000_000)

        // Data should still exist
        let retrieved: String? = try await sut.get(key)
        #expect(retrieved == value)
    }

    // MARK: - Complex Data Types

    @Test func Set_CodableStruct_StoresAndRetrieves() async throws {
        struct TestData: Codable, Equatable {
            let id: Int
            let name: String
            let tags: [String]
        }

        let key = "struct_key"
        let value = TestData(id: 456, name: "ValkeyTest", tags: ["x", "y", "z"])

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: TestData? = try await sut.get(key)

        #expect(retrieved == value)
    }

    @Test func Set_Array_StoresAndRetrieves() async throws {
        let key = "array_key"
        let value = [10, 20, 30, 40, 50]

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: [Int]? = try await sut.get(key)

        #expect(retrieved == value)
    }

    @Test func Set_Dictionary_StoresAndRetrieves() async throws {
        let key = "dict_key"
        let value = ["country": "USA", "state": "CA"]

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: [String: String]? = try await sut.get(key)

        #expect(retrieved == value)
    }

    // MARK: - Overwrite Tests

    @Test func Set_OverwriteExistingKey_UpdatesValue() async throws {
        let key = "overwrite_key"

        try await sut.set(key, value: "original", ttl: nil)
        try await sut.set(key, value: "updated", ttl: nil)

        let retrieved: String? = try await sut.get(key)
        #expect(retrieved == "updated")
    }

    @Test func Set_OverwriteWithDifferentType_UpdatesValue() async throws {
        let key = "type_change_key"

        try await sut.set(key, value: "string_value", ttl: nil)
        try await sut.set(key, value: 99, ttl: nil)

        let retrieved: Int? = try await sut.get(key)
        #expect(retrieved == 99)
    }

    // MARK: - Edge Cases

    @Test func Set_EmptyString_StoresSuccessfully() async throws {
        let key = "empty_string_key"
        let value = ""

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: String? = try await sut.get(key)

        #expect(retrieved == value)
    }

    @Test func Set_EmptyArray_StoresSuccessfully() async throws {
        let key = "empty_array_key"
        let value: [Int] = []

        try await sut.set(key, value: value, ttl: nil)
        let retrieved: [Int]? = try await sut.get(key)

        #expect(retrieved == value)
    }

    @Test func Get_WrongType_ReturnsNil() async throws {
        let key = "type_mismatch_key"

        try await sut.set(key, value: "string_value", ttl: nil)

        // Try to retrieve as wrong type
        let retrieved: Int? = try await sut.get(key)

        // Should return nil when type doesn't match
        #expect(retrieved == nil)
    }

    // MARK: - Key Prefix Tests

    @Test func Keys_WithPrefix_Isolated() async throws {
        // Set values with different prefixes
        try await sut.set("prefix1:key", value: "value1", ttl: nil)
        try await sut.set("prefix2:key", value: "value2", ttl: nil)

        // Retrieve with correct prefixes
        let value1: String? = try await sut.get("prefix1:key")
        let value2: String? = try await sut.get("prefix2:key")

        #expect(value1 == "value1")
        #expect(value2 == "value2")
    }
}
