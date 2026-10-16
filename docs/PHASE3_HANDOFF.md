# Phase 3 handoff: Liquid Glass and iOS UI modernization

Last updated: 2026-10-16, after Phase 3.5 (validation). Nothing is committed.

**Status: partially validated.** Phase 3 is **not complete**. The modernized UI builds, every hosted app test passes on iOS 17.0, 18.0, 26.0 and 27.0 simulators, and the screenshots have been reviewed. These remain open:

- UI interaction tests run on iOS 26 only.
- Physical-device testing is limited to install and launch.
- Tab-bar minimization was not observed.
- Four owner decisions are pending (§7).

Labels used below: **passed**, **failed**, **blocked**, **not run**, **not available**.

## 1. Environment (2026-10-16)

| Item | Value |
|---|---|
| Xcode | 27.0 (27A266a), iOS 27.0 SDK. Commands use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Without it, `xcode-select -p` points at `/Library/Developer/CommandLineTools` and `xcrun simctl` is not found. |
| Simulator runtimes | iOS 17.0 (21A328), 18.0 (22A3351), 26.0 (23A343), 27.0 (24A434) |
| Physical devices | **Zachary's iPhone 15 Pro** (iPhone16,1, iOS 27.2, Developer Mode on): used. "Marc's iPhone 18 Pro" is also paired but was **not used**, because it isn't the owner's device. |
| Scheme / targets | Scheme `SpecMatrix`; targets `SpecMatrix`, `SpecMatrixTests` (hosted, Swift Testing) and `SpecMatrixUITests` (XCTest). Package scheme `SpecMatrixKit`. |
| Deployment targets | App: `$(RECOMMENDED_IPHONEOS_DEPLOYMENT_TARGET)`, which resolves to **17.0**. Both test targets: **18.2**. Package: iOS 17, macOS 13. **Unchanged.** |

## 2. Results

### Builds

| Build | Result |
|---|---|
| Baseline, before Phase 3.5 changes (`build-for-testing`, iOS 27 simulator) | **Passed**, no compiler warnings |
| Final, after fixes (`build-for-testing`, iOS 27 simulator) | **Passed**, no compiler warnings. The only warnings are Xcode's `appintentsmetadataprocessor` notices. |
| Device build (`build`, iPhone 15 Pro, Personal Team `8QU4WRDSA4`) | **Passed** |
| Build with `IPHONEOS_DEPLOYMENT_TARGET=17.0` passed on the command line (for running tests on iOS 17.0/18.0, see §2 note) | **Passed**, no warnings |

### Tests

Per-test results are in `docs/phase3-evidence/test-results.txt`.

| Run | Destination | Result |
|---|---|---|
| `xcodebuild test-without-building -only-testing:SpecMatrixTests` | iPhone 17, **iOS 27.0** | **Passed**, 14/14 test functions (the snapshot test's 3 variants each passed). The first attempt was **blocked** by an environmental simulator failure ("Simulator device failed to launch … No such process"). It passed on the one allowed retry after `simctl shutdown all`. |
| same | iPhone 17 Pro, **iOS 26.0** | **Passed**, 14/14 |
| same, with `IPHONEOS_DEPLOYMENT_TARGET=17.0` | iPhone 16 Pro, **iOS 18.0** | **Passed**, 14/14 |
| same, with `IPHONEOS_DEPLOYMENT_TARGET=17.0` | iPhone 15 Pro, **iOS 17.0** | **Passed**, 14/14 |
| `-only-testing:SpecMatrixTests/ScreenSnapshotTests` (adds the hidden-state test) | iPhone 15 Pro, iOS 17.0 | **Passed**, 2/2 |
| `-only-testing:SpecMatrixUITests/SpecMatrixUITestsLaunchTests` and `…/ScreenTourUITests` | iPhone 17 Pro, **iOS 26.0** | **Passed**: `testLaunch` (19 s) and `testScreenTour` (1 min 17 s; taps all five tabs and scrolls each) |
| UI tests | iOS 27.0 | **Blocked**. They fail during runner bootstrap on this Mac; the owner confirmed they do not work. This phase's attempt was stopped by the owner, so it produced no result. |
| UI tests | iOS 17.0 / 18.0 | **Not run** |
| `swift test --package-path Packages/SpecMatrixKit` | macOS host | **Passed**, 114/114 (92 core, 11 platform, 11 state) |
| `xcodebuild test -only-testing:SpecMatrixTests` | iPhone 15 Pro (physical) | **Blocked by signing** before any test ran. The test targets still use `com.zacdevv.SpecMatrixTests` / `…UITests` and team `LSYVL36ZN3`, which has no development certificate on this Mac. See decision 4 in §7. |

**Why the command-line override was needed:** the test targets' 18.2 deployment target rejects iOS 17.0 and 18.0 destinations. Passing `IPHONEOS_DEPLOYMENT_TARGET=17.0` to `xcodebuild` changes only the test bundles in that build: the app already resolves to 17.0, and the package is 17. No project file was changed.

### Hosted test functions (14)

- **Catalog (6):**
  - `bundledCatalogLoadsInsideTheApp`
  - `compositionRootCreatesAnIdleStoreWithoutStartingWork`
  - `liveRefreshProducesAReportWithConsistentProvenance`
  - `legacyScreensShowCatalogValuesForIPhone16_1`
  - `legacyScreensUseTheRightModelForEachIdentifier`
  - `legacyScreensShowUnknownInsteadOfGuessing`
- **Running model (1):** `runningModelResolvesThroughTheBundledCatalog`
- **Interface (3):** `interfaceSymbolsExist`, `batteryLevelText`, `displaySettingsKeepTheirStoredFormat`
- **Behavior (3, new in 3.5):**
  - `settingsChangesReachViewsThatReadThem`
  - `memorySamplesDoNotRedrawOtherSections`
  - `memoryMonitorStillPublishesFrequently`
- **Snapshots:** `renderEveryTab` (light, dark and AX5; only when `TEST_RUNNER_SPECMATRIX_SNAPSHOT_DIR` is set). `renderHiddenNotices` was added in 3.5 and has been run on iOS 17.0 only.

## 3. Behavior changes: verification

**Settings storage (`CodableAppStorage`, `SpecMatrix/ContentView.swift`): passed.**

- It is a `DynamicProperty` backed by `@AppStorage`. The key is still `displaySettings` and the value is still JSON-encoded `DisplaySettings` data in `UserDefaults.standard`.
- `displaySettingsKeepTheirStoredFormat` checks that data written the old way is read back and that writes keep that format.
- `settingsChangesReachViewsThatReadThem` hosts a view that reads the settings, writes them through a separate wrapper (as a Settings toggle does), and confirms the view re-renders with the new value. Nothing else drives redraws, so this would fail with the pre-Phase 3 wrapper.
- No key or format was changed in 3.5.

**Monitor scoping: passed.** `BatteryInfoView`, `MemoryInfoView` and `NetworkScreen` own their monitors.

- `memorySamplesDoNotRedrawOtherSections` shows a sibling section is not re-evaluated over 1 s while the memory monitor ticks.
- `memoryMonitorStillPublishesFrequently` shows the existing 0.1 s sampling is unchanged (at least 5 updates per second).
- **Known difference:** the network monitor now starts when the Network tab is first shown, not at app launch, and memory sampling stops while its section is hidden. Battery refresh was not tested on hardware: the Simulator always reports an unknown level, and battery state could not be changed on the phone.

## 4. Screenshots and visual review

**Locations:**
- `docs/phase3-evidence/screenshots/rendered-ios{17,18,26,27}/`: every tab in light, dark and AX5, top and bottom; `hidden-*` (iOS 17 only).
- `docs/phase3-evidence/screenshots/uitest-ios26/`: real-screen captures from the running app.

All are JPEG, at most 1000 px tall.

**How they were made:** the "rendered" images draw the real `ContentView` into a window in the hosted test (`drawHierarchy`). They show layout and styling but are not screen captures; for example, there is no status bar. Only `uitest-ios26` shows the real screen with Liquid Glass composited by the system.

**Review summary (all images opened and inspected):**

- **Pass:**
  - Native inset-grouped lists and large titles on all four OS versions, in light and dark.
  - No clipping or overlap at standard text size.
  - Multi-line camera values wrap and align.
  - Safe areas are correct, with content scrolling under the bars.
  - Hidden-section notices are centered and readable (iOS 17).
- **Pass, iOS 17 and 18 fallback:**
  - The standard pre-26 tab and navigation bars.
  - The same layout and order as on iOS 26+.
  - No navigation subtitle, as designed.
- **Pass, iOS 26 and 27:**
  - A floating glass tab bar.
  - The fade at the top edge where content scrolls under the navigation bar.
  - The navigation subtitle showing the model.
- **Fixed in 3.5:**
  1. At AX5, the battery "Health" row overlapped itself. It was a hand-built `HStack`; it now uses `SpecRow` and stacks.
  2. The battery header symbol was red when the level is unknown, as in the Simulator, implying a low battery. It is now secondary gray.
- **Not fixed (system behavior or minor):**
  - Large titles truncate at AX5 ("Camera Sys…"). That is standard UIKit behavior; changing the titles would change copy.
  - Section headers hyphenate at AX5 ("Informa-tion"), also system behavior.
  - The "Health" button label uses the tint at secondary opacity, which gives lower contrast than the old solid blue. This needs a design call.
  - An empty list (hidden state) shows a plain background instead of the grouped gray.
- **Not observed: tab-bar minimization (`tabBarMinimizeBehavior(.onScrollDown)`, iOS 26+).**
  - In the iOS 26 UI tour, the tab bar stayed full size after scrolling down.
  - The cause is **undetermined**: it may be how XCUITest scrolls, or the modifier may not take effect with `.tabItem`-based tabs.
  - It needs a manual check by scrolling on a device or simulator before any code change.
- **Pre-existing data, not caused by Phase 3:** the iPhone 17 and 17 Pro simulators show the camera table's invented fallback values ("12 MP Main, ƒ/1.8"); see decision 3 in §7.

## 5. UI-test setup diagnosis

**Phase 3 symptoms** (iOS 27.0 runtime only installed):
- "Timed out waiting for AX loaded notification";
- a crash in `XCTWaiter handleStalledWait` during bootstrap;
- once, CoreSimulator "Mach error -308 server died";
- Xcode's unchanged template test failed the same way.

**Phase 3.5 evidence:**
- The same UI-test target, scheme and test code passed on the **iOS 26.0** runtime. `xcodebuild` ran them on cloned simulators ("Clone 2/3 of iPhone 17 Pro"), because the scheme marks the UI-test target `parallelizable = YES`.
- Hosted tests launch on all four runtimes.

**Diagnosis:** the project's UI-test configuration works. The blocker is specific to the **iOS 27.0 simulator runtime / Xcode 27 environment** on this Mac, where the runner never finishes bootstrapping. It is not a SpecMatrix startup regression: the app launches in hosted tests on iOS 27 and on the iPhone 15 Pro running iOS 27.2.

Two environmental factors were noted but not proven to be the cause:
- `xcode-select` points at the Command Line Tools;
- Xcode 27 here has no `Simulator.app`; DeviceHub is present.

**Repair:** no repository change was needed or made.

**Remaining action (owner):**
- run UI tests on iOS 26 (or on 27 if a later Xcode or runtime fixes it);
- optionally `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.

## 6. OS compatibility

| OS | Compiles | Launches | Runtime checks | Visual review | Interaction (UI tests) |
|---|---|---|---|---|---|
| iOS 17.0 (simulator) | **Passed** (deployment target 17.0) | **Passed** (hosted tests) | **Passed** (14/14) | **Passed** (rendered) | **Not run** |
| iOS 18.0 (simulator) | **Passed** | **Passed** | **Passed** (14/14) | **Passed** (rendered) | **Not run** |
| iOS 26.0 (simulator) | **Passed** | **Passed** | **Passed** (14/14) | **Passed** (rendered and real screen) | **Passed** (launch and tab tour) |
| iOS 27.0 (simulator) | **Passed** | **Passed** | **Passed** (14/14) | **Passed** (rendered) | **Blocked** (environment) |
| iOS 27.2 (iPhone 15 Pro, physical) | **Passed** (device build, signed `8QU4WRDSA4`) | **Passed** (installed with `devicectl`; the first install failed with "Connection invalid" and the one retry succeeded; launched and still running after 15 s; no SpecMatrix crash logs) | **Blocked** (test signing, decision 4) | **Not run** (no capture method) | **Not run** |

**Availability:** every `#available` check is in `SpecMatrix/DesignSystem/PlatformCompatibility.swift`, and there are only two (`tabBarMinimizeBehavior`, `navigationSubtitle`, both iOS 26.0 in the SDK). A grep finds no other checks in the app. The 17.0 deployment target makes the compiler reject any unguarded newer API.

## 7. Owner decisions needed

Nothing below has been changed.

1. **Remember the theme between launches?**
   - Now: `ContentView` writes the picked theme to `UserDefaults` key `selectedTheme` but never reads it, so every launch starts on "System".
   - Option A: read it on launch (same key and raw-value string).
   - Option B: keep the current behavior and stop writing the unused key.
   - **Depends on the answer:** the `selectedTheme` state in `ContentView.swift`.
2. **The battery "Open Settings" link.**
   - Now: the Battery Health alert's "Open Settings" opens `URL(string: "App-prefs:")`. This URL scheme is not documented by Apple, and it was not tested this phase because the alert couldn't be tapped on a device.
   - Option A: keep it.
   - Option B: use the documented `UIApplication.openSettingsURLString`, which opens SpecMatrix's own page in Settings, not Battery.
   - Option C: remove the button and keep the written steps.
   - **Depends on the answer:** `BatteryInfoView` in `SpecMatrix/Screens/SpecsScreen.swift`.
3. **The camera table.**
   - Now: `CameraInfo.getInfo()` in `ContentView.swift` hardcodes camera specs for `iPhone17,1–17,4` and `iPhone16,1`, plus `iPhone16,3`. That last identifier isn't real: the catalog work found that 16,3 and 16,4 were invented.
   - Every other model gets invented generic values, which appear on the iPhone 17 / 17 Pro simulators.
   - Some of the hardcoded values look inconsistent with Apple's published specs, for example 16 Pro listed with a 12 MP Ultra Wide and 3x telephoto. This was **not re-verified** against apple.com this phase.
   - Option A: keep it.
   - Option B: show "Unknown" for models not in the table.
   - Option C: add sourced camera data to the catalog (a schema change).
   - **Depends on the answer:** `CameraInfo` and `CameraScreen`.
4. **Test-target signing (new, found in 3.5).**
   - Now: `SpecMatrixTests` and `SpecMatrixUITests` use bundle IDs `com.zacdevv.SpecMatrixTests` / `…UITests` and project-level team `LSYVL36ZN3`. There is no certificate for that team on this Mac, so the tests cannot run on the iPhone.
   - Option: move them to `com.zacharyaflalo.specmatrix.Tests` / `.UITests` and team `8QU4WRDSA4`.
   - This is an identity/signing change, so it needs approval.
   - **Depends on the answer:** physical-device test runs.

## 8. What changed

**Phase 3, still current:**

- `SpecMatrix/DesignSystem/PlatformCompatibility.swift`: all OS-version checks.
- `SpecMatrix/DesignSystem/SpecComponents.swift`: `SpecScreen`, `HiddenNotice`, `SpecSection`, `SpecRow`.
- `SpecMatrix/Screens/*`: the five tabs.
- `SpecMatrix/ContentView.swift`:
  - the thin `TabView` shell with `init(initialTab:)`;
  - the observable `CodableAppStorage`;
  - battery symbol and level text fixes;
  - models, monitors and the camera table.
- Tests:
  - `SpecMatrixTests/SpecMatrixTests.swift`: interface tests;
  - `SpecMatrixTests/ScreenSnapshotTests.swift`;
  - `SpecMatrixUITests/ScreenTourUITests.swift`.

**Phase 3.5:**

- `SpecMatrix/DesignSystem/SpecComponents.swift`: `SpecRow` gained `accessorySystemImage` and `isSelectable`, for the Health row fix.
- `SpecMatrix/Screens/SpecsScreen.swift`: the Health button uses `SpecRow`.
- `SpecMatrix/ContentView.swift`: `BatteryInfo.stateColor` returns `.secondary` when the level is unknown.
- `SpecMatrixTests/InterfaceBehaviorTests.swift` (new): the three behavior tests.
- `SpecMatrixTests/ScreenSnapshotTests.swift`: added `renderHiddenNotices`, which restores the stored settings bytes afterwards.
- `docs/phase3-evidence/` (new): screenshots and `test-results.txt`.
- This file.

**Not changed:** the project file, schemes, deployment targets, signing, bundle IDs, CI, the package, and stored data formats.

## 9. Remaining work before Phase 3 is complete

1. **Tab-bar minimization:** check it by hand on iOS 26+ by scrolling a long tab. If it doesn't minimize, investigate before changing code (§4).
2. **Owner decisions:** get answers to §7, then implement the chosen options with tests.
3. **Device tests:** once decision 4 is made, run `xcodebuild test -only-testing:SpecMatrixTests` on the iPhone 15 Pro.
4. **Manual device check:**
   - glass under Reduce Transparency and Increase Contrast;
   - battery states while charging and unplugged;
   - the Battery Health alert and its link;
   - Settings toggles and the hidden notices.
5. **Interaction tests:** add UI tests for hiding a section, Show/Hide All, the theme picker, the battery alert, and the diagnostics push. Run them on iOS 26, and on 17/18 with the deployment override.
6. **Remaining snapshots:** run `renderHiddenNotices` on iOS 26/27 as well.
7. **Design call:** the contrast of the "Health" label.

Reproduce the simulator runs with these commands. Set `DEVELOPER_DIR` first, and add `TEST_RUNNER_SPECMATRIX_SNAPSHOT_DIR=<dir>` for snapshots.

```
xcodebuild -scheme SpecMatrix -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test -only-testing:SpecMatrixTests -only-testing:SpecMatrixUITests
xcodebuild -scheme SpecMatrix -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0' IPHONEOS_DEPLOYMENT_TARGET=17.0 test -only-testing:SpecMatrixTests
```

## 10. Liquid Glass decisions (unchanged)

- **Glass comes from system components**, automatically with the 26+ SDK:
  - the tab bar;
  - navigation bars, with their scroll-edge effect;
  - toolbars;
  - alerts;
  - picker and menu presentation.
- **The only opt-in behavior** is the tab bar shrinking while scrolling (iOS 26+), which wasn't observed (§4).
- **No custom `glassEffect` surfaces.** Content is lists of facts, and glass belongs to controls, not content.
- **Fallback on iOS 17–18:** the standard bars and list styling, with no blur or opacity imitations of glass.

## 11. Phase 4 considerations (not started)

- **The app is iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`). Adding iPad needs owner approval.
- **Navigation:** each tab owns a `NavigationStack` inside `SpecScreen`. For iPad, use `TabView` with `.sidebarAdaptable` (iOS 18+, behind a `PlatformCompatibility` wrapper with a 17 fallback), or `NavigationSplitView`. Keep the five destinations as data.
- **Screens are `List`/`Section`-based**, which adapts to iPad and Mac. Constrain the readable width on wide windows.
- **Keep the availability rule:** OS checks go only in `PlatformCompatibility.swift`.
- **UIKit-only code to route through SpecMatrixKit** (`DeviceInfoStore`) before a Mac build:
  - `UIDevice`;
  - `UIScreen.main` (deprecated in 26);
  - `UIDevice.modelIdentifier()`, used by `CatalogDeviceInfo` and `CameraInfo`.
- **Swift versions:** keep the app target on Swift 5 and SpecMatrixKit on Swift 6. Keep monitors owned by the sections that display them.
- **Custom glass** belongs only on future floating controls: group it in `GlassEffectContainer`, add a `.regularMaterial` fallback in the compatibility file, and use `ToolbarSpacer` (26+) for toolbar groups.
- **Testing:**
  - the test targets' 18.2 deployment target blocks iOS 17/18 test runs without the command-line override;
  - align them with 17.0 when deployment-target changes are approved;
  - resolve decision 4 for device runs.
