// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpecMatrixKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        // The iOS/iPadOS app's product. Unchanged; SpecMatrixShared comes in through SpecMatrixCore.
        .library(
            name: "SpecMatrixKit",
            targets: ["SpecMatrixCore", "SpecMatrixPlatform", "SpecMatrixState"]
        ),
        // The macOS app's product. It must never include SpecMatrixCore (the iPhone/iPad catalog),
        // SpecMatrixPlatform or SpecMatrixState.
        .library(
            name: "SpecMatrixMacKit",
            targets: ["SpecMatrixShared", "SpecMatrixMacCatalog", "SpecMatrixMacPlatform"]
        ),
    ],
    targets: [
        // Platform-neutral primitives shared by the iOS and macOS apps: SpecValue and provenance, units,
        // catalog citations, hardware identifiers, formatting. Foundation only; no catalog data.
        .target(
            name: "SpecMatrixShared"
        ),
        // The iPhone/iPad catalog, readings, providers and calculations. Foundation only.
        // Re-exports SpecMatrixShared so existing `import SpecMatrixCore` keeps working.
        .target(
            name: "SpecMatrixCore",
            dependencies: ["SpecMatrixShared"],
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
        // The Mac catalog (MacCatalog.json, schema 1), its validation and exact lookup. Mac only in
        // meaning, platform-neutral in code.
        .target(
            name: "SpecMatrixMacCatalog",
            dependencies: ["SpecMatrixShared"],
            resources: [.process("Resources")]
        ),
        // Mac hardware detection (sysctl, Metal, IOKit power sources, NSScreen/CoreGraphics) and the
        // resolver that combines it with the Mac catalog. Framework code is compiled for macOS only.
        .target(
            name: "SpecMatrixMacPlatform",
            dependencies: ["SpecMatrixShared", "SpecMatrixMacCatalog"]
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
        .testTarget(
            name: "SpecMatrixMacTests",
            dependencies: ["SpecMatrixMacCatalog", "SpecMatrixMacPlatform", "SpecMatrixShared"]
        ),
    ]
)
