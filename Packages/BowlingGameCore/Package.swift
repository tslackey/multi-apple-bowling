// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BowlingGameCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .watchOS(.v11),
    ],
    products: [
        .library(name: "BowlingGameCore", targets: ["BowlingGameCore"]),
    ],
    targets: [
        .target(name: "BowlingGameCore"),
        .testTarget(
            name: "BowlingGameCoreTests",
            dependencies: ["BowlingGameCore"]
        ),
    ]
)
