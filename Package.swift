// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "SwiftEmailValidator",
    platforms: [
            .macOS(.v10_12),
            .iOS(.v11),
            .tvOS(.v11)
        ],
    products: [
        .library(
            name: "SwiftEmailValidator",
            targets: ["SwiftEmailValidator"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/ekscrypto/SwiftPublicSuffixList.git",
            .upToNextMajor(from: "1.1.5")
        ),
    ],
    targets: [
        .target(
            name: "SwiftEmailValidator",
            dependencies: ["SwiftPublicSuffixList"],
            resources: []),
        .testTarget(
            name: "SwiftEmailValidatorTests",
            dependencies: ["SwiftEmailValidator","SwiftPublicSuffixList"]),
    ]
)
