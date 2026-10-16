# SpecMatrixKit

The shared foundation for SpecMatrix: device-information models, provenance, the hardware catalog,
platform providers, and observable state. It supports iOS/iPadOS 17+ and macOS 13+, and it compiles in
Swift 6 language mode. The app target links the single product `SpecMatrixKit`.

## Modules

| Target | Depends on | Responsibility | May import |
|---|---|---|---|
| `SpecMatrixCore` | — | Values, units, provenance, models, catalog schema, validation and lookup, pure calculations, provider protocols, formatting | Foundation only |
| `SpecMatrixPlatform` | Core | Live providers that read the running system | UIKit, IOKit, Metal, Network, Darwin |
| `SpecMatrixState` | Core | `DeviceInfoStore` (`ObservableObject`): refresh scheduling, observer lifetimes, published state | Foundation, Combine |

Dependency rules:
- State and the UI depend on the provider **protocols** in Core, never on `SpecMatrixPlatform`.
- Only the app's composition root (`SpecMatrix/Foundation/AppEnvironment.swift`) creates live providers.
- Platform-specific code stays inside `SpecMatrixPlatform`, behind `#if os(...)`.

## Provenance

Every value is a `SpecValue<Value>`:

| Case | Meaning |
|---|---|
| `.measured(value, MeasurementSource)` | Read from a supported API. The source names the API and records `device` or `simulator`. |
| `.catalog(value, CatalogReference)` | From a validated catalog entry. The reference names the entry, catalog version, verification status, and source URLs. |
| `.unavailable(UnavailableReason)` | Not exposed by the platform, not supported by the hardware, not meaningful in the Simulator, or not implemented yet. |
| `.unknown(String)` | Cannot be determined reliably, for example an identifier missing from the catalog or an out-of-range API value. |
| `.error(SpecError)` | A supported read was attempted and failed. |

Rules:
- No placeholders: never `0`, `-1`, `NaN`, a stale value, or another model's specification.
- Measured and catalog values are kept in separate types (`DeviceReport.hardware` vs the readings).
- In the Simulator, values that would describe the host Mac (core counts, RAM, GPU, battery) are
  `.unavailable(.simulator)`.

Quantities use validated unit types:
- `ByteCount`: non-negative bytes.
- `UnitFraction`: finite, in 0…1.
- `RefreshRate`: hertz.
- `DisplayDiagonal`: inches.
- `PixelDensity`: pixels per inch.
- `PixelDimensions`: portrait orientation.
- `CalendarDate`: `YYYY-MM-DD`.

## Data sources

| Reading | API | Notes |
|---|---|---|
| Hardware identifier | `uname().machine` (iOS), `SIMULATOR_MODEL_IDENTIFIER` (Simulator), `sysctl hw.model` (macOS) | Format-validated only; product data comes from the catalog |
| OS name / version / build | `UIDevice.systemName`, `ProcessInfo.operatingSystemVersion`, `sysctl kern.osversion` | |
| CPU | `ProcessInfo.processorCount` / `activeProcessorCount`, `sysctl hw.nperflevels`, `hw.perflevelN.physicalcpu_max` | Whether the iOS sandbox allows the perf-level sysctls has not been checked on a device; failures surface as `.error` |
| Memory | `ProcessInfo.physicalMemory`, `task_info(TASK_VM_INFO).phys_footprint`, `os_proc_available_memory()` (iOS only) | No system-wide "used RAM" |
| GPU | `MTLDevice.name`, `supportsFamily(.metal3)`, `recommendedMaxWorkingSetSize` | GPU core counts are catalog-only |
| Storage | `volumeTotalCapacityKey`, `volumeAvailableCapacityForImportantUsageKey` | "Available" includes purgeable space (matches Settings) |
| Battery | `UIDevice.batteryLevel` / `batteryState` (iOS), `IOPSCopyPowerSourcesInfo` (macOS) | iOS rounds to 5 % steps; no health or cycle count |
| Thermal / Low Power Mode | `ProcessInfo.thermalState`, `isLowPowerModeEnabled` | |
| Display (iOS) | The window scene's `UIScreen`: `nativeBounds`, `nativeScale`, `maximumFramesPerSecond`, `brightness` | Max fps is the *current* cap; macOS display is not implemented yet |
| Network | `NWPathMonitor` | `satisfied` means a route exists, not that the Internet is reachable. No network requests are made. |

Not provided, because no supported public API exists:
- system-wide CPU or GPU utilisation on iOS;
- temperatures;
- iOS battery health or cycle count;
- carrier name;
- iOS Wi-Fi details.

## Catalog (schema version 1)

The bundled file is `Sources/SpecMatrixCore/Resources/DeviceCatalog.json`. Each entry has:
- **Required:** `id` (lowercase slug), `identifiers`, `family`, `marketingName`, `sources`, and `verification`.
- **Optional:** `releaseDate`, `chip` (`name` plus core counts), and `display` (`diagonalInches`, `pixelWidth`/`pixelHeight` in portrait, `pixelsPerInch`, `maximumRefreshRateHz`).

Validation (`CatalogDecoder`) is all-or-nothing and reports every issue it finds:
- The schema version must be 1.
- Unknown keys are rejected.
- Values must have the right JSON types.
- Numbers must be positive.
- Dates must be valid `YYYY-MM-DD`.
- Source URLs must be HTTPS.
- Identifiers must be well-formed and unique.
- A field that is absent means "not recorded" and resolves to `.unknown`.

Lookup is an exact identifier match. An unknown identifier resolves every catalog field to `.unknown`;
nothing is copied from another model.

A `verified` entry means:
- every specification comes from Apple's published technical specifications;
- the identifier mapping is confirmed by at least two independent references.

The current catalog (2026.10.0) is a deliberately small seed of eight iPhone 16 and iPhone 17 models,
verified on 2026-10-15. Fields Apple does not publish (iPhone RAM, refresh rate on non-ProMotion models) are omitted.
Expanding the catalog is a later phase. Test fixtures in `Tests/SpecMatrixCoreTests/Fixtures` are synthetic
(`TestPhone…` identifiers) and are never bundled with the app.

## State and concurrency

- `DeviceInfoStore` is `@MainActor`. Providers are `Sendable` and run their UIKit reads through `MainActor.run`.
- There are no timers. Refreshes are triggered by `start()`, by system notifications (battery, thermal,
  Low Power Mode, brightness), or by `refresh()`.
- Concurrent refresh requests are coalesced into at most one follow-up pass.
- Static values (identity, OS, CPU, GPU, physical memory) are read once per store.
- `stop()`, or deallocating the store, cancels its tasks. The stream termination handlers then remove
  notification observers and cancel `NWPathMonitor`.
- `UIDevice.isBatteryMonitoringEnabled` is turned on when power is read and left on, because it is
  process-wide and the legacy UI also uses it.

## Tests

```bash
# macOS: fast; validates the macOS 13 build of every target
swift test --package-path Packages/SpecMatrixKit

# iOS Simulator: run from Packages/SpecMatrixKit (creates an ignored .swiftpm/ folder there)
xcodebuild test -scheme SpecMatrixKit -destination 'platform=iOS Simulator,name=iPhone 17'
```

If `swift` or `xcodebuild` resolves to the Command Line Tools, prefix the command with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
