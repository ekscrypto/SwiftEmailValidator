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
        .library(
            name: "SwiftEmailValidatorUTS39",
            targets: ["SwiftEmailValidatorUTS39"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftEmailValidator",
            dependencies: [],
            resources: []),
        .target(
            name: "SwiftEmailValidatorUTS39",
            dependencies: ["SwiftEmailValidator"],
            exclude: ["Tools"],
            resources: []),
        .testTarget(
            name: "SwiftEmailValidatorTests",
            dependencies: ["SwiftEmailValidator"]),
        .testTarget(
            name: "SwiftEmailValidatorUTS39Tests",
            dependencies: ["SwiftEmailValidatorUTS39", "SwiftEmailValidator"]),
    ]
)
