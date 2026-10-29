# SpecMatrix for macOS: architecture plan (Phase 1, proposal)

Date: 2026-10-16.

**Status:** architecture approved. Phase 1, Part 1 (project foundation) is implemented and uncommitted; see §0. Everything else described as "proposed" doesn't exist yet: Mac catalog, Mac detection, Mac UI, Mac CI job.

**Evidence base:**
- static inspection of the repository at `a8e012d` ("2.0": Phase 4, README, `MARKETING_VERSION 2.0`). The working tree also has an uncommitted owner edit to `project.pbxproj`, noted in §2.1 and not made by this phase;
- read-only queries of the development Mac;
- the installed SDKs.

**Labels used:**
- **Verified:** checked in the repository, the SDK headers, or on this Mac.
- **Earlier audit:** recorded in `docs/audit/` and not re-checked in this phase.
- **Assumption / to verify:** not yet confirmed.

---

## 0. Implementation status

### Phase 1, Part 1: project foundation (2026-10-16, uncommitted)

**Owner decisions implemented:**
- same repository;
- a separate Mac Xcode project;
- macOS 13.0 minimum, Apple silicon only;
- Mac version 1.0 (build 1), independent of iOS 2.0;
- a separate Mac catalog (location reserved, not built);
- no serial numbers;
- no third-party dependencies.

**What exists now:**

| Item | Detail |
|---|---|
| `SpecMatrixMac/SpecMatrixMac.xcodeproj` | One macOS app target, `SpecMatrixMac`. Shared scheme `xcshareddata/xcschemes/SpecMatrixMac.xcscheme`. Synchronized source folder `SpecMatrixMac/SpecMatrixMac/`. |
| Mac target settings | `SDKROOT = macosx`, `SUPPORTED_PLATFORMS = macosx`, `MACOSX_DEPLOYMENT_TARGET = 13.0`, `ARCHS = arm64`, `SWIFT_VERSION = 6.0`, bundle ID `com.zacharyaflalo.specmatrix.mac`, `PRODUCT_NAME = "SpecMatrix-Mac"` (the built bundle is `SpecMatrix-Mac.app`, executable `SpecMatrix-Mac`, distinct from the iOS app's `SpecMatrix.app`) with `PRODUCT_MODULE_NAME = SpecMatrixMac` (a hyphen isn't valid in a Swift module name), `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1`, generated Info.plist (display name "SpecMatrix", category Utilities), `ENABLE_APP_SANDBOX = YES`, `ENABLE_HARDENED_RUNTIME = YES` |
| Signing | `CODE_SIGN_IDENTITY = "-"` (Sign to Run Locally), no team. No signing, notarization or packaging work. |
| Sources | `SpecMatrixMacApp.swift`: `WindowGroup("SpecMatrix")` with standard macOS windows and menus, `.defaultSize(640×420)`. `PlaceholderView.swift`: "SpecMatrix for Mac / The Mac version is under development." Imports SwiftUI only; reads no hardware. |
| Assets | `Assets.xcassets` with an empty macOS `AppIcon` set (16–512 pt, @1x/@2x, no images yet) and `AccentColor` (system default) |
| Package link | Local package `../Packages/SpecMatrixKit`, product **`SpecMatrixMacKit` only** |
| `SpecMatrixShared` (new package target, Foundation only) | Moved from `SpecMatrixCore`, unchanged: `Values/Units.swift` (`ByteCount`, `UnitFraction`, `RefreshRate`, `DisplayDiagonal`, `PixelDensity`, `PixelDimensions`, `CalendarDate`); `Formatting/SpecFormat.swift`; from `SpecValue.swift`, as `Values/Provenance.swift`: `Provenance`, `RuntimeEnvironment`, `MeasurementSource`, `UnavailableReason`, `SpecError`, `MissingValue`, `SpecErrorReporting`; from `DeviceIdentity.swift`, as `Models/DeviceIdentity.swift`: `HardwareIdentifier`, `DeviceIdentity`, `OSVersion`. All of these were already `public` with no internal members. |
| `SpecMatrixCore` | Depends on `SpecMatrixShared` and re-exports it (`Exports.swift`: `@_exported import SpecMatrixShared`), so existing `import SpecMatrixCore` in the iOS app, Platform, State and tests is unchanged. Keeps `SpecValue`, `CatalogReference` and `OperatingSystemInfo` (now `Models/OperatingSystemInfo.swift`), all catalog types and data, readings, providers and calculations. Core files that use moved types gained `import SpecMatrixShared`. |
| Products | `SpecMatrixKit` unchanged (Core, Platform, State). New `SpecMatrixMacKit` = `SpecMatrixShared`. |
| Not changed | `SpecMatrix.xcodeproj` (the uncommitted edit there is the owner's, made before this part); iOS sources and tests; `DeviceCatalog.json`; catalog scripts; `.github/workflows/ci.yml`; test-target settings |

**Update, 1.0 development pass (2026-10-29):** the full Mac app, the schema 2 Mac catalog with per-model chip configurations, the Mac CI workflow and the release checklist are described in `docs/MACOS_HANDOFF.md`, which supersedes the status notes below.

**Update, Phase 2 (2026-10-16):** the `SpecValue` blocker below is resolved. `SpecValue`, `CatalogReference` and the catalog-citation types moved unchanged to `SpecMatrixShared`, and the Mac catalog and detection targets now exist. Details: `docs/MACOS_PHASE2_HANDOFF.md`.

**Deviations from the plan:**

1. **`SpecValue` and `CatalogReference` stay in `SpecMatrixCore` (blocker; resolved in Phase 2).**
   - **The chain:** `SpecValue.catalog` carries a `CatalogReference`. That holds `[CatalogSource]`, whose `supports: Set<CatalogField>` is the iPhone/iPad catalog's field list (identifiers, marketingName, releaseDate, chip, display, cameras).
   - **Why it can't move yet:** moving `SpecValue` would either carry the iPhone field list into the shared module, or change `SpecValue`'s public shape, which would break iOS-facing APIs.
   - **Consequence:** the Mac product can't use `SpecValue` yet.
   - **Options (decision needed):**
     - **(a)** Turn `CatalogField` into an extensible `struct` with `static let` members (iOS fields declared in Core, Mac fields in the Mac catalog), and move the catalog source and verification types plus `CatalogReference` and `SpecValue` into Shared. Mostly source-compatible; the `CaseIterable` / `Comparable` uses in the decoder need small adjustments. **Recommended.**
     - **(b)** Make the catalog reference generic or type-erased. This changes `SpecValue`'s public type and pattern matches.
     - **(c)** Give the Mac its own `SpecValue`-like type. This duplicates a domain concept, which the brief disallows.
2. **No `SpecMatrixMacCatalog` / `SpecMatrixMacPlatform` targets yet.** Detection and catalog are out of scope for Part 1. Their reserved locations: `Packages/SpecMatrixKit/Sources/SpecMatrixMacCatalog/` (schema, decoder, `Resources/MacCatalog.json`) and `Packages/SpecMatrixKit/Sources/SpecMatrixMacPlatform/`. Both join the `SpecMatrixMacKit` product.
3. **Sources live in `SpecMatrixMac/SpecMatrixMac/`**, the usual Xcode layout beside the project. §4 showed `SpecMatrixMac/` loosely.
4. **No workspace was added:** nothing requires one for command-line builds.

**Mac catalog source material (unchanged, for M2):**
- **Seed records:** the 44 `family: "Mac"` entries in `Packages/SpecMatrixKit/Sources/SpecMatrixCore/Resources/DeviceCatalog.json`, with their Apple "Identify your Mac" and tech-specs citations.
- **Verifier:** `Packages/SpecMatrixKit/Scripts/verify_catalog_sources.py`. Its `fetch` (with section scoping for "Identify your Mac" pages), `normalize` and chip/display `claims` logic can serve as the basis of a Mac mode.
- **Ownership:** the Mac catalog will be owned by `SpecMatrixMacCatalog`, with its own `schemaVersion` and `catalogVersion`. Nothing in `DeviceCatalog.json` is moved or deleted in Part 1.

**Validation (Part 1):**
- **Done (static and parse-only, no compilation):**
  - `plutil -lint` on the Mac `project.pbxproj`: OK;
  - `xmllint` on the scheme: OK;
  - asset JSON: OK;
  - `swift package dump-package`: products and targets as above;
  - `xcodebuild -list`: target `SpecMatrixMac`, scheme `SpecMatrixMac`, local package resolved;
  - `xcodebuild -showBuildSettings`: the settings above, as intended;
  - `swiftc -parse` (syntax only) on every new or split Swift file: OK;
  - the moved text is byte-identical apart from import lines;
  - no file references a moved type with a `SpecMatrixCore.` prefix;
  - every Platform, State, test and iOS file that uses a moved type imports `SpecMatrixCore`.
- **Not done:** compiling the package, the iOS app or the Mac app, and running any tests. **Compilation is unconfirmed.**
- **Recommended compile-only checks** (no simulator; need owner approval):
  - `swift build --package-path Packages/SpecMatrixKit`;
  - `xcodebuild build -project SpecMatrixMac/SpecMatrixMac.xcodeproj -scheme SpecMatrixMac -destination 'platform=macOS,arch=arm64'`;
  - the existing iOS generic-simulator `build-for-testing`.

  Pushing would also let the existing CI confirm the package and the iOS app on Xcode 26. CI doesn't build the Mac project yet.

## 1. Executive summary and recommendation

**Repository:** build the Mac app in **this repository**. There is no concrete technical reason to split, and four reasons to stay:
- the local package already builds and tests on macOS;
- the catalog tooling and the 44 Mac catalog entries already live here;
- CI already runs on a macOS runner;
- one repository keeps the shared code in one place.

**Shape:**

1. **A separate Mac app.** It has its own Xcode project (`SpecMatrixMac/SpecMatrixMac.xcodeproj`), its own SwiftUI sources (`SpecMatrixMac/`), its own versioning and its own CI job. The iOS project file (`SpecMatrix.xcodeproj`) is not modified.
2. **`SpecMatrixKit` narrowed by additions, not by moving iOS code:**
   - **New target `SpecMatrixShared`:** the genuinely platform-neutral primitives, the "provenance layer" that tags each value as measured, from the catalog, unavailable, unknown or an error.
   - **`SpecMatrixCore` keeps the iOS/iPadOS catalog**, and re-exports `SpecMatrixShared`, so no iOS source file changes.
   - **New Mac-only targets:**
     - `SpecMatrixMacCatalog`: the Mac schema, decoder and `MacCatalog.json`;
     - `SpecMatrixMacPlatform`: Mac detection;
     - optionally `SpecMatrixMacState`.
   - **New product `SpecMatrixMacKit`:** the Mac app links only this. It contains no iPhone catalog, no `UIKit` code and no iPhone screens.
3. **A Mac-specific catalog** with its own schema version and release cadence.
   - **Seed data:** the 44 Mac entries already in `DeviceCatalog.json`, re-verified.
   - **Mac-only shape:** the schema can express things the iPhone schema cannot, such as one identifier sold with several chip configurations ("M4 Pro or M4 Max").
4. **Detection first, catalog second.**
   - **Detected directly:** macOS exposes the model identifier, chip name, CPU core clusters, memory, displays, battery, storage, network and thermal state through public APIs (verified on this Mac).
   - **Catalog only:** the marketing name, GPU core count and similar values.
   - **Labeling:** every value keeps its existing source label (measured / catalog / unavailable / unknown / error).
5. **Platform:** macOS 13 Ventura minimum, Apple silicon only (`arm64`), sandboxed, Hardened Runtime.
6. **Distribution:** outside the App Store, a notarized DMG needs a paid Apple Developer Program membership (Developer ID). That's a decision for you (§10).

## 2. Repository and existing-code audit

### 2.1 Projects, targets and settings

All verified, from `SpecMatrix.xcodeproj/project.pbxproj`.

| Item | Value |
|---|---|
| Targets | `SpecMatrix` (app), `SpecMatrixTests` (hosted unit tests, Swift Testing), `SpecMatrixUITests` |
| App platform | `SDKROOT = iphoneos`, `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`, `TARGETED_DEVICE_FAMILY = 1` (iPhone), `SUPPORTS_MACCATALYST = NO`, `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO` |
| App deployment target | `IPHONEOS_DEPLOYMENT_TARGET = 17.0` (explicit since `dd85147`) |
| Test deployment target | `SpecMatrixTests` 18.2. `SpecMatrixUITests` sets none and inherits the project level, which is 18.2 at `a8e012d` and 17.6 in the uncommitted owner edit. |
| Swift | App target Swift 5 mode; package `swift-tools-version: 6.0` (Swift 6 mode) |
| Identity | App `com.zacharyaflalo.specmatrix`, team `8QU4WRDSA4` (Personal Team, free), automatic signing; the uncommitted owner edit adds `CODE_SIGN_IDENTITY = "Apple Development"` and an empty `PROVISIONING_PROFILE_SPECIFIER` to the app target. Test targets `com.zacharyaflalo.specmatrix.Tests` / `.UITests`. |
| Version | `MARKETING_VERSION = 2.0` for the app (committed in `a8e012d`), `CURRENT_PROJECT_VERSION = 1`. Test targets 1.0. |
| Groups | File-system-synchronized groups: new files in `SpecMatrix/` join the app automatically. |
| Package reference | `XCLocalSwiftPackageReference "Packages/SpecMatrixKit"` |

**Conclusion:** the iOS project is single-platform. Adding a macOS destination or target to it would edit the iOS project file and its shared scheme. A separate Mac project avoids that (§4).

### 2.2 iPhone app

- **Shell:** `SpecMatrix/ContentView.swift` is a `TabView` with five tabs.
- **Screens** (`SpecMatrix/Screens/*`): `SpecScreen` / `SpecSection` / `SpecRow` (`SpecMatrix/DesignSystem/SpecComponents.swift`).
- **Version checks:** only in `SpecMatrix/DesignSystem/PlatformCompatibility.swift`.
- **Status colors:** `SpecMatrix/DesignSystem/SpecColors.swift`.
- **Measured values:** most screens read them from older UIKit-based models and monitors in `ContentView.swift` (`UIDevice`, `UIScreen.main`, `vm_statistics64`, `NWPathMonitor`).
- **Catalog values:** read through `SpecMatrix/Foundation/CatalogDeviceInfo.swift` (iPhone identifiers, cameras, display).
- **The package's `DeviceInfoStore`** is used only by the debug-only `SpecMatrix/Foundation/FoundationDiagnosticsView.swift`.

None of this UI code is suitable for the Mac app. It's iPhone-shaped by design.

### 2.3 `Packages/SpecMatrixKit`

Verified from the sources and `Package.swift`.

| Target | Files (lines) | Imports | macOS today |
|---|---|---|---|
| `SpecMatrixCore` | 13 files, about 1,750 lines | Foundation only | Compiles and is tested on macOS. CI runs `swift test` on `macos-26`. |
| `SpecMatrixPlatform` | 8 files | Foundation, Darwin, Network, Metal, UIKit (`#if os(iOS)`), IOKit.ps (`#if os(macOS)`) | Has macOS paths (below) |
| `SpecMatrixState` | `DeviceInfoStore.swift` | Combine, Foundation | Platform-neutral `ObservableObject` |

The package declares `.iOS(.v17), .macOS(.v13)` and has one library product, `SpecMatrixKit`, which contains all three targets.

**What `SpecMatrixPlatform` does on macOS today:**

| Reader | macOS behavior |
|---|---|
| `IdentityReader.swift` | `sysctl hw.model` (on this Mac it returns `Mac14,2`) |
| `SystemReaders.swift` | OS name "macOS" and version; `sysctl kern.osversion`; `ProcessInfo` core counts; `hw.nperflevels` / `hw.perflevelN.physicalcpu_max` for performance and efficiency cores (and a single-tier path for Intel); `ProcessInfo.physicalMemory`; app footprint via `task_info`; `appAvailable` returns `.unavailable(.notExposedByPlatform)`; Metal GPU name, Metal 3 support and working-set size; home-volume capacity |
| `PowerReader.swift` | `IOPSCopyPowerSourcesInfo` internal battery (level, state); desktops report `notSupportedByHardware`; thermal state; Low Power Mode |
| `LiveSources.swift` | Display returns `.unavailable(.notYetImplemented)`. `NWPathMonitor` path status is shared. |
| `ChangeNotifications.swift` | Thermal and Low Power notifications only (iOS adds battery and brightness) |

**What in `SpecMatrixCore` is generic and what is iOS-shaped:**
- **Generic:**
  - `Values/SpecValue.swift`: `SpecValue`, `Provenance`, `MissingValue`, `UnavailableReason`, `MeasurementSource`, `CatalogReference`;
  - `Values/Units.swift`;
  - `Models/DeviceIdentity.swift`: `HardwareIdentifier`, `OSVersion`, `DeviceIdentity`;
  - `Calculations/StorageMath.swift`;
  - `Formatting/SpecFormat.swift`;
  - the source and verification types in `Catalog/CatalogEntry.swift`.
- **iOS-shaped:**
  - `RuntimeEnvironment` (`device` / `simulator`);
  - `RuntimeDeviceInfo.appAvailableMemory` (iOS-only concept);
  - `DisplayReading`, which describes one screen with brightness, where Macs have several displays;
  - `ChangeNotifications` battery and brightness.
- **iOS catalog:** `Catalog/*` plus `Resources/DeviceCatalog.json`:
  - schema 3, version 2026.10.3, families iPhone 36 / iPad 32 / Mac 44;
  - Mac entries: 58 identifiers, 33 with a chip, 29 with a display, none with cameras;
  - `DeviceCatalog.loadBundled()` loads every family into the iPhone app.
  - The `cameras` group is iPhone-only. iPad and Mac entries record none.

**What would stop the package compiling for a Mac app:** nothing found. It already builds for macOS 13 (CI's `swift test` on `macos-26` compiles all three targets for macOS).

**Gaps for a real Mac app:**
1. no macOS display reader;
2. only one, home-volume, storage reading;
3. no multi-display model;
4. no Mac-specific catalog schema;
5. the single product would link the iPhone catalog resource into the Mac app.

### 2.4 Catalog storage, schema and identification

- **Storage:** one bundled JSON (`SpecMatrixCore/Resources/DeviceCatalog.json`). All-or-nothing validation in `Catalog/CatalogDecoder.swift`; exact, case-sensitive identifier lookup in `Catalog/DeviceCatalog.swift`.
- **Field-level sources:** checked against Apple pages by `Packages/SpecMatrixKit/Scripts/verify_catalog_sources.py`.
- **Mac identifier evidence (earlier phase):** Apple's "Identify your MacBook Air / MacBook Pro / iMac / Mac mini / Mac Studio / Mac Pro" pages, plus EveryMac. Where Apple groups chips ("M4 Pro or M4 Max"), no chip was recorded (`Packages/SpecMatrixKit/README.md`).
- **The decoder enforces Mac identifier prefixes** (`Mac`, `MacBookAir`, `MacBookPro`, `Macmini`, `iMac`, `MacPro`) in `CatalogDecoder.identifierPrefixes`.

### 2.5 Detected values versus catalog values (iOS)

- **Detected:** OS, cores, memory, battery, thermal state, Low Power Mode, storage, network path, display geometry and brightness.
- **From the catalog:** marketing name, chip name and core counts, GPU and Neural Engine cores, display size and density, cameras.
- **Estimated:** none in the package. The older iOS memory monitor falls back to "25% of RAM" if `host_statistics64` fails (`ContentView.swift`, `MemoryInfo.getCurrentMemoryInfo`). That path is iOS UI code and is not to be copied to the Mac.

### 2.6 Documentation, CI, versioning

- **Documentation:**
  - `docs/PHASE3_HANDOFF.md`, `docs/PHASE4_HANDOFF.md`;
  - `docs/audit/*`, especially `MULTIPLATFORM_ARCHITECTURE.md` and `TECHNICAL_DECISIONS.md`: TD-03 (Intel), TD-07 (sandbox), TD-08 (undocumented IORegistry), TD-09 (distribution), TD-12 (menu bar extra).
- **CI** (`.github/workflows/ci.yml`, verified):
  - one job, `build-and-test`, on `macos-26` (Xcode 26), 45-minute timeout;
  - steps: `swift test` (package), select an iPhone simulator, `xcodebuild build` (`-project SpecMatrix.xcodeproj -scheme SpecMatrix`), `xcodebuild test -only-testing:SpecMatrixTests`;
  - no app-version assumptions.
- **Versioning:** the iPhone app is 2.0. The package has no version of its own; it's a local path reference.
- **Release plan:** `docs/audit/DISTRIBUTION_AND_RELEASE_AUDIT.md` (earlier audit) proposed an IPA on GitHub Releases for iOS and a notarized DMG for macOS.
- **Stale links:** the git remote is `SpecMatrix-App/SpecMatrix`, but `SpecMatrix/Screens/SettingsView.swift` and `README.md` link to `Belligerently/SpecMatrix`. This is an iOS item, out of scope here.

### 2.7 Where earlier decisions disagree

- **Minimum macOS and Intel:**
  - `TECHNICAL_DECISIONS.md` TD-01 recommended macOS 14, and TD-03 recommended a universal binary.
  - The owner's later decisions are **macOS 13+ and Apple silicon only**, and this plan follows them.
- **Consequence of macOS 13:**
  - no `@Observable` (macOS 14) and no `ContentUnavailableView` (macOS 14);
  - `DeviceInfoStore` is already an `ObservableObject`, so it fits;
  - Mac UI fallbacks will need compatibility wrappers.

## 3. Shared versus platform-specific code

| Code | Classification | Notes |
|---|---|---|
| `SpecValue`, `Provenance`, `MissingValue`, `UnavailableReason`, `MeasurementSource`, `SpecError` (`Values/SpecValue.swift`) | **Share unchanged** | The core of "detected vs catalog vs unavailable". Same meaning on both platforms. |
| `Units.swift` (`ByteCount`, `PixelDimensions`, `PixelDensity`, `RefreshRate`, `UnitFraction`, `DisplayDiagonal`) | **Share unchanged** | Pure value types |
| `HardwareIdentifier`, `OSVersion` (`Models/DeviceIdentity.swift`) | **Share unchanged** | Parses both `iPhone16,1` and `Mac14,2` (verified by existing tests) |
| `StorageMath`, `SpecFormat` | **Share unchanged** | Pure |
| `CatalogSource`, `CatalogSourceLocation`, `CatalogVerification(Status)`, `CatalogPolicy`, `CalendarDate` | **Share after a small move** | Source and verification rules are identical; the field groups (`CatalogField`) are not. Generalize, or keep a Mac-specific field enum. |
| `DeviceIdentity.environment` / `RuntimeEnvironment` | **Share, with care** | `.simulator` never happens on macOS. Harmless; the Mac code always uses `.device`. |
| `Sysctl`, `CString` (`SpecMatrixPlatform/Sysctl.swift`, internal) | **Share after making it accessible**, or copy into the Mac platform target | Pure Darwin, identical on both |
| `NetworkPathMapping`, `LiveNetworkPathSource`, `NetworkReading` | **Share unchanged** | `NWPathMonitor` is identical; Mac adds wired Ethernet more often |
| Thermal and Low Power mapping (`ThermalLevel`, `PowerReader` parts) | **Share unchanged** | `ProcessInfo` on both (Low Power on macOS 12+, verified in SDK) |
| `DeviceCatalog`, `CatalogEntry`, `CatalogDecoder`, `HardwareSpecification`, `DeviceCatalog.json` | **iOS/iPadOS-specific** (keep in `SpecMatrixCore`) | iPhone/iPad field set, cameras, identifier rules. Must not be linked into the Mac app. |
| Mac catalog schema, decoder, data | **Mac-specific (new)** | Configurations, ports, displays optional, no cameras for now |
| `StaticDeviceInfo` / `RuntimeDeviceInfo` / `DeviceReport` | **Platform-specific** | iOS-shaped (`appAvailableMemory`, single display). The Mac gets its own report model. |
| `DisplayReading`, `DisplayReader` | **Platform-specific** | The Mac needs a list of displays (built-in plus external) |
| `PowerReader` macOS branch, `MacBatteryMapping` | **Mac-specific**; currently inside the shared Platform target | Move or duplicate into the Mac platform target later. The iOS paths stay untouched. |
| `DeviceInfoStore` | **Pattern reusable, type not** | Generic over iOS-shaped info types. A Mac store with the same scheduling pattern is simpler than generalizing. |
| All SwiftUI (`SpecMatrix/**`) | **iOS-specific** | Not shared. The Mac UI is new. |
| `PlatformCompatibility.swift` | **iOS-specific** | The Mac gets its own compatibility file for macOS 13 vs 14 vs 26 differences. |

**Rules:**
- **Share only when the meaning is identical on both platforms.**
- **When the fields differ, don't build a shared supertype:** a Mac type and an iOS type with similar names are acceptable.

## 4. Proposed repository layout and targets (partly created; see §0)

```
SpecMatrix/                     existing iPhone app (unchanged)
SpecMatrix.xcodeproj            existing iOS project (unchanged)
SpecMatrixTests/, SpecMatrixUITests/   existing (unchanged)
SpecMatrixMac/                  NEW: Mac app sources (SwiftUI, AppKit where needed)
SpecMatrixMac/SpecMatrixMac.xcodeproj  NEW: Mac app, Mac unit-test, (later) Mac UI-test targets
SpecMatrixMacTests/             NEW (inside or beside the Mac project)
Packages/SpecMatrixKit/
  Sources/SpecMatrixShared/      NEW: platform-neutral primitives (moved from Core, see below)
  Sources/SpecMatrixCore/        existing: iOS/iPadOS catalog; re-exports SpecMatrixShared
  Sources/SpecMatrixPlatform/    existing: iOS providers (unchanged behavior)
  Sources/SpecMatrixState/       existing
  Sources/SpecMatrixMacCatalog/  NEW: Mac schema, decoder, Resources/MacCatalog.json
  Sources/SpecMatrixMacPlatform/ NEW: Mac detection (sysctl, IOKit power sources, CoreGraphics/AppKit displays, Metal, volumes)
  Sources/SpecMatrixMacState/    NEW (optional): Mac stores
docs/macos/                     NEW: Mac handoffs, catalog notes, release notes
```

**Products:**
- `SpecMatrixKit` stays exactly as today: Core + Platform + State. The iOS app keeps linking it.
- New `SpecMatrixMacKit`: Shared + MacCatalog + MacPlatform (+ MacState). The Mac app links **only** this.

**Keeping iOS untouched while extracting the shared code:**
- **The move:** the files listed as "share unchanged" in §3 move from `SpecMatrixCore` to `SpecMatrixShared`.
- **The re-export:** `SpecMatrixCore` adds `@_exported import SpecMatrixShared`, so every existing `import SpecMatrixCore` in the iOS app and tests still compiles with no source edits.
- **Risks** (§10):
  - `@_exported` is underscored, though widely used.
  - Moving types changes their module, which matters to anything that names `SpecMatrixCore.SpecValue` explicitly. A static search shows no such qualified references.
  - **Alternative if you prefer no move:** the Mac targets depend on `SpecMatrixCore` directly. That's simpler, but it links the iPhone catalog code and its JSON into the Mac app, against the principle.

**Avoiding accidental iPhone links:**
- **Products:** the Mac project references only the `SpecMatrixMacKit` product.
- **Dependencies:** the Mac package targets declare no dependency on `SpecMatrixCore`, `SpecMatrixPlatform` or `SpecMatrixState`.
- **Isolation check:** a CI step (§8) compiles the Mac app and checks its linked modules (for example `otool -L` / build log, or `swift package show-dependencies`) to confirm no iOS target is present.
- **Code location:** Mac-specific code lives under `Mac*` targets and `SpecMatrixMac/` only.

**Why a separate Xcode project rather than a new target in `SpecMatrix.xcodeproj`:**
- the iOS `project.pbxproj`, its shared `SpecMatrix` scheme and the iOS CI steps stay untouched;
- separate build settings, signing, entitlements and versioning (`MARKETING_VERSION`) for the Mac;
- **cost:** Xcode opens a local package in only one window at a time. An optional `SpecMatrix.xcworkspace` containing both projects would fix that for development. CI keeps using `-project`. (§10 decision)

**Independent catalog and release lifecycle:**
- **Catalog:** `MacCatalog.json` has its own `schemaVersion` (starting at 1) and `catalogVersion`. It never changes `DeviceCatalog.json` or its tests.
- **Release:** the Mac app has its own `MARKETING_VERSION` and build numbers, tags (for example `mac-v…`), release notes and handoffs.
- **iOS release:** the 2.0 release is never blocked by Mac work, because nothing the iOS app links changes. The one exception is the `SpecMatrixShared` extraction, which is a separate, approval-gated step with its own CI run.

## 5. Mac catalog and system-information strategy

### 5.1 What macOS exposes through public APIs

All verified: on this Mac (MacBook Air M2, `Mac14,2`, macOS 27.2) unless the source column says "SDK header".

| Information | API | Verified evidence |
|---|---|---|
| Model identifier | `sysctl hw.model` | `Mac14,2` (also used by today's `IdentityReader`) |
| Chip name | `sysctl machdep.cpu.brand_string` | `Apple M2` |
| CPU clusters | `hw.nperflevels`, `hw.perflevelN.physicalcpu_max`, `hw.perflevelN.name` | 2 levels: "Performance" 4, "Efficiency" 4 |
| Logical CPUs | `hw.logicalcpu_max` / `ProcessInfo` | 8 |
| Memory | `hw.memsize` / `ProcessInfo.physicalMemory` | 8 GiB |
| macOS version and build | `ProcessInfo`, `sysctl kern.osversion` | 27.2, `26B5101f` |
| Architecture | `hw.optional.arm64` | 1 |
| GPU name, unified memory, working set | `MTLDevice.name`, `hasUnifiedMemory` (macOS 10.15), `recommendedMaxWorkingSetSize` (10.12) | SDK header |
| Displays | `CGGetOnlineDisplayList`, `CGDisplayIsBuiltin`, `CGDisplayScreenSize` (physical mm); `NSScreen.localizedName` (10.15), `maximumFramesPerSecond` (12.0), `maximumExtendedDynamicRangeColorComponentValue` | SDK headers |
| Battery | `IOPSCopyPowerSourcesInfo`; public keys `kIOPSCurrentCapacityKey`, `kIOPSMaxCapacityKey`, `kIOPSIsChargingKey`, `kIOPSPowerSourceStateKey`, `kIOPSTimeToEmptyKey`, `kIOPSTimeToFullChargeKey`, `kIOPSBatteryHealthKey`, `kIOPSBatteryHealthConditionKey` | SDK header `IOPSKeys.h`; level and state already used by `PowerReader` |
| Thermal state, Low Power Mode | `ProcessInfo.thermalState`, `isLowPowerModeEnabled` (macOS 12.0) | SDK header |
| Storage | `URLResourceValues` volume capacities; mounted volumes via `FileManager.mountedVolumeURLs` | Capacity keys are used today. Multiple volumes: assumption, to verify in the sandbox. |
| Network path | `NWPathMonitor` (shared) | Used today |
| Wi-Fi details | CoreWLAN `CWInterface` (`ssid` is in the SDK) | SDK header. Whether SSID needs Location Services authorization on the minimum and current macOS: **to verify**. |

### 5.2 Not exposed, or not acceptable

These come from the catalog or are marked unavailable. They are never invented.
- **Marketing name** ("MacBook Air (M2, 2022)"): no public API, so it comes from the catalog. (An undocumented IORegistry `product-name` exists on some systems; it wasn't present under `IOPlatformExpertDevice` on this Mac, and TD-08 rules out undocumented sources.)
- **GPU core count, Neural Engine cores:** no public API, so they come from the catalog. These vary by configuration under one identifier, so the catalog must hold the configurations (5.3).
- **Battery cycle count:** not among the public `IOPS` keys (verified), so unavailable. An undocumented `AppleSmartBattery` registry value exists (TD-08: omit).
- **CPU and GPU temperatures, fan speeds, per-core frequency and power:** not available through public APIs, so unavailable. They need SMC or `powermetrics`, which require root or private interfaces. Don't promise them.
- **RAM type and speed, SSD model and health, display panel model:** not public. The catalog can provide a few, where Apple publishes them.
- **Serial number:** readable (the `IOPlatformSerialNumber` key exists, verified), but sensitive. Recommendation: don't read or show it (§10 decision).

### 5.3 Mac catalog

- **Seed data:** the 44 existing Mac entries (`DeviceCatalog.json`, family "Mac", Apple-sourced, verified 2026-10-15), copied into `MacCatalog.json` and re-verified with a Mac-specific mode of the source verifier.
- **Schema needs that iPhone entries don't have:**
  - **configurations per identifier:** chip variants, CPU/GPU core options and memory options, each with its own sources;
  - **an optional display:** desktops have none, and the schema should say "no built-in display" explicitly instead of leaving it unknown (a known limitation recorded in the package README);
  - **ports and wireless standards**, if approved (§10, decision 7);
  - **no cameras** unless separately approved.
- **Resolving a configuration** combines the catalog with detection. Example: `Mac16,6` could be M4 Pro or M4 Max. The detected `machdep.cpu.brand_string` plus the core counts select the matching configuration. If none matches exactly, configuration-specific fields stay "unknown", never guessed.
- **Coverage:** Apple silicon only (`hw.optional.arm64`). Intel Macs are out of scope for the app (owner decision), so the catalog doesn't need Intel entries.
- **Lifecycle:** separate from the iOS catalog. Removing the 44 Mac entries from `DeviceCatalog.json` is an **optional, separately approved** cleanup:
  - **Behavior:** it doesn't change iOS behavior, because the iPhone app can't run on a Mac (`SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO`).
  - **Tests:** it does change the iOS catalog's tests and counts.
  - **Recommendation:** defer it until after the iOS 2.0 release.

## 6. Product direction (high level; no screen design yet)

- **Window:** a native Mac window with a `NavigationSplitView` (macOS 13) sidebar, not tabs.
- **Sidebar items:**
  - **Overview:** model (from the catalog), identifier, chip, memory, macOS. Each value shows where it came from (detected, catalog, unavailable).
  - **Processor:** chip, CPU clusters, logical CPUs.
  - **Graphics:** GPU name and unified memory are detected; GPU core count is from the catalog, per configuration.
  - **Memory:** installed memory (detected), plus memory pressure if approved.
  - **Storage:** volumes and capacity (sandbox scope to verify).
  - **Displays:** built-in and external, with resolution, physical size, refresh rate and EDR headroom (all detected).
  - **Battery:** laptops only; desktops show a clear "no battery" state. Level, charging, time remaining and health condition use public keys. Cycle count is **unavailable**.
  - **Connectivity:** network path; Wi-Fi details only if the permission story is acceptable (to verify); Bluetooth **not planned** (it would need a usage description and permission).
  - **System:** uptime, thermal state, Low Power Mode.
- **Settings:** a `Settings` scene (Cmd-,) with appearance and "about".
- **Optional, later:**
  - a `MenuBarExtra` (macOS 13), per TD-12;
  - export or copy of a report, which would be a new feature, not in scope.
- **Labeling:** detected, catalog and unavailable values are visually distinct, with the reason shown for unavailable ones.
- **Liquid Glass and detailed design:** a later phase.

## 7. Compatibility, permissions, distribution

| Topic | Plan | Status |
|---|---|---|
| Minimum OS | macOS 13 Ventura | Owner decision. SwiftUI features introduced in macOS 14 (`@Observable`, `ContentUnavailableView`, `inspector`) need fallbacks via a Mac compatibility file. |
| Architecture | `arm64` only (`ARCHS = arm64`) | Owner decision. Intel Macs (which can run macOS 13–26) cannot run an arm64-only app, so they are unsupported; the download page must say so. |
| SDK / CI compiler | Local Xcode 27.1 (macOS 27.0 SDK); CI Xcode 26 (macOS 26 SDK) | Verified locally. Use only APIs available in the macOS 26 SDK; guard newer APIs or avoid them (as in iOS Phase 4). |
| App Sandbox | Enabled; `com.apple.security.network.client` only if CoreWLAN or networking needs it | Earlier audit (TD-07): the recommended data sources work sandboxed, verified on macOS 27.2. Re-verify each Mac reader when implemented. |
| Hardened Runtime | Enabled | Required for notarization |
| Privacy | No serial number, no location, no Bluetooth; a privacy manifest (`PrivacyInfo.xcprivacy`) declaring required-reason APIs (for example disk-space APIs) | Assumption: required-reason categories to confirm against Apple's current list |
| Distribution outside the App Store | A Developer ID-signed, notarized DMG | **Needs a paid Apple Developer Program membership** (earlier audit, TD-09). The current team (`8QU4WRDSA4`) is a free Personal Team, which can't create Developer ID certificates or notarize. Without that, downloaded builds are blocked by Gatekeeper and users must override them manually. |
| App Store | Possible later | The sandbox and no private APIs keep it open; not planned |

## 8. CI and development workflow

**Today:** one job on `macos-26` (`.github/workflows/ci.yml`). It must keep passing unchanged.

**Proposed (approval needed; nothing changed now):**
1. **A second, independent job, `mac-build-and-test`,** on `macos-26`:
   - `xcodebuild build -project SpecMatrixMac/SpecMatrixMac.xcodeproj -scheme SpecMatrixMac -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`;
   - `xcodebuild test … -only-testing:SpecMatrixMacTests`.

   **Mac tests run natively on the runner, with no simulator involved.** That's a significant advantage given the simulator problems on the development Mac.
2. **Isolation:** the existing iOS job doesn't depend on the Mac job, so a Mac failure never blocks the iOS 2.0 work. Path filters can be added later.
3. **`swift test`** on the package already covers the new Mac package targets on macOS; keep it in the iOS job or move it to a shared job.
4. **Link check:** fail the Mac job if the Mac app links `SpecMatrixCore`, `SpecMatrixPlatform` or `SpecMatrixState`.
5. **Xcode version:** CI's Xcode 26 is the compatibility authority (as in Phase 4). Local Xcode 27.1 work must avoid macOS 27-only APIs.

**Local workflow:**
- Mac unit tests can run locally without simulators: `xcodebuild test -destination 'platform=macOS'` or `swift test`.
- Whether to run them is your call, per your current testing preferences.

## 9. Staged roadmap

Each stage needs your approval before it starts.

| Stage | Goal | Main outputs | Exit criteria |
|---|---|---|---|
| M0. Decisions | Resolve §10 decisions | Updated plan | All open decisions answered |
| M1. Package architecture | Extract `SpecMatrixShared`; add empty `SpecMatrixMac*` targets and the `SpecMatrixMacKit` product | Package changes only | iOS app unchanged (no source edits); `swift test` passes; iOS CI green |
| M2. Mac catalog | Mac schema, decoder and validation; seed `MacCatalog.json` from the 44 entries; verifier Mac mode | `SpecMatrixMacCatalog` + tests | Decoder tests; verifier passes against Apple pages; configurations modeled |
| M3. Mac detection | Readers in `SpecMatrixMacPlatform` (identity, chip, clusters, memory, GPU, displays, battery, storage, thermal, network) | Readers + mapping tests with fakes | Every value labeled; unavailable reasons explicit; sandbox behavior verified |
| M4. Mac project and CI | `SpecMatrixMac.xcodeproj`, minimal app shell, entitlements, Mac CI job | Builds in CI | Mac job green; link-isolation check passes; iOS job unaffected |
| M5. Interface design | Information architecture and screens; macOS 13 fallbacks; Liquid Glass on macOS 26+ | Design doc | Approved design |
| M6. Implementation | Screens per the design, Settings scene | App | Feature checklist met; unit tests |
| M7. Validation | Native Mac tests; manual checks on Apple silicon Macs (M1–M5 families as available, macOS 13 and the current release) | Validation report | Results recorded; unverified items listed |
| M8. Release | Signing, notarization (if membership), DMG, release notes, Mac version and tag | Release candidate | Owner sign-off |

The iOS 2.0 release can proceed in parallel. Only M1 touches code the iOS app links, and M1 is behavior-preserving and approval-gated.

## 10. Risks, open questions and decisions

**Risks:**
- **`SpecMatrixShared` extraction:** it moves types between modules. Mitigation: the `@_exported` re-export, no iOS source edits, a full `swift test` run and iOS CI before merging.
- **Configuration resolution:** Mac identifiers that cover several configurations may be ambiguous. Mitigation: model configurations explicitly and fall back to "unknown".
- **Sandbox limits:** some readers (CoreWLAN, multiple volumes) may behave differently when sandboxed. Mitigation: verify each reader in a sandboxed build before relying on it.
- **Two Xcode versions:** local 27.1 versus CI 26. Mitigation: treat CI as the authority.
- **macOS 13 testing:** no macOS 13 machine or VM is known to be available. That makes "minimum OS verified" an open item.
- **Distribution:** without a paid membership there's no notarized download.

**Resolved by the owner for Phase 1, Part 1:**
- 1: same repository;
- 2: separate Mac project, no workspace;
- 3: the `SpecMatrixShared` approach, partly implemented, with `SpecValue` blocked (§0);
- 6: the Mac version is 1.0;
- 8: serial number never read.

The items below are kept as originally asked.

**Decisions needed from you:**
1. **Repository:** confirm the same repository. Recommended: yes.
2. **Project:** a separate `SpecMatrixMac.xcodeproj` (recommended) or a new target in `SpecMatrix.xcodeproj`. Also, whether to add a `SpecMatrix.xcworkspace` for development convenience.
3. **Package sharing:** extract `SpecMatrixShared` and re-export it from `SpecMatrixCore` (recommended), or let the Mac depend on `SpecMatrixCore` and accept linking the iOS catalog.
4. **Mac catalog seed:** reuse the 44 Mac entries as seed data (recommended), and whether to remove them from `DeviceCatalog.json` after iOS 2.0.
5. **Distribution:** will a paid Apple Developer Program membership be available for Developer ID and notarization? If not, how should Mac builds be distributed?
6. **Mac version numbering:** start at 2.0 to match the brand, or 1.0 as a new app.
7. **Scope of optional data:**
   - Wi-Fi details (permission implications);
   - battery health condition (public key);
   - menu bar extra;
   - ports and wireless standards in the catalog.
8. **Serial number:** confirm it's never read (recommended).
9. **Test hardware:** which Apple silicon Macs (and macOS versions, especially 13) are available for validation?
10. **CI:** approve adding a separate Mac job when M4 starts.

**Questions still open (to verify during M2–M4):**
- CoreWLAN SSID authorization requirements on macOS 13 and the current release.
- Sandbox access to non-boot volumes.
- `CGDisplayScreenSize` accuracy for external displays, since it relies on EDID.
- Exact privacy-manifest reason codes.

## 11. What must not change in the iPhone app

- `SpecMatrix.xcodeproj`:
  - targets, schemes, build settings;
  - `IPHONEOS_DEPLOYMENT_TARGET` (17.0 app; test and project-level values as the owner sets them);
  - `TARGETED_DEVICE_FAMILY = 1`;
  - `SUPPORTS_MACCATALYST = NO`, `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO`;
  - signing team and identity, bundle identifiers, `MARKETING_VERSION 2.0`, `CURRENT_PROJECT_VERSION`. (Mac work makes no edits here; the owner's own pending edit is theirs to commit.)
- Everything under `SpecMatrix/`, `SpecMatrixTests/`, `SpecMatrixUITests/`: no edits for the Mac app.
- The `SpecMatrixKit` product's contents and behavior for iOS:
  - `DeviceCatalog.json` (schema 3, 2026.10.3) and its tests;
  - `SpecMatrixPlatform` iOS paths;
  - `DeviceInfoStore`.

  The only planned package change iOS will see is the behavior-preserving `SpecMatrixShared` extraction (M1), which needs approval.
- `.github/workflows/ci.yml`'s existing iOS job: steps, runner, destination selection.
- `docs/PHASE3_HANDOFF.md`, `docs/PHASE4_HANDOFF.md`.
