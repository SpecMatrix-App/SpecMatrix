# SpecMatrix: Multiplatform Architecture

Audit date: 2026-10-15. This document proposes an architecture; nothing has been implemented. Decisions that need approval are cross-referenced to `TECHNICAL_DECISIONS.md` (TD-xx).

## 1. Starting point

- The app is one iOS target, iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), with a deployment target of iOS 18.2.
- All logic lives in `ContentView.swift`, which imports UIKit, CoreTelephony, Network and Darwin directly.
- None of the code compiles for macOS without changes, because UIKit types are used unconditionally.
- No code is structured for reuse (`CODEBASE_AUDIT.md` CB-13).

The architecture below is therefore new. What carries over from the existing app:
- the identifier acquisition technique (`uname` + `SIMULATOR_MODEL_IDENTIFIER`);
- the battery notification pattern;
- the `NWPathMonitor` usage;
- the label/value row concept.

## 2. Target structure options

| Option | Description | Pros | Cons | Verdict |
|---|---|---|---|---|
| **A. One multiplatform app target + local Swift package** | A single app target with iPhone, iPad and Mac destinations. Shared code lives in a local SPM package in the repo (`SpecMatrixKit`) with a few library targets. | One product, one bundle ID family, one scheme. The package's platform-neutral modules can be tested with fast `swift test` on macOS. The Xcode 16+ template direction. | Needs `#if os(macOS)` in the App entry and providers. Per-platform Info.plist keys sit in one target's build settings. | **Recommended** (TD-02) |
| B. Separate iOS and macOS app targets + shared package | Two app targets that both depend on the package. | Clean per-platform settings, entitlements and icons; independent versioning possible. | Duplicated target settings; two schemes; easy to drift. | Fallback if A's per-platform settings become unwieldy. Moving from A to B is cheap because the code lives in the package. |
| C. Mac Catalyst | Run the iPad app on Mac through UIKit for Mac. | Least effort. | Not AppKit-native. The forum reports `AVCaptureDevice.DiscoverySession` lists no devices under Catalyst. iOS-only APIs such as `UIDevice` battery return iPad-style values. Contradicts the "native macOS application" requirement. | **Rejected** |
| D. "Designed for iPad" on Apple silicon Macs | The unmodified iOS app runs on Mac. | Zero effort. | Not native; reports iPad semantics on a Mac. | **Rejected** |
| E. Many SPM modules (10+) | One package per subsystem. | Strict boundaries. | Excessive fragmentation for an app this size. | Rejected: use 4–5 modules |

## 3. Proposed module layout and dependency direction

```
SpecMatrix (app target: iOS + iPadOS + macOS)
 ├─ App/            SpecMatrixApp, composition root, scenes, commands (macOS), menu bar extra
 └─ depends on ↓
SpecMatrixKit (local Swift package, Packages/SpecMatrixKit)
 ├─ SpecCore        Foundation-only. Domain models, units, provenance, formatting rules,
 │                  catalog schema types, identifier resolution logic. No UIKit/AppKit/SwiftUI.
 ├─ SpecCatalog     Bundled catalog resources (JSON) + loader + validator. Depends on SpecCore.
 ├─ SpecProviders   Platform detection: protocols in a shared file, implementations
 │                  under #if os(iOS) / #if os(macOS). Depends on SpecCore.
 ├─ SpecUI          Design system + shared screens + view models (stores).
 │                  Depends on SpecCore only (it receives providers via protocols).
 └─ Tests/          SpecCoreTests, SpecCatalogTests (catalog validation),
                    SpecProvidersTests (with fakes), SpecUITests (view-model + snapshot)
```

**Dependency rule:** `App → {SpecUI, SpecProviders, SpecCatalog} → SpecCore`.
- `SpecUI` never imports `SpecProviders`. It depends on provider **protocols** declared in `SpecCore` (or in a tiny protocol file).
- The App's composition root injects the concrete implementations.

This rule is what keeps hardware detection out of views. It also lets the UI run on deterministic fixture providers in previews and UI tests.

Why no separate modules for networking, persistence or formatting: each is under about 300 lines. Separate modules would add build configuration without any boundary benefit. Persistence is `@AppStorage` plus the bundled catalog. Revisit this only if a remote catalog is added (TD-05).

## 4. Domain model

### 4.1 Static specifications vs runtime measurements

| Category | Type | Examples | Source | Update policy |
|---|---|---|---|---|
| **Identity** | `DeviceIdentity` | identifier `iPhone17,1` / `Mac14,2`; platform; OS version and build; simulator flag; architecture | Public API (`uname`, `sysctl hw.model`, `ProcessInfo.operatingSystemVersion`, `sysctl kern.osversion`) | Once per launch |
| **Specification** | `DeviceSpec`, `ChipSpec`, `DisplaySpec`, `CameraSpec` … | Marketing name, SoC, core counts, GPU cores, panel size/ppi/refresh capability, lens MP/aperture, connectivity | **Catalog** (verified records with sources) | Ships with the app (catalog version) |
| **Capability (queried)** | `QueriedCapability` | Metal GPU families, `recommendedMaxWorkingSetSize`, camera device types present, max photo dimensions, `physicalMemory`, `processorCount`, perf-level core counts | Public API, read once | Once per launch; some on demand |
| **Runtime measurement** | `Measurement<T>` | Battery level/state, thermal state, Low Power Mode, storage free, app footprint, network path, brightness, current max FPS, macOS CPU load | Public API, sampled | Event-driven or periodic, only while visible |

### 4.2 Provenance (applies to every displayed value)

```swift
public enum Provenance: Sendable, Hashable {
    case measured(source: APISource, at: Date)        // read from a public API now
    case queried(source: APISource)                   // public API, static for this launch
    case catalog(recordID: String, catalogVersion: String)  // verified reference data
    case derived(from: [String], rule: String)        // e.g. advertised storage tier inferred from volume size
    case estimated(method: String)                    // used sparingly; must explain itself
}
public enum Availability<Value: Sendable>: Sendable {
    case available(Value, Provenance)
    case unavailable(UnavailableReason)                // .notExposedOnPlatform, .unknownDevice, .permissionDenied, .failed(String)
}
```

Simple values do not get timestamps. `Measurement` adds `at:` only for sampled values. Catalog values reference the record, and the record holds its sources. This satisfies the "value, unit, timestamp, source, confidence, availability" requirement without attaching metadata to every Bool.

### 4.3 Identifier resolution

`DeviceResolver.resolve(identity, catalog) -> ResolvedDevice` is a pure function in `SpecCore`, so it can be tested with fixtures. It returns one of:
- `.known(DeviceSpec)`;
- `.unknownIdentifier(String, platformFamily)`: show the raw identifier plus queried and measured data, with "Not yet in catalog";
- `.simulator(underlying:)`.

It **never** produces a fabricated fallback (fixes CB-03).

## 5. Platform detection providers

| Protocol (SpecCore) | iOS/iPadOS implementation | macOS implementation |
|---|---|---|
| `IdentityProvider` | `uname().machine`; `SIMULATOR_MODEL_IDENTIFIER` in Simulator | `sysctlbyname("hw.model")` (`uname` returns `arm64` on Apple silicon: verified); `kern.osversion` |
| `ChipProvider` (queried) | `hw.nperflevels`, `hw.perflevelN.physicalcpu` (header present in iOS SDK; app-sandbox readability **to verify on device**), `ProcessInfo.processorCount` | Same sysctls (verified in sandbox), `machdep.cpu.brand_string` (verified) |
| `GPUProvider` | `MTLCreateSystemDefaultDevice()`: `name`, `supportsFamily` (`.metal3` iOS 16+, `.metal4` behind `#available(iOS 26, *)`), `recommendedMaxWorkingSetSize` (iOS 16+) | Same. GPU **core count is catalog-only** (the IORegistry `gpu-core-count` is undocumented; TD-08) |
| `MemoryProvider` | `physicalMemory`, `os_proc_available_memory()`, `task_info` `phys_footprint` | `physicalMemory`, `host_statistics64` (memory pressure / used breakdown is meaningful on Mac), `phys_footprint` |
| `PowerProvider` | `UIDevice` battery level (5 % steps since iOS 17) and state via notifications; `thermalState`; `isLowPowerModeEnabled` | `IOPSCopyPowerSourcesInfo` (percent, charging, time remaining; works in sandbox); `thermalState`; `isLowPowerModeEnabled` (macOS 12+). No cycle count via public keys. |
| `StorageProvider` | `volumeTotalCapacityKey`, `volumeAvailableCapacityForImportantUsageKey` | Same, plus enumerating mounted volumes (optional) |
| `DisplayProvider` | `UIWindowScene.screen` (not the deprecated `UIScreen.main`): `nativeBounds`, `nativeScale`, `maximumFramesPerSecond`, `brightness` + notification | `NSScreen.screens`: `localizedName`, `frame`, `backingScaleFactor`, `maximumFramesPerSecond` (12+), EDR headroom; `CGDisplayCopyAllDisplayModes` |
| `CameraProvider` | `AVCaptureDevice.DiscoverySession`: device types, position, `lensAperture`, `videoFieldOfView`, `supportedMaxPhotoDimensions` (16+). No capture session. | DiscoverySession: built-in/external cameras, formats. `lensAperture` is not available on macOS. |
| `NetworkProvider` | `NWPathMonitor` (interface types, expensive, constrained); `serviceCurrentRadioAccessTechnology` (no carrier: `CTCarrier` deprecated with no replacement) | `NWPathMonitor`; optional CoreWLAN RSSI and transmit rate (needs `com.apple.security.network.client` in the sandbox; SSID needs Location) |
| `CPULoadProvider` | **Not offered.** DTS: there is no supported system-wide CPU load API on iOS. Show this app's own CPU only, if anything. | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` deltas (verified in sandbox) |

Each provider is a `Sendable` struct or `actor` exposing `async` reads or `AsyncStream`s. UIKit- and AppKit-touching implementations are `@MainActor`. This resolves the 58 strict-concurrency warnings by construction (CB-12).

### 5.1 Sampling policy

| Value | Policy |
|---|---|
| Identity, chip, GPU, camera, display capability | Once at launch, cached in memory |
| Battery, thermal, Low Power Mode, brightness, network path | Event-driven (notifications / `NWPathMonitor`) |
| Storage | On appear and when `scenePhase` becomes `.active` |
| App memory footprint, macOS CPU load | Every 1–2 s, **only while a Live view is visible** (`.task` modifier: cancelled automatically on disappear) |
| Background | No work. Nothing in the core feature set needs background execution. |

## 6. Universal iPhone/iPad strategy

- **One target and bundle**, with `TARGETED_DEVICE_FAMILY = "1,2"`. iPad needs all orientations and multitasking support. This is the opposite of the current `1`.
- **Shared screens; adaptive composition.** The root picks the layout:
  - Compact width: `TabView` → `NavigationStack`.
  - Regular width: `NavigationSplitView` (iOS 16/17), or `TabView` with `.sidebarAdaptable` (iOS 18+ via the compat layer).
  - Detail screens are identical views.
- **Dashboards** use `Grid` / `LazyVGrid` with an adaptive column count and a readable-width cap. The iPhone column layout is not simply scaled up.
- **Catalog** (Phase 4) uses `Table` on iPad regular width, which collapses to its first column in compact width, and `List` on iPhone.
- **Keyboard and pointer:** `.keyboardShortcut` for Refresh, Search and Export; standard controls provide hover effects.
- **Multitasking:** the app must behave correctly at every Split View and Stage Manager width; test with size-class fixtures in previews.
- **iPad-specific data:** identifier families `iPad*`. Display data comes from the window's scene screen, which matters for Stage Manager with an external display. iPads without cellular have no telephony, so handle a `nil` radio technology. Camera sets differ (LiDAR on Pro).

## 7. Native macOS architecture

- **Entry:** the shared `SpecMatrixApp`, with `#if os(macOS)` adding:
  - `Settings { SettingsView() }`
  - `.commands { SpecCommands() }`: Refresh ⌘R, Export Report ⌘E, Copy Summary ⇧⌘C
  - optionally `MenuBarExtra` (macOS 13+) with live thermal, battery and CPU, off by default (TD-12)
  - `.defaultSize(width: 980, height: 640)` and a minimum frame on the root view
- **Window model:** one main window. A second window type ("Compare") becomes justified only with the Catalog feature.
- **Host vs device:** the Mac shows **the Mac it runs on**: `hw.model` → catalog Mac record, plus Apple silicon vs Intel. Mac-only data (CPU load, memory pressure breakdown, multiple displays, external volumes, power adapter state) are separate sections. Avoid sections that make no sense on a Mac, such as cellular radio, and Mac-irrelevant camera fields.
- **Sandbox:** recommended (TD-07). Entitlements: `app-sandbox`, `network.client` (only if CoreWLAN or update checks are used). Camera entitlement only if capture is ever added (not planned).
- **Architectures:** universal (`arm64 x86_64`) for a minimum of 13–26 (TD-03). On Intel Macs, `hw.model` returns `MacBookPro16,1`-style IDs and there are no perf levels, so the catalog needs Intel Mac records or an explicit "Intel Mac: limited catalog" state.

## 8. API availability strategy

1. **Choose the minimums first** (TD-01). Everything below assumes iOS 17 / macOS 14 is recommended, with iOS 16 / macOS 13 as the costed alternative.
2. **One compat file per module** (`Compat.swift`) owns every `#available`. Screens and providers call `sm…` wrappers. The design-system section shows the pattern.
3. **APIs that differ by minimum:**

| Need | iOS 16 / macOS 13 | iOS 17 / macOS 14 | iOS 18 / macOS 15 | 26+ |
|---|---|---|---|---|
| State observation | `ObservableObject` + `@Published` (or the Point-Free *Perception* back-port, an extra dependency) | `@Observable` | — | — |
| Change handlers | `onChange(of:perform:)` (deprecated in 17; warning only) | `onChange(of:initial:_:)` | — | — |
| Empty states | custom view | `ContentUnavailableView` | — | — |
| Adaptive tabs/sidebar | `NavigationSplitView` / `TabView` switch | same | `Tab` + `.sidebarAdaptable` | glass tab bar automatically |
| Metal 4 family | — | — | — | `.metal4` |
| Glass surfaces | `.regularMaterial` | same | same | `.glassEffect` |
| Inspector panel (Mac/iPad detail) | custom | `.inspector` | — | — |

4. **Build with the newest SDK** (Xcode 27). Back-deploy to the chosen minimums. Never raise a minimum to make one feature easier; gate the feature instead.

## 9. iOS 16 and macOS Ventura compatibility: assessment

| Question | iOS/iPadOS 16 | macOS 13 Ventura |
|---|---|---|
| Can the current toolchain build for it? | **Yes.** Xcode 27 deployment floor is iOS 15 | **Yes.** Floor is macOS 12 |
| Compile blockers in today's code | Only the two `onChange` calls (verified by an override build) | N/A (no macOS code yet) |
| SwiftUI coverage for the planned UI | Good: NavigationStack/SplitView, Charts, Gauge, Grid, Table, ShareLink all exist in 16 | Same: plus MenuBarExtra, Settings |
| Biggest cost | No `@Observable` (use `ObservableObject` everywhere or add a back-port dependency); no `ContentUnavailableView`, `inspector`, `symbolEffect` | Same |
| **Testing** | **Xcode 27 cannot run or debug on iOS 16 devices and has no iOS 16 simulator** (device and simulator support start at iOS 17). Verifying iOS 16 needs a physical iOS 16 device **plus a second Xcode 26.x install**, or debugger-less Ad Hoc/TestFlight installs. | Xcode 27 needs macOS 26.6+. Testing on 13 needs a separate Ventura Mac or VM (Virtualization.framework VMs of macOS 13 on Apple silicon are feasible). |
| Hardware locked to it | iPhone 8/8 Plus/X are capped at iOS 16; iPad 5th gen and iPad Pro 1st gen are capped at iPadOS 16 (to be confirmed against Apple's compatibility lists before final decision) | Macs capped at Ventura: 2017 iMac, 2017 MacBook Pro and others of that era (Intel only) |
| Practical? | **Technically yes, operationally expensive.** | **Practical** if a test Mac or VM is available; requires a universal binary. |

**Recommendation (TD-01): iOS/iPadOS 17 and macOS 14 Sonoma.**
- The deciding reasons are testability with the current toolchain, and the `@Observable`/`onChange` alignment across both platforms. Implementation convenience is not the reason.
- Both minimums support every planned feature.
- If iOS 16 / macOS 13 remain hard requirements, the architecture still works: use `ObservableObject` stores and the compat wrappers above. Budget for a second Xcode and an iOS 16 test device.
- macOS 13 could be kept even with iOS 17, but only if stores avoid `@Observable` on both platforms. Mixing observation systems across platforms is not recommended.

## 10. Liquid Glass integration (summary)

See `DESIGN_SYSTEM_AUDIT.md` §3–4.
- Standard containers adopt glass automatically when built with the 26/27 SDK. `UIDesignRequiresCompatibility` is ignored with the 27 SDK, so adoption is not optional with Xcode 27.
- Custom glass is limited to floating live-status chips and toolbar groups, behind `smSurface`.
- Older OSes get native materials.

## 11. Future Android portability

What makes a later independent Kotlin/Jetpack Compose app cheaper, without compromising the Apple app:

| Asset | Portable form | Notes |
|---|---|---|
| Hardware catalog | **JSON files plus a JSON Schema** (`catalog/schema/*.schema.json`), not Swift literals, plists or Core Data | Android can bundle the same files. Records gain `platform: "android"` and `manufacturer` later. |
| Measurement semantics | `docs/specs/MEASUREMENTS.md`: defines each metric, unit, rounding, and decimal/binary policy | Platform-neutral contract. |
| Provenance vocabulary | The `measured / queried / catalog / derived / estimated / unavailable` enum, documented | Same UX language on both apps. |
| Validation rules | Catalog validator spec (required fields, source URL present, enums); implemented in Swift now, and could become a language-neutral script (e.g. Python in `tools/`) run in CI | |
| Resolver logic | Small and pure (identifier → record). Re-implement natively in Kotlin; document it with test vectors (`catalog/test-vectors.json`) | Shared test vectors are the reuse mechanism, not shared code. |

Not recommended now: Kotlin Multiplatform, Skip, Swift-on-Android, or any shared runtime. Swift code is not reusable by a conventional Kotlin app, and abstracting for an unbuilt product would cost Apple-side quality.
