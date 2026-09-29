// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CleanSweep",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CleanSweep", targets: ["CleanSweep"])
    ],
    targets: [
        .executableTarget(
            name: "CleanSweep",
            path: "Sources/CleanSweep"
        ),
        .testTarget(
            name: "CleanSweepTests",
            dependencies: ["CleanSweep"],
            path: "Tests/CleanSweepTests"
        )
    ]
)
