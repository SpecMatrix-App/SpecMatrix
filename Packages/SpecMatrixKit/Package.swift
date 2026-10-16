// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpecMatrixKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "SpecMatrixKit",
            targets: ["SpecMatrixCore", "SpecMatrixPlatform", "SpecMatrixState"]
        ),
    ],
    targets: [
        // Platform-independent models, provenance, catalog, and calculations. Foundation only.
        .target(
            name: "SpecMatrixCore",
            resources: [.process("Resources")]
        ),
        // Live system-information providers. The only target that imports UIKit, IOKit, Metal, or Network.
        .target(
            name: "SpecMatrixPlatform",
            dependencies: ["SpecMatrixCore"]
        ),
        // ObservableObject stores that own refresh scheduling and observer lifecycles.
        .target(
            name: "SpecMatrixState",
            dependencies: ["SpecMatrixCore"]
        ),
        .testTarget(
            name: "SpecMatrixCoreTests",
            dependencies: ["SpecMatrixCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "SpecMatrixPlatformTests",
            dependencies: ["SpecMatrixPlatform", "SpecMatrixCore"]
        ),
        .testTarget(
            name: "SpecMatrixStateTests",
            dependencies: ["SpecMatrixState", "SpecMatrixCore"]
        ),
    ]
)
