// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "SwiftEmailValidator",
    products: [
        .library(
            name: "SwiftEmailValidator",
            targets: ["SwiftEmailValidator"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/ekscrypto/SwiftPublicSuffixList.git",
            .upToNextMajor(from: "1.0.0")
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
