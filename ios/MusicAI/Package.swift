// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MusicAI",
    platforms: [
        .macOS(.v14),
        .iOS("26.0")
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MusicAI",
            targets: ["MusicAI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/huggingface/swift-transformers.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MusicAI",
            dependencies: [
                .product(name: "Transformers", package: "swift-transformers")
            ],
            resources: [
                .process("Resources/MusicNER.mlpackage")
            ]
        ),
        .testTarget(
            name: "MusicAITests",
            dependencies: ["MusicAI"]
        ),
    ]
)