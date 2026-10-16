# Phase 4 handoff: UI modernization (iPhone)

Last updated: 2026-10-16.

**Status:** all seven parts of the approved plan are implemented. None of the work has been **compiled, tested or visually checked**: CI confirmation is **pending**, and the manual checks in §4 are **deferred**. Not ready for release.

**Commit state:** the work is uncommitted on top of `dd85147` ("CI test fix 2").

Labels used: **done (static)** means the diff and code were inspected; **not run**; **pending**; **deferred**; **owner-reported**.

## 1. Summary

Phase 4 modernized the existing iPhone app's interface. It added no features. The direction is a readable, list-based "instrument panel" in native style:

- inset-grouped lists inside navigation stacks;
- system text styles;
- one set of named status colors;
- the system's own bars and alerts, which get Liquid Glass automatically on iOS 26+;
- glass only on controls, never on content.

**Scope decisions** (owner-approved before implementation):
- UI modernization only.
- iPhone only.
- The five tabs stay: Specs, Network, Display, Camera, Settings.
- The accent stays system blue.
- The per-section hide settings and their behavior are unchanged.
- No changes to CI, tests or project settings.
- No builds, tests or simulator runs during Phase 4.

## 2. Completed parts

All file changes are relative to `dd85147`. "Done (static)" means the diff was inspected against the part's checklist. It does not mean the code compiled or ran.

**Part 1: prominent button style**
- **File:** `SpecMatrix/DesignSystem/PlatformCompatibility.swift`.
- **Change:** adds `specProminentButtonStyle()`, which applies `.buttonStyle(.glassProminent)` on iOS 26+ and `.buttonStyle(.borderedProminent)` on earlier versions, behind one `#available(iOS 26.0, *)`.
- **Comment corrections:**
  - the file header now mentions styles as well as behaviors;
  - `specTabBarMinimizesOnScroll()` now says it *asks* the tab bar to shrink, and notes that this wasn't observed;
  - `specNavigationSubtitle(_:)` now says the subtitle is lost before iOS 26 only while the matching content is hidden.
- **No behavior change** to the two existing wrappers.

**Part 2: hidden-state background and "Show in Settings"**
- **`SpecMatrix/DesignSystem/SpecComponents.swift`:**
  - **Background:** in the hidden state, `SpecScreen` hides the list's own background and draws the grouped background color behind it, because an empty list doesn't draw one. The notice stays centered.
  - **Button:** `HiddenNotice` adds a **Show in Settings** button in `ContentUnavailableView`'s actions. It uses `specProminentButtonStyle()` and the hint "Opens the Settings tab".
  - **Wiring:** the action comes from a new environment value, `showSettingsTab`. If no value is provided, as in previews, the button isn't shown.
- **`SpecMatrix/ContentView.swift`:** the `TabView` sets `.environment(\.showSettingsTab, { selectedTab = 4 })` (tag 4 is Settings).
- **Coverage:** all four hideable tabs (Specs, Network, Display, Camera) build their notice inside that `TabView`. The action only switches tabs. It doesn't change any saved preference, scroll to a toggle, or highlight anything.
- **Unchanged:** the notice text ("… Hidden" / "Enable in Settings") and the hide settings.

**Part 3: Health label contrast**
- **Cause:** the Battery Health row is a `SpecRow` inside a `Button`. The button's tint combined with the label's secondary style and made it pale blue.
- **`SpecComponents.swift`:** `SpecRow` has a new option, `labelIsPrimary` (off by default). When on, the label uses the primary text color (`UIColor.label`), which a button can't tint. Every other row keeps `.secondary`.
- **`SpecMatrix/Screens/SpecsScreen.swift`:** the Health row turns the option on. The value and the ⓘ icon keep the button's accent tint.
- **Unchanged:** the battery logic, the alert (title, written steps, single OK button) and the VoiceOver hint.

**Part 4: concise screen titles**

Only the `title:` passed to `SpecScreen` changed:

| File | Old title | New title |
|---|---|---|
| `SpecsScreen.swift` | "Device Specs" | "Specs" |
| `NetworkScreen.swift` | "Network Status" | "Network" |
| `DisplayScreen.swift` | "Display Information" | "Display" |
| `CameraScreen.swift` | "Camera System" | "Camera" |

Settings is unchanged. Section headers and Settings toggle labels that use the old strings are unchanged.

**Part 5: named status colors**
- **New file:** `SpecMatrix/DesignSystem/SpecColors.swift`, with five adaptive system colors:

  | Name | Color |
  |---|---|
  | `good` | `systemGreen` |
  | `caution` | `systemYellow` |
  | `warning` | `systemOrange` |
  | `critical` | `systemRed` |
  | `neutral` | `secondaryLabel` |

- **Uses:**
  - `BatteryInfo.stateColor` in `ContentView.swift`: unknown level → neutral; charging or full → good; ≤10% → critical; ≤20% → warning; ≤50% → caution. Above 50% is explicitly `Color.accentColor` (system blue), because a normal level isn't a status to call out.
  - `NetworkInfo.statusColor`: connected → good, disconnected → critical.
  - Camera feature checkmarks (`CameraScreen.swift`): good.
  - `SpecSection`'s default header icon: written explicitly as `Color.accentColor`, with a doc note that it's the accent, not a status color.
- **Unchanged:** thresholds, conditions, labels and camera-feature logic. Text styling elsewhere, such as `.secondary` and `.primary` in `FoundationDiagnosticsView` and `SpecRow`, is untouched.

**Part 6: accessibility review**
- **Reviewed statically:**
  - row grouping;
  - header icons;
  - the hidden notice and its button;
  - Settings links;
  - the theme picker and toggles;
  - camera feature labels;
  - the Health row;
  - tab labels.
- **One problem fixed, in `SpecMatrix/Screens/SettingsView.swift`:** the Contact row's email address was forced onto one truncating line beside "Contact". At accessibility text sizes it's far wider than the screen, and this row is the only place it appears. `ExternalLinkLabel` now puts the address on its own line under the title at accessibility sizes, where it can wrap. At standard sizes the layout is the original one, unchanged (15 added lines, none removed).
- **Everything else needed no change.**
- **Noted, not changed:** the Health row's value text "View in Settings" slightly overstates what the button does (it shows instructions). Changing it would be a content rewrite, which was out of scope.

**Part 7: this document**
- **File:** `docs/PHASE4_HANDOFF.md` (new).
- **Not changed:** existing documents, including `docs/PHASE3_HANDOFF.md`.

## 3. Validation and evidence

| Kind | Status |
|---|---|
| Static diff and code inspection | **Done (static)** for each part: files changed, intended lines only, `#available` only in `PlatformCompatibility.swift`, no iOS 27-only APIs (checked against the iOS 27.1 SDK interface for the APIs used), behavior-preserving changes |
| Local builds (`xcodebuild`) | **Not run** |
| Package tests (`swift test`) | **Not run** |
| App unit tests, UI tests, simulator runs | **Not run** |
| Physical-device checks | **Not run** during Phase 4 |
| CI (`.github/workflows/ci.yml`, Xcode 26) | **Pending.** It runs after the owner commits and pushes. Until then, whether Phase 4 compiles is **unconfirmed**. |
| Visual appearance | **Not checked.** All visual checks are deferred (§4). |

**Tests that may be affected but weren't changed:**
- `SpecMatrixUITests/InterfaceUITests.swift` looks for hidden-notice text and section headers that Phase 4 didn't change. It doesn't look up screen titles. The added "Show in Settings" button is new to those screens. These tests haven't been run.
- CI doesn't run UI tests.

**Prior evidence:**
- Phase 3 and 3.5 evidence is in `docs/PHASE3_HANDOFF.md`.
- The last CI success the owner reported was on `dd85147`, before Phase 4.

## 4. Deferred manual checks and known limitations

**Deferred manual checks.** None of these has been done. Each needs a device, or a simulator once the environment is reliable.

1. **VoiceOver on a device:** the rows, the hidden notice and its button, the Health row, the theme picker and toggles, and the Contact and link rows.
2. **Largest Dynamic Type sizes (AX1–AX5):**
   - the concise titles no longer truncating;
   - the stacked Contact row;
   - the hidden-notice button;
   - the Health row.
3. **Status colors** in light, dark and Increase Contrast: battery and network header icons, camera checkmarks.
4. **Hidden state on iOS 26+:** grouped background and the glass prominent button. **On iOS 17–18:** grouped background and the bordered prominent button.
5. **Health row:** label contrast and that the row still reads as a button, in light, dark and Increase Contrast.
6. **Camera screen** with the sourced catalog data. It was never visually reviewed, including long aperture lines such as "ƒ/1.48–4.0, ƒ/2.2, ƒ/2.8".
7. **Physical-device run** of the Phase 4 build. Earlier device evidence is **owner-reported** (the app works on the owner's iPhone 15 running iOS 27.2 Developer Beta and on other iPhones) and predates Phase 4.

**Known limitations:**
- **Tab bar doesn't shrink on scroll (iOS 26+): unresolved.**
  - `specTabBarMinimizesOnScroll()` applies `tabBarMinimizeBehavior(.onScrollDown)` to the `TabView`, but shrinking wasn't observed on the iOS 26.0 simulator. The investigation is in `docs/PHASE3_HANDOFF.md` §F5.
  - Phase 4 left the setting in place and made no fix or workaround.
  - The UI test `testTabBarMinimizesWhileScrollingDown` is marked as an expected failure and hasn't been run in that form.
- **Native iPad support:** deferred until after the macOS version. The app target stays iPhone-only (`TARGETED_DEVICE_FAMILY = 1`).
- **Out-of-date screenshots:** `docs/phase3-evidence/screenshots/` predates Phase 4, and its Camera-tab images predate the sourced camera catalog. They don't show the current titles, hidden state, Health row or colors.
- **Simulators and UI tests on this Mac:** simulators crash or hang and UI tests hang, so local visual and UI validation isn't available (see `docs/PHASE3_HANDOFF.md` §C3).

## 5. Platform and API constraints

- **Minimum OS:** iOS / iPadOS 17 and macOS 13 Ventura (package). The app target's `IPHONEOS_DEPLOYMENT_TARGET` is explicitly `17.0`. The app is iPhone-only, and there is no Mac app target yet.
- **CI compiler:** CI uses Xcode 26 on `macos-26`, while the local machine has Xcode 27.1. Use only APIs available in the iOS 26 SDK; APIs marked iOS 27.0 (for example `toolbarMinimizationBehavior`) won't compile on CI. Phase 4 adds no iOS 27-only API.
- **Version checks:** `SpecMatrix/DesignSystem/PlatformCompatibility.swift` is the only place for `#available` and other availability-sensitive behavior. It holds:
  - `specTabBarMinimizesOnScroll()` (iOS 26);
  - `specNavigationSubtitle(_:)` (iOS 26);
  - `specProminentButtonStyle()` (iOS 26, with the iOS 17–18 fallback).

  Screens call these wrappers and contain no version checks, so each screen has one implementation on every supported OS.
- **Liquid Glass:** applied by the system to tab bars, navigation bars, alerts and pickers, plus `.glassProminent` on the hidden-notice button through the wrapper. There's no custom glass on content.

## 6. Release readiness

- **Implementation:** all seven parts of the approved plan are implemented.
- **Before it counts as complete:** CI must pass on the pushed changes, and the deferred manual checks in §4 must be done or explicitly accepted.
- **Release:** SpecMatrix 2.0 is **not** release-ready and has not been released. Release preparation is a separate, unstarted task.
