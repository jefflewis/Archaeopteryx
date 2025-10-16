import XCTest
@testable import TranslationLayer
@testable import ATProtoAdapter
@testable import MastodonModels
@testable import IDMapping

/// Tests for ProfileTranslator - ATProto profile to MastodonAccount translation
final class ProfileTranslatorTests: XCTestCase {
    var sut: ProfileTranslator!
    var mockIDMapping: MockIDMappingService!
    var facetProcessor: FacetProcessor!

    override func setUp() async throws {
        try await super.setUp()
        mockIDMapping = MockIDMappingService()
        facetProcessor = FacetProcessor()
        sut = ProfileTranslator(idMapping: mockIDMapping, facetProcessor: facetProcessor)
    }

    override func tearDown() async throws {
        sut = nil
        mockIDMapping = nil
        facetProcessor = nil
        try await super.tearDown()
    }

    // MARK: - Complete Profile Tests

    func testTranslateProfile_CompleteProfile_AllFieldsMapped() async throws {
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
        XCTAssertEqual(result.id, "123456789") // From mock

        // Handle fields
        XCTAssertEqual(result.username, "alice")
        XCTAssertEqual(result.acct, "alice.bsky.social")

        // Display info
        XCTAssertEqual(result.displayName, "Alice Smith")
        XCTAssertEqual(result.note, "<p>Software engineer and cat lover</p>")

        // URLs
        XCTAssertTrue(result.url.contains("alice.bsky.social"))
        XCTAssertEqual(result.avatar, "https://cdn.bsky.app/avatar123.jpg")
        XCTAssertEqual(result.avatarStatic, "https://cdn.bsky.app/avatar123.jpg")
        XCTAssertEqual(result.header, "https://cdn.bsky.app/banner123.jpg")
        XCTAssertEqual(result.headerStatic, "https://cdn.bsky.app/banner123.jpg")

        // Counts
        XCTAssertEqual(result.followersCount, 150)
        XCTAssertEqual(result.followingCount, 200)
        XCTAssertEqual(result.statusesCount, 42)

        // Flags
        XCTAssertFalse(result.bot)
        XCTAssertFalse(result.locked)
    }

    // MARK: - Minimal Profile Tests

    func testTranslateProfile_MinimalProfile_UsesDefaults() async throws {
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
        XCTAssertEqual(result.displayName, "bob.bsky.social")

        // Empty note
        XCTAssertEqual(result.note, "<p></p>")

        // Default avatar
        XCTAssertTrue(result.avatar.contains("gravatar") || result.avatar.contains("default"))

        // Default header
        XCTAssertTrue(result.header.contains("default") || result.header.isEmpty)
    }

    // MARK: - Display Name Tests

    func testTranslateProfile_MissingDisplayName_UsesHandle() async throws {
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

        XCTAssertEqual(result.displayName, "test.bsky.social")
    }

    func testTranslateProfile_EmptyDisplayName_UsesHandle() async throws {
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

        XCTAssertEqual(result.displayName, "test.bsky.social")
    }

    // MARK: - Bio/Description Tests

    func testTranslateProfile_Bio_ConvertedToHTML() async throws {
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
        XCTAssertTrue(result.note.hasPrefix("<p>"))
        XCTAssertTrue(result.note.hasSuffix("</p>"))
        XCTAssertTrue(result.note.contains("&amp;"))
    }

    // MARK: - Avatar Tests

    func testTranslateProfile_MissingAvatar_UsesFallback() async throws {
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
        XCTAssertFalse(result.avatar.isEmpty)
        XCTAssertTrue(
            result.avatar.contains("gravatar") ||
            result.avatar.contains("default") ||
            result.avatar.contains("avatar")
        )
    }

    // MARK: - Username Extraction Tests

    func testTranslateProfile_ExtractsUsernameFromHandle() async throws {
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

            XCTAssertEqual(
                result.username,
                testCase.expectedUsername,
                "Failed for handle: \(testCase.handle)"
            )
            XCTAssertEqual(result.acct, testCase.handle)
        }
    }

    // MARK: - Created At Tests

    func testTranslateProfile_WithIndexedAt_ParsesDate() async throws {
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

        // Should have a valid date
        XCTAssertNotNil(result.createdAt)
        // Date should be in 2023
        let calendar = Calendar.current
        let year = calendar.component(.year, from: result.createdAt)
        XCTAssertEqual(year, 2023)
    }

    func testTranslateProfile_WithoutIndexedAt_UsesCurrentDate() async throws {
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

        // Should have a date (current date as fallback)
        XCTAssertNotNil(result.createdAt)

        // Should be recent (within last hour)
        let timeSinceCreation = abs(result.createdAt.timeIntervalSinceNow)
        XCTAssertLessThan(timeSinceCreation, 3600) // Within 1 hour
    }

    // MARK: - Profile URL Tests

    func testTranslateProfile_GeneratesCorrectProfileURL() async throws {
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

        XCTAssertTrue(result.url.contains("alice.bsky.social"))
        XCTAssertTrue(result.url.contains("profile") || result.url.contains("bsky.app"))
    }
}
