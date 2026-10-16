# SpecMatrix: Hardware Data Audit

Research date: **2026-10-15**. Full cited tables are in `research/ios_ipad_devices.md`.

Source tags used below:
- **[A]** Apple primary source (support.apple.com tech specs, Newsroom, Metal documentation).
- **[S]** Secondary source. Identifier→name mappings and iPhone RAM are never published by Apple.
- **[X]** Read from the CoreSimulator device profiles that ship with Xcode 27.0. These are Apple files but not public documentation.

## 1. What the app currently contains

The app contains **5 separate hard-coded tables**, all keyed on `UIDevice.modelIdentifier()` and all in `SpecMatrix/ContentView.swift`:

| Table | Lines | Identifiers covered | Fields |
|---|---|---|---|
| `getDetailedDeviceModel()` | 416-440 | 20 (iPhone13,1 → iPhone17,4) | Marketing name |
| `GPUInfo.getInfo` | 43-143 | 20 | GPU name, cores, "Metal 3" |
| `ScreenInfo.ppi` / `physicalSize` | 808-830 | 7 | ppi, inches |
| `CameraInfo.getInfo` | 1004-1101 | 6 | Rear/front resolution strings, apertures, feature flags |
| `ContentView.processorInfo` (String) + file-scope `ProcessorInfo` (dead) | 1286-1325, 1149-1189 | 7 / 7 | Chip, CPU/GPU/NE cores |
| `CPUInfoView` | 497-502 | **All devices** (constants) | "A17 Pro", 6/2/4, 6 GPU, 16 NE |

The tables have no sources, no dates and no provenance. The catalog was last touched on 2025-01-04 (`d1cd5c6`).

## 2. Verification of every identifier mapping

| Identifier in code | Code says | Correct [S+X] | Verdict |
|---|---|---|---|
| iPhone13,1 | iPhone 13 mini | iPhone 12 mini | **Wrong** |
| iPhone13,2 | iPhone 13 | iPhone 12 | **Wrong** |
| iPhone13,3 | iPhone 13 Pro | iPhone 12 Pro | **Wrong** |
| iPhone13,4 | iPhone 13 Pro Max | iPhone 12 Pro Max | **Wrong** |
| iPhone14,4 | iPhone 14 Pro | iPhone 13 mini | **Wrong** |
| iPhone14,5 | iPhone 14 Pro Max | iPhone 13 | **Wrong** |
| iPhone14,7 | iPhone 14 | iPhone 14 | Correct |
| iPhone14,8 | iPhone 14 Plus | iPhone 14 Plus | Correct |
| iPhone15,2 | iPhone 15 | iPhone 14 Pro | **Wrong** |
| iPhone15,3 | iPhone 15 Plus | iPhone 14 Pro Max | **Wrong** |
| iPhone15,4 | iPhone 15 Pro | iPhone 15 | **Wrong** |
| iPhone15,5 | iPhone 15 Pro Max | iPhone 15 Plus | **Wrong** |
| iPhone16,1 | iPhone 15 Pro | iPhone 15 Pro | Correct |
| iPhone16,2 | iPhone 15 Plus | iPhone 15 Pro Max | **Wrong** |
| iPhone16,3 / iPhone16,4 | iPhone 15 Pro / 15 Pro Max | *Not found in any reference consulted* | Phantom identifiers |
| iPhone17,1–17,4 | 16 Pro / 16 Pro Max / 16 / 16 Plus | Same | Correct |

**Result:** 11 of the 20 mapped identifiers are wrong, and 2 refer to identifiers that do not exist in any reference consulted. Only 7 are correct.

**Never mapped** (all fall through to fabricated defaults):
- iPhone14,2 / 14,3 (13 Pro / 13 Pro Max)
- iPhone14,6 (SE 3rd gen)
- iPhone17,5 (16e)
- iPhone18,1–18,5 (17 Pro / 17 Pro Max / 17 / Air / 17e)
- iPhone19,2 (18 Pro), iPhone19,3 and 19,7 (18 Pro Max)
- Every iPad. The app is iPhone-only, but the tables will matter for the universal app.

**Simulator check [X]:** the iPhone 17 simulator reports `iPhone18,3` and the iPhone 18 Pro simulator reports `iPhone19,2`. Both are unmapped, so they would show "iPhone", "Apple GPU / 4 cores", "12 MP Main ƒ/1.8", "458 PPI", "6.1″" and, on the CPU card, "A17 Pro".

## 3. Incorrect specification values (Apple tech-specs pages)

| Code claim (location) | Correct value [A] | Source |
|---|---|---|
| A18 Pro Neural Engine "18-core" (L1159, L1292) | **16-core** | support.apple.com/en-us/121031 |
| iPhone 16 / 16 Plus GPU "6 cores" (`GPUInfo`, L58-63) | **5-core** (6-core is the A18 Pro; the 16e is 4-core) | /121029, /122208 |
| Chip name "A18 Bionic" (L1163, L1296) | **"A18"**. The "Bionic" name ended with the A16 | /121029 |
| iPhone 16 Pro ultra wide "12 MP" (L1009) | **48 MP**, f/2.2 | /121031 |
| iPhone 16 Pro telephoto "3x" (L1009) | **5x** (120 mm) on both the 16 Pro and the 16 Pro Max | /121031 |
| iPhone 16 ultra wide "f/2.4" (L1047-1048) | **f/2.2** | /121029 |
| iPhone 16 / 16 Plus "458 ppi" (L813) | **460 ppi** | /121029, /121030 |
| iPhone 15 Plus "458 ppi" (L815; identifier also wrong) | **460 ppi** | /111830 |
| Default "458 ppi" for unknown devices (L817) | No default. 460 is the most common, but it would still be fabricated | — |
| iPhone 16 Pro "6.1″" (L826) | **6.3″** | /121031 |
| iPhone 16 Pro Max "6.7″" (L824) | **6.9″** | /121032 |
| iPhone 16 Plus listed as a "Pro Max" model at 6.7″ (L825) | The size is right (6.7″); the comment grouping is wrong | /121030 |
| iPhone 15 Pro (16,1) GPU A17 Pro, 6 cores | Correct | /111829 |
| iPhone 15 Pro front camera 12 MP f/1.9 | Correct | /111829 |
| Metal "Metal 3" for all GPUs | Incomplete. Every A14-or-later device supports **Metal 4 on iOS 26+**. This should be **queried at runtime** (`supportsFamily(.metal4)`), not stored | support.apple.com/en-us/102894 |
| CPU card "A17 Pro / 6 / 2 / 4 / 6 / 16" for every device (L497-502) | Device-specific (see §4) | — |
| Unknown camera: "12 MP Main ƒ/1.8", front "ƒ/2.2" | Fabricated | — |

## 4. Coverage required for a current catalog (as of 2026-10-15)

Full tables with sources: `research/ios_ipad_devices.md` §1–2.

### 4.1 iPhone (all models that can run iOS 17+, or 16+ if TD-01 keeps 16)

| Generation | Identifiers | SoC (CPU P+E / GPU / NE) [A] |
|---|---|---|
| iPhone 12 family | 13,1–13,4 | A14 Bionic (2+4 / 4 / 16) |
| iPhone 13 family | 14,4 mini, 14,5, 14,2 Pro, 14,3 Pro Max | A15 Bionic (2+4 / **4** non-Pro, **5** Pro / 16) |
| iPhone SE (3rd gen) | 14,6 | A15 Bionic (2+4 / 4 / 16) |
| iPhone 14 / 14 Plus | 14,7 / 14,8 | A15 Bionic (2+4 / 5 / 16) |
| iPhone 14 Pro / Pro Max | 15,2 / 15,3 | A16 Bionic (2+4 / 5 / 16) |
| iPhone 15 / 15 Plus | 15,4 / 15,5 | A16 Bionic (2+4 / 5 / 16) |
| iPhone 15 Pro / Pro Max | 16,1 / 16,2 | A17 Pro (2+4 / 6 / 16) |
| iPhone 16 / 16 Plus | 17,3 / 17,4 | A18 (2+4 / 5 / 16) |
| iPhone 16 Pro / Pro Max | 17,1 / 17,2 | A18 Pro (2+4 / 6 / 16) |
| iPhone 16e | 17,5 | A18 (2+4 / **4** / 16) |
| iPhone 17 | 18,3 | A19 (2+4 / 5 / 16) |
| iPhone Air | 18,4 | A19 Pro (2+4 / **5** / 16) |
| iPhone 17 Pro / Pro Max | 18,1 / 18,2 | A19 Pro (2+4 / 6 / 16) |
| iPhone 17e | 18,5 | A19 (2+4 / 4 / 16) |
| iPhone 18 Pro / Pro Max | 19,2 / 19,3 + 19,7 | A20 Pro (2 "super" + 4 E / 7 / "Dual 16-core") |

Older iPhones (XS/XR/11 series, SE 2nd gen) support iOS 17/18 but were **not researched in this pass**. Their identifiers are iPhone11,x and iPhone12,x. They must be added before release if the minimum is iOS 17 (Phase 3 task). iPhone 8/X are needed only for iOS 16.

### 4.2 iPad

Identifiers, SoCs and displays are tabulated for every iPad from 2021 onward ([A]+[S]+[X]), including the M4/M5 iPad Pro, the M3/M4 iPad Air, the iPad (A16) and the iPad mini (A17 Pro).

Two gaps remain:
- **Pre-2021 iPadOS 16/17 devices are listed but not re-verified.**
- **The adamawolf gist mislabels iPad16,3–16,6.** They are the iPad Pro M4, not "5th/7th gen", so do not import that gist blindly.

### 4.3 Mac

**Not researched in this pass.** The approach is verified: `sysctl hw.model` returns e.g. `Mac14,2` (an M2 MacBook Air, verified on the audit machine) and works inside App Sandbox. There is no public marketing-name API (DTS).

A Mac catalog must cover every Mac that can run the chosen macOS minimum. For macOS 14 that includes Intel Macs from 2018 onward, or 2017 iMac Pro / iMac models for 13. **Decide whether Intel Macs get full catalog coverage** (TD-03). This is an Phase 3 research task and it is sizeable: roughly 60+ Mac identifiers since 2017.

### 4.4 Unofficial or unverifiable data

- **iPhone RAM is never published by Apple.** The secondary values are 4/6/8/12 GB, and the 17e and 18 Pro values are unverified. Show RAM from `ProcessInfo.physicalMemory`, labelled "as reported by the system". Show catalog RAM only with an "Unofficial" provenance badge, or omit it (TD-06).
- **The A20 Pro Metal family** (Apple10 vs Apple11) is unknown. Query it at runtime.
- **The iPhone 12 Pro / Pro Max pages do not list core counts.** The values are taken from the A14 on the iPhone 12 page. Mark the field with `derivedFrom`.
- **Two Apple sources conflict on Metal 3 support for the iPad 9th gen (A13).** Record the conflict in the record's `notes`.

## 5. Proposed catalog schema

Format: **JSON files bundled with the app**, validated against **JSON Schema (2020-12)** in CI. One file per family keeps diffs reviewable: `catalog/devices/iphone.json`, `ipad.json`, `mac.json`, plus `catalog/chips.json` and `catalog/sources.json`.

Chips are separate records so that SoC facts are written once. The GPU core *count* stays on the device, because the same chip ships with different enabled GPU cores (A15: 4 vs 5; A18: 4 vs 5).

```jsonc
// catalog/chips.json (one entry)
{
  "id": "apple-a18-pro",
  "name": "A18 Pro",
  "vendor": "Apple",
  "announced": "2024-09-09",
  "cpu": { "clusters": [ { "kind": "performance", "cores": 2 }, { "kind": "efficiency", "cores": 4 } ] },
  "gpu": { "maxCores": 6 },
  "neuralEngine": { "cores": 16 },
  "metal": { "gpuFamily": "apple9" },            // from Metal Feature Set Tables
  "sources": ["apple-121031", "metal-fst-2026-05"],
  "verification": { "status": "verified", "verifiedOn": "2026-10-15" }
}
```

```jsonc
// catalog/devices/iphone.json (one entry)
{
  "id": "iphone-16-pro",
  "identifiers": ["iPhone17,1"],                 // all hardware IDs mapping to this product
  "platform": "ios",                             // ios | ipados | macos | (future) android
  "family": "iPhone",
  "name": "iPhone 16 Pro",
  "manufacturer": "Apple",
  "released": "2024-09-20",
  "chip": { "ref": "apple-a18-pro", "gpuCores": 6 },
  "memory": { "options": [ { "gb": 8 } ], "provenance": "unofficial", "sources": ["iphonescompare-ram"] },
  "storage": { "optionsGB": [128, 256, 512, 1024] },
  "display": {
    "diagonalIn": 6.3, "technology": "OLED", "resolution": [2622, 1206], "ppi": 460,
    "maxRefreshHz": 120, "adaptiveRefresh": true, "proMotion": true
  },
  "cameras": [
    { "role": "main", "megapixels": 48, "aperture": 1.78 },
    { "role": "ultraWide", "megapixels": 48, "aperture": 2.2 },
    { "role": "telephoto", "megapixels": 12, "aperture": 2.8, "opticalZoom": 5 },
    { "role": "front", "megapixels": 12, "aperture": 1.9 }
  ],
  "sensors": ["LiDAR"],
  "connectivity": { "cellular": ["5G"], "wifi": "Wi-Fi 7", "bluetooth": "5.3", "port": "USB-C (USB 3)" },
  "sources": ["apple-121031", "everymac-iphone-ids", "xcode27-simprofiles"],
  "fieldSources": { "memory": ["iphonescompare-ram"] },   // overrides for specific fields
  "verification": { "status": "verified", "verifiedOn": "2026-10-15", "verifiedBy": "audit" },
  "notes": []
}
```

```jsonc
// catalog/sources.json (one entry)
{ "id": "apple-121031", "kind": "apple-primary", "title": "iPhone 16 Pro - Tech Specs",
  "url": "https://support.apple.com/en-us/121031", "accessed": "2026-10-15" }
```

Note: the `connectivity` values in this example are illustrative, because the audit did not verify them. Every connectivity field must be checked against the cited page before it is committed.

**Schema rules:**
- Every non-null field must be covered by `sources` or `fieldSources`.
- `verification.status` ∈ {`verified`, `secondary-only`, `unverified`, `conflict`}.
- Identifiers are unique across all files.
- Units are fixed by field name (`diagonalIn`, `maxRefreshHz`, `optionsGB` in decimal GB as Apple markets it).
- Unknown means **absent**, never `0` and never `""`.
- Top-level `catalogVersion` (`YYYY.MM.patch`) and `schemaVersion` (integer).

## 6. Data provenance requirements

1. Apple primary sources first. Secondary sources only for fields Apple does not publish (identifiers, RAM), and those fields are tagged accordingly.
2. Each displayed catalog value can reveal its source title, link and verification date (the `ProvenanceBadge` described in the design audit).
3. Conflicts between sources are recorded (`status: conflict` plus `notes`). They are not silently resolved.
4. Unreleased or rumoured devices are **never** added.
5. Simulator identifiers come from the device's `identifiers`; `SIMULATOR_MODEL_IDENTIFIER` resolves to the same record, with a "Simulator" badge.

## 7. Bundled vs remote catalog

| Option | Benefit | Cost / risk | Verdict |
|---|---|---|---|
| **Bundled JSON, updated with app releases** | Offline, deterministic, testable, no privacy surface, no infrastructure | New devices need an app release. For sideloaded or Ad Hoc users that is already the update channel. | **Recommended for the modernization** (TD-05) |
| Bundled + optional remote refresh (signed JSON on GitHub Pages / Releases) | New iPhones are recognised without an app update | Needs signature verification (e.g. Ed25519), a schema-compatibility gate, a cache, and network disclosure. Adds the app's only network dependency. | Later, optional. Reconsider after 1–2 hardware cycles. |
| Backend service | — | Unjustified for static reference data | Rejected |

**Unknown future devices:** the resolver returns `.unknownIdentifier`. The UI shows the raw identifier, everything that can be queried or measured at runtime (cores, Metal families, RAM visible to the OS, display mode, cameras present), and a "This device is newer than SpecMatrix's catalog (version X)" notice. Nothing is fabricated.

**Android reuse:** the same JSON files and schema serve a future Android catalog, with `platform: "android"` and a non-Apple `manufacturer`. Test vectors (`catalog/test-vectors.json`: identifier → expected record id) are the cross-language contract.

## 8. Maintenance workflow

| Trigger | Action | Owner check |
|---|---|---|
| Apple event / Newsroom launch (Sept iPhone, spring iPad/Mac, WWDC Macs) | Wait for the support.apple.com tech-specs pages, which usually appear around availability day. Add records with `status: verified` for the Apple fields. | PR template checklist |
| Identifier availability | Get identifiers from the new Xcode's CoreSimulator profiles (`profile.plist` `modelIdentifier` / `representedModelIdentifiers`). Cross-check with everymac and The Apple Wiki once real devices ship. Mark `secondary-only` until two sources agree. | `tools/catalog/sim-identifiers` script (proposed) dumps the profiles |
| New OS release | Update the OS-compatibility fields (if TD-11 adds them). Check API deprecations that affect providers (e.g. `UIScreen.main` in iOS 26). | — |
| Correction reported (GitHub issue template "Spec correction") | Must include a source URL. A maintainer verifies it, edits the record, and bumps `catalogVersion`. | — |
| Every PR touching `catalog/` | CI runs schema validation, unique identifiers, source presence, test vectors, and a unit-convention lint | Required check |
| Quarterly | Re-verify a sample of records (link rot, Apple page renames). Update `verifiedOn`. | — |

**Estimated initial effort:** about 70 iPhone/iPad records from the existing research, plus about 60 Mac records still to research, plus older iPhones and iPads depending on the minimum OS. Budget this explicitly in Phase 3.
