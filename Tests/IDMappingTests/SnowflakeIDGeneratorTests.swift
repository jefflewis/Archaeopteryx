import Testing
import Foundation
@testable import IDMapping

@Suite struct SnowflakeIDGeneratorTests {

    @Test func generateUniqueIDs() async throws {
        // Test that we can generate IDs
        let generator = SnowflakeIDGenerator()
        let id1 = await generator.generate()
        let id2 = await generator.generate()

        // IDs should be unique
        #expect(id1 != id2)

        // IDs should be positive
        #expect(id1 > 0)
        #expect(id2 > 0)
    }

    @Test func idsAreMonotonicallyIncreasing() async throws {
        // Snowflake IDs should increase over time
        let generator = SnowflakeIDGenerator()
        var previousID: Int64 = 0

        for _ in 0..<100 {
            let id = await generator.generate()
            #expect(id > previousID)
            previousID = id
        }
    }

    @Test func extractTimestamp() async throws {
        // We should be able to extract the timestamp from a Snowflake ID
        let generator = SnowflakeIDGenerator()
        let beforeTime = floor(Date().timeIntervalSince1970)
        let id = await generator.generate()
        let afterTime = ceil(Date().timeIntervalSince1970) + 1

        let extractedTime = await generator.extractTimestamp(from: id)

        // Extracted time should be between before and after (within tolerance due to millisecond precision)
        #expect(extractedTime >= beforeTime - 0.01)
        #expect(extractedTime <= afterTime + 0.01)
    }

    @Test func customEpoch() async throws {
        // Test that we can use a custom epoch (like Twitter's 2010-11-04)
        let twitterEpoch: Int64 = 1288834974657
        let generator = SnowflakeIDGenerator(epoch: twitterEpoch)

        let id = await generator.generate()
        #expect(id > 0)
    }

    @Test func sequenceNumber() async throws {
        // When generating IDs in the same millisecond, sequence number should increment
        let generator = SnowflakeIDGenerator()

        // Generate many IDs quickly to trigger sequence increment
        var ids: [Int64] = []
        for _ in 0..<10 {
            ids.append(await generator.generate())
        }

        // All IDs should be unique
        let uniqueIDs = Set(ids)
        #expect(uniqueIDs.count == ids.count)
    }

    @Test func threadSafety() async throws {
        // Test that generator works correctly with concurrent access
        let generator = SnowflakeIDGenerator()

        await withTaskGroup(of: Int64.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    return await generator.generate()
                }
            }

            var ids: Set<Int64> = []
            for await id in group {
                ids.insert(id)
            }

            // All IDs should be unique
            #expect(ids.count == 100)
        }
    }
}
