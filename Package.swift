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
        )
    ],
    dependencies: [
        // Hummingbird - Modern Swift web framework
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        // Swift Valkey - Redis-compatible client
        .package(url: "https://github.com/swift-server/swift-valkey.git", from: "1.0.0"),
        // ATProtoKit - AT Protocol / Bluesky SDK
        .package(url: "https://github.com/MasterJ93/ATProtoKit.git", from: "0.1.0"),
        // Swift Configuration - Apple's configuration management
        .package(url: "https://github.com/apple/swift-configuration.git", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "Archaeopteryx",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "Valkey", package: "swift-valkey"),
                .product(name: "ATProtoKit", package: "ATProtoKit"),
                .product(name: "Configuration", package: "swift-configuration"),
            ]
        ),
        .testTarget(
            name: "ArchaeopteryxTests",
            dependencies: ["Archaeopteryx"]
        ),
    ]
)
