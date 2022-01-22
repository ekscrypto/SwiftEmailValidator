// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftEmailValidator",
    products: [
        .library(
            name: "SwiftEmailValidator",
            targets: ["SwiftEmailValidator"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftEmailValidator",
            dependencies: [],
            resources: []),
        .testTarget(
            name: "SwiftEmailValidatorTests",
            dependencies: ["SwiftEmailValidator"]),
    ]
)
