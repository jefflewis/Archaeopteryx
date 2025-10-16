import Foundation
@testable import IDMapping

/// Mock ID Mapping Service for testing
actor MockIDMappingService: IDMappingProtocol {
    func getSnowflakeID(forDID did: String) async -> Int64 {
        return 123456789 // Fixed ID for testing
    }

    func getDID(forSnowflakeID snowflakeID: Int64) async -> String? {
        return "did:plc:test"
    }

    func getSnowflakeID(forATURI uri: String) async -> Int64 {
        return 987654321 // Fixed ID for AT URI
    }

    func getATURI(forSnowflakeID snowflakeID: Int64) async -> String? {
        return "at://test"
    }

    func getSnowflakeID(forHandle handle: String) async -> Int64 {
        return 123456789
    }
}
