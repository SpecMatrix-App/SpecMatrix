# Phase 3 handoff: Liquid Glass and iOS UI modernization

Last updated: 2026-10-16, after the Phase 3.5 finalization (owner-approved changes). Nothing in the
finalization is committed; it starts from commit `5f9ea1a`.

**Status: partially validated. Phase 3 is not complete.** All four approved changes are implemented and
build. The package tests and the camera source check pass, and the theme fix and the new tests were
verified on iOS 27. These remain open:

- The final app-test run across iOS 17, 18, 26 and 27 was **not run**: the owner stopped simulator use because the simulators crash and spike CPU.
- Two UI tests have unverified fixes: the section-toggle test's scroll helper and the tab-bar test's expected-failure marker.
- The iOS 26 tab-bar shrinking is **not working**, cause undetermined (§F5).

Labels used below: **passed**, **failed**, **blocked**, **not run**, **not available**. Sections F1–F7
cover the finalization; §1–§11 below them are the earlier Phase 3.5 validation record, kept for reference.

## F1. Finalization summary

| Approved change | Status | Evidence |
|---|---|---|
| 1. Restore the saved theme on launch | **Implemented and passing** | `savedThemeIsRestored`, `systemMissingAndInvalidThemesFollowTheSystem` and `choosingAThemeStoresItsRawValue` passed on iOS 27; `savedThemeIsRestored` passed on the rerun after its test fix (F2, F6); UI test `testThemeChoiceIsRestoredAfterRelaunch` **passed** on iOS 26 |
| 2. Remove the `App-prefs:` button from the Battery Health alert | **Implemented and passing** | UI test `testBatteryHealthAlertExplainsTheStepsWithoutASettingsLink` **passed** on iOS 26: one OK button, written steps present, no "Open Settings" |
| 3. Sourced camera catalog | **Implemented and passing** | 36 iPhones; verifier 112/112, including every camera value; 5/5 planted errors caught; package tests pass |
| 4. Test-target signing on the Personal Team | **Implemented; device signing verified by build** | Device `build-for-testing` **passed** and signed all three bundles with team `8QU4WRDSA4`. Not run on a device, at the owner's request. |
| 5. Physical-device testing | **Not repeated**, at the owner's request | Owner reports the app works on their iPhone 15 running iOS 27.2 Developer Beta and on other iPhones. This is owner-reported, not automated. |

## F2. Theme restoration

- **Implementation:**
  - `ContentView` now reads the theme with `@AppStorage(AppTheme.storageKey)`, using the same key (`selectedTheme`) and format (the raw-value string "Light", "Dark" or "System") the old code wrote.
  - It is read before the first frame, so there is no visible switch from System.
  - A missing or unrecognised value falls back to `.system`.
  - The write-only `saveTheme` / `onChange` pair was removed, so there is one source of truth.
  - `ContentView(initialTab:preferences:)` takes an injectable `UserDefaults` for tests.
- **Tests:**
  - Hosted, all **passed** on iOS 27:
    - `savedThemeIsRestored`: Dark and Light;
    - `systemMissingAndInvalidThemesFollowTheSystem`: "System", absent, "Purple" and "" under both system appearances;
    - `choosingAThemeStoresItsRawValue`.
  - UI, **passed** on iOS 26: `testThemeChoiceIsRestoredAfterRelaunch` picks Dark, terminates, relaunches and finds Dark selected.
- **Test correction:** the first version of `savedThemeIsRestored` read the test window's trait collection and **failed** for Dark. SwiftUI applies `preferredColorScheme` to the hosting controller's view, not to a test-created window. The test now reads the hosting view and **passed**. This was a test fix, not a product change.

## F3. Battery Health alert

- The "Open Settings" button (`App-prefs:`, an undocumented scheme) is removed.
- The alert keeps its title and written steps ("To view battery health: 1. Open Settings 2. Tap Battery 3. Tap Battery Health"), with a single **OK** (cancel role).
- No other battery behavior changed.
- UI test **passed** on iOS 26: the alert appears from the Health row, shows the steps, has exactly one button, and dismisses.

## F4. Camera catalog

**Audit of the old table** (`CameraInfo.getInfo()` in `ContentView.swift`, now removed):
- **Coverage:** it held only `iPhone17,1`, `17,2`, `17,3`/`17,4` and `iPhone16,1`, plus `iPhone16,3`.
- **`iPhone16,3` is not an Apple identifier.** It is absent from the Xcode simulator profiles, which give iPhone 15 Pro `iPhone16,1` and 15 Pro Max `iPhone16,2`, and from the identifier gist. Checked 2026-10-16.
- **Every other model** got invented generic values ("12 MP Main, ƒ/1.8").
- **Wrong against Apple's pages:**
  - iPhone 16 Pro: 12MP Ultra Wide (Apple: 48MP) and 3x telephoto (Apple: 5x);
  - iPhone 16 and 16 Plus: Ultra Wide ƒ/2.4 (Apple: ƒ/2.2).

**New data:**
- **Where it lives:** an optional `cameras` group in `DeviceCatalog.json`, now **schema 3, catalog 2026.10.3**.
- **Coverage:** all **36 iPhone entries**, iPhone XS / XR through iPhone 18 Pro Max, which is every model the app's iOS 17+ minimum supports.
- **Fields:**
  - each physical rear camera (Apple's name, megapixels, aperture or apertures, telephoto optical zoom);
  - the front camera (name if Apple gives one, megapixels, aperture);
  - per side, the features Apple states (flash / Retina Flash, Night mode, Portrait mode).
- **Sources:** each iPhone's Apple tech-specs page (`support.apple.com/en-us/<id>`, the page each entry already cites, now also supporting `cameras`), accessed 2026-10-16. Field-level attribution is in the JSON; the method is in `Packages/SpecMatrixKit/README.md`.

**Validation:**
- **Decoder rules:** each side has at least one camera; megapixels positive; f-numbers 0.95–22, each listed once; zoom above 1; unique rear camera names; known features; unknown keys rejected; `cameras` must be attributed to a source.
- **`verify_catalog_sources.py`:**
  - checks every camera value inside the right page section;
  - requires each side's feature list to **equal** what the page states;
  - run: **112/112 passed** (with the profile citations pointed at the installed Xcode, see F7);
  - mutation test: **5/5 planted errors caught**, including the old table's two real errors.

**App:**
- `CatalogDeviceInfo` formats the camera screen:
  - "48 MP Main" lines, with zoom appended when the name lacks it ("12 MP Telephoto (2x)");
  - f-numbers as Apple prints them (ƒ/2.0, ƒ/1.78), and a variable aperture as "ƒ/1.48–4.0";
  - "Retina Flash" for the front.
- Any model or side without catalog data shows **Unknown** and no features, never another phone's data.

**Tests:**
- **Package** (`CameraCatalogTests.swift`, 10 test functions), all passing:
  - exact values for 15 Pro, 16 Pro, 16/16 Plus, XS, 18 Pro, SE (3rd generation) and Air;
  - coverage and attribution for all 36 iPhones;
  - `iPhone16,3` and `iPhone16,4` not catalogued;
  - the 11 decoder rule cases;
  - unknown keys and attribution.
- **App:** `camerasForIPhone16_1ComeFromTheCatalog`, `cameraFormatsAcrossModels` and `camerasAreUnknownWithoutCatalogData` **passed** on iOS 27.

**Remaining unknowns:**
- Only what the screen shows is recorded: no focal lengths, video specs or crop "telephotos".
- iPad and Mac cameras are not recorded.
- iPhone models older than the XS are out of scope, because they can't run iOS 17.

## F5. Tab bar on iOS 26+

**Not working; cause undetermined.**

**Evidence** (iOS 26.0 simulator, iPhone 17 Pro, UI test `testTabBarMinimizesWhileScrollingDown`):
- **The gesture scrolls:** a slow, held drag on the list scrolled it by more than a screen, and the large title collapsed into the inline title (screenshot).
- **The bar didn't change:** its frame was (0, 791, 402×83) before and after, the Network tab stayed tappable, and the screenshot shows the full bar.
- **The setting is applied:** `tabBarMinimizeBehavior(.onScrollDown)` is applied to the `TabView` on the iOS 26 path.

**What was ruled out:**
- **The gesture:** see above.
- **The `.tabItem` vs `Tab` API:** a temporary switch to the iOS 18 `Tab` API made no difference. It was reverted, and `ContentView.swift` was restored byte for byte.

**Conclusion:** this is either system or simulator behavior the app can't control through this API, or a cause I haven't found. No workaround or private API was added.

**Test:** the UI test is marked `XCTExpectFailure` with this explanation, so it will flag itself if the bar starts shrinking. That version of the test has **not been run**.

## F6. Test results (finalization)

| Run | Destination | Result |
|---|---|---|
| `swift test --package-path Packages/SpecMatrixKit` | macOS | **Passed**, 124/124 (core 102, platform 11, state 11) |
| `verify_catalog_sources.py` | network | **Passed**, 112/112 (with the profile citations rewritten to the installed Xcode 27.1 in a scratch copy, see F7) |
| Hosted app tests, run 01 | iPhone 17, iOS 27.0 | 18 passed, **1 failed** (`savedThemeIsRestored`, a test bug, see F2), 2 skipped (snapshot tests, by design) |
| `savedThemeIsRestored` after the test fix | iPhone 17, iOS 27.0 | **Passed** |
| UI tests (`InterfaceUITests`), run 04 | iPhone 17 Pro, iOS 26.0 | 3 **passed** (Hide/Show All, theme relaunch, battery alert); 2 **failed**: the section-toggle test (scroll helper couldn't reach a row near the top; helper fixed, **not run**) and the tab bar (F5; now an expected failure, **not run**) |
| Full UI target re-run (run 06) | iOS 26.0 | **Stopped** by the owner: UI runs hang. No results. |
| Hosted app tests on iOS 17.0, 18.0, 26.0, and the final run on 27.0 | — | **Not run**: the owner stopped simulator use (crashes, CPU spikes) |
| Device `build-for-testing -allowProvisioningUpdates` | generic iOS | **Passed**: app, test bundle and UI runner signed by `8QU4WRDSA4` |
| Final `build-for-testing` | generic iOS Simulator | **Passed**, 0 errors, no compiler warnings |

**Screenshots:** none were reviewed for the new camera screen. The snapshot run was not done (see the row above). The iOS 26 UI-test screenshots (Network hidden, Camera hidden, Dark selected and after relaunch, Battery Health alert, before and after scrolling) were exported and the tab-bar pair reviewed (F5). They were not copied into `docs/phase3-evidence/`.

## F7. Environment changes noticed

- **Xcode is now 27.1 (27A9275).** The catalog's identifier sources cite the Xcode 27.0 simulator profiles, so the verifier reports those profile checks as not done.
  - On 2026-10-16 all 68 cited profiles listed exactly the catalogued identifiers under 27.1.
  - The citations were not rewritten.
- **Test signing:** Xcode's signed-in team is "Zachary Aflalo (Personal Team)", `8QU4WRDSA4`, a free provisioning team. It holds one development certificate.

## F8. Files changed in the finalization

- **Package:**
  - `Catalog/CatalogEntry.swift`: the camera types and `CatalogField.cameras`;
  - `Catalog/CatalogDecoder.swift`: schema 3, camera decoding and rules;
  - `Catalog/DeviceCatalog.swift`: `supportedSchemaVersion = 3`;
  - `Resources/DeviceCatalog.json`: cameras for 36 iPhones; version 2026.10.3; iPhone Apple sources dated 2026-10-16;
  - `Scripts/verify_catalog_sources.py`: camera checks;
  - `README.md`: the camera schema, sources, rules and limitations;
  - tests: the new `CameraCatalogTests.swift`; fixtures and expectations moved to schema 3; catalog version 2026.10.3.
- **App:**
  - `ContentView.swift`: theme via `@AppStorage`; the camera table removed;
  - `Foundation/CatalogDeviceInfo.swift`: camera summaries;
  - `Screens/CameraScreen.swift`: reads the catalog;
  - `Screens/SpecsScreen.swift`: alert button removed.
- **Project:** `project.pbxproj`, test targets only: `DEVELOPMENT_TEAM = 8QU4WRDSA4` and bundle IDs `com.zacharyaflalo.specmatrix.Tests` / `.UITests`. The app target, deployment targets and the project-level team are unchanged.
- **Tests:**
  - `SpecMatrixTests/SpecMatrixTests.swift`: the camera tests;
  - `SpecMatrixTests/InterfaceBehaviorTests.swift`: the theme tests;
  - new `SpecMatrixUITests/InterfaceUITests.swift`.

## F9. Remaining work before Phase 3 is complete

1. **Hosted app tests:** run `xcodebuild … test -only-testing:SpecMatrixTests` on iOS 17.0, 18.0 and 26.0 (17/18 with `IPHONEOS_DEPLOYMENT_TARGET=17.0`), and again on 27.0 after the final edits.
2. **UI tests:** run `SpecMatrixUITests/InterfaceUITests` on iOS 26 to confirm the helper fix and the expected-failure marker. Skip `SpecMatrixUITestsLaunchTests` and `ScreenTourUITests`; the launch test runs once per appearance and orientation and is what hangs.
3. **Camera screen snapshots:** render and review them with `TEST_RUNNER_SPECMATRIX_SNAPSHOT_DIR`.
4. **Tab bar:** decide whether shrinking is still wanted. If it is, check it by hand on a device; otherwise remove `specTabBarMinimizesOnScroll()` and its test.
5. **Design call:** the contrast of the "Health" label, still open from Phase 3.5.

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

## 7. Owner decisions (resolved; see F1–F4)

The owner approved theme restoration, removing the button, a sourced camera catalog and the test signing. The text below is the original question record.

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

## 9. Remaining work before Phase 3 is complete (superseded by F9)

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
- **The only opt-in behavior** is the tab bar shrinking while scrolling (iOS 26+), which doesn't take effect (F5).
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
- **Catalog:** schema 3 with `cameras`. An iPad build would need iPad camera data, which isn't recorded.
- **Testing:**
  - the test targets' 18.2 deployment target blocks iOS 17/18 test runs without the command-line override;
  - align them with 17.0 when deployment-target changes are approved;
  - resolve decision 4 for device runs.
