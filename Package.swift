// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-iso-9075",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "ISO 9075 Foundation", targets: ["ISO 9075 Foundation"]),
        .library(name: "ISO 9075 Call-Level Interface", targets: ["ISO 9075 Call-Level Interface"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-time.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-4122.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "ISO 9075 Foundation",
            dependencies: [
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Time", package: "swift-time"),
                .product(name: "RFC 4122", package: "swift-rfc-4122"),
            ]
        ),
        .target(
            name: "ISO 9075 Call-Level Interface",
            dependencies: ["ISO 9075 Foundation"]
        ),
        .testTarget(
            name: "ISO 9075 Foundation Tests",
            dependencies: [
                "ISO 9075 Foundation",
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Time", package: "swift-time"),
            ]
        ),
        .testTarget(
            name: "ISO 9075 Call-Level Interface Tests",
            dependencies: ["ISO 9075 Call-Level Interface"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
