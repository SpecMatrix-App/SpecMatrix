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
| `.catalog(value, CatalogReference)` | From a validated catalog entry. The reference names the entry, catalog version, verification status, and the sources attributed to that value's field. |
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

## Catalog (schema version 2)

The bundled file is `Sources/SpecMatrixCore/Resources/DeviceCatalog.json`. The current version is
**2026.10.1**, and every entry was checked against its sources on 2026-10-15.

### Coverage

The catalog covers every iPhone and iPad that supports iOS 17 / iPadOS 17 (the app's minimum),
plus later models. It is **not** a list of every Apple device: Macs, older iPhones and iPads, and
other device types are not catalogued.

| Family | Models | Identifiers | Range |
|---|---|---|---|
| iPhone | 36 | 38 | iPhone XS, XS Max, XR (2018) → iPhone 18 Pro, 18 Pro Max |
| iPad | 6 | 12 | iPad (6th generation) → iPad (A16) |
| iPad mini | 3 | 6 | iPad mini (5th generation) → iPad mini (A17 Pro) |
| iPad Air | 9 | 18 | iPad Air (3rd generation) → iPad Air 13-inch (M4) |
| iPad Pro | 14 | 36 | iPad Pro (10.5-inch) → iPad Pro 13-inch (M5) |
| Mac | 0 | 0 | Not catalogued yet |
| **Total** | **68** | **110** | All 68 entries are `verified` |

How many entries record each field:

| Field | iPhone (36) | iPad (32) | Why fields are missing |
|---|---|---|---|
| Chip name | 36 | 32 | |
| Performance cores | 30 | 13 | Not published for older models; varies with storage on M4/M5 iPad Pro; called "super cores" on A20 Pro and M5 |
| Efficiency cores | 32 | 17 | Not published for older models |
| GPU cores | 32 | 19 | Not published for iPhone 11 Pro and 12 Pro models, or most iPads before 2021 |
| Neural Engine cores | 32 | 19 | Not published for older models; "Dual 16-core" on A20 Pro is ambiguous |
| Display diagonal, resolution, pixel density | 36 | 32 | |
| Maximum refresh rate | 14 | 4 | Recorded only where Apple states a rate ("up to 120Hz"). Pages for older ProMotion iPads say "ProMotion technology" without a rate. Non-ProMotion models publish no rate. |
| Release date | 11 | 0 | Recorded only where an Apple Newsroom article states the in-store date |

Not in the schema, so not recorded: RAM, storage configurations, cameras, and per-SKU variants.
Apple does not publish iPhone RAM. iPad and Mac RAM and core counts vary by configuration under
one identifier.

### Entry format

- **Required:** `id` (lowercase slug), `identifiers`, `family`, `marketingName`, `sources`, `verification`.
- **Optional:** `releaseDate`, `chip` (`name` plus core counts), and `display` (`diagonalInches`,
  `pixelWidth`/`pixelHeight` in portrait, `pixelsPerInch`, `maximumRefreshRateHz`).
- **`diagonalInches`** is the screen measured as a rectangle, as Apple publishes it. For
  rounded-corner screens this is the footnote figure ("measured as a standard rectangular shape, the
  screen is 6.12 inches"), not the marketing size ("6.1-inch"). Newer iPad pages give only the
  rectangle figure, and it is the figure consistent with pixel density.
- **Sources.** Each source has a `title`, an `accessed` date, a `supports` list and one location:
  - **`supports`** names the field groups the source backs: `identifiers`, `marketingName`,
    `releaseDate`, `chip`, `display`.
  - **Location:** an HTTPS `url`, or an `xcodeSimulatorDeviceType` with its `xcodeVersion`.
- **Release date** is the first in-store or availability date stated in Apple's announcement.

### Provenance per value

`HardwareResolver` attaches to each catalog value only the sources attributed to that value's
field group. A GPU core count cites the tech-specs page, not the identifier lists. A
`.catalog` value's `CatalogReference` therefore says exactly which sources back it.

### Sources and research method

| Field group | Source | How it was checked |
|---|---|---|
| Name, chip, display | Apple's tech-specs page for the exact model (`support.apple.com/en-us/<id>`), found through Apple's tech-specs index | Each value matched in the page text |
| Chip (5 older iPhones) | Apple Newsroom launch article, where the tech-specs page gives no core counts | Sentence naming the counts for that model |
| Release date | Apple Newsroom launch article | "in stores" or "availability beginning" sentence, with the article's year |
| Identifiers | (1) Xcode 27.0 (27A266a) Simulator device types, whose `representedModelIdentifiers` Apple ships with Xcode; plus (2) the adamawolf identifier gist and/or EveryMac identifier pages | Exact identifier strings |

Rules applied:
- **No borrowing:** values are never copied between models, even ones sharing a chip name. The same
  chip ships with different GPU core counts; for example, A15 Bionic has 4 GPU cores in iPhone 13
  and 5 in iPhone 13 Pro.
- **Mislabelled references are not cited:** the gist mislabels several iPad Pro generations; for
  example, it calls `iPad8,1` "3rd Gen" when it is the 1st generation. Those rows are not cited, and
  EveryMac pages are used instead.
- **Every variant is included:** an entry's identifiers must equal its simulator profile's set
  exactly. Wi-Fi, cellular and 1 TB variants share an entry only because all their recorded
  values are identical.

`verified` is enforced by the decoder (`CatalogPolicy.apple`):
- every populated specification group has an `apple.com` source;
- identifiers are supported by at least two independent publishers.

Publishers are counted by domain: `apple.com` covers both Apple's pages and Xcode, and the other
publishers are `github.com` and `everymac.com`.

### Validation (`CatalogDecoder`)

Loading is all-or-nothing, and every issue is reported with its JSON path. An invalid catalog
never loads partially.

**Structure**
- The schema version must be 2; version 1 files are rejected.
- Unknown keys and wrong JSON types are rejected, and so are integers too large to represent.
- `catalogVersion` must have the form `YYYY.MM.N`.

**Values**
- Numbers must be positive and dates valid.
- Resolution must be in portrait (width ≤ height), with width and height given together.

**Identity**
- Entry IDs must be unique slugs.
- Identifiers must be well formed and unique across the catalog.
- Each identifier must match the entry's family (an `iPad…` identifier can't sit in an iPhone entry).
- Marketing names must be unique.

**Sources**
- URLs must be HTTPS.
- Each source has exactly one location.
- Xcode sources may support only identifiers.
- No source is cited twice in an entry.
- `supports` values must be known.

**Attribution**
- Every populated field group must be supported by at least one source.
- No source may claim a field group the entry doesn't record.

**Consistency**
- `accessed` dates and `releaseDate` may not be after `verifiedOn`.
- Pixel density must agree with resolution and diagonal within 1 %. Apple's rounding accounts
  for up to about 0.6 %.
- Entries naming the same chip must agree on its Neural Engine core count.

**Verified policy:** as described above.

Lookup is an exact identifier match. An identifier that isn't catalogued (for example `iPhone19,1`,
`iPhone10,1` or `Mac14,2`) resolves every catalog field to `.unknown`; nothing is copied from a
neighbouring model.

### Adding or changing a device

1. **Specifications:** open Apple's tech-specs page for the exact model and copy only the values
   it states. Use the measured-as-rectangle diagonal and record resolution in portrait. Leave out
   anything the page doesn't state, anything ambiguous, and anything that varies by configuration.
2. **Identifiers:** take them from the Xcode Simulator device type's `profile.plist`
   (`representedModelIdentifiers`), and cite at least one web reference that lists every identifier
   under the correct model name.
3. **Sources:** add each source with a `supports` list naming only the field groups it backs.
4. **Dates:** set `accessed` and `verifiedOn` to the day the sources were checked, and bump
   `catalogVersion`.
5. **Check the result** (commands below), then update the counts in
   `BundledCatalogTests.coverageMatchesTheDocumentedCounts` and in this README.

```bash
# Decoder rules and catalog regression tests (offline)
swift test --package-path Packages/SpecMatrixKit

# Re-check every value against the pages and Simulator profiles it cites (network; development only).
# Needs the cited Xcode; with a different Xcode the profile check is reported as not done.
python3 Packages/SpecMatrixKit/Scripts/verify_catalog_sources.py
```

`verify_catalog_sources.py` fetches each cited page. For every value it checks that a source
attributed to that field states it. For every source it checks that the source confirms at least
one of the values it is attributed to. For every identifier it requires two publishers. It is a
development tool, not part of the app or CI.

### Known limitations

- **No device testing:** no catalogued identifier has been confirmed by running SpecMatrix on
  that physical device. The identifiers rest on Apple's simulator profiles plus one or two web
  references. Identifiers that have only one web reference besides Apple's profile:
  - `iPhone11,4` (XS Max): gist only;
  - `iPhone19,2`, `iPhone19,3`, `iPhone19,7` (iPhone 18 Pro / Pro Max): EveryMac only;
  - `iPad17,1`–`iPad17,4` (iPad Pro M5): EveryMac only;
  - `iPad8,1`–`iPad8,4` (iPad Pro 11-inch, 1st generation): EveryMac model pages only;
  - `iPad8,5`–`iPad8,8` (iPad Pro 12.9-inch, 3rd generation): gist only;
  - `iPad7,1`–`iPad7,4`, `iPad8,9`–`iPad8,10`, `iPad13,4`–`iPad13,7`, `iPad16,5`–`iPad16,6`:
    EveryMac only.
- **Pages can change:** Apple's tech-specs pages are not versioned, so a later edit by Apple would
  not be detected until the verifier is run again.
- **Not catalogued:** Macs. Per-configuration CPU and GPU counts under one identifier, and the
  missing macOS display reader, make them a separate piece of work.

Test fixtures in `Tests/SpecMatrixCoreTests/Fixtures` are synthetic (`TestPhone…` identifiers and
`example.*` domains) and are never bundled with the app.

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
# macOS: fast; validates the macOS 13 build of every target. CI runs this step.
swift test --package-path Packages/SpecMatrixKit

# iOS Simulator: run from Packages/SpecMatrixKit (creates an ignored .swiftpm/ folder there)
xcodebuild test -scheme SpecMatrixKit -destination 'platform=iOS Simulator,name=iPhone 17'
```

If `swift` or `xcodebuild` resolves to the Command Line Tools, prefix the command with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
