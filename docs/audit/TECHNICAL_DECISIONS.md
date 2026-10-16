# SpecMatrix: Technical Decisions Requiring Approval

Audit date: 2026-10-15. Each entry below is a **proposal**. None has been applied.
Status key: 🟡 awaiting decision.

---

## TD-00 · Overall approach: rewrite in place or patch incrementally? 🟡
- **Options:**
  - **A. Patch the existing `ContentView.swift`.**
  - **B. Rewrite in the same repo and project, using the existing app as the behavioural reference.**
  - **C. New repo.**
- **Evidence:**
  - The app is about 1,800 lines in a single file.
  - The data tables are wrong for most devices (CB-01–03).
  - The settings only work by accident (CB-08).
  - Nothing compiles for macOS or in Swift 6 mode.
  - There is no user data to migrate except two `UserDefaults` keys.
- **Recommendation: B.** Keep the git history, project, bundle ID and licence. Build the new architecture alongside the old code, switch the app entry over, then delete `ContentView.swift`. A tiny fix-only release (Phase 1) can ship first if current users need correct data sooner.
- **Consequences:** Nearly every line of the application is replaced. The things that carry over are the identifier technique, the battery notification pattern, `NWPathMonitor`, and the row concept.

## TD-01 · Minimum deployment targets 🟡
- **Question:** iOS/iPadOS 16 + macOS 13 (the stated goal), or something higher?
- **Evidence** (`MULTIPLATFORM_ARCHITECTURE.md` §9):
  - Xcode 27 **builds** for iOS 15+ and macOS 12+.
  - It **runs and debugs only on iOS 17+ devices**, and its simulators are iOS 17+ only.
  - Today's code has exactly two iOS 16 compile blockers.
  - `@Observable`, the new `onChange`, `ContentUnavailableView` and `inspector` all require iOS 17 / macOS 14.
  - The only installed simulator runtime is iOS 27.

| Option | Advantages | Disadvantages |
|---|---|---|
| iOS 16 / macOS 13 | Meets the stated goal. Covers iPhone 8/X and Ventura-capped Macs. | Needs `ObservableObject` everywhere, or a back-port dependency. Needs a second Xcode (26.x) plus a physical iOS 16 device to debug. Needs a Ventura test machine or VM. More compat shims. |
| **iOS 17 / macOS 14** | Testable with the current toolchain (simulators, debugger, Instruments). `@Observable` is available on both platforms. Fewer shims. | Drops iPhone 8/8 Plus/X and some 2017 Macs. |
| iOS 17 / macOS 13 | Keeps Ventura. | Forces `ObservableObject` on both platforms anyway, or separate observation code. |
| iOS 18 / macOS 15 | `Tab` API and `sidebarAdaptable` everywhere. | Drops XS/XR-era support for little gain. Raises the minimum mainly for convenience. |

- **Recommendation: iOS/iPadOS 17 and macOS 14.**
  - This is driven by verifiability on the oldest supported OS, which the brief requires, not by convenience.
  - If iOS 16 is non-negotiable, the architecture supports it. Budget for an iOS 16 device, Xcode 26.x, and `ObservableObject` stores.
- **Unresolved:** actual install-base data for iOS 16 and macOS 13 among SpecMatrix users (unknown, since there are no analytics). Also confirm that the iOS 17/18 simulator runtimes download in Xcode 27.

## TD-02 · Project and target structure 🟡
- **Options:**
  - **A.** One multiplatform app target plus a local SPM package (`SpecCore`, `SpecCatalog`, `SpecProviders`, `SpecUI`).
  - **B.** Separate iOS and macOS targets plus the package.
  - **C.** Mac Catalyst.
- **Recommendation: A.** Keep B as a cheap fallback. C is rejected because it is not AppKit-native and camera discovery is reported empty under Catalyst.
- **Consequences:** a new `Packages/SpecMatrixKit` directory. The `.pbxproj` gains a macOS destination and a package reference. Tests move largely into the package, where `swift test` runs on macOS.

## TD-03 · macOS architectures and Intel Mac coverage 🟡
- **Evidence:** macOS 26 is the last release for Intel Macs. Intel Macs can run macOS 13–26.
- **Options:**
  - Universal binary with full Intel catalog records.
  - Universal binary with Intel shown as "limited catalog".
  - Apple silicon only (`arm64`), which excludes Intel users even though they could run the minimum OS.
- **Recommendation:** ship a universal binary. Cover Intel Macs in the catalog in a later pass, with an explicit limited state until then.
- **Unresolved:** whether any Intel test hardware is available.

## TD-04 · State observation 🟡
- Follows TD-01. With 17/14, use `@Observable` stores injected through `Environment`. With 16/13, use `ObservableObject`, with no third-party back-port.

## TD-05 · Hardware catalog delivery 🟡
- **Options:** bundled JSON; bundled plus signed remote refresh; backend.
- **Recommendation:** bundled JSON validated by JSON Schema in CI. Revisit a signed remote refresh only after shipping and seeing how often new-device lag hurts users. Never a backend for static data.

## TD-06 · Show unofficial RAM figures? 🟡
- **Evidence:** Apple publishes no iPhone RAM. The secondary sources mostly agree, but values for recent devices are unverified.
- **Options:**
  - (a) Show only `physicalMemory` ("as reported by the system").
  - (b) Also show catalog RAM with an "Unofficial" badge.
  - (c) Omit RAM.
- **Recommendation: (b)** for devices where two independent secondary sources agree; otherwise (a).

## TD-07 · macOS App Sandbox 🟡
- **Evidence:** The sandbox is not required for Developer ID. All recommended data sources work sandboxed (verified on macOS 27.2). CoreWLAN additionally needs `network.client`.
- **Recommendation:** enable the sandbox, plus the Hardened Runtime, which is mandatory for notarization.

## TD-08 · Undocumented IORegistry data on macOS 🟡
- **Evidence:** `product-name`, `gpu-core-count` and `AppleSmartBattery CycleCount` are readable in the sandbox. Apple DTS states that undocumented properties are not API.
- **Recommendation:** do not use them in production paths. Get marketing name and GPU cores from the catalog. Omit cycle count, or put it in an opt-in "Experimental (unsupported)" section with a visible badge. Default: omit.

## TD-09 · Distribution channels and Apple Developer Program 🟡
- **Questions:**
  - Is a paid membership available, and which team should own the app?
  - Should TestFlight or the App Store listing (id6740110428) be maintained?
- **Facts:**
  - A notarized DMG requires a paid membership and Developer ID.
  - Ad Hoc is limited to 100 devices per family per year.
  - Free-team and sideloaded installs expire every 7 days.
- **Recommendation:**
  - **macOS:** Developer ID-signed, notarized DMG on GitHub Releases.
  - **iOS:** an IPA on GitHub Releases for self-signing users (documented limits), plus TestFlight for wider testing if a membership exists.
  - Decide on the App Store separately; the architecture keeps it possible (privacy manifest, no private APIs).

## TD-10 · Units and formatting policy 🟡
- **Recommendation:**
  - Storage in decimal units (GB = 10⁹), matching Apple's marketing and the Settings app.
  - Catalog RAM in GB as marketed.
  - Measured RAM in binary units, labelled as such ("7.5 GiB visible to system").
  - Localised `FormatStyle` throughout.
  - Write the policy in `docs/specs/MEASUREMENTS.md`.

## TD-11 · Scope of the catalog feature 🟡
- **Question:** browse all devices (catalog, compare) in the first modernised release, or only "this device"?
- **Recommendation:** ship "this device", correct and honest, first (Phases 1–6, release 1.0). Add catalog browsing and comparison in Phase 7 (1.1). The data exists either way.

## TD-12 · macOS menu bar extra 🟡
- **Recommendation:** add it in the macOS polish phase, off by default (live CPU, thermal, battery). It is low cost (`MenuBarExtra`, macOS 13+) and well suited to the Mac.

## TD-13 · Swift 6 language mode 🟡
- **Evidence:** the current code fails Swift 6 with 2 errors and 58 strict-concurrency warnings. These disappear with the new design.
- **Recommendation:** use Swift 6 language mode for the package and app from the start.

## TD-14 · Network "speed" feature 🟡
- **Recommendation:** remove the 1 Hz favicon loop (CB-06). Optionally add later an explicit "Run speed test" with a disclosed endpoint and data cost. Using an Apple endpoint without permission is not appropriate. This would be the app's only network use, so it needs a privacy note.

## TD-15 · Identity and signing hygiene 🟡
- Unify `DEVELOPMENT_TEAM` across targets. Replace `com.example.*` test bundle IDs. Add `.gitignore`. Stop tracking `xcuserdata`. Share schemes.
- **Decide** whether the bundle ID stays `com.zacdevv.SpecMatrix`. Changing it breaks continuity with the existing App Store listing and installed copies. Recommendation: **keep it**, and use `com.zacdevv.SpecMatrix` for macOS too (one ID across platforms is allowed for multiplatform apps).

## TD-16 · Third-party dependencies 🟡
- **Current:** none.
- **Recommendation:**
  - Keep the core at zero dependencies.
  - Allow Sparkle (macOS updates) when updates are needed.
  - Allow at most one snapshot-testing library in test targets only (e.g. `swift-snapshot-testing`).
  - Avoid identifier-mapping libraries (e.g. DeviceKit), since the catalog is a product asset that needs provenance.

## TD-17 · Removing per-section "hide" toggles 🟡
- **Recommendation:** remove them (CB-22). If users want customisation, add an editable Live dashboard later.
- **Consequence:** the `displaySettings` key becomes obsolete. Ignore it; no migration is needed.
