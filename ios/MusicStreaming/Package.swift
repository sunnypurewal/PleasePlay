// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MusicStreaming",
    platforms: [
        .iOS(.v18),
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MusicStreaming",
            targets: ["MusicStreaming"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tidal-music/tidal-sdk-ios", from: "0.10.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MusicStreaming",
            dependencies: [
                .product(name: "Auth", package: "tidal-sdk-ios"),
                .product(name: "Player", package: "tidal-sdk-ios"),
                .product(name: "TidalAPI", package: "tidal-sdk-ios")
            ]
        ),
        .testTarget(
            name: "MusicStreamingTests",
            dependencies: ["MusicStreaming"]
        ),
    ]
)
