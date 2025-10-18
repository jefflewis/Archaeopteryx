import Foundation
import Testing
@testable import TranslationLayer
@testable import ATProtoAdapter
@testable import MastodonModels
@testable import IDMapping

/// Tests for ProfileTranslator - ATProto profile to MastodonAccount translation
@Suite struct ProfileTranslatorTests {
    let sut: ProfileTranslator
    var mockIDMapping: MockIDMappingService!
    var facetProcessor: FacetProcessor!

    init() async {
       mockIDMapping = MockIDMappingService()
        facetProcessor = FacetProcessor()
        sut = ProfileTranslator(idMapping: mockIDMapping, facetProcessor: facetProcessor)
    }

    // MARK: - Complete Profile Tests

    @Test func TranslateProfile_CompleteProfile_AllFieldsMapped() async throws {
        let profile = ATProtoProfile(
            did: "did:plc:abc123",
            handle: "alice.bsky.social",
            displayName: "Alice Smith",
            description: "Software engineer and cat lover",
            avatar: "https://cdn.bsky.app/avatar123.jpg",
            banner: "https://cdn.bsky.app/banner123.jpg",
            followersCount: 150,
            followsCount: 200,
            postsCount: 42,
            indexedAt: "2023-01-15T10:30:00Z"
        )

        let result = try await sut.translate(profile)

        // ID mapping
        #expect(result.id == "123456789") // From mock

        // Handle fields
        #expect(result.username == "alice")
        #expect(result.acct == "alice.bsky.social")

        // Display info
        #expect(result.displayName == "Alice Smith")
        #expect(result.note == "<p>Software engineer and cat lover</p>")

        // URLs
        #expect(result.url.contains("alice.bsky.social"))
        #expect(result.avatar == "https://cdn.bsky.app/avatar123.jpg")
        #expect(result.avatarStatic == "https://cdn.bsky.app/avatar123.jpg")
        #expect(result.header == "https://cdn.bsky.app/banner123.jpg")
        #expect(result.headerStatic == "https://cdn.bsky.app/banner123.jpg")

        // Counts
        #expect(result.followersCount == 150)
        #expect(result.followingCount == 200)
        #expect(result.statusesCount == 42)

        // Flags
        #expect(!(result.bot))
        #expect(!(result.locked))
    }

    // MARK: - Minimal Profile Tests

    @Test func TranslateProfile_MinimalProfile_UsesDefaults() async throws {
        let profile = ATProtoProfile(
            did: "did:plc:xyz789",
            handle: "bob.bsky.social",
            displayName: nil,
            description: nil,
            avatar: nil,
            banner: nil,
            followersCount: 0,
            followsCount: 0,
            postsCount: 0,
            indexedAt: nil
        )

        let result = try await sut.translate(profile)

        // Display name falls back to handle
        #expect(result.displayName == "bob.bsky.social")

        // Empty note
        #expect(result.note == "<p></p>")

        // Default avatar
        #expect(result.avatar.contains("gravatar") || result.avatar.contains("default"))

        // Default header
        #expect(result.header.contains("default") || result.header.isEmpty)
    }

    // MARK: - Display Name Tests

    @Test func TranslateProfile_MissingDisplayName_UsesHandle() async throws {
        let profile = ATProtoProfile(
            did: "did:plc:test",
            handle: "test.bsky.social",
            displayName: nil,
            description: nil,
            avatar: nil,
            banner: nil,
            followersCount: 0,
            followsCount: 0,
            postsCount: 0,
            indexedAt: nil
        )

        let result = try await sut.translate(profile)

        #expect(result.displayName == "test.bsky.social")
    }

    @Test func TranslateProfile_EmptyDisplayName_UsesHandle() async throws {
        let profile = ATProtoProfile(
            did: "did:plc:test",
            handle: "test.bsky.social",
            displayName: "",
            description: nil,
            avatar: nil,
            banner: nil,
            followersCount: 0,
            followsCount: 0,
            postsCount: 0,
            indexedAt: nil
        )

        let result = try await sut.translate(profile)

        #expect(result.displayName == "test.bsky.social")
    }

    // MARK: - Bio/Description Tests

    @Test func TranslateProfile_Bio_ConvertedToHTML() async throws {
        let profile = ATProtoProfile(
            did: "did:plc:test",
            handle: "test.bsky.social",
            displayName: "Test User",
            description: "I love Swift & coding!",
            avatar: nil,
            banner: nil,
            followersCount: 0,
            followsCount: 0,
            postsCount: 0,
            indexedAt: nil
        )

        let result = try await sut.translate(profile)

        // Should be wrapped in paragraph and HTML-escaped
        #expect(result.note.hasPrefix("<p>"))
        #expect(result.note.hasSuffix("</p>"))
        #expect(result.note.contains("&amp;"))
    }

    // MARK: - Avatar Tests

    @Test func TranslateProfile_MissingAvatar_UsesFallback() async throws {
        let profile = ATProtoProfile(
            did: "did:plc:test",
            handle: "test.bsky.social",
            displayName: "Test User",
            description: nil,
            avatar: nil,
            banner: nil,
            followersCount: 0,
            followsCount: 0,
            postsCount: 0,
            indexedAt: nil
        )

        let result = try await sut.translate(profile)

        // Should use gravatar or default avatar
        #expect(!(result.avatar.isEmpty))
        #expect(
            result.avatar.contains("gravatar") ||
            result.avatar.contains("default") ||
            result.avatar.contains("avatar")
        )
    }

    // MARK: - Username Extraction Tests

    @Test func TranslateProfile_ExtractsUsernameFromHandle() async throws {
        let testCases: [(handle: String, expectedUsername: String)] = [
            ("alice.bsky.social", "alice"),
            ("bob.custom.domain", "bob"),
            ("test-user.bsky.social", "test-user"),
            ("user123.example.com", "user123"),
        ]

        for testCase in testCases {
            let profile = ATProtoProfile(
                did: "did:plc:test",
                handle: testCase.handle,
                displayName: nil,
                description: nil,
                avatar: nil,
                banner: nil,
                followersCount: 0,
                followsCount: 0,
                postsCount: 0,
                indexedAt: nil
            )

            let result = try await sut.translate(profile)

            #expect(result.username == testCase.expectedUsername)
            #expect(result.acct == testCase.handle)
        }
    }

    // MARK: - Created At Tests

    @Test func TranslateProfile_WithIndexedAt_ParsesDate() async throws {
        let profile = ATProtoProfile(
            did: "did:plc:test",
            handle: "test.bsky.social",
            displayName: nil,
            description: nil,
            avatar: nil,
            banner: nil,
            followersCount: 0,
            followsCount: 0,
            postsCount: 0,
            indexedAt: "2023-06-15T14:30:00Z"
        )

        let result = try await sut.translate(profile)

        // Date should be in 2023
        let calendar = Calendar.current
        let year = calendar.component(.year, from: result.createdAt)
        #expect(year == 2023)
    }

    @Test func TranslateProfile_WithoutIndexedAt_UsesCurrentDate() async throws {
        let profile = ATProtoProfile(
            did: "did:plc:test",
            handle: "test.bsky.social",
            displayName: nil,
            description: nil,
            avatar: nil,
            banner: nil,
            followersCount: 0,
            followsCount: 0,
            postsCount: 0,
            indexedAt: nil
        )

        let result = try await sut.translate(profile)

        // Should be recent (within last hour)
        let timeSinceCreation = abs(result.createdAt.timeIntervalSinceNow)
        #expect(timeSinceCreation < 3600) // Within 1 hour
    }

    // MARK: - Profile URL Tests

    @Test func TranslateProfile_GeneratesCorrectProfileURL() async throws {
        let profile = ATProtoProfile(
            did: "did:plc:test",
            handle: "alice.bsky.social",
            displayName: nil,
            description: nil,
            avatar: nil,
            banner: nil,
            followersCount: 0,
            followsCount: 0,
            postsCount: 0,
            indexedAt: nil
        )

        let result = try await sut.translate(profile)

        #expect(result.url.contains("alice.bsky.social"))
        #expect(result.url.contains("profile") || result.url.contains("bsky.app"))
    }
}

