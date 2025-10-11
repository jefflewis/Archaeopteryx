// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Archaeopteryx",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "Archaeopteryx",
            targets: ["Archaeopteryx"]
        ),
        // Optional: Expose libraries for reuse
        .library(name: "MastodonModels", targets: ["MastodonModels"]),
        .library(name: "TranslationLayer", targets: ["TranslationLayer"]),
    ],
    dependencies: [
        // Hummingbird - Modern Swift web framework
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        // RediStack - Redis/Valkey client for Swift
        .package(url: "https://github.com/swift-server/RediStack.git", from: "1.6.0"),
        // ATProtoKit - AT Protocol / Bluesky SDK
        .package(url: "https://github.com/MasterJ93/ATProtoKit.git", from: "0.1.0"),
    ],
    targets: [
        // ========================================
        // Core Package - Foundation utilities
        // ========================================
        .target(
            name: "ArchaeopteryxCore",
            dependencies: []
        ),
        .testTarget(
            name: "ArchaeopteryxCoreTests",
            dependencies: ["ArchaeopteryxCore"]
        ),

        // ========================================
        // Mastodon Models Package
        // ========================================
        .target(
            name: "MastodonModels",
            dependencies: ["ArchaeopteryxCore"]
        ),
        .testTarget(
            name: "MastodonModelsTests",
            dependencies: ["MastodonModels"]
        ),

        // ========================================
        // ID Mapping Package
        // ========================================
        .target(
            name: "IDMapping",
            dependencies: ["ArchaeopteryxCore"]
        ),
        .testTarget(
            name: "IDMappingTests",
            dependencies: ["IDMapping"]
        ),

        // ========================================
        // Cache Layer Package
        // ========================================
        .target(
            name: "CacheLayer",
            dependencies: [
                "ArchaeopteryxCore",
                .product(name: "RediStack", package: "RediStack"),
            ]
        ),
        .testTarget(
            name: "CacheLayerTests",
            dependencies: ["CacheLayer"]
        ),

        // ========================================
        // AT Proto Adapter Package
        // ========================================
        .target(
            name: "ATProtoAdapter",
            dependencies: [
                "ArchaeopteryxCore",
                "CacheLayer",
                .product(name: "ATProtoKit", package: "ATProtoKit"),
            ]
        ),
        .testTarget(
            name: "ATProtoAdapterTests",
            dependencies: ["ATProtoAdapter"]
        ),

        // ========================================
        // Translation Layer Package
        // ========================================
        .target(
            name: "TranslationLayer",
            dependencies: [
                "ArchaeopteryxCore",
                "MastodonModels",
                "ATProtoAdapter",
                "IDMapping",
            ]
        ),
        .testTarget(
            name: "TranslationLayerTests",
            dependencies: ["TranslationLayer"]
        ),

        // ========================================
        // OAuth Service Package
        // ========================================
        .target(
            name: "OAuthService",
            dependencies: [
                "ArchaeopteryxCore",
                "MastodonModels",
                "CacheLayer",
                "ATProtoAdapter",
            ]
        ),
        .testTarget(
            name: "OAuthServiceTests",
            dependencies: ["OAuthService"]
        ),

        // ========================================
        // Main Application
        // ========================================
        .executableTarget(
            name: "Archaeopteryx",
            dependencies: [
                "ArchaeopteryxCore",
                "MastodonModels",
                "ATProtoAdapter",
                "TranslationLayer",
                "CacheLayer",
                "IDMapping",
                "OAuthService",
                .product(name: "Hummingbird", package: "hummingbird"),
            ]
        ),
        .testTarget(
            name: "ArchaeopteryxTests",
            dependencies: ["Archaeopteryx"]
        ),
    ]
)
