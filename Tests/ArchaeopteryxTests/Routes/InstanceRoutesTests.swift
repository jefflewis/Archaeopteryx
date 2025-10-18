import Foundation
import Testing
@testable import Archaeopteryx
@testable import MastodonModels

@Suite struct InstanceRoutesTests {
    // MARK: - Instance Model Tests

    @Test func Instance_CanBeCreated() {
        let instance = Instance(
            uri: "bsky.example.com",
            title: "Test Instance",
            shortDescription: "A test instance",
            description: "A longer description",
            email: "admin@example.com",
            version: "4.0.0 (compatible; Archaeopteryx 0.1.0)"
        )

        #expect(instance.uri == "bsky.example.com")
        #expect(instance.title == "Test Instance")
        #expect(instance.shortDescription == "A test instance")
        #expect(instance.email == "admin@example.com")
        #expect(instance.version.contains("compatible"))
    }

    @Test func Instance_HasDefaultConfiguration() {
        let instance = Instance(
            uri: "bsky.example.com",
            title: "Test",
            shortDescription: "Test",
            description: "Test",
            email: "test@example.com",
            version: "1.0.0"
        )

        // Should have default configuration values
        #expect(instance.configuration.statuses.maxCharacters == 300)  // Bluesky limit
        #expect(instance.configuration.statuses.maxMediaAttachments == 4)
        #expect(instance.configuration.polls.maxOptions == 4)
    }

    @Test func Instance_EncodesWithSnakeCase() throws {
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
        #expect(json.contains("short_description"))
        #expect(json.contains("approval_required"))
        #expect(json.contains("invites_enabled"))
    }

    @Test func Instance_DecodesCorrectly() throws {
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
        #expect(decoded.uri == "test.com")
        #expect(decoded.shortDescription == "Short")
        #expect(decoded.approvalRequired == true)
        #expect(decoded.invitesEnabled == false)
    }

    @Test func InstanceConfiguration_HasCorrectDefaults() {
        let config = InstanceConfiguration()

        // Status limits match Bluesky
        #expect(config.statuses.maxCharacters == 300)
        #expect(config.statuses.maxMediaAttachments == 4)

        // Media limits are reasonable
        #expect(config.mediaAttachments.imageSizeLimit == 10_485_760)  // 10 MB
        #expect(config.mediaAttachments.videoSizeLimit == 41_943_040)  // 40 MB

        // Poll limits
        #expect(config.polls.maxOptions == 4)
        #expect(config.polls.maxCharactersPerOption == 50)
    }

    @Test func InstanceStats_DefaultsToZero() {
        let stats = InstanceStats()

        #expect(stats.userCount == 0)
        #expect(stats.statusCount == 0)
        #expect(stats.domainCount == 0)
    }

    @Test func InstanceRule_CanBeCreated() {
        let rule = InstanceRule(id: "1", text: "Be kind")

        #expect(rule.id == "1")
        #expect(rule.text == "Be kind")
    }

    @Test func Instance_SupportsEquatable() {
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

        #expect(instance1 == instance2)
    }

    @Test func Instance_DisablesRegistrationsByDefault() {
        let instance = Instance(
            uri: "test.com",
            title: "Test",
            shortDescription: "Short",
            description: "Long",
            email: "test@test.com",
            version: "1.0.0"
        )

        // Registrations should be disabled for a Bluesky bridge
        #expect(!(instance.registrations))
        #expect(instance.approvalRequired)
        #expect(!(instance.invitesEnabled))
    }
}

