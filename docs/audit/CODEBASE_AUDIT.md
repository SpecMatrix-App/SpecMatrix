# SpecMatrix — Codebase Audit

Audit date: 2026-10-15 · Commit audited: `faafc9c` (branch `main`, tag `v1` at `d866a87`)
Scope: every file tracked in the repository plus untracked `xcuserdata` (inspected, not modified).

Severity: **P0** critical correctness/data-integrity/release-blocking · **P1** major architecture/accuracy/compat · **P2** maintainability/perf/UX/testing · **P3** polish.
Confidence: **Confirmed** (reproduced by build, probe, or unambiguous code reading) · **High** · **Medium** · **Low**.

---

## 1. Repository inventory

| Path | Lines | Content |
|---|---|---|
| `SpecMatrix/SpecMatrixApp.swift` | 17 | `@main SpecMatrixApp` → `WindowGroup { ContentView() }` |
| `SpecMatrix/ContentView.swift` | 1,774 | **The entire application**: 28 top-level types/functions — models, monitors, hardware tables, views, settings, persistence wrapper |
| `SpecMatrix/Assets.xcassets` | — | `AppIcon` (3 × 1024² PNGs, **byte-identical**: SHA-1 `c5a0ae7c…` for any/dark/tinted), empty `AccentColor` |
| `SpecMatrix/Preview Content/Preview Assets.xcassets` | — | Empty |
| `SpecMatrixTests/SpecMatrixTests.swift` | 17 | Xcode template, one empty `@Test` |
| `SpecMatrixUITests/*.swift` | 76 | Xcode template: empty `testExample`, `testLaunchPerformance`, launch screenshot |
| `SpecMatrix.xcodeproj/project.pbxproj` | — | 3 targets, objectVersion 77, file-system-synchronized groups, no package dependencies |
| `SpecMatrix.xcodeproj/xcuserdata/zachary.xcuserdatad/…` | — | **Tracked in git** (user-specific scheme management) |
| `SpecMatrix.xcodeproj/xcuserdata/zac.xcuserdatad/`, `project.xcworkspace/xcuserdata/` | — | Untracked (pre-existing; preserved) |
| `README.md`, `LICENSE` (MIT, © 2025 Zachary Aflalo) | — | Docs |

Absent: `.gitignore`, shared schemes (`xcshareddata/xcschemes`), CI (`.github/`), Swift packages, `Package.resolved`, entitlements, explicit `Info.plist` (generated), `PrivacyInfo.xcprivacy`, string catalogs, changelog.

### 1.1 Build configuration (from `project.pbxproj`)

| Setting | Value | Note |
|---|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET` | 18.2 (project, app, unit tests) | README also says 18.2 |
| `TARGETED_DEVICE_FAMILY` (app) | `1` (iPhone only) | Was `"1,2"` at initial commit; changed in `1a28003` "only works on ios" |
| `SUPPORTS_MACCATALYST` / `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD` / `…XR…` | NO / NO / NO | |
| `SWIFT_VERSION` | 5.0 (all targets) | Swift 6 language mode not enabled |
| `SDKROOT` | `iphoneos` | Created with Xcode 16.2 (`CreatedOnToolsVersion = 16.2`) |
| `DEVELOPMENT_TEAM` | App: `LSYVL36ZN3`; test targets: `8QU4WRDSA4` | **Inconsistent teams** |
| `PRODUCT_BUNDLE_IDENTIFIER` | App `com.zacdevv.SpecMatrix`; tests `com.example.SpecMatrixTests`, `com.example.SpecMatrixUITests` | Template IDs left in place |
| `CODE_SIGN_STYLE` | Automatic | |
| `INFOPLIST_KEY_LSApplicationCategoryType` | `public.app-category.developer-tools` | macOS key; harmless on iOS |
| Orientations (iPhone) | Portrait, Landscape L/R | Layout not designed for landscape |

### 1.2 Feature → implementation map

| Screen / feature | Entry | Implementation | Data source |
|---|---|---|---|
| Tab bar (5 tabs) | `ContentView.body` L1417 | `TabView` + `.tabItem` | — |
| **Specs** tab header | L1422-1432 | Static SF Symbol + `UIDevice.current.model` | Public API (always the generic "iPhone") |
| Battery card | `BatteryInfoView` L363 | `BatteryMonitor` L1215 | `UIDevice.batteryLevel/State` + notifications |
| Battery health row | L383-408 | Alert → `UIApplication.open("App-prefs:")` | Unsupported URL scheme; no data |
| System card | `SystemInfoView` L454 | `getDetailedDeviceModel()` L412, `UIDevice.systemVersion` | `uname` → hard-coded `switch` |
| GPU card | `GPUInfoView` L511 | `GPUInfo.getInfo` L39 | Hard-coded `switch` |
| CPU card | `CPUInfoView` L481 | **Literal strings L497-502** | None — constant for every device |
| Memory card | `MemoryInfoView` L538 | `MemoryMonitor` L1106 (10 Hz) | `ProcessInfo.physicalMemory`, `host_statistics64` |
| Storage card | `StorageInfoView` L565 | `ContentView.storageInfo` L1336 (once) | `attributesOfFileSystem(forPath: NSHomeDirectory())` |
| **Network** tab | `NetworkInfoView` L772 | `NetworkMonitor` L650 | `NWPathMonitor`, 1 Hz download of `apple.com/favicon.ico` |
| **Display** tab | `ScreenInfoView` L851 | `ContentView.screenInfo` L1376 (once), `BrightnessMonitor` L1192 | `UIScreen.main` + hard-coded PPI/size `switch` |
| **Camera** tab | `CameraInfoView` L952 | `CameraInfo.getInfo` L1000 | Hard-coded `switch` (4 cases + default) |
| **Settings** tab | `SettingsView` L1632 | `CodableAppStorage` L326, `@State selectedTheme` | `UserDefaults` |
| Theme (Light/Dark/System) | L1639-1656 | `.preferredColorScheme` | `@State` (not restored) |
| Section visibility toggles, Show/Hide All | L1658-1695 | `DisplaySettings` (9 Bools) | `UserDefaults` JSON |
| About links | L1697-1741 | `Link` to GitHub (old `Belligerently/SpecMatrix` URL), mailto, licence | Static |

### 1.3 Dead / unreachable code (Confirmed by symbol search)

| Symbol | Location | Status |
|---|---|---|
| `private func getDeviceIdentifier()` | L444 | Never called (duplicate of `UIDevice.modelIdentifier()`) |
| `BatteryInfo.getCurrentBatteryInfo()` | L193 | Never called (and it is the only path with the `-1` guard) |
| `BatteryInfo.health` | L151 | Always `-1`, never read |
| `ScreenInfo.getCurrentScreenInfo()` | L838 | Never called (duplicated inline at L1376) |
| `ScreenInfo.brightness` | L805 | Stored, never read (`BrightnessMonitor` used instead) |
| File-scope `let processorInfo: ProcessorInfo` + `struct ProcessorInfo` | L1139-1189 | Never read; shadowed by `ContentView.processorInfo: String` |
| `ContentView.processorInfo` (String, L1276) | — | Passed to `CPUInfoView`, which **ignores it** |
| `GPUInfo.metalVersion`, `GPUInfo.getInfo(for:)` parameter | L37, L39 | Never displayed / parameter ignored |
| `NetworkInfo.CellularInfo` (`carrier`, `signalStrength`, `radioTech`, `displayTechnology`) | L600-617 | Populated with constants (`"Cellular"`, `3`), never displayed |
| `safeGetDeviceInfo().camera` | L1397 | Computed every render, discarded |
| `ScreenInfoView.colorScheme` | L854 | Unused environment value |
| `ContentView.saveTheme` → key `"selectedTheme"` | L1413 | Written, **never read** |

---

## 2. Build & static-analysis evidence

All builds used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (Xcode 27.0, 27A266a) with `-derivedDataPath` in a temporary scratch directory. Repo checksums and `git status` were compared before and after: **no repository file changed**. Full commands are in `TESTING_STRATEGY.md` §8.

| Build | Result | Diagnostics |
|---|---|---|
| Debug, iOS Simulator (iPhone 17, iOS 27.0), unsigned | **Succeeded** | 0 Swift warnings |
| Release, `generic/platform=iOS`, unsigned | **Succeeded** | 0 Swift warnings; arm64 only; `MinimumOSVersion 18.2`, `UIDeviceFamily [1]`, 1.1 MB |
| Override `SWIFT_VERSION=6` | **Failed** | 2 errors: L1149, L1193 "main actor-isolated default value in a nonisolated context" |
| Override `SWIFT_STRICT_CONCURRENCY=complete` | Succeeded | **58 unique concurrency warnings** |
| Override `IPHONEOS_DEPLOYMENT_TARGET=16.0` | **Failed** | 2 errors: L1473, L1625 `onChange(of:initial:_:)` is iOS 17+ — **the only iOS 16 compile blockers** |
| Unit tests (`SpecMatrixTests`) | 1 passed | Template test with no assertions |
| UI tests | **Not completed** | First run: runner killed at bootstrap (signing disabled). Second run (ad-hoc signed) stalled because the simulator service failed (`launchd_sim` could not bind session). Environmental, not attributed to the app. |

---

## 3. Findings

### P0 — Data integrity

#### CB-01 · CPU card shows "A17 Pro" on every device
- **Confidence:** Confirmed (code reading).
- **Where:** `CPUInfoView.body`, `ContentView.swift` L497-502.
- **Evidence:** `InfoRow(label: "Chip", value: "A17 Pro")`, `"6-core"`, `"2"`, `"4"`, `"6-core"`, `"16-core"` are literals. The `processorInfo` property (L482) is never referenced in `body`.
- **Impact:** Each of the six rows on the CPU card is a fixed literal. On an iPhone 16 the card still says A17 Pro, and on an iPhone 12 it says A17 Pro with 6 GPU cores. This is the app's core claim, and it is wrong for most users.
- **Fix:** Remove the view. CPU data must come from the hardware catalog (`HARDWARE_DATA_AUDIT.md`), with live core counts read from `sysctl`/`ProcessInfo`.
- **Verify:** Snapshot tests across catalog fixtures, plus a unit test that the CPU section is derived from the resolved device record.
- **Scope:** Rewrite (trivial in isolation, but it belongs to the catalog rewrite).

#### CB-02 · The identifier-to-model mapping is wrong for most entries
- **Confidence:** High. The correct mapping is cross-checked in `HARDWARE_DATA_AUDIT.md` §2.
- **Where:**
  - `getDetailedDeviceModel()` L412-441
  - `GPUInfo.getInfo` L43-143
  - `ScreenInfo.ppi` / `physicalSize` L808-830
  - `CameraInfo.getInfo` L1004-1101
  - `ContentView.processorInfo` L1286-1325
- **Evidence:**
  - Of the 20 identifiers mapped, 11 are wrong and 2 do not exist (`iPhone16,3`, `iPhone16,4`).
  - Only `iPhone17,1-4`, `iPhone16,1`, `iPhone14,7` and `iPhone14,8` are correct.
  - `iPhone16,2` is labelled "iPhone 15 Plus" (it is the 15 Pro Max).
  - `iPhone15,2/15,3` are labelled 15/15 Plus (they are the 14 Pro/14 Pro Max).
  - `iPhone15,4/15,5` are labelled 15 Pro/Pro Max (they are the 15/15 Plus).
  - `iPhone14,4/14,5` are labelled 14 Pro/Pro Max (they are the 13 mini/13).
  - `iPhone13,1-4` are labelled the iPhone 13 series (they are the iPhone 12 series).
  - The GPU, PPI and camera tables inherit these errors.
- **Impact:** Owners of the iPhone 12, 13, 14 Pro and 15 series see the wrong model name and wrong GPU data.
- **Fix:** Use a single catalog keyed by identifier, populated from verified sources, with fixture tests for every identifier.
- **Verify:** Run table-driven tests that check every catalog identifier against the reference list.
- **Scope:** Rewrite.

#### CB-03 · Unknown devices get fabricated specifications
- **Confidence:** Confirmed.
- **Where:** `default:` branches at L135-142 (GPU "Apple GPU", 4 cores, Metal 3), L1081-1100 (camera "12 MP Main", f/1.8), L817/L828 (458 ppi, 6.1"), L1179-1187 (6-core 2P/4E), L437-439 (model "iPhone"). Memory has a separate fabricated fallback at L294-297.
- **Evidence:**
  - Any identifier not in the tables falls through to the `default:` values above. This covers every iPhone released after September 2024 (16e, 17, 17 Pro/Pro Max, Air, 17e, 18 Pro/Pro Max) and every simulator ID that is not mapped.
  - If `host_statistics64` fails, memory falls back to an invented "25% usage" (L294-297).
- **Impact:** The app shows invented numbers in the same style as verified ones, with no way to tell them apart. As of October 2026, every new iPhone sold gets fabricated data.
- **Fix:** Return an explicit `unknown`/`unavailable` state. For unrecognised identifiers, show the raw identifier, live-measurable values, and a clear "Not in catalog" state.
- **Verify:** Unit test that an unknown identifier yields no catalog-derived fields. UI snapshot of the unknown state.
- **Scope:** Rewrite (part of the domain model).

### P1 — Major correctness, accuracy, architecture

#### CB-04 · Battery card shows "-100%" and missing icons
- **Confidence:** Confirmed. The missing SF Symbols were checked with `NSImage(systemSymbolName:)` on macOS 27.2.
- **Where:** `BatteryMonitor.init` L1222-1226, observers L1240-1252, `BatteryInfo.stateIcon` L167-175, `stateColor` L177-191.
- **Evidence:**
  - `BatteryMonitor` passes `UIDevice.current.batteryLevel` through unchecked. Apple documents this value as `-1.0` when unknown (for example in the Simulator, or before monitoring delivers a value).
  - The only `< 0` guard is in the dead `getCurrentBatteryInfo()`.
  - With a level of `-1`, the card shows `Level: -100%`, colours the icon red, and builds `"battery.-100"`.
  - The probe found that `battery.unknown`, `battery.37` and `battery.-100` do **not exist** as SF Symbols. Only `battery.0/25/50/75/100` and the `…percent` forms exist.
  - So the icon is blank whenever the state is `.unknown`, and whenever the device is unplugged at any level other than 0/25/50/75/100.
- **Impact:** Visible defects on the first card of the first screen.
- **Fix:** Model battery level as `Double?`. Map to `battery.0percent…100percent` buckets, or use `Image(systemName:variableValue:)` (iOS 16+).
- **Verify:** Unit tests for the mapping from level and state to presentation, including `-1`, `0.37` and `.unknown`.
- **Scope:** Incremental (small rewrite of the battery feature).

#### CB-05 · "View battery health" opens an unsupported private URL scheme
- **Confidence:** High.
- **Where:** `BatteryInfoView` L399-408: `URL(string: "App-prefs:")`.
- **Evidence:** `App-prefs:` is not a documented URL scheme. The supported API is `UIApplication.openSettingsURLString`, which opens the app's own settings page, not Battery. See `RESEARCH_SOURCES.md`.
- **Impact:** It may silently do nothing on some OS versions, and it is grounds for App Review rejection. The row also looks like data ("Health: View in Settings") but is actually a button.
- **Fix:** Show a "Not available to apps on iOS" explanation with written instructions. Do not deep-link into Settings.
- **Scope:** Incremental.

#### CB-06 · The network "Speed" figure is not a meaningful measurement and wastes data
- **Confidence:** High.
- **Where:** `NetworkMonitor.startSpeedTimer` L729-734, `measureSpeed` L736-763.
- **Evidence:**
  - Once connected, a 1-second repeating `Timer` downloads `https://www.apple.com/favicon.ico` through `URLSession.shared` (default `URLCache`). It computes `bytes / wall-clock time` and labels the result "Mbps".
  - For a file of a few KB the result is dominated by DNS, TLS and RTT latency. Cached responses inflate it.
  - Failures are silently ignored, so the last value stays on screen.
  - It runs while the app is foregrounded regardless of which tab is visible, and even when "Network Information" is hidden in Settings: the `@StateObject` is owned by `ContentView`.
  - On cellular this is roughly 3,600 requests per hour to apple.com.
  - "Type" shows "Unknown" for Ethernet and other wired interfaces.
  - `CellularInfo` holds a hard-coded carrier and signal strength and is never shown.
- **Impact:** A misleading metric, plus energy and data use and an undisclosed network dependency. This is the app's only network traffic.
- **Fix:** Remove the continuous speed estimate. Keep `NWPathMonitor` for interface, expensive and constrained flags. If throughput testing is wanted later, make it an explicit, user-initiated test against a documented endpoint, with a disclosed data cost (`FEATURE_ROADMAP.md`).
- **Scope:** Rewrite.

#### CB-07 · A 10 Hz memory timer re-renders the whole app and leaks Mach port references
- **Confidence:** Confirmed. The leak was probed on macOS 27.2: 1,000 calls took send urefs from 1 to 1,001. Both platforms use the XNU `host_self_trap`, so iOS is expected to behave the same; this is not yet verified on a device.
- **Where:** `MemoryMonitor.startMonitoring` L1119-1125 (interval `0.1`), `MemoryInfo.getCurrentMemoryInfo` L266.
- **What happens on each tick:**
  - `mach_host_self()` is called and its send right is never released with `mach_port_deallocate`.
  - `@Published memoryInfo` changes. Because `memoryMonitor` is a `@StateObject` of `ContentView`, the **entire 5-tab `ContentView.body`** is re-evaluated.
  - That re-evaluation runs `safeGetDeviceInfo()` (L1440), which calls `uname` + `Mirror` at least 3 times, prints up to 4 debug lines, and builds the camera info only to discard it.
  - It also triggers about 9 JSON decodes of `DisplaySettings` from `UserDefaults` (one per `displaySettings.showX` read, via `CodableAppStorage.wrappedValue`).
- **Impact:**
  - Constant CPU wake-ups and log spam (about 40 lines per second).
  - The port leak grows by about 36,000 references per hour while the app is in the foreground. The ceiling (`MACH_PORT_UREFS_MAX`) is 65,535, after which `mach_host_self` behaviour degrades. **Medium confidence on the exact failure mode.**
- **Fix:** Sample at 1–2 s, only while the memory view is visible. Release the host port. Isolate the sampling in a service so it cannot invalidate unrelated views.
- **Verify:** Instruments (Time Profiler, Energy Log) before and after, and a unit test that the sampler releases ports.
- **Scope:** Rewrite.

#### CB-08 · Settings toggles only work by accident
- **Confidence:** High (from the SwiftUI update model; not runtime-verified because the simulator was unavailable).
- **Where:** `CodableAppStorage` L325-359, used at L1270.
- **Evidence:**
  - The wrapper is a plain `struct` that is neither `DynamicProperty` nor backed by `@State`/`@AppStorage`, so SwiftUI does not observe it.
  - Writes through `$displaySettings` go straight to `UserDefaults`, and nothing triggers a re-render.
  - The UI reflects changes only because CB-07's 10 Hz timer re-renders `ContentView` constantly.
- **Impact:** Fixing CB-07 on its own will appear to break Settings. These two findings must be fixed together.
- **Fix:** Use `@AppStorage` per key, or an observable settings store.
- **Scope:** Rewrite.

#### CB-09 · The theme choice is never restored
- **Confidence:** Confirmed.
- **Where:** `@State private var selectedTheme: AppTheme = .system` L1268; `saveTheme` L1412 writes `"selectedTheme"`. A search for the key finds only the write.
- **Impact:** The theme resets to System on every launch.
- **Note:** `.onChange` is attached twice (L1473 inside the Specs tab, L1625 on the `TabView`), so every change saves twice. These are also the two iOS 16 blockers.
- **Fix:** `@AppStorage("appearance")`.
- **Scope:** Incremental.

#### CB-10 · Display data is captured once and computed from the wrong properties
- **Confidence:** High.
- **Where:** `ContentView.screenInfo` L1376-1385, `ScreenInfo.resolution` L832-836, `ppi` L808, `physicalSize` L821.
- **Evidence:**
  - Resolution is calculated as `bounds × scale`. Apple's `nativeBounds` gives physical pixels directly. `bounds` is in points, depends on orientation, and changes with Display Zoom, so landscape launch or Display Zoom produce a wrong or rotated value.
  - The value is captured once, at `ContentView` initialisation.
  - PPI and physical size come from hard-coded tables with wrong values (see `HARDWARE_DATA_AUDIT.md`) and fabricated defaults.
  - `maximumFramesPerSecond` reports the current cap (for example 60 in Low Power Mode on ProMotion devices), but it is labelled as the panel's "Refresh Rate".
  - `UIScreen.main` is deprecated (`RESEARCH_SOURCES.md`).
- **Fix:** Get the panel specification from the catalog, the live mode from the window's screen (`UIWindowScene.screen`), and label the two separately.
- **Scope:** Rewrite.

#### CB-11 · Storage is a one-time snapshot with undefined semantics
- **Confidence:** High.
- **Where:** `ContentView.storageInfo` L1336-1362, `StorageInfo.usagePercentage` L319.
- **Evidence:**
  - The value is computed once, when the view struct is created.
  - `systemFreeSize` leaves out purgeable space, so the result differs from the Settings app. Apple recommends `volumeAvailableCapacityForImportantUsageKey`.
  - When the read fails, it returns zeros. `usagePercentage` then divides by zero and shows `nan%`.
  - "Total Storage" (the formatted filesystem size, for example "245.1 GB") is shown as though it were the advertised capacity (256 GB).
- **Fix:** Use `URLResourceValues` capacity keys and refresh when the view appears or the app becomes active. Show the advertised capacity only if it can be inferred, labelled as inferred.
- **Scope:** Incremental, inside a new provider.

#### CB-12 · Concurrency is unsafe; Swift 6 mode does not compile
- **Confidence:** Confirmed (build probes, §2).
- **Where:**
  - `UIDevice`/`UIScreen` (main-actor) accessed from nonisolated code: L194-196, L839-845, L1221-1263
  - `NetworkMonitor` captured across queues: L680-693, L753-754
  - Global `processorInfo` initialiser: L1149
  - Default property value: L1193
  - Non-Sendable captures in `CodableAppStorage`: L351-354
- **Impact:** These are latent data races. Swift 6 language mode cannot be adopted without restructuring.
- **Fix:** Make providers `@MainActor` where they touch UIKit, `actor` or `Sendable` value types for sampled data, and use async sequences instead of `Timer` and `NotificationCenter` closures.
- **Scope:** Rewrite (falls out of the new architecture).

#### CB-13 · Monolithic structure, no seams for testing or multiple platforms
- **Confidence:** Confirmed.
- **Where:** `ContentView.swift` (1,774 lines, 28 types).
- **Evidence:**
  - Data functions call `UIDevice.modelIdentifier()` directly in at least 9 places, so they cannot be tested.
  - The views import UIKit, CoreTelephony, Darwin and Network.
  - There is no dependency injection, no protocol boundaries, and no separation between models and views.
  - Five independent `switch` tables key on the identifier and contradict each other:
    - `GPUInfo` gives the A18 6 GPU cores (L58-63); `ContentView.processorInfo` gives it 5 (L1300).
    - Chip names differ between "A18" (GPU table) and "A18 Bionic" (CPU tables).
  - Nothing can be compiled for macOS (`UIDevice`, `UIScreen`, `UIApplication` and `CoreTelephony` are used unconditionally).
- **Scope:** Rewrite (see `MULTIPLATFORM_ARCHITECTURE.md`).

#### CB-14 · Project configuration blocks reliable builds by others and CI
- **Confidence:** Confirmed.
- **Evidence:**
  - There are no shared schemes. `xcodebuild -list` auto-generated one, but a CI build should not rely on that.
  - Per-user `xcuserdata` (`zachary`) is committed, and there is no `.gitignore`.
  - The app and test targets use different `DEVELOPMENT_TEAM`s (`LSYVL36ZN3` vs `8QU4WRDSA4`).
  - Test bundle IDs are still the template's `com.example.*`.
  - There is no privacy manifest, even though the app uses required-reason APIs (`UserDefaults`; disk-space via `systemFreeSize`). This matters only for App Store submission, but the README links to an App Store listing.
  - There is no CI.
- **Scope:** Incremental (Phase 0 in `IMPLEMENTATION_PLAN.md`; needs approval because it touches project and signing configuration).

### P2 — Maintainability, performance, UX, testing

| ID | Finding | Where | Confidence | Fix | Scope |
|---|---|---|---|---|---|
| CB-15 | 17 `print("DEBUG …")` calls ship in Release builds; several run inside `body` (L1392-1408, L1470) and so fire at 10 Hz; they log hardware identifiers | L41, 136, 414, 438, 1002, 1082, 1341-1359, 1392-1408, 1470-1471, 1622-1623 | Confirmed | `os.Logger` with categories, `.debug` level, privacy annotations | Incremental |
| CB-16 | 0 % meaningful test coverage; the only tests are templates | `SpecMatrixTests`, `SpecMatrixUITests` | Confirmed | `TESTING_STRATEGY.md` | Rewrite |
| CB-17 | "Used RAM" = system-wide `active + wired` pages; the definition is not shown; it is labelled as if it were the app's or the user's usage. The total uses `physicalMemory` with `.memory` (binary) formatting, so an 8 GB device shows ≈ "7.5 GB" next to marketing figures | L259-298, L554-556 | High | Separate "Installed RAM (catalog)", "Visible to OS (`physicalMemory`)", "This app's footprint" (`phys_footprint`), and "Available to this app" (`os_proc_available_memory`); drop system-wide page counts on iOS (see detection matrix) | Rewrite |
| CB-18 | The header shows `UIDevice.current.model` ("iPhone"), not the resolved model | L1431 | Confirmed | Use the resolved product name | Incremental |
| CB-19 | Accessibility: theme rows use `onTapGesture`, so they have no button trait and are not announced as selectable; 60 pt decorative symbols are not hidden from VoiceOver; the brightness bar has no accessibility value; battery state relies on colour; the fixed `.system(size: 60)` ignores Dynamic Type | L1640-1655, L1422-1425, L887-900 | High | Use `Picker`/`Button`, `.accessibilityHidden`, `ProgressView`/`Gauge` with a value, text alongside colour | Rewrite with design system |
| CB-20 | No localisation; `String(format: "%.1f%%")` ignores locale; spacing is inconsistent (`"120Hz"`); `LOCALIZATION_PREFERS_STRING_CATALOGS=YES` but there is no catalog | throughout | Confirmed | String Catalog, `FormatStyle`/`Measurement` | Rewrite |
| CB-21 | `NavigationView` is deprecated (iOS 16) | `SettingsView` L1637 | Confirmed | `NavigationStack` | Incremental |
| CB-22 | Hiding sections in Settings blanks entire tabs (Network, Display, Camera show "Hidden — enable in Settings"). This is a confusing information architecture | L1496-1517, L1540-1559, L1582-1602 | High (UX judgement) | Remove per-section hiding, or replace it with dashboard customisation (`FEATURE_ROADMAP.md`) | Rewrite |
| CB-23 | App icon dark and tinted variants are copies of the light icon, so the tinted Home Screen will render poorly; filenames are `Untitled design (2)*.png`; there is no Icon Composer (layered) icon for 26+ | `AppIcon.appiconset` | Confirmed (identical SHA-1) | Commission proper variants and an Icon Composer `.icon` | Design work |
| CB-24 | README makes claims the code does not support ("Battery Health: Monitor battery status and performance", "Monitor network speed", "Compiled assets catalog (Assets.car)"), recommends paid third-party certificate services (KravaSign), and links an App Store listing (`id6740110428`) whose current status could not be checked | `README.md` | Confirmed (claims vs code) | Rewrite the README after the modernisation | Docs |
| CB-25 | The in-app GitHub links point to `github.com/Belligerently/SpecMatrix`; the remote is `github.com/SpecMatrix-App/SpecMatrix` | L1706, L1730 | Confirmed | Centralise URLs in configuration | Incremental |

### P3 — Polish

| ID | Finding | Where |
|---|---|---|
| CB-26 | `CameraInfoView` uses its own `HStack` rows rather than `InfoRow`, so its typography is inconsistent | L967-977 |
| CB-27 | Camera "Resolution" packs three lenses into one newline-separated string, and "Aperture" puts three apertures in a separate row, so lenses and apertures are not paired | L1009-1010 |
| CB-28 | Forced unwraps of literal URLs (L737, L1706, L1718, L1730); safe in practice, but avoidable with static constants | — |
| CB-29 | `Spacer()` inside a `ScrollView` `VStack` has no effect | L1466 |

---

## 4. Subsystem dispositions

| Subsystem | Current symbols | Disposition | Reasoning |
|---|---|---|---|
| App entry | `SpecMatrixApp` | **Retain → Refactor** | Trivial and correct; it will gain a macOS scene, commands, and environment injection |
| Identifier acquisition | `UIDevice.modelIdentifier()` | **Improve** | The `uname` + `SIMULATOR_MODEL_IDENTIFIER` approach is the standard public technique and is sound. Consolidate it into one provider, add `sysctlbyname("hw.model")` for macOS, and remove the duplicate at L444 |
| Hardware data tables | `getDetailedDeviceModel`, `GPUInfo.getInfo`, `ProcessorInfo`, `ContentView.processorInfo`, `ScreenInfo.ppi/physicalSize`, `CameraInfo.getInfo` | **Remove → Rewrite as catalog** | Five contradictory tables, mostly wrong, with fabricated defaults (CB-01–03, CB-13) |
| CPU view | `CPUInfoView` | **Rewrite** | Fully hard-coded (CB-01) |
| Battery | `BatteryInfo`, `BatteryMonitor`, `BatteryInfoView` | **Refactor** | The notification-based approach is fine; the invalid-value handling, icons and health row must change (CB-04, CB-05) |
| Memory | `MemoryInfo`, `MemoryMonitor` | **Rewrite** | 10 Hz timer, port leak, undefined semantics (CB-07, CB-17) |
| Storage | `StorageInfo`, inline closure | **Improve** | The Foundation API family is right; it needs the correct key, a refresh policy, and empty and error states (CB-11) |
| Network | `NetworkInfo`, `NetworkMonitor` | **Rewrite** | Keep `NWPathMonitor` and remove the speed loop and fake cellular data (CB-06) |
| Display | `ScreenInfo`, `BrightnessMonitor`, `ScreenInfoView` | **Rewrite** | Wrong properties, captured once, table-based (CB-10); the brightness observer pattern can be reused |
| Camera | `CameraInfo` | **Rewrite** | Static and mostly wrong; replace with catalog plus `AVCaptureDevice.DiscoverySession` facts |
| Settings & persistence | `DisplaySettings`, `CodableAppStorage`, `SettingsView` | **Rewrite** | Not observed by SwiftUI (CB-08); the theme is not restored (CB-09) |
| `InfoRow` | `InfoRow` | **Retain (concept)** | The label/value row is the right primitive; rebuild it in the design system with accessibility and provenance badges |
| Tests | templates | **Rewrite** | Nothing to keep |
| Project & config | `.pbxproj` | **Refactor** | Keep the single project; add shared schemes, `.gitignore`, a consistent team, real bundle IDs, macOS support, and a local package (see `TECHNICAL_DECISIONS.md` TD-02) |
| Assets | `AppIcon` | **Investigate** | Proper dark, tinted and macOS icons are a design deliverable |

### Risks of retaining versus replacing

- **Retaining** keeps a product that shows wrong data to most users and cannot compile for macOS or Swift 6. Every new iPhone release widens the gap, because the tables have to be edited by hand.
- **Replacing** is cheap. The app is about 1,800 lines with no persisted user data worth migrating; the only data are two `UserDefaults` keys: `displaySettings` (JSON) and `selectedTheme`, which is never read. The main risk is losing behaviours users rely on. The feature inventory in §1.2 and `FEATURE_AND_DETECTION_MATRIX.md` is the regression checklist.
