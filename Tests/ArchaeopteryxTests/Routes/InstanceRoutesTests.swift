import XCTest
@testable import Archaeopteryx
@testable import MastodonModels

final class InstanceRoutesTests: XCTestCase {
    // MARK: - Instance Model Tests

    func testInstance_CanBeCreated() {
        let instance = Instance(
            uri: "bsky.example.com",
            title: "Test Instance",
            shortDescription: "A test instance",
            description: "A longer description",
            email: "admin@example.com",
            version: "4.0.0 (compatible; Archaeopteryx 0.1.0)"
        )

        XCTAssertEqual(instance.uri, "bsky.example.com")
        XCTAssertEqual(instance.title, "Test Instance")
        XCTAssertEqual(instance.shortDescription, "A test instance")
        XCTAssertEqual(instance.email, "admin@example.com")
        XCTAssertTrue(instance.version.contains("compatible"))
    }

    func testInstance_HasDefaultConfiguration() {
        let instance = Instance(
            uri: "bsky.example.com",
            title: "Test",
            shortDescription: "Test",
            description: "Test",
            email: "test@example.com",
            version: "1.0.0"
        )

        // Should have default configuration values
        XCTAssertEqual(instance.configuration.statuses.maxCharacters, 300)  // Bluesky limit
        XCTAssertEqual(instance.configuration.statuses.maxMediaAttachments, 4)
        XCTAssertEqual(instance.configuration.polls.maxOptions, 4)
    }

    func testInstance_EncodesWithSnakeCase() throws {
        let instance = Instance(
            uri: "test.com",
            title: "Test",
            shortDescription: "Short",
            description: "Long",
            email: "test@test.com",
            version: "1.0.0",
            registrations: false,
            approvalRequired: true,
            invitesEnabled: false
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(instance)
        let json = String(data: data, encoding: .utf8)!

        // Verify snake_case keys
        XCTAssertTrue(json.contains("short_description"))
        XCTAssertTrue(json.contains("approval_required"))
        XCTAssertTrue(json.contains("invites_enabled"))
    }

    func testInstance_DecodesCorrectly() throws {
        let original = Instance(
            uri: "test.com",
            title: "Test",
            shortDescription: "Short",
            description: "Long",
            email: "test@test.com",
            version: "1.0.0",
            registrations: false,
            approvalRequired: true,
            invitesEnabled: false
        )

        // Encode (we use explicit CodingKeys, not automatic conversion)
        let data = try JSONEncoder().encode(original)

        // Decode
        let decoded = try JSONDecoder().decode(Instance.self, from: data)

        // Verify round-trip preserves values
        XCTAssertEqual(decoded.uri, "test.com")
        XCTAssertEqual(decoded.shortDescription, "Short")
        XCTAssertEqual(decoded.approvalRequired, true)
        XCTAssertEqual(decoded.invitesEnabled, false)
    }

    func testInstanceConfiguration_HasCorrectDefaults() {
        let config = InstanceConfiguration()

        // Status limits match Bluesky
        XCTAssertEqual(config.statuses.maxCharacters, 300)
        XCTAssertEqual(config.statuses.maxMediaAttachments, 4)

        // Media limits are reasonable
        XCTAssertEqual(config.mediaAttachments.imageSizeLimit, 10_485_760)  // 10 MB
        XCTAssertEqual(config.mediaAttachments.videoSizeLimit, 41_943_040)  // 40 MB

        // Poll limits
        XCTAssertEqual(config.polls.maxOptions, 4)
        XCTAssertEqual(config.polls.maxCharactersPerOption, 50)
    }

    func testInstanceStats_DefaultsToZero() {
        let stats = InstanceStats()

        XCTAssertEqual(stats.userCount, 0)
        XCTAssertEqual(stats.statusCount, 0)
        XCTAssertEqual(stats.domainCount, 0)
    }

    func testInstanceRule_CanBeCreated() {
        let rule = InstanceRule(id: "1", text: "Be kind")

        XCTAssertEqual(rule.id, "1")
        XCTAssertEqual(rule.text, "Be kind")
    }

    func testInstance_SupportsEquatable() {
        let instance1 = Instance(
            uri: "test.com",
            title: "Test",
            shortDescription: "Short",
            description: "Long",
            email: "test@test.com",
            version: "1.0.0"
        )

        let instance2 = Instance(
            uri: "test.com",
            title: "Test",
            shortDescription: "Short",
            description: "Long",
            email: "test@test.com",
            version: "1.0.0"
        )

        XCTAssertEqual(instance1, instance2)
    }

    func testInstance_DisablesRegistrationsByDefault() {
        let instance = Instance(
            uri: "test.com",
            title: "Test",
            shortDescription: "Short",
            description: "Long",
            email: "test@test.com",
            version: "1.0.0"
        )

        // Registrations should be disabled for a Bluesky bridge
        XCTAssertFalse(instance.registrations)
        XCTAssertTrue(instance.approvalRequired)
        XCTAssertFalse(instance.invitesEnabled)
    }
}
