# SpecMatrix: Feature Roadmap

Audit date: 2026-10-15. Phase numbers refer to `IMPLEMENTATION_PLAN.md`. Complexity scale: S < 1 day · M 1–3 days · L 1–2 weeks · XL more than 2 weeks (one developer).

## 1. Existing functionality

| Feature | Disposition | Why | Acceptance criteria | Phase |
|---|---|---|---|---|
| Device model name | **Rewrite** (catalog) | Most mappings are wrong (CB-02) | Every catalog identifier resolves to the Apple marketing name. Unknown identifiers show the raw ID and a "not in catalog" notice. | 2–3 |
| OS version | **Improve** | Correct, but the build number is missing | Shows the version and build | 2 |
| CPU card | **Rewrite** | Hard-coded A17 Pro (CB-01) | Chip and core counts come from the catalog. Queried perf-level counts are shown and cross-checked. | 2–3 |
| GPU card | **Rewrite** | Wrong values and a fabricated default | Name and Metal families come from Metal. Core count comes from the catalog. | 2–3 |
| Battery level and state | **Refactor** | Source is fine; presentation is broken (CB-04) | Never shows a negative value. Valid icon for every state. Explains 5 % steps. | 1–2 |
| Battery health link | **Remove / replace** | Private URL scheme; no data (CB-05) | iOS shows an "Unavailable" explanation. macOS shows the public max-capacity %. | 1 / 5 |
| Memory card | **Rewrite** | 10 Hz loop, port leak, undefined meaning (CB-07, CB-17) | iOS: RAM visible to the system, app footprint and headroom. macOS: memory breakdown with definitions. Samples at ≤ 1 Hz, only while visible. | 1–2 |
| Storage card | **Improve** | Wrong key; one-time snapshot (CB-11) | Matches Settings within rounding. Refreshes when the app becomes active. Shows no NaN. | 2 |
| Network status/type | **Improve** | Correct core; wired connections show as "Unknown" | Interface, expensive and constrained flags; radio technology on cellular | 2 |
| Network "speed" | **Remove** | Not a measurement; wastes data (CB-06) | No background network traffic | 1 |
| Display info | **Rewrite** | Wrong inputs; captured once (CB-10) | Native resolution correct under Display Zoom. Panel spec comes from the catalog. Current max fps is labelled separately. | 2–3 |
| Brightness bar | **Retain (concept)** | Correct and live | Accessible gauge | 2 |
| Camera info | **Rewrite** | Static and wrong; fabricated default | Lenses present and apertures from AVFoundation, MP and zoom from the catalog, no capture session | 2–3 |
| Theme picker | **Rewrite (small)** | Not persisted (CB-09) | Persists across relaunch | 1 |
| Section visibility toggles | **Remove** | Broken observation; confusing UX (CB-08, CB-22) | — | 2 |
| About links | **Retain** | — | Correct org URL | 2 |

## 2. Candidate features

| ID | Feature | User benefit | Feasibility / API limits | Complexity | Depends on | Testing | Priority | Release |
|---|---|---|---|---|---|---|---|---|
| F-01 | **This Device: complete, honest spec sheet** with provenance badges | Core promise: correct data, with its source visible | Fully feasible (detection matrix §2) | L | Architecture, catalog | Fixtures + device checks | **P0** | Modernization 1.0 |
| F-02 | **Live view**: battery, thermal, Low Power Mode, storage, app memory, network path, brightness | Situational awareness | All public APIs. **No** system CPU, temperatures or GPU usage on iOS | M | Providers | Unit with fakes; device | **P1** | 1.0 |
| F-03 | **Universal iPad layout** | iPad users | SwiftUI split view / `Grid` | M | Design system | Snapshot per size class; manual multitasking | **P1** | 1.0 |
| F-04 | **Native macOS app** (host Mac specs + live CPU, memory, battery, displays) | New platform | Verified APIs (sysctl, IOPS, host_processor_info, NSScreen) | L | Architecture, Mac catalog | Unit + manual on Apple silicon (+ Intel if TD-03) | **P1** | 1.0 |
| F-05 | **Unknown-device mode** | New hardware still shows useful information | Queried and measured fields only | S | Resolver | Unit | **P0** | 1.0 |
| F-06 | **Export / share technical report** (Markdown / plain text / JSON via `ShareLink`; Copy on Mac) | Support tickets, resale listings, forums | `ShareLink` iOS 16+. Must exclude nothing sensitive beyond what the user sees. | S–M | F-01 | Unit (report rendering) | **P1** | 1.0 |
| F-07 | **Hardware catalog browser** (all Apple devices, search, filter) | Reference tool beyond the user's own device | Data only; offline | L | Catalog completeness | Fixtures; UI | P2 | 1.1 |
| F-08 | **Compare devices** (side by side, across generations) | Purchase or upgrade decisions | `Table` / `Grid` | M | F-07 | Snapshot | P2 | 1.1 |
| F-09 | **Saved devices / comparison lists** | Convenience | `@AppStorage`/JSON in the app container; SwiftData (17+) is unnecessary | S | F-08 | Unit | P3 | 1.2 |
| F-10 | **OS compatibility info** ("supports iOS 27?", feature availability such as Apple Intelligence) | Frequently asked question | Data only; needs careful sourcing each WWDC | M (data) | Catalog schema extension | Fixtures | P2 | 1.1 |
| F-11 | **Feature explanations** (what ProMotion, the Neural Engine, Metal 4 and thermal states mean) | Education; supports honest "unavailable" states | Static content; must be localised | M | Design system | Content review | P2 | 1.0 (subset), 1.1 |
| F-12 | **User-initiated network test** (throughput and latency) | Diagnostics | Needs an endpoint the project is allowed to use; data cost disclosure; privacy note | M | TD-14 | Integration (against a local server in tests) | P3 | Later |
| F-13 | **macOS menu bar extra** | Glanceable CPU, thermal and battery | `MenuBarExtra` macOS 13+ | S–M | F-04 | Manual | P2 | 1.0 or 1.1 (TD-12) |
| F-14 | **Widgets** (battery, storage, thermal) | Home Screen glanceability | WidgetKit. Widgets cannot sample live, so they show values from timeline refreshes, which can be stale. Needs an App Group, which costs extra App IDs under free provisioning. | M | F-02 | Unit + manual | P3 | Later |
| F-15 | **Configurable Live dashboard** | Personalisation (replaces the old hide toggles) | Plain SwiftUI | M | F-02 | UI | P3 | Later |
| F-16 | **Localization** (beyond English) | Reach | String Catalog from day one; translations later | S (infra), M per language | Design system | Pseudo-localisation run | P2 (infra) | Infra 1.0 |
| F-17 | **Accessibility pass** | Required quality | — | M | Design system | VoiceOver, Dynamic Type AX5, Reduce Transparency audits | **P1** | 1.0 |
| F-18 | **Signed remote catalog refresh** | Recognise new devices without an update | Signing + schema gating | M | TD-05 | Integration | P3 | Later |
| F-19 | **Wi‑Fi details on macOS** (RSSI, Tx rate) | Mac diagnostics | Needs `network.client`; SSID needs Location (skip SSID) | S | F-04 | Manual | P3 | 1.1 |
| F-20 | Battery health / cycle count / temperatures / GPU utilisation on iOS | — | **Not available through public APIs** | — | — | — | **Rejected** | — |
| F-21 | Carrier name | — | `CTCarrier` deprecated with no replacement | — | — | — | **Rejected** | — |

## 3. Release shape

- **0.x fix release (optional, Phase 1).** Stop showing wrong and fabricated data in the existing iPhone app:
  - correct the mappings or show "Unknown";
  - remove the hard-coded CPU card values and the speed loop;
  - fix the battery value and icons;
  - restore the persisted theme.

  This is useful only if current users need an interim build.
- **1.0 Modernization:** F-01–F-06, F-11 (subset), F-13 (if approved), F-16 infrastructure, F-17. Universal iOS/iPadOS IPA and notarized macOS DMG.
- **1.1:** F-07, F-08, F-10, F-19, more F-11 content.
- **Later:** F-09, F-12, F-14, F-15, F-18.

## 4. Feature-level acceptance rule (applies to all)

A metric may ship only if all of the following hold:
1. It has a row in `FEATURE_AND_DETECTION_MATRIX.md` §2 naming its source and category.
2. Its provenance is visible in the UI.
3. It has an `unavailable` presentation.
4. It has a unit or fixture test.
5. If it is measured, it has a documented sampling policy.
