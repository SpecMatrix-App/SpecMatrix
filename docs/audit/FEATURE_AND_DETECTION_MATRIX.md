# SpecMatrix — Feature & Detection Matrix

Audit date: 2026-10-15. API facts: `research/system_apis_and_toolchain.md`. Device facts: `research/ios_ipad_devices.md`.

**Detection categories:** **A** public API reports the value directly · **B** stable identifier → maintained reference database · **C** calculation from directly available values · **D** estimate/heuristic · **E** third-party dependency · **F** private/unsupported API · **G** not reliably obtainable under platform restrictions.

## 1. Current features and metrics (as implemented)

| # | UI label (screen) | Current implementation (`ContentView.swift`) | Actual source | Category actually used | **Presented as** | Accuracy / confidence | Misrepresentation? | Recommended action | Tests needed |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Header device name (Specs) | `UIDevice.current.model` L1431 | Public API | A | Device name | Always "iPhone" | Generic, not the model | Replace with resolved catalog name (B) | Resolver fixtures |
| 2 | Model (System) | `getDetailedDeviceModel()` L412 | `uname` → hard-coded switch | B (broken) | Exact model | **11 of 20 mappings wrong, 2 phantom; all post-2024 devices → "iPhone"** | Yes: wrong names presented as fact | Catalog (B), unknown state | Table-driven tests over every identifier |
| 3 | iOS (System) | `UIDevice.current.systemVersion` L1371 | Public API | A | OS version | Exact | No (build number missing) | Keep; add build (`kern.osversion`) | Unit (format) |
| 4 | Battery Status | `UIDevice.batteryState` + notifications | Public API | A | State | Exact (if monitoring on) | `.unknown` renders a blank icon (invalid symbol) | Keep source; fix presentation | Mapping unit tests |
| 5 | Battery Level | `UIDevice.batteryLevel` | Public API | A | "NN%" | 5 % steps since iOS 17; **-1 → "-100%"** | Shows -100% when unknown | Keep; `nil` when <0; note the 5 % granularity | Unit tests incl. -1 |
| 6 | Battery Health | Constant "View in Settings" + `App-prefs:` | None / private URL scheme | **F** (URL) / **G** (value) | A data row | No data | Looks like a metric; private API usage | Replace with an "Unavailable on iOS" explanation; on macOS use the public IOPS `Max Capacity` % with clear labelling | Snapshot of unavailable state |
| 7 | "Note: battery level readings are approximate" | Static text | — | — | Disclaimer | Accurate | No | Keep the meaning; explain the 5 % step | — |
| 8 | GPU Name | `GPUInfo.getInfo` switch | Hard-coded | B (broken) + **D** default "Apple GPU" | Exact | Wrong for many models | Yes | `MTLDevice.name` (A) + chip name from catalog (B) | Fixtures; device check |
| 9 | GPU Cores | same | Hard-coded; default **4** | B (broken) / **D** | Exact | iPhone 16 shows 6 (should be 5); unknown → 4 | Yes: fabricated default | Catalog only (no public API: G for live) | Fixtures |
| 10 | Metal Support | constant `true` | Hard-coded | D | Yes/No | Trivially true | Minor | `supportsFamily(.metal3/.metal4/.appleN)` (A) | Device check |
| 11 | CPU Chip / Cores / P / E / GPU / NE (CPU card) | **Literals L497-502** | None | **D (fabricated)** | Exact | **Wrong on every device but the iPhone 15 Pro/Pro Max** | **Yes: severe** | Catalog (B) + live `hw.perflevelN.physicalcpu` / `processorCount` (A) | Fixtures + device check that sysctl matches catalog |
| 12 | Total RAM (Memory) | `ProcessInfo.physicalMemory` | Public API | A | "Total RAM" | Exact bytes visible to the OS; binary formatting | Shown as if it were the marketed capacity | Keep (A), label "visible to system"; optional catalog "installed (unofficial)" | Formatting unit tests |
| 13 | Used RAM / Usage % | `host_statistics64` active+wired, **10 Hz** | Public (but DTS: not meaningful on iOS) | C | App or system "used RAM" | Undefined semantics; fallback **"25 %"** estimate | Yes: unlabeled heuristic + fabricated fallback | iOS: app footprint (`phys_footprint`) + `os_proc_available_memory` (A). macOS: memory breakdown via `host_statistics64` (C) with definitions | Unit tests with fake samplers |
| 14 | Total Storage | `attributesOfFileSystem.systemSize` (once) | Public API | A | "Total Storage" | Volume size (not the advertised tier) | Mild (no explanation) | `volumeTotalCapacityKey` (A); advertised tier as **derived** (C: nearest catalog option ≥ volume size) | Unit tests for the derivation |
| 15 | Used / Available / Usage % | `systemFreeSize` (once) | Public API | A/C | Free space | Excludes purgeable space, so it disagrees with Settings; NaN on failure | Mild | `volumeAvailableCapacityForImportantUsageKey` (A); refresh on activation | Unit tests incl. failure |
| 16 | Network Status / Type | `NWPathMonitor` | Public API | A | Connected / WiFi / Cellular / Unknown | Correct; wired → "Unknown" | Minor | Keep (A); add wired, expensive, constrained | Unit tests with path fixtures |
| 17 | Network "Speed (Mbps)" | 1 Hz GET apple.com/favicon.ico | Own measurement | **D** | Link speed | **Not a speed measurement** (latency-dominated, cache-affected) | **Yes** | Remove. Optional user-initiated throughput test later (feature F-12) | — |
| 18 | Cellular technology / carrier / signal (not displayed) | CoreTelephony + constants | A (RAT) + fabricated (carrier "Cellular", signal 3) | A / D | Not shown | — | Dead code | Keep RAT (A) only; no carrier (`CTCarrier` deprecated, no replacement) | Unit tests |
| 19 | Resolution (Display) | `bounds × scale` from `UIScreen.main` (once) | Public API | C (wrong inputs) | Native resolution | Wrong under Display Zoom / landscape launch | Yes | `nativeBounds` from `windowScene.screen` (A) + catalog native resolution (B) | Device check incl. Display Zoom |
| 20 | Scale Factor / Native Scale | `UIScreen.main.scale/nativeScale` | Public API | A | Exact | Correct | No | Keep, via scene screen | — |
| 21 | Pixel Density (PPI) | Hard-coded; default **458** | Hard-coded | B (broken) / **D** | Exact | Wrong for 16/16 Plus/15 Plus; fabricated default | Yes | Catalog only (B) | Fixtures |
| 22 | Physical Size | Hard-coded; default **6.1″** | Hard-coded | B (broken) / **D** | Exact | 16 Pro / Pro Max wrong; fabricated default | Yes | Catalog only (B) | Fixtures |
| 23 | Refresh Rate | `UIScreen.maximumFramesPerSecond` (once) | Public API | A | Panel refresh rate | Reports the *current cap* (e.g. 60 in Low Power Mode on ProMotion) | Mild | Show "Panel: up to 120 Hz" (B) **and** "Current max: 60 fps (Low Power Mode)" (A) | Device check with LPM |
| 24 | Brightness (bar) | `UIScreen.brightness` + notification | Public API | A | Live % | Correct | No | Keep, via scene screen; accessible gauge | — |
| 25 | Back / Front camera resolution, aperture, features | `CameraInfo.getInfo` switch; default 12 MP f/1.8 | Hard-coded | B (broken) / **D** | Exact | 16 Pro UW/tele wrong; 16 UW aperture wrong; most devices get the fabricated default | Yes | Catalog (B) + present lenses / `lensAperture` / max photo dimensions from `AVCaptureDevice` (A, no capture) | Fixtures; device check |
| 26 | Theme (Settings) | `@State` + write-only UserDefaults | — | — | Persisted preference | **Not restored** | — | `@AppStorage` | UI test relaunch |
| 27 | Show/Hide sections (Settings) | `CodableAppStorage` | UserDefaults | — | Live toggle | Updates only because of the 10 Hz re-render | — | Remove or redesign (dashboard editing) | — |
| 28 | About: author, GitHub, contact, licence | Static `Link`s | — | — | Links | GitHub URL is the old org | — | Keep; central config | — |

**Undocumented behaviours found:** the continuous network traffic to apple.com (#17), the 10 Hz sampling (#13), and logging of the device identifier to the console (CB-15).

## 2. Target detection matrix (what the modernised app should show)

Legend for the presentation column: **Measured** (live, timestamped) · **Queried** (public API, static per launch) · **Catalog** (verified spec, sourced) · **Derived** (shows its rule) · **Unavailable** (with reason).

### 2.1 iOS / iPadOS

| Metric | Source | Cat. | Perm. | Changes at runtime | Cache | Presentation | Unknown hardware | How to test |
|---|---|---|---|---|---|---|---|---|
| Hardware identifier | `uname().machine`; Simulator: `SIMULATOR_MODEL_IDENTIFIER` | A | none | No | Launch | Queried | Shown raw | Unit (parser); device |
| Marketing name, family, release date | Catalog | B | none | No | Bundle | Catalog | "Unknown model (iPhoneXX,Y)" | Fixture tests per identifier |
| SoC name | Catalog | B | none | No | Bundle | Catalog | Unavailable | Fixtures |
| CPU P/E core counts | `hw.perflevel0/1.physicalcpu` (header in iOS SDK; **verify sandbox readability on device**) ↔ catalog | A + B | none | `physicalcpu` can vary with power mode; use `_max` for spec | Launch | Queried (cross-checked against catalog) | Queried values still shown | Device check; unit for parsing |
| Total logical CPUs | `ProcessInfo.processorCount` / `activeProcessorCount` | A | none | active may change | No | Queried | Shown | Unit |
| System-wide CPU usage | — | **G** (DTS: no supported API) | — | — | — | Unavailable ("iOS doesn't let apps see system-wide CPU load") | — | — |
| This app's CPU usage | `task_threads` + `thread_info` | A/C | none | Yes | No | Measured (optional, Live view) | — | Unit with fake |
| GPU name | `MTLDevice.name` | A | none | No | Launch | Queried | Shown | Device |
| GPU core count | Catalog | B (G for live) | none | No | Bundle | Catalog | Unavailable | Fixtures |
| Metal support | `supportsFamily(.metal3)` (16+), `.metal4` (`#available` 26), `.appleN` | A | none | No | Launch | Queried | Shown | Device / simulator (note: the simulator reports host GPU families) |
| GPU working-set size | `recommendedMaxWorkingSetSize` (iOS 16+) | A | none | No | Launch | Queried (with an explanation) | Shown | Device |
| Neural Engine cores | Catalog | B | none | No | Bundle | Catalog | Unavailable | Fixtures |
| RAM visible to OS | `ProcessInfo.physicalMemory` | A | none | No | Launch | Queried | Shown | Unit (formatting) |
| Installed RAM (marketing) | Catalog, **unofficial** | B (secondary) | none | No | Bundle | Catalog + "Unofficial" badge, or omit (TD-06) | Unavailable | Fixtures |
| App memory footprint / headroom | `task_info` `phys_footprint`; `os_proc_available_memory()` | A | none | Yes | No | Measured, 1–2 s while visible | — | Unit with fake |
| Storage capacity / available | `volumeTotalCapacityKey`; `volumeAvailableCapacityForImportantUsageKey` | A | none (privacy-manifest reason **85F4.1** if App Store) | Yes | Refresh on activate | Measured | — | Unit with fake FS |
| Advertised storage tier | nearest catalog option ≥ volume size | C | none | No | Launch | Derived ("≈ 256 GB model") | Hidden | Unit |
| Battery level / state | `UIDevice` + notifications | A | none | Yes | No | Measured (5 % steps on iOS 17+) | — | Unit mapping; device |
| Battery health / cycles / max capacity | — | **G** | — | — | — | Unavailable + instructions to Settings → Battery | — | Snapshot |
| Thermal state | `ProcessInfo.thermalState` + notification | A | none | Yes | No | Measured (nominal/fair/serious/critical) | — | Unit mapping |
| Low Power Mode | `isLowPowerModeEnabled` + notification | A | none | Yes | No | Measured | — | Unit |
| CPU/GPU/battery temperature, GPU utilisation | — | **G** | — | — | — | Not shown (explained in a FAQ only) | — | — |
| Display: native resolution, scale | `windowScene.screen.nativeBounds/nativeScale` | A | none | Display Zoom, external display | Per scene | Queried | Shown | Device incl. Display Zoom |
| Display: size, ppi, technology, panel max refresh, ProMotion | Catalog | B | none | No | Bundle | Catalog | Unavailable | Fixtures |
| Display: current max frame rate | `screen.maximumFramesPerSecond` | A | none | Yes (LPM) | No | Measured | Shown | Device with LPM on |
| Brightness | `screen.brightness` + notification | A | none | Yes | No | Measured | — | Device |
| Cameras present (wide/ultra-wide/tele/TrueDepth/LiDAR) | `AVCaptureDevice.DiscoverySession` | A | **Verify** that no permission is needed to enumerate (docs tie permission to capture only) | No | Launch | Queried | Shown | Device |
| Lens aperture, field of view, max photo dims | `lensAperture`, `videoFieldOfView`, `supportedMaxPhotoDimensions` (16+) | A | as above | No | Launch | Queried | Shown | Device |
| Lens marketing specs (MP, zoom factor, focal length) | Catalog | B | none | No | Bundle | Catalog | Unavailable | Fixtures |
| Network path (interface, expensive, constrained) | `NWPathMonitor` | A | none | Yes | No | Measured | — | Unit with path fakes |
| Cellular radio technology | `serviceCurrentRadioAccessTechnology` | A | none | Yes | No | Measured (when on cellular) | — | Device |
| Carrier name | `CTCarrier` deprecated, no replacement | **G** | — | — | — | Not shown | — | — |
| Wi‑Fi SSID / signal | `NEHotspotNetwork` (entitlement + location) | A (gated) | entitlement + location | Yes | No | **Not recommended** (permission cost) | — | — |
| Link speed / throughput | — | G (no API); D if self-measured | — | — | — | Optional user-initiated test only | — | — |
| Connectivity specs (Wi‑Fi gen, BT, 5G, UWB, USB) | Catalog | B | none | No | Bundle | Catalog | Unavailable | Fixtures |
| OS version / build | `ProcessInfo.operatingSystemVersion`; `sysctl kern.osversion` | A | none | No | Launch | Queried | — | Unit |
| Uptime | `systemUptime` | A | **No approved privacy reason for displaying uptime** | Yes | No | **Not shown** if App Store is ever targeted | — | — |

### 2.2 macOS (host Mac)

| Metric | Source | Cat. | Sandbox OK? | Presentation |
|---|---|---|---|---|
| Model identifier | `sysctlbyname("hw.model")` (e.g. `Mac14,2`); **not** `uname` (returns `arm64`) | A | Yes (verified) | Queried |
| Marketing name, year, chip, GPU cores, display spec | Catalog | B | — | Catalog (IORegistry `product-name` and `gpu-core-count` are readable but undocumented → **not used**, TD-08) |
| CPU brand string, P/E counts, cache sizes | `machdep.cpu.brand_string`, `hw.perflevelN.*` | A | Yes (verified) | Queried |
| System-wide CPU load (per core) | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` deltas | C | Yes (verified) | Measured |
| Memory: physical, used breakdown, pressure | `physicalMemory`; `host_statistics64`; dispatch memory-pressure source | A/C | Yes | Measured, with definitions |
| Battery: %, charging, time remaining, max capacity % | `IOPSCopyPowerSourcesInfo` (on Apple silicon, Current/Max are percentages) | A | Yes (verified) | Measured; "Maximum capacity" labelled as reported by macOS |
| Battery cycle count | `AppleSmartBattery` IORegistry: undocumented | **F** | Readable | **Not shown** (TD-08), or clearly marked experimental |
| Thermal state / Low Power Mode | `ProcessInfo` (LPM on macOS 12+) | A | Yes | Measured |
| Displays | `NSScreen` (`localizedName`, frame, `backingScaleFactor`, `maximumFramesPerSecond` 12+, EDR headroom); `CGDisplayCopyAllDisplayModes` | A | Yes | Queried / Measured |
| Storage (all volumes) | `URLResourceValues` capacity keys | A | Yes | Measured |
| GPU | `MTLDevice` name, families, `recommendedMaxWorkingSetSize`, `hasUnifiedMemory` | A | Yes | Queried |
| Wi‑Fi RSSI / transmit rate | CoreWLAN | A | Needs `com.apple.security.network.client` (verified); SSID needs Location | Optional (Phase 5) |
| Network path | `NWPathMonitor` | A | Yes | Measured |
| Cameras | `AVCaptureDevice.DiscoverySession` (no `lensAperture` on macOS) | A | Enumeration without the camera entitlement **unverified** | Queried |

## 3. Summary: measured vs catalog vs unavailable

- **Measured / queried directly (A):**
  - Identifier, OS, CPU topology, GPU name and Metal families.
  - RAM visible to the OS, storage, battery level and state, thermal state, Low Power Mode.
  - Display mode and brightness, present cameras and their apertures, network path, radio technology.
  - On macOS also: CPU load, memory breakdown, battery max-capacity %, all displays and volumes.
- **Needs the catalog (B):**
  - Marketing name, release date, SoC name, GPU and Neural Engine core counts.
  - Panel size, ppi, technology and refresh capability.
  - Lens megapixels and zoom factors, connectivity standards, advertised storage tiers, installed RAM (unofficial).
- **Unavailable (G); the app must say so rather than estimate:**
  - iOS battery health and cycle count.
  - Temperatures, GPU utilisation, system-wide CPU load on iOS.
  - Carrier name, Wi‑Fi link speed on iOS.
  - Mac marketing name and GPU cores through supported API.
