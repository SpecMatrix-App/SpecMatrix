# SpecMatrix for Mac: Phase 2 handoff (core application)

Date: 2026-10-16.

**Status:**
- **Implemented, uncommitted.**
- **Compilation not verified:** no build was authorized for this phase. Phase 1 built only the placeholder app.
- **Not run or inspected:** no tests and no launch. Nothing here has been checked visually.

Builds on `docs/MACOS_PLAN.md` (§0 for Phase 1).

**Scope mapping:** the plan has no stage called "Phase 2". This phase covers:
- the parts of **M2** (Mac catalog) and **M3** (Mac detection) that the dashboard needs;
- the dashboard part of **M6** (implementation).

It is not covered by a separate M5 design document.

## 1. What was implemented

### The app (`SpecMatrixMac/SpecMatrixMac/`)

| File | Contents |
|---|---|
| `SpecMatrixMacApp.swift` | A single `Window("SpecMatrix", id: "main")` (macOS 13), default size 960×640, minimum 720×460. View ▸ Refresh (⌘R). |
| `ContentView.swift` | `NavigationSplitView`: sidebar with Overview, Processor, Graphics, Memory, Storage, Battery, Displays. Grouped `Form` detail with the model name as the window subtitle. Refresh toolbar button. A loading state ("Reading this Mac…") until the first snapshot. Starts the store on appear and stops it on disappear. |
| `SectionViews.swift` | One pane per section (details in §3); a footer in every pane explains the badges and shows the time of the last reading. |
| `SpecValueRow.swift` | `SpecValueRow`: label, value and a source badge, with a tooltip giving the API or catalog citation, or the reason a value is missing. Also `ProvenanceText` and `MacFormat` for units and formatting. |
| `MacInfoStore.swift` | `@MainActor ObservableObject` (`@Observable` requires macOS 14). See §4. |
| `PlaceholderView.swift` | Removed. It was the uncommitted Phase 1 placeholder. |

### Package (`Packages/SpecMatrixKit`)

| Target | Contents |
|---|---|
| `SpecMatrixMacCatalog` (new) | `MacCatalog`, `MacCatalogEntry`, `MacChipSpecification`, `MacDisplaySpecification`; exact lookup; `reference(for:field:)` for citations; `MacCatalogDecoder` (all-or-nothing validation, rules in its doc comment); `Resources/MacCatalog.json` |
| `SpecMatrixMacPlatform` (new) | Readers: `MacStaticReader`, `MacRuntimeReader`, `MacBatteryReader` with a testable `MacBatteryMapping`, `MacDisplayReader` (`@MainActor`), `MacSysctl`. Reading models in `MacReadings.swift`. `MacSpecificationResolver`, which combines detection with the catalog. Framework code is under `#if os(macOS)`. |
| `SpecMatrixShared` | Gained, moved unchanged from `SpecMatrixCore`: `SpecValue`, `CatalogReference`, `CatalogVerificationStatus`, `CatalogField`, `CatalogSourceLocation`, `CatalogSource`, `CatalogIssue`, `CatalogLoadError`, `BatteryChargeState`, `ThermalLevel` |
| `SpecMatrixMacKit` product | `SpecMatrixShared`, `SpecMatrixMacCatalog`, `SpecMatrixMacPlatform` |
| `SpecMatrixMacTests` (new) | Bundled catalog (counts, `Mac14,2`, Mac-only identifiers, exact lookup); decoder rules (schema version, iPhone identifiers, `cameras` attribution, portrait resolution, unknown fields); resolver (matching chip, mismatched chip, configuration-dependent values, uncatalogued model, catalog failure, chip-name matching); battery mapping. **Not run.** |

## 2. Architectural decisions and deviations

1. **The Phase 1 `SpecValue` blocker is resolved by moving the catalog-citation types unchanged**, rather than through the plan's option (a).
   - **Why it's safe:** the Mac catalog uses the same attribution groups as the iPhone/iPad catalog: identifiers, marketingName, releaseDate, chip, display. `cameras` is the only iPhone-only group, and `MacCatalogDecoder` rejects it.
   - **What iOS sees:** every moved type is public with no internal members, and `SpecMatrixCore` re-exports `SpecMatrixShared`. So no iOS source, test or API changed. Each move was checked line by line against `HEAD` (identical apart from import lines).
2. **No shared `sysctl` helper.** `SpecMatrixMacPlatform` has its own `MacSysctl` (about 30 lines). The existing helper lives in `SpecMatrixPlatform`, which belongs to the iOS product. Moving it would need `package` access visible through a re-export to a `@testable` iOS test (`PlatformMappingTests` uses `CString`), which can't be confirmed without compiling.
3. **The existing `SpecMatrixPlatform` macOS branches are not reused.** They are shaped for the iOS report (`DeviceReport`, single display, level and state only) and depend on `SpecMatrixCore`. The Mac battery mapping is new: it adds the power source and time estimate, and `PowerSourceDescription` makes it testable without IOKit.
4. **The store lives in the app**, not in a `SpecMatrixMacState` package target. It holds only UI-facing lifecycle code; the logic worth testing (resolver, battery mapping, catalog) is in the package.
5. **No Settings scene and no menu bar extra.** Neither was assigned to this phase.

## 3. Data shown, its sources and provenance

**Badges:**
- **Detected:** read from macOS.
- **Catalog:** the published specification for this exact model, from `MacCatalog.json`.

Missing values read "Not available" (`.unavailable`), "Unknown" (`.unknown`) or "Error" (`.error`), with the reason in the tooltip.

| Pane | Detected (API) | Catalog | Notes |
|---|---|---|---|
| Overview | Model identifier (`sysctl hw.model`); chip (`machdep.cpu.brand_string`); Apple silicon (`hw.optional.arm64`); memory (`ProcessInfo.physicalMemory`); macOS version and build (`ProcessInfo`, `kern.osversion`); thermal state; Low Power Mode | Model name | Shows a warning row if the catalog fails to load |
| Processor | Chip; CPU cores (`ProcessInfo.processorCount`); one row per cluster with macOS's own name (`hw.perflevelN.name`, `.physicalcpu_max`) | Chip in the catalog; Neural Engine cores | |
| Graphics | GPU name, unified memory, Metal 3 support, recommended working set (Metal) | GPU cores | |
| Memory | Installed memory (binary units, `SpecFormat.memory`) | — | |
| Storage | Volume name, capacity, available for important usage, used fraction (`URLResourceValues` on the home volume) | — | Decimal units (`SpecFormat.storage`). Only the startup disk. |
| Battery | Charge, state, power source, time remaining (`IOPSCopyPowerSourcesInfo` public keys) | — | Desktops show "This Mac has no internal battery." |
| Displays | Per display: name, built-in, resolution of the current mode (`CGDisplayCopyDisplayMode`), "looks like" points (`NSScreen.frame`), scale, maximum refresh rate, physical size (`CGDisplayScreenSize`, from EDID), EDR headroom | For the built-in display: published size, resolution, pixel density, refresh rate | |

**Catalog rules** (in `MacSpecificationResolver`):
- **Chip-specific values** (GPU cores, Neural Engine cores) are shown only when the catalog's chip equals the chip macOS reports, ignoring only the "Apple " prefix.
- **On a mismatch** they are "Unknown" with an explanation.
- **Values the catalog doesn't record** are "Unknown". A value isn't recorded when it differs between configurations of one identifier (for example the MacBook Air M2's 8- or 10-core GPU).
- **Uncatalogued identifiers** show all catalog values as "Unknown". Nothing is borrowed from another model.

### Mac catalog (`MacCatalog.json`, schema 1, version 2026.10.0)

- **Contents:** the 44 `family: "Mac"` records (58 identifiers) from `DeviceCatalog.json` 2026.10.3, **copied without new research**.
- **Transformations:** `family` is removed, and display resolution is stored landscape.
- **Check:** a script confirmed 0 differences from the source records apart from these two changes, all identifiers unique and Mac-prefixed, and attribution groups limited to identifiers, marketingName, chip and display.
- **Unchanged:** sources, accessed dates and verification (all `verified`, 2026-10-15). No iPhone or iPad records are included. `DeviceCatalog.json` is unchanged.
- **Not re-run:** `verify_catalog_sources.py` against Apple's pages for the Mac file. It has no Mac mode yet; that is later M2 work.
- **No configuration model:** the schema can't yet describe several hardware configurations per identifier. Where Apple groups chips ("M4 Pro or M4 Max"), the entry records no chip, so the app shows the detected chip and "Unknown" for chip-specific catalog values.

### Unavailable or not shown, and why

- **Serial number:** never read (owner decision).
- **Battery cycle count:** not a public power-source key. **Battery health:** a public key exists, but it was not approved for this phase.
- **CPU/GPU temperatures, fan speeds, frequencies, power:** no public API.
- **GPU core count and Neural Engine cores:** no public API; catalog only, under the rules above.
- **Marketing name:** no public API; catalog only.
- **Other volumes, Wi-Fi details, Bluetooth, network information:** out of scope. The app makes no network requests.
- **Display physical size:** depends on EDID and may be missing or approximate for external displays. It's labeled "Size (reported by the display)" and shown next to the published size for the built-in display.

## 4. Monitoring and lifecycle (`MacInfoStore`)

- **Static values** (identity, chip, clusters, memory, GPU, macOS) are read once, off the main actor (`Task.detached`).
- **Runtime values** (thermal state, Low Power Mode, storage, battery, displays) are re-read:
  - when `ProcessInfo.thermalStateDidChangeNotification`, `.NSProcessInfoPowerStateDidChange` or `NSApplication.didChangeScreenParametersNotification` is posted;
  - every 60 seconds while the window is open, because macOS posts no simple notification for battery level;
  - on ⌘R or the toolbar button.
- **Displays** are read on the main actor (`NSScreen`).
- **Coalescing:** a request made during a refresh schedules exactly one more (the same pattern as the iOS `DeviceInfoStore`).
- **Observer lifetime:** observers capture the store weakly and are removed on `stop()` (`onDisappear`), which also cancels the timer.
- **No `@unchecked Sendable`, `nonisolated(unsafe)` or `assumeIsolated`.**

## 5. Static checks performed (no compilation)

- **Syntax:** `swiftc -parse` on every new or changed Swift file (app, Mac package targets, Mac tests, `SpecMatrixShared`, changed Core files): all pass.
- **Manifest:** `swift package dump-package`: `SpecMatrixMacKit` = Shared, MacCatalog, MacPlatform. The Mac targets depend only on `SpecMatrixShared` / `SpecMatrixMacCatalog`, and `SpecMatrixKit` is unchanged.
- **Data:** `MacCatalog.json` is valid JSON and matches its source records.
- **Imports:** Mac code imports only SwiftUI, AppKit, Combine, CoreGraphics, Darwin, Foundation, IOKit.ps, Metal and the Shared/Mac modules. It doesn't use UIKit, `SpecMatrixCore`, `SpecMatrixPlatform`, `SpecMatrixState` or `DeviceCatalog`.
- **Safety searches:** no serial-number access, IORegistry/IOService, `dlopen`/`dlsym`, selector tricks, SMC/powermetrics, network APIs, `@unchecked Sendable` or unsafe isolation. The matches were all comments or user-facing text.
- **macOS 13 review** against SDK availability annotations: `Window`, `defaultSize`, `NavigationSplitView`, `navigationSplitViewColumnWidth`, `LabeledContent`, `.formStyle(.grouped)`, `Task.sleep(for:)`, `Duration` unit formatting and `MTLGPUFamily.metal3` are macOS 13. Everything else used is macOS 12 or earlier.
- **Fix made during review:** `Text.foregroundStyle` (returns `Text`) is macOS 14, so `Text` values use `foregroundColor` instead; view-level `foregroundStyle` (macOS 12) is not used on `Text`.
- **Unchanged:** `.github/`, the iOS app, iOS tests, the iOS catalog, `SpecMatrixPlatform`, `SpecMatrixState` and the catalog scripts. The only change in `SpecMatrix.xcodeproj` is the owner's earlier, unrelated edit.
- **Whitespace:** `git diff --check` is clean, and new files have no trailing whitespace.

## 6. Not done or not verified

- **Compilation:** not compiled, so it's **unverified** for the package (including the moved types, as seen by the iOS targets and tests), the Mac app and the Mac tests. Type errors are possible.
- **Tests:** `SpecMatrixMacTests` and the existing package tests were not run.
- **App:** not launched; no visual, VoiceOver or text-size inspection; no Reduce Transparency or Increase Contrast check.
- **Sandbox behavior:** not checked at runtime (`IOPS`, `sysctl`, Metal, `NSScreen`, home-volume capacity are expected to work sandboxed per `docs/audit/TECHNICAL_DECISIONS.md` TD-07).
- **macOS 13:** no test machine.
- **CI:** pushing **will compile and run the new Mac package targets and `SpecMatrixMacTests`** in the existing `swift test` step on `macos-26`. That step is shared with the iOS job, so a compile error in Mac package code would turn the iOS CI red. CI doesn't build the Mac app project.

**Recommended next steps, in order, once authorized (no simulator needed):**
1. `swift build --package-path Packages/SpecMatrixKit`, then `swift test --package-path Packages/SpecMatrixKit` (native macOS).
2. `xcodebuild build -project SpecMatrixMac/SpecMatrixMac.xcodeproj -scheme SpecMatrixMac -destination 'platform=macOS,arch=arm64'`, then launch and inspect each pane on this Mac (MacBook Air M2, `Mac14,2`).
3. The existing iOS generic-simulator `build-for-testing` (compile only).

## 7. Later-phase work

- **M2:**
  - a Mac mode for `verify_catalog_sources.py` and a re-verification of `MacCatalog.json`;
  - a configuration model (multiple chips or GPU options per identifier) with detection-based selection;
  - catalog coverage review, including release dates (none recorded).
- **M3:**
  - multiple volumes (sandbox to verify);
  - network path and Wi-Fi (permissions);
  - battery health (public key; needs approval);
  - an `IOPSNotificationCreateRunLoopSource`-based battery change feed in place of the 60-second refresh.
- **M4:** a Mac CI job and link-isolation check (approval needed).
- **M5/M6:** an interface design review, a Settings scene, a menu bar extra (TD-12), Liquid Glass on macOS 26+, and the app-menu name (`CFBundleName` is "SpecMatrix-Mac").
- **M7/M8:** validation on Apple silicon Macs and macOS 13, then signing, notarization and distribution.
