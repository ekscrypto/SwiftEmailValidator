// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "EmailBench",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/evanrobertson/EmailValidator.git", branch: "master"),
        .package(url: "https://github.com/igorrendulic/MimeEmailParser.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "EmailBench",
            dependencies: [
                .product(name: "SwiftEmailValidator", package: "SwiftEmailValidator"),
                .product(name: "EmailValidator", package: "EmailValidator"),
                .product(name: "MimeEmailParser", package: "MimeEmailParser"),
            ]
        )
    ]
)
