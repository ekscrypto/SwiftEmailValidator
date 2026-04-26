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
        .library(
            name: "SwiftEmailValidatorIDNA",
            targets: ["SwiftEmailValidatorIDNA"]),
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
        .target(
            name: "SwiftEmailValidatorIDNA",
            dependencies: ["SwiftEmailValidator"],
            exclude: ["Tools"],
            resources: []),
        .testTarget(
            name: "SwiftEmailValidatorTests",
            dependencies: ["SwiftEmailValidator"]),
        .testTarget(
            name: "SwiftEmailValidatorUTS39Tests",
            dependencies: ["SwiftEmailValidatorUTS39", "SwiftEmailValidator"]),
        .testTarget(
            name: "SwiftEmailValidatorIDNATests",
            dependencies: ["SwiftEmailValidatorIDNA", "SwiftEmailValidator"],
            resources: [.copy("Resources/IdnaTestV2.txt")]),
    ]
)
