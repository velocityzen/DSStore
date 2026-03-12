// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DSStore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "DSStore",
            targets: ["DSStore"]
        ),
        .executable(
            name: "dsstore",
            targets: ["DSStoreCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/velocityzen/fp-swift", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "DSStoreAliasBridge",
            cSettings: [
                .unsafeFlags(["-Wno-deprecated-declarations"])
            ]
        ),
        .target(
            name: "DSStore",
            dependencies: [
                "DSStoreAliasBridge",
                .product(name: "FP", package: "fp-swift"),
            ]
        ),
        .executableTarget(
            name: "DSStoreCLI",
            dependencies: [
                "DSStore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "DSStoreTests",
            dependencies: ["DSStore"],
            exclude: ["Fixtures"]
        ),
    ]
)
