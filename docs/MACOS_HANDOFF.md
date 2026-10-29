# SpecMatrix for Mac 1.0: development handoff

Date: 2026-10-29. Builds on `docs/MACOS_PLAN.md` (architecture) and `docs/MACOS_PHASE2_HANDOFF.md` (the first dashboard).

## Status at a glance

| Status | Meaning in this document | What it covers |
|---|---|---|
| **Implemented** | Code is written and reviewed by reading. | Everything in §2–§6. |
| **Compiled** | Built without errors or warnings. | The Mac app (`xcodebuild build`, Xcode 27.1, macOS 27.0 SDK, unsigned). The package with its tests (`swift build --build-tests`). Every Mac module and the app sources, type-checked separately against the **macOS 26.5 SDK** with a macOS 13 target (§8). |
| **Tested** | Automated tests were run. | **Nothing.** As instructed, no tests were run, the app was never launched, and no simulator or device was used. The Mac tests were updated and compile, but haven't run. |
| **Verified against sources** | Checked against live published pages. | `MacCatalog.json`: all 44 entries pass `verify_mac_catalog_sources.py` against the Apple and EveryMac pages they cite, fetched on 2026-10-29 (§5). |
| **Unverified** | Not observed at runtime. | All runtime behavior, visual design, accessibility and sandbox behavior (§9). |

**The app is not release-ready.** It compiles, and its catalog is checked against Apple's pages. Nobody has run it, looked at it, or tested it on a second Mac or on macOS 13–15.

Nothing has been committed, pushed, signed, notarized, packaged or published.

## 1. Architecture

These approved decisions are unchanged:
- same repository as the iPhone app;
- an independent Xcode project, `SpecMatrixMac/SpecMatrixMac.xcodeproj`;
- macOS 13.0 minimum and `ARCHS = arm64`;
- Swift 6 language mode;
- version 1.0 (build 1);
- bundle ID `com.zacharyaflalo.specmatrix.mac`;
- App Sandbox and Hardened Runtime enabled;
- no third-party dependencies.

```
SpecMatrixMac/SpecMatrixMac/          the app (SwiftUI; AppKit for appearance, pasteboard, About panel)
Packages/SpecMatrixKit/
  Sources/SpecMatrixShared/           shared primitives (SpecValue, units, citations) — NOT changed in this pass
  Sources/SpecMatrixMacCatalog/       Mac catalog: schema 2, decoder, MacCatalog.json
  Sources/SpecMatrixMacPlatform/      Mac detection, monitors, catalog resolver
  Tests/SpecMatrixMacTests/           Mac catalog, resolver and battery-mapping tests (not run)
  Scripts/verify_mac_catalog_sources.py   Mac catalog source verifier (new)
.github/workflows/mac.yml             Mac CI (new, separate from ci.yml)
```

**Isolation from the iPhone app:**
- The Mac app links only the `SpecMatrixMacKit` product.
- The built bundle contains no `DeviceCatalog.json` and no `SpecMatrixCore`. This was checked on the local build, and the CI workflow checks it too.
- Nothing the iOS app links was changed: `SpecMatrixShared`, `SpecMatrixCore`, `SpecMatrixPlatform` and `SpecMatrixState` are all untouched.
- `SpecMatrix.xcodeproj`, `SpecMatrix/`, the iOS tests, `DeviceCatalog.json`, `verify_catalog_sources.py` and `.github/workflows/ci.yml` are unchanged.

**Data flow:**
1. Readers in `SpecMatrixMacPlatform` return `SpecValue`s. Each is `.measured` (with the API name), `.catalog` (with the citation), `.unavailable`, `.unknown` or `.error`, and every missing value carries its reason.
2. `MacSpecificationResolver` combines the detected identifier, chip name and CPU clusters with the catalog.
3. `MacInfoStore` (`@MainActor ObservableObject`) owns the lifecycle and publishes a `MacSnapshot`, plus the network path, which arrives separately.
4. Views render `SpecValueRow`s, which show the value, a "Detected" or "Catalog" badge, and a tooltip with the source or the reason the value is missing.

**Concurrency** (Swift 6, strict):
- **No escape hatches:** no `@unchecked Sendable`, `nonisolated(unsafe)` or `assumeIsolated`.
- **Off the main actor:** blocking reads (sysctl, Metal, IOKit, volumes, `host_statistics64`) run in `Task.detached`.
- **On the main actor:** `NSScreen` and CoreGraphics display reads.
- **Network path:** `NWPathMonitor` runs on its own queue and hands each change to the main actor as a `Sendable` reading.
- **Power-source changes:** the IOKit C callback, which can't capture context, posts a notification; the store observes it on the main queue.

## 2. Implemented functionality

### Window and navigation
- **Main window** (`Window` scene, macOS 13):
  - `NavigationSplitView` with a grouped sidebar:
    - **This Mac:** Overview;
    - **Hardware:** Processor, Graphics, Memory, Storage, Displays, Battery & Power;
    - **Software:** Network, macOS, Model Record.
  - Not the iPhone's five-tab layout.
  - A "Reading this Mac…" state until the first snapshot arrives.
- **Overview dashboard:**
  - **Header:** model name, plus capsules for identifier, chip, memory and macOS version.
  - **Cards:** one per area, each showing key values with source badges and opening its section.
  - **Gauges:** storage and battery.
  - **Footer:** a badge legend.
- **Sections:** grouped `Form`s of `SpecValueRow`s, each with explanatory footers and the time of the last reading.
- **Model Record:**
  - the catalog entry, its verification status and date;
  - every published chip configuration, with those consistent with this Mac checked;
  - every source, with links that open in the browser.
- **Empty, unavailable and error states:**
  - `SpecStatusView` uses `ContentUnavailableView` on macOS 14+ and an equivalent fallback on 13.
  - Individual values read "Not available", "Unknown" or "Error", with the reason in the tooltip.

### Commands and keyboard
- **App menu:** About SpecMatrix shows the standard About panel, with the name "SpecMatrix", a description and a website link. Settings… (⌘,) is standard.
- **Edit menu:** Copy Hardware Report (⇧⌘C) copies a plain-text report of every value with `[detected]` or `[catalog]`, or the reason it is missing.
- **View menu:**
  - Refresh (⌘R);
  - the first nine visible sections on ⌘1–⌘9;
  - Toggle Sidebar (from `SidebarCommands`).
- **Help menu:** SpecMatrix Website (`https://specmatrix.me`), SpecMatrix on GitHub (`https://github.com/SpecMatrix-App/SpecMatrix`), and Report an Issue (`…/issues`).
- **Toolbar:** Copy Report and Refresh.
- **Copying values:**
  - every value is selectable;
  - each row's context menu offers Copy Value, Copy Label and Value, and Copy Source.
- **Keyboard:** the sidebar list supports arrow-key navigation.

### Settings (`Settings` scene)
- **General:**
  - Appearance (System, Light, Dark), applied app-wide through `NSApp.appearance`, so it also covers Settings and the About panel;
  - Show source badges.
- **Sidebar:** show or hide each section except Overview. A hidden section that is currently selected falls back to Overview, and the ⌘-number shortcuts follow the visible order.
- **About:** version and build, a privacy statement, and Website, Source Code and Report an Issue buttons.
- **Storage:** `@AppStorage` (`UserDefaults.standard`), keys in `AppSettings.swift`. Nothing leaves the Mac.

### Application behavior
- **Closing the window quits the app**, as single-window utilities do.
- **No outbound traffic:**
  - no network requests, analytics, telemetry, tracking or remote services;
  - links open in the user's browser via `openURL` or `NSWorkspace.open`.
- **No new entitlements or permission prompts.**

### Appearance and compatibility (`MacCompatibility.swift`)
Every OS-version check lives in this file:
- **macOS 26+:**
  - **Liquid Glass styles:** content buttons use `.buttonStyle(.glass)`, and the overview header capsules use `.glassEffect(.regular, in: Capsule())`.
  - **System chrome:** the sidebar, toolbar and window adopt Liquid Glass automatically when built with the macOS 26 SDK or later.
  - **Cards:** dashboard cards are content, so they deliberately use a plain grouped fill on every version, following Apple's guidance to reserve glass for controls and navigation.
- **macOS 13–25:** bordered buttons and a quiet capsule fill.
- **macOS 14+:** `ContentUnavailableView`, with a fallback on 13.
- **Package-level checks:**
  - `MTLGPUFamily.metal4` is checked with `#available(macOS 26)`;
  - Apple GPU families are probed by raw value, so the code compiles against SDKs that don't name Apple10 or Apple11.
- **APIs that need macOS 14+:** none. `onChange(of:perform:)` uses the macOS 13 form, and `Text` colors use `foregroundColor`. The macOS 13 type-check (§8) enforces this.

### Accessibility (implemented, not yet tested; §9)
- **VoiceOver:**
  - each value row is one element: the label, then the value followed by "detected" or "from the catalog", with the reason as a hint when the value is missing;
  - badges have labels;
  - decorative images and bars are hidden;
  - dashboard cards are combined into one element with a hint.
- **Text and color:**
  - only semantic system fonts (`.body`, `.headline`, `.title2` and similar), no fixed text sizes;
  - semantic system colors (`labelColor` and similar), so light, dark and Increase Contrast are handled by the system;
  - no information is conveyed by color alone.

## 3. Hardware information: supported and unavailable

Every API below is public. **Detected** values update as listed in the last column.

| Area | Detected (API) | Catalog | Updates |
|---|---|---|---|
| Identity | Model identifier (`sysctl hw.model`); architecture (`uname`); Apple silicon (`hw.optional.arm64`) | Marketing name | Once |
| Processor | Chip (`machdep.cpu.brand_string`); physical and logical cores; per-cluster cores with macOS's names, L1i/L1d/L2 sizes and cores per L2 (`hw.perflevelN.*`) | Chip name, Neural Engine cores; published configurations | Once |
| Graphics | GPU name, unified memory, recommended working set, Apple GPU family, Metal 3, Metal 4 (macOS 26+), ray tracing, largest buffer, threads per threadgroup (Metal) | GPU cores | Once |
| Memory | Installed (`ProcessInfo.physicalMemory`); wired, active, inactive, compressed and free (`host_statistics64`); swap used and size (`sysctl vm.swapusage`) | — | 60 s; every 5 s while the Memory pane is open |
| Storage | Startup disk: name, capacity, available for important usage. Every visible mounted volume: name, format, internal, external or network, mount point, capacity, available, read-only, ejectable (`FileManager.mountedVolumeURLs` with `.skipHiddenVolumes`, `URLResourceValues`) | — | On mount, unmount or rename; 60 s |
| Displays | Per display: name, built-in, main, mirrored, rotation, current resolution, "looks like" points, scale, largest available mode, maximum refresh rate, current-mode refresh rate, color profile, physical size from EDID, EDR headroom (`NSScreen`, CoreGraphics) | Built-in display size, resolution, pixel density, refresh rate | On display-configuration change; 60 s |
| Battery & power | Charge, state, power source, time remaining, health summary and service recommendation (`IOPSCopyPowerSourcesInfo` public keys), adapter wattage (`IOPSCopyExternalPowerAdapterDetails`, the Watts key only), thermal state, Low Power Mode | — | On IOKit power-source change notification; thermal and Low Power notifications; 60 s |
| Network | Path status, interfaces (BSD name and type), expensive, Low Data Mode, IPv4, IPv6, DNS (`NWPathMonitor`) | — | Pushed on every path change |
| macOS | Version, build (`kern.osversion`), Darwin release (`kern.osrelease`) | — | Once |

**Unavailable, and why:**

| Value | Reason |
|---|---|
| Serial number | Owner decision: never read. The power-source dictionary contains `kIOPSHardwareSerialNumberKey`, but the code reads only the specific keys it maps. |
| Battery cycle count, maximum capacity (mAh or %), design capacity | Not public power-source values on Apple silicon. Undocumented `AppleSmartBattery` registry values are excluded (TD-08). |
| CPU/GPU temperatures, fan speeds, frequencies, power draw | Need SMC or `powermetrics`, which means private interfaces or root. |
| GPU core count, Neural Engine cores, marketing name | No public API. These come from the catalog, under the rules in §5. |
| Wi-Fi network name, IP addresses, Bluetooth | SSID needs CoreWLAN plus Location Services and the `network.client` entitlement; Bluetooth needs a permission. IP addresses are deliberately not shown. |
| System uptime | Would be a required-reason API (`systemUptime`) with no matching approved reason for display. It was omitted to keep the privacy manifest honest. |
| RAM type and speed, SSD model and health, display panel model | Not exposed publicly, and not recorded in the catalog. |

## 4. Catalog resolution rules (`MacSpecificationResolver`)

1. **Exact identifier lookup only:**
   - an uncatalogued identifier leaves every catalog value "Unknown", with the reason;
   - nothing is borrowed from a neighboring model.
2. **Narrowing:**
   - **By chip:** the entry's configurations are narrowed to those whose chip equals the detected chip, ignoring only the "Apple " prefix.
   - **By CPU:** they are then narrowed by the detected CPU, either by total cores or by cores per cluster in order, highest performance first. Only cluster counts are compared, never names, because macOS's cluster names (for example "Performance") don't necessarily match Apple's marketing tiers ("super").
   - **Missing fields:** a configuration that doesn't record a value is not excluded on that value.
3. **When nothing matches:** configuration-specific values are "Unknown", and the reason names what macOS reports and what Apple publishes.
4. **Showing a value:** a value is shown as Catalog only when **every** remaining configuration records it and all agree. Otherwise it is "Unknown" with the published options. Example: "Apple sells this configuration of MacBook Air (M2, 2022) with an 8-core or 10-core GPU. macOS does not report which one this Mac has."
5. **Built-in display values:** come from the entry's `display` record. Desktops have none, so these values are "Unknown" with that reason.

## 5. Mac catalog

**Format:** `MacCatalog.json`, schema **2**, catalog version **2026.10.1**.

**Coverage:**
- 44 models and 58 identifiers: MacBook Air 9, MacBook Pro 15, iMac 5, Mac mini 6, Mac Studio 8, Mac Pro 1.
- This is every Apple-silicon Mac from M1 (2020) to the M6 Mac mini.
- Intel Macs are out of scope.

**What changed from the seed (schema 1, copied from `DeviceCatalog.json`):**
- **Configurations replace the chip record:** the single optional `chip` record is replaced by `configurations`. That is 89 configurations, each with chip, CPU cores, CPU clusters (`super`, `performance`, `efficiency`, highest first), GPU cores and Neural Engine cores, transcribed from the Apple tech-specs page each entry cites.
- **Unstated fields are omitted:**
  - the cluster split of an option such as "M4 Max with 16-core CPU", which is stated on some pages but not others;
  - M1 Max Neural Engine cores on the 14-inch 2021 page;
  - the M6's "Dual 16-core Neural Engine", which isn't a single count.
- **Attribution:** `chip` is now attributed to each entry's Apple tech-specs page. Where the seed attributed `chip` to an "Identify your Mac" page, that attribution is kept, because that page ties the identifier to the chip.
- **Dates:** all sources were re-fetched on 2026-10-29, with `accessed` and `verifiedOn` set to 2026-10-29. Every entry is `verified`.
- **Unchanged:** names, identifiers, displays and URLs.

**Identifying the configuration:**
- **16 entries:** a single configuration.
- **18 entries:** for at least one chip, configurations differ only in GPU cores, which macOS doesn't report, so the GPU core count stays "Unknown", with the options named. These entries are:
  - MacBook Air (M1) and the 13-inch M2–M5 models;
  - the M1 iMac (7- or 8-core);
  - every model that sells a Max or Ultra chip with two GPU options;
  - the 10-core M1 Pro in the 14-inch 2021 MacBook Pro.
- **The rest:** told apart by detected CPU cores. Example: the M4 Pro 12-core/16-core GPU versus 14-core/20-core GPU.

**Decoder (`MacCatalogDecoder`, all-or-nothing):**
- the schema 1 rules still apply;
- configurations must be non-empty and distinct;
- clusters must be non-empty, use each type at most once, highest first, and add up to `cpuCores`;
- configurations need `chip` attribution, and `verified` entries need an apple.com source for it.

**Verifier (`Scripts/verify_mac_catalog_sources.py`):**
- **Reuses:** fetching, caching and matching from `verify_catalog_sources.py`, which is not modified.
- **Checks:**
  - landscape resolution;
  - identifiers confirmed by two publishers;
  - each configuration's chip, CPU/GPU pairing (the base configuration or a "Configurable to" option), cluster split and Neural Engine count, against the chip's own section of the Apple page;
  - **completeness:** every CPU/GPU pair the page states for a recorded chip must be recorded, and a stated cluster split or Neural Engine count can't be left out.
- **Result on 2026-10-29:** 44/44 pass.
- **Mutation checks:** each of these deliberate errors is caught:
  - a wrong GPU count;
  - an omitted configuration;
  - a wrong or omitted cluster split;
  - another identifier's chip;
  - a wrong or omitted Neural Engine count;
  - "Dual 16-core" recorded as 16;
  - a mispaired CPU/GPU;
  - a wrong resolution.
- **Not in CI:** it makes network requests.

**Limitations:**
- **Release dates:** none recorded.
- **Memory and storage options:** not recorded. Detected memory is authoritative.
- **The M6 and M5-generation entries** come from pages that existed on the access date. They are checked against those pages, not against hardware.

## 6. Privacy, entitlements, distribution prerequisites

**Sandbox and entitlements:**
- **Sandbox:** on. The only entitlement is the App Sandbox; this pass added none.
- **Sandbox-dependent APIs:**
  - **Earlier audit:** the earlier audit (TD-07) found that `sysctl`, IOKit power sources, Metal, `NSScreen` and `NWPathMonitor` work in the sandbox on macOS 27.2. These weren't re-checked at runtime in this pass.
  - **Unchecked:** whether every mounted volume reports its values inside the sandbox. Volumes that don't show "Unknown" or "Error" per value.
- **Hardened Runtime:** on. With ad-hoc signing, Xcode disables it for local builds, as the build log notes.

**Privacy manifest (`PrivacyInfo.xcprivacy`, bundled):**
- no tracking and no collected data;
- required-reason APIs:
  - disk space `85F4.1` (display to the user);
  - UserDefaults `CA92.1` (the app's own settings).
- Re-check the categories against Apple's current list before any App Store submission. The manifest isn't required for direct distribution.

**Copy Report:** the report contains no serial, user or computer name, addresses or network names. It does include volume names and display names.

**Distribution (not done):**
- **Not done in this pass:** no signing, notarization, DMG, tag or release.
- **Gatekeeper:** a Developer ID-signed, notarized build needs a **paid Apple Developer Program membership**. The current team is a free Personal Team. Without it, downloaded builds are blocked by Gatekeeper until the user overrides them manually. This was not worked around.

## 7. CI (`.github/workflows/mac.yml`, new)

- **Separate:** a separate workflow and job, `mac-build-and-test` on `macos-26`, 30 minutes. `ci.yml` is unchanged, and the two don't depend on each other.
- **Triggers:**
  - pushes to `main` and pull requests that touch `SpecMatrixMac/**`, `Packages/SpecMatrixKit/**` or the workflow;
  - manual dispatch.
- **Steps:**
  1. Show the toolchain.
  2. `swift test --filter SpecMatrixMacTests`, failing if no tests ran.
  3. Unsigned `xcodebuild build` of the Mac app.
  4. Check the bundle: `LSMinimumSystemVersion` is 13.0, version is 1.0, the privacy manifest and `MacCatalog.json` are present, and there is no `DeviceCatalog.json` or `SpecMatrixCore`.
- **Not run yet:** the workflow has never run. Step 4 was run locally against a local build and passed.
- **Overlap with iOS CI:** the existing iOS job's `swift test` step still compiles and runs the Mac package tests, as it did before this pass. A Mac test failure would therefore also fail the iOS workflow. Changing that would mean editing `ci.yml`, which was out of scope.

## 8. Validation performed (2026-10-29, on the development Mac: MacBook Air M2, macOS 27.2, Xcode 27.1)

1. **App build (compile only):**
   - command: `xcodebuild build -project SpecMatrixMac/SpecMatrixMac.xcodeproj -scheme SpecMatrixMac -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`, with `DEVELOPER_DIR` set to Xcode, because `xcode-select` points to the Command Line Tools;
   - result: **BUILD SUCCEEDED**, no Swift errors or warnings.
2. **Package build (compile only):** `swift build --build-tests` for the whole package compiled without errors, including the Mac tests.
3. **macOS 26 SDK type-check:**
   - **Why:** the local Xcode 27.1 SDK is newer than CI's Xcode 26.
   - **How:** `SpecMatrixShared`, `SpecMatrixMacCatalog` and `SpecMatrixMacPlatform` were compiled with `swiftc -emit-module`, and the app sources type-checked, against `/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk` with `-target arm64-apple-macos13.0`.
   - **Result:** all pass with no warnings. This also confirms that nothing newer than macOS 13 is used outside `#available`.
   - **Caveat:** the compiler was Swift 6.4, not CI's Xcode 26 compiler, so the CI run is the definitive check.
4. **Built bundle inspection:**
   - `LSMinimumSystemVersion` 13.0, arm64 only, version 1.0 (1);
   - privacy manifest and Mac catalog present; no iPhone catalog; only system frameworks linked.
5. **Catalog:** the verifier passed 44/44 entries, and the mutation checks were caught (§5).
6. **Static searches:** no serial-number reads, IORegistry access, `dlopen`, selector tricks, SMC, network clients or unsafe-isolation attributes in the Mac code. The only matches are comments or user-facing text.

**Not performed:** test execution, app launch, simulator or device use, UI tests, or any visual check.

## 9. Deferred visual and hardware checks (manual, before 1.0)

1. **Run the tests:** `swift test --package-path Packages/SpecMatrixKit --filter SpecMatrixMacTests`, then let both CI workflows run once.
2. **Launch on the development Mac and inspect every pane:**
   - Is each Detected value plausible against System Information?
   - Does the Mac14,2 entry show two matching configurations, with GPU cores "Unknown"?
   - Does each catalog value's tooltip cite the right pages?
3. **Light and dark appearance:** check System, Light and Dark, and that changing the setting applies immediately to all windows.
4. **macOS 26 or later:** check the Liquid Glass buttons and capsules, and the sidebar and toolbar.
5. **macOS 13, 14 and 15:** check the fallback styles, `SpecStatusView` on 13, and that nothing crashes. No test machine is available.
6. **Accessibility:**
   - VoiceOver: row reading order, dashboard cards, and the Settings tabs;
   - Increase Contrast and Reduce Transparency;
   - full keyboard navigation (Tab, the sidebar arrows, ⌘1–⌘9).
7. **Sandbox behavior:**
   - external and network volumes, and mount or unmount updates;
   - the `NWPathMonitor` status, including Wi-Fi off and Ethernet;
   - battery notifications on charge changes and when unplugging;
   - adapter wattage.
8. **Desktop Mac:** the battery-absent state and the published-display "Unknown" rows.
9. **External displays:** an external display and a mirrored set; check the EDID size and the refresh rates for variable-refresh (ProMotion) displays.
10. **Other Macs and configurations:** at least one M-Pro or M-Max Mac, to confirm that cluster-based configuration matching selects the right entry, and an M5 or later Mac, to confirm that `hw.perflevel` reports the super and efficiency tiers in the expected order.
11. **Idle CPU:** measure the app at idle to confirm that the 60-second refresh and notification-driven updates are light.

## 10. Known limitations

- **App menu name:** the app menu and default menu items read "SpecMatrix-Mac", because `CFBundleName` comes from `PRODUCT_NAME = "SpecMatrix-Mac"`.
  - **Options tried:** both `INFOPLIST_KEY_CFBundleName` and an `INFOPLIST_FILE` merge were tried; Xcode's generated `CFBundleName` wins over both.
  - **Remaining fixes**, each an owner decision:
    - (a) rename `PRODUCT_NAME` to `SpecMatrix`, giving `SpecMatrix.app`; it builds into a different products folder from the iOS app;
    - (b) switch to a hand-maintained Info.plist (`GENERATE_INFOPLIST_FILE = NO`).
  - **Already correct:** the About panel shows "SpecMatrix", via its options.
- **No app icon artwork:** the `AppIcon` set has no images, so a generic icon shows.
- **Memory categories:** these are the kernel's page counts, which differ from Activity Monitor's "Memory Used". The pane says so.
- **`hw.perflevel` names:** shown as macOS reports them. Their mapping to Apple's marketing tiers isn't asserted.
- **Single window:** no menu bar extra (TD-12) and no report export to a file, which would need the user-selected-file entitlement. Copy Report covers sharing.
- **The Phase 2 handoff is superseded** by this document for current behavior.

## 11. Remaining release requirements

1. **Checks:** complete §9, and fix what it finds.
2. **App menu name:** decide on the `CFBundleName` options (§10).
3. **App icon artwork.**
4. **Decide the distribution channel.** For a notarized DMG on GitHub Releases:
   - join the Apple Developer Program;
   - create a Developer ID Application certificate;
   - set the team on the Mac target;
   - archive with Hardened Runtime;
   - notarize with `notarytool` and staple;
   - build the DMG.
   - The release tag should be Mac-specific (for example `mac-v1.0`), so it doesn't collide with iOS 2.0.
5. **Download page and release notes:**
   - state that macOS 13+ and Apple silicon are required, and that Intel Macs are unsupported;
   - restate the privacy summary.
6. **Root README:** optionally add a Mac section. The iPhone README and metadata were deliberately left unchanged in this pass.
7. **Catalog:** re-run `verify_mac_catalog_sources.py` just before release, and add any new Mac models announced since 2026-10-29.
