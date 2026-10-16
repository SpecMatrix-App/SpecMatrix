# SpecMatrix: Testing Strategy

Audit date: 2026-10-15.

## 1. Current state

| Target | Content | Value |
|---|---|---|
| `SpecMatrixTests` (Swift Testing) | One empty `@Test func example()` | None. It passed during this audit with zero assertions. |
| `SpecMatrixUITests` (XCTest) | Empty `testExample`, `testLaunchPerformance`, launch screenshot | Launch smoke test only. It could not be completed in this environment (§8). |

Nothing in the app can be tested in isolation. Every data function calls `UIDevice.modelIdentifier()` directly and reads `UIDevice`/`UIScreen` singletons (CB-13).

## 2. Principles

1. **Detection logic is pure and injectable.** Resolution, mapping, formatting and provenance are tested with fixtures. They never depend on the device the tests run on.
2. **Never weaken detection to make a test pass.** Fakes exist to exercise the logic around a provider. Each real provider also has a device check (§5) confirming that it returns real data.
3. **Simulator ≠ hardware.** The simulator reports `SIMULATOR_MODEL_IDENTIFIER`, the host's GPU families and memory, a battery level of `-1`, and no cameras. Simulator tests validate UI and logic only.
4. **Test the oldest and newest supported OS** wherever the toolchain allows. Where it doesn't, record the gap explicitly.

## 3. Test layers

| Layer | Framework | Runs where | Covers |
|---|---|---|---|
| Core unit | Swift Testing (`swift test` on macOS; also iOS sim via `xcodebuild`) | CI, every PR | `DeviceResolver`; identifier parsing (incl. `iPhone19,7`, simulator); provenance; formatters (decimal vs binary, locale); battery level and state presentation incl. `-1`; storage-tier derivation; thermal mapping; SF Symbol names exist (`UIImage(systemName:)`/`NSImage` non-nil) |
| Catalog validation | Swift Testing + JSON Schema validator | CI, every PR touching `catalog/` | Schema conformance; unique identifiers; every non-null field sourced; enum values; units; test vectors; **every identifier in the installed Xcode's CoreSimulator profiles resolves** (a guard against a new device shipping without a catalog record) |
| Provider unit | Swift Testing with fake system interfaces (e.g. an injected `sysctl` reader, `NWPath` snapshots, power-source dictionaries captured from real Macs) | CI | Parsing and mapping of raw system data; error paths; unavailable states |
| Concurrency | Swift 6 language mode (compile-time); tests that cancel `.task` sampling | CI | No data races; sampling stops on cancellation; no work after disappear |
| View model / store | Swift Testing | CI | Composition of providers + catalog into screen state; unknown-device mode; partial data |
| Snapshot | `swift-snapshot-testing` (TD-16) or Xcode previews rendered in tests | CI (iOS sim, macOS) | Compact/regular, light/dark, AX5 Dynamic Type, RTL pseudo-locale, unavailable states; iOS 26+ glass vs pre-26 fallback (needs both simulator runtimes) |
| UI | XCTest UI | CI (sim), nightly | Launch; tab and sidebar navigation; Settings persistence across relaunch; export sheet; macOS menu commands and keyboard shortcuts; window resizing to minimum size |
| Performance / energy | XCTest metrics + Instruments | Manual per release, physical devices | Launch time; CPU wakeups with the Live view open; sampling stops when backgrounded or hidden; no Mach port growth (`mach_port_get_refs` before/after in a test, the regression test for CB-07) |
| Accessibility | Xcode Accessibility Inspector audit (`XCUIApplication.performAccessibilityAudit`, iOS 17+), manual VoiceOver | CI (audit) + manual | Labels, traits, contrast, Dynamic Type clipping |
| Distribution | Scripts | Release pipeline | `codesign --verify --deep --strict`, `spctl -a -vv`, `stapler validate`, IPA `embedded.mobileprovision` inspection, install on a clean device/account |

## 4. Fixtures

- `catalog/test-vectors.json`: identifier → expected record id (plus the expected "unknown" outcome for made-up IDs such as `iPhone99,1`).
- `Tests/Fixtures/sysctl/*.json`: captured `hw.*` values from real devices (an M2 MacBook Air was captured during the audit; add iPhone and iPad captures during Phase 2 device checks).
- `Tests/Fixtures/powersources/*.plist`: IOPS dictionaries (Mac with battery, desktop Mac without battery, charging, full).
- `Tests/Fixtures/paths/*.json`: `NWPath` snapshots (wifi, cellular expensive, wired, constrained, unsatisfied).
- Fake providers live in `SpecProviders/Fakes`. They are compiled for tests and previews only and are never linked into Release builds.

## 5. Physical-device validation checklist (manual, per release)

| Check | Devices |
|---|---|
| Identifier resolves to the right record; no "Unknown" | Every available physical device |
| `hw.perflevel*` readable on iOS and matches the catalog P/E counts | One A-series iPhone, one M-series iPad |
| Battery level, state and notifications; no negative values; icons render | iPhone/iPad (unplug, plug, full) |
| Thermal state changes reported | Any device under load |
| Low Power Mode toggling updates LPM row and "current max fps" | ProMotion iPhone |
| Display Zoom on → native resolution unchanged | Any iPhone |
| External display / Stage Manager → display section follows the window's screen | M-series iPad |
| Camera enumeration without a permission prompt (or with it, documented) | iPhone with telephoto; iPad; Mac |
| Storage matches Settings → General → Storage (within rounding) | Any |
| macOS: battery %, charging, max capacity match System Settings → Battery | MacBook |
| macOS: CPU load tracks Activity Monitor (±5 %) | Any Mac |
| macOS sandboxed build: every provider returns data | Any Mac |

## 6. OS coverage matrix

| OS | How | Gap |
|---|---|---|
| iOS/iPadOS 27 (newest) | Simulator (installed) + device | — |
| iOS/iPadOS 26 (first Liquid Glass release) | Simulator runtime via Xcode 27 Components (**availability to confirm**) + device | — |
| iOS 17 (recommended minimum) | Simulator runtime (Xcode 27 supports 17+; **download to confirm**) + device | Needs an iOS 17 device or a device held back on 17 |
| iOS 16 (if TD-01 keeps it) | **Not possible with Xcode 27.** Needs Xcode 26.x plus an iOS 16 device, or Ad Hoc/TestFlight installs without a debugger | Significant |
| macOS 27 (newest) | This Mac (27.2) | — |
| macOS 26 | VM or second Mac | — |
| macOS 14 / 13 (minimum) | macOS VM on Apple silicon (Virtualization framework) or old hardware | Intel coverage unknown |

## 7. CI proposal

- **PR:** `swift test` (package core + catalog), `xcodebuild test` on the iOS simulator (iPhone and iPad destinations), `xcodebuild build` for macOS, catalog validation. Use the `xcode-27` preview runner (or `macos-26` with Xcode 26.6 if the 27 SDK is not needed yet).
- **Nightly:** UI tests on several simulators, snapshot comparison, accessibility audit.
- **Release:** the signed and notarized pipeline (`DISTRIBUTION_AND_RELEASE_AUDIT.md` §4).

## 8. Commands executed during this audit

Environment:
- macOS 27.2 (26B5101f), arm64 (MacBook Air M2, `Mac14,2`).
- Xcode 27.0 (27A266a) at `/Applications/Xcode.app`, used via `DEVELOPER_DIR`. `xcode-select` points to the Command Line Tools and was **not changed**.
- Swift 6.4.
- SDKs: iOS 27.0, iOS Simulator 27.0, macOS 27.0 (plus tvOS, watchOS and visionOS).
- Simulator runtime: **iOS 27.0 only**.
- 0 code-signing identities.

All builds wrote only to a scratch `DerivedData` outside the repository. Repo file checksums and `git status` were identical before and after.

| # | Command (abbreviated; `D=DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`) | Completed? | Result |
|---|---|---|---|
| 1 | `$D xcodebuild -list -project SpecMatrix.xcodeproj` | Yes | 3 targets, configurations Debug/Release, scheme `SpecMatrix` (auto-generated; no shared scheme file) |
| 2 | `$D xcodebuild build -scheme SpecMatrix -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath <scratch> CODE_SIGNING_ALLOWED=NO` | Yes | **BUILD SUCCEEDED**, 0 Swift warnings |
| 3 | same + `SWIFT_VERSION=6` | Yes | **Failed**: 2 errors (L1149, L1193) |
| 4 | same + `IPHONEOS_DEPLOYMENT_TARGET=16.0` | Yes | **Failed**: 2 errors (`onChange` iOS 17+, L1473, L1625) |
| 5 | same + `SWIFT_STRICT_CONCURRENCY=complete` | Yes | Succeeded, **58 unique warnings** |
| 6 | `$D xcodebuild build -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` | Yes | **BUILD SUCCEEDED**; arm64; MinimumOSVersion 18.2; UIDeviceFamily [1]; 1.1 MB `.app` |
| 7 | `$D xcodebuild test -scheme SpecMatrix -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO` | Partially | Unit: `SpecMatrixTests/example()` **passed**. UI: runner "crashed with signal kill before establishing connection" (an unsigned UI-test runner cannot launch) → exit 65 |
| 8 | `$D xcodebuild test -only-testing:SpecMatrixUITests … CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGN_STYLE=Manual` | **No** | Build succeeded, then stalled launching the app for more than 10 minutes. It was terminated. |
| 9 | `xcrun simctl boot` (iPhone 18 Pro) / `install` / `launch` / `io screenshot` | **No** | `launchd_sim` failed ("could not bind to session"); install/launch timed out. **No runtime screenshots or console output were obtained.** |
| 10 | Probe (scratch Swift on macOS 27.2): `NSImage(systemSymbolName:)` for the app's symbol names | Yes | `battery.unknown`, `battery.37`, `battery.-100` **missing**; others exist |
| 11 | Probe: 1,000 × `mach_host_self()` without deallocation | Yes | Send urefs 1 → 1,001 (leak confirmed on macOS) |
| 12 | Research agent probes (scratch, macOS, unsandboxed and App-Sandboxed ad-hoc builds): sysctl, IOPS, IORegistry, `host_processor_info`, CoreWLAN, Metal | Yes | See `research/system_apis_and_toolchain.md`. Side effect: a sandbox container `~/Library/Containers/com.example.sbprobe` was created on this Mac, outside the repository. |

**Not executed:** any physical iOS or iPadOS device test, any iOS 16–26 simulator, any macOS build of SpecMatrix (no macOS target exists), signing, archiving, or export.

**Environmental limitations:**
- The simulator service was unhealthy.
- Only the iOS 27 simulator runtime is installed.
- There are no signing identities.
- There are no physical devices attached.
- The runtime behaviour claims CB-08 (settings observation) and CB-06 (cache effect on "speed") are therefore based on code reasoning and are not observed.
