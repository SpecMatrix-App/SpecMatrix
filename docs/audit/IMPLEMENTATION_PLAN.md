# SpecMatrix: Implementation Plan

Audit date: 2026-10-15. **Nothing in this plan has been started.** Every phase needs explicit approval, and the Phase 0 decisions (`TECHNICAL_DECISIONS.md`) gate everything after them.

The ordering principle is: **make the data truthful → build the foundations → fill the catalog → build the UIs → ship**. Architectural prerequisites (Phases 0, 2, 3) are kept separate from feature work (Phases 4, 5, 7).

```
Phase 0 Decisions & repo hygiene ──► Phase 2 Foundations ──► Phase 3 Catalog ──┬─► Phase 4 iOS/iPadOS app ──┐
        │                                   │                                    └─► Phase 5 macOS app ───────┼─► Phase 6 Release ─► Phase 7 Catalog features (1.1)
        └─► Phase 1 Interim fix release (optional, old code)                                                  │
                                                                                Phase 4 and Phase 5 can run in parallel
```

---

## Phase 0: Decisions and repository hygiene
- **Objective:** remove the blockers to collaboration and CI, and lock in the decisions.
- **Rationale:** without a shared scheme, a consistent signing team and a CI build, nobody can verify the later phases (CB-14, DR-01).
- **Prerequisites:** owner answers to TD-01, TD-02, TD-09, TD-15 at minimum.
- **Components:** `.gitignore` (new), `xcshareddata/xcschemes/SpecMatrix.xcscheme` (new), `project.pbxproj` (team, test bundle IDs), `.github/workflows/ci.yml` (new), README "Building" section.
- **Changes:**
  - Untrack `xcuserdata/`. The local copies are preserved; only the git index changes.
  - Unify `DEVELOPMENT_TEAM`.
  - Change the test bundle IDs to `com.zacdevv.SpecMatrixTests` / `com.zacdevv.SpecMatrixUITests`.
  - Add a CI job: build plus unit tests on the simulator, unsigned.
- **Risks:** signing changes can break the owner's local builds. Make them on a branch and verify in Xcode.
- **Testing:** CI green on a clean checkout. `xcodebuild -list` shows the shared scheme.
- **Acceptance / done:** a fresh clone builds and runs its tests with one documented command, and CI runs on every PR.
- **Dependencies:** none.

## Phase 1: Interim truthfulness fixes (optional, existing code)
- **Objective:** stop the shipped app from showing fabricated or wrong data, before the rewrite lands.
- **Rationale:** today, every new iPhone gets invented specs (CB-01–03). This phase is worth doing only if an interim IPA will actually be distributed; otherwise skip to Phase 2.
- **Components:** `ContentView.swift` only.
- **Changes:**
  - Replace the CPU literals and all `default:` fallbacks with "Unknown".
  - Correct the identifier names using the audit table.
  - Remove the speed loop.
  - Make the memory timer 2 s and deallocate the host port.
  - Fix the battery `-1` handling and the symbols.
  - Persist the theme with `@AppStorage`.
  - Replace `CodableAppStorage` with `@AppStorage` keys. **This is required in the same change as the timer change** (CB-08).
- **Risks:** throwaway effort. Keep it under about 1 day.
- **Testing:** manual check on one device or simulator; build with `IPHONEOS_DEPLOYMENT_TARGET` unchanged.
- **Acceptance:** no fabricated values appear for an unmapped identifier, and the battery card never shows a negative value.
- **Dependencies:** Phase 0 (CI) recommended.

## Phase 2: Architecture foundations
- **Objective:** build the package, domain model, provider protocols, iOS providers, design-system primitives and a new app shell. Switch the entry point to the new shell.
- **Rationale:** every later phase depends on these seams (CB-12, CB-13).
- **Prerequisites:** TD-00, TD-01, TD-02, TD-04, TD-13 approved.
- **Components:**
  - New `Packages/SpecMatrixKit` (`SpecCore`, `SpecProviders`, `SpecUI`, plus test targets).
  - `SpecMatrixApp.swift`.
  - `project.pbxproj`: deployment targets per TD-01, `TARGETED_DEVICE_FAMILY = 1,2`, Swift 6 mode, package reference.
- **Architectural changes:**
  - `Provenance` / `Availability` / `Measurement` types.
  - `DeviceIdentity` and `DeviceResolver`, with an empty catalog interface.
  - iOS providers: identity, chip (sysctl), GPU (Metal), memory, power, storage, display (scene screen), camera (discovery only), network.
  - Fake providers for previews and tests.
  - `SpecSection` / `SpecRow` / `ProvenanceBadge` / `UnavailableNotice`, plus the compat layer (`smSurface`, `smOnChange`…).
  - Sampling via `.task` and `AsyncStream`.
- **Delivers:**
  - A runnable iPhone and iPad app showing **measured and queried** data with correct provenance. Catalog fields show "Unavailable" until Phase 3.
  - `ContentView.swift` is deleted at the end of the phase.
- **Risks:**
  - Scope creep into UI polish.
  - Sysctl perf-level readability on iOS is unverified. Check on a device early in the phase, before building UI on it.
- **Testing:**
  - Unit tests for every provider's parsing and mapping with fakes.
  - Concurrency: Swift 6 with zero warnings.
  - Smoke-test the app on the oldest and newest available simulators.
  - **Physical device verification** of every provider (§ device checklist in `TESTING_STRATEGY.md`).
- **Acceptance:**
  - Builds with zero warnings in Swift 6 mode for iOS.
  - No `UIScreen.main`.
  - No timers faster than 1 Hz.
  - Every row has provenance.
  - Package tests run with `swift test` (core) and `xcodebuild test` (providers).
- **Done:** old `ContentView.swift` removed; feature parity with the old app's *truthful* metrics (matrix §1, recommended actions).
- **Dependencies:** Phase 0.

## Phase 3: Hardware catalog
- **Objective:** a verified, sourced, versioned catalog with a validator and resolver.
- **Rationale:** B-category data is the product's main value, and it is entirely missing or wrong today (HD §2–3).
- **Prerequisites:** TD-05, TD-06, TD-10; schema review.
- **Components:**
  - `SpecCatalog` module.
  - `catalog/` JSON and `catalog/schema/`.
  - `tools/catalog/` (sim-identifier dump script, validator CLI or test).
  - `docs/specs/MEASUREMENTS.md`, `docs/catalog/CONTRIBUTING.md`.
- **Work items:**
  - Schema v1.
  - Load the existing research data: about 28 iPhones and 20 iPads since 2020/2021.
  - Research and add the older devices required by the TD-01 minimum (iPhone XS/XR/11/SE 2; pre-2021 iPads).
  - Research and add **Mac records** (Apple silicon first; Intel per TD-03).
  - Test vectors.
  - CI validation.
- **Risks:**
  - Data entry errors. Mitigate with two-source rules, review, and tests that cross-check against simulator profiles.
  - Effort underestimation (about 130–180 records).
- **Testing:**
  - Schema validation; uniqueness; every identifier in the Xcode simulator profiles resolves.
  - Spot checks against Apple pages (20 % sample, documented).
- **Acceptance:**
  - 100 % of the records have sources.
  - Every identifier for every device supported by the chosen minimum OS resolves.
  - The unknown-identifier path is tested.
- **Dependencies:** Phase 2 (types). Data research can start in parallel with Phase 2.

## Phase 4: iOS / iPadOS product
- **Objective:** a complete universal app: This Device, Live, Export, Settings, iPad layouts, Liquid Glass and fallbacks, accessibility, localisation infrastructure.
- **Prerequisites:** Phases 2 and 3.
- **Components:** `SpecUI` screens, the app's scenes, the asset catalog (semantic colours, new icon variants and `.icon`), the String Catalog.
- **Delivers:** F-01, F-02, F-03, F-05, F-06, F-11 (subset), F-16 infrastructure, F-17.
- **Risks:**
  - Over-applying glass.
  - iPad multitasking edge cases.
  - Icon design dependency (external).
- **Testing:**
  - Snapshot tests (compact and regular; light and dark; AX5; iOS 26+ glass vs pre-26 fallback where a simulator exists).
  - UI tests for the main flows.
  - Manual VoiceOver pass.
  - Performance: Energy Log on a device with the Live view open for 10 minutes.
- **Acceptance:**
  - No `#available` outside the compat files.
  - VoiceOver reads every row correctly.
  - The Live view stops sampling when not visible (verified in Instruments).
  - Builds and runs on the minimum-OS and newest-OS simulators.
- **Dependencies:** Phases 2 and 3. Can run in parallel with Phase 5.

## Phase 5: Native macOS app
- **Objective:** macOS destination: providers, layouts, `Settings` scene, commands, optional `MenuBarExtra`, sandbox and Hardened Runtime.
- **Prerequisites:** TD-03, TD-07, TD-08, TD-12; the Mac catalog from Phase 3.
- **Components:** `SpecProviders` macOS implementations (sysctl `hw.model`, IOPS, `host_processor_info`, `host_statistics64`, NSScreen/CG, volumes, Metal, NWPathMonitor); `SpecMatrixApp` (`#if os(macOS)`); entitlements file (new).
- **Delivers:** F-04, F-13 (if approved), macOS export via Copy and Share.
- **Risks:**
  - Intel coverage.
  - Testing on macOS 13/14 requires a separate machine or VM.
- **Testing:**
  - Unit tests with fakes.
  - Manual tests on Apple silicon (current macOS and the minimum macOS in a VM); Intel if available.
  - Verify sandboxed behaviour of every provider.
- **Acceptance:**
  - Sandboxed build passes all provider checks.
  - Window minimum size enforced.
  - Keyboard shortcuts work.
  - Universal binary (if TD-03).
- **Dependencies:** Phases 2 and 3.

## Phase 6: Release engineering (1.0)
- **Objective:** reproducible IPA and notarized DMG; updated README and installation guides.
- **Prerequisites:** TD-09; Developer ID certificate and API key (owner action).
- **Components:** `ExportOptions-*.plist`, `scripts/release/*.sh`, `.github/workflows/release.yml`, `.xcconfig` versioning, `PrivacyInfo.xcprivacy` (iOS: disk space 85F4.1, UserDefaults CA92.1), `CHANGELOG.md`, README rewrite.
- **Risks:**
  - Certificate handling in CI (use a temporary keychain).
  - Runner image changes (macos-14 retirement, openssl 4).
- **Testing:**
  - `spctl` and `stapler validate` on the DMG.
  - Install the DMG on a clean Mac user account.
  - Install the IPA via each documented method on at least one device.
- **Acceptance:**
  - A tagged commit produces both artifacts, with checksums, from CI or a single script.
  - Gatekeeper opens the app without warnings.
- **Dependencies:** Phases 4 and 5.

## Phase 7: Catalog features (1.1)
- **Objective:** F-07 catalog browser, F-08 compare, F-10 OS compatibility, F-19 Mac Wi‑Fi.
- **Rationale:** this is valuable, but it depends on a complete catalog and a stable UI. Keep it out of the critical path.
- **Testing:** fixtures for search and filter; `Table` snapshots on iPad and Mac.
- **Dependencies:** Phase 6 shipped.

---

## Effort outline (single developer, indicative only)

| Phase | Estimate |
|---|---|
| 0 | 0.5–1 day |
| 1 (optional) | 1 day |
| 2 | 1.5–2.5 weeks |
| 3 | 1.5–3 weeks (data-bound) |
| 4 | 2–3 weeks |
| 5 | 1.5–2.5 weeks |
| 6 | 3–5 days (plus account set-up lead time) |
| 7 | 2–3 weeks |

These estimates are uncertain. They assume familiarity with SwiftUI and access to at least one recent iPhone, one iPad and one Apple silicon Mac.
