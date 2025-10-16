// swift-tools-version: 6.2
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
        // swift-dependencies - Dependency injection
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.0.0"),
        // swift-otel - OpenTelemetry for observability (logs, traces, metrics)
        .package(url: "https://github.com/swift-otel/swift-otel.git", from: "0.8.0"),
        // swift-distributed-tracing - Required for OTel
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.2.0"),
        // swift-metrics - Required for OTel
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.4.1"),
        // swift-crypto - Cross-platform cryptography (replaces CryptoKit on Linux)
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
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
            dependencies: [
                "ArchaeopteryxCore",
                .product(name: "Crypto", package: "swift-crypto"),
            ]
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
                "IDMapping",  // For CacheProtocol
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
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "ATProtoAdapterTests",
            dependencies: [
                "ATProtoAdapter",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
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
                .product(name: "Crypto", package: "swift-crypto"),
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
                .product(name: "Crypto", package: "swift-crypto"),
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
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "OTel", package: "swift-otel"),
                .product(name: "OTLPGRPC", package: "swift-otel"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "Metrics", package: "swift-metrics"),
            ]
        ),
        .testTarget(
            name: "ArchaeopteryxTests",
            dependencies: [
                "Archaeopteryx",
                .product(name: "HummingbirdTesting", package: "hummingbird"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),

        // ========================================
        // Integration Tests
        // ========================================
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "Archaeopteryx",
                "ArchaeopteryxCore",
                "MastodonModels",
                "ATProtoAdapter",
                "CacheLayer",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ]
        ),
    ]
)
