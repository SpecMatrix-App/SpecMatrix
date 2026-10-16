# SpecMatrix: Executive Summary

**Audit date:** 2026-10-15 · **Commit:** `faafc9c` (main) · **Toolchain:** Xcode 27.0 / iOS 27 SDK on macOS 27.2.

This audit made **no changes** to source, project, signing or assets. The only additions are the documents in `docs/audit/`.

## Current state

- **What it is:** an iPhone-only SwiftUI app (iOS 18.2+, Swift 5 mode) with no dependencies. All of the logic, roughly 1,770 lines, lives in a single file, `SpecMatrix/ContentView.swift`.
- **History:** one release, tagged `v1` on 2025-01-04. No meaningful changes since.
- **Builds:** clean for the iOS 27 simulator, with zero warnings.
- **Tests:** only Xcode templates.
- **Not supported:** iPad and macOS, a CI pipeline, and a shared scheme.

## Most important findings

1. **Most of the displayed hardware data is wrong or invented (P0).**
   - The CPU card shows "A17 Pro, 6-core…" on every device. These are literals at `ContentView.swift` L497-502.
   - Of the 20 hard-coded identifier mappings, 11 are wrong and 2 refer to identifiers that do not exist. For example, every iPhone 12 is shown as an iPhone 13, and the 15 Pro Max as the 15 Plus.
   - Every iPhone released after September 2024 falls through to fabricated defaults: "Apple GPU, 4 cores", "12 MP f/1.8", "458 ppi", "6.1″". That covers the 16e, the 17 family, the Air, the 17e and the 18 Pro.
   - Several iPhone 16 specifications are wrong compared with Apple's own pages: Neural Engine cores, GPU cores, ultra-wide camera, telephoto, ppi and screen sizes.
2. **The live metrics are misleading or wasteful (P1).**
   - "Network speed" downloads `apple.com/favicon.ico` once a second and labels the result as Mbps.
   - A 10 Hz memory timer re-renders the entire app and leaks a Mach port reference on every tick. The leak was verified at 1 → 1,001 references after 1,000 calls.
   - The battery level can show "-100%", and the battery icons use SF Symbol names that do not exist.
   - "Battery health" opens a private URL scheme (`App-prefs:`).
3. **Several features work only by accident or not at all (P1).**
   - The settings toggles work only because of the 10 Hz re-render. Fixing the timer alone would break them.
   - The theme choice is saved but never read back.
4. **The architecture blocks every goal (P1).**
   - There are no seams, so nothing can be tested and the code cannot compile for macOS.
   - Swift 6 mode fails with 2 errors, and complete concurrency checking reports 58 warnings.
   - The only blockers to building for iOS 16 are two `onChange` calls.

## Overall assessment

The **identifier technique** (`uname` + `SIMULATOR_MODEL_IDENTIFIER`), the **battery notification pattern**, **`NWPathMonitor`** and the **label/value row** idea are sound and carry forward. Everything else should be rebuilt.

That is affordable: the codebase is small, and the only user data is two `UserDefaults` keys. The rewrite is driven by evidence of incorrect output and missing seams, not by the code's age.

## Recommended target architecture

- **Structure:** one multiplatform app target (iPhone, iPad and Mac) plus a local Swift package with four modules: `SpecCore` (Foundation-only domain), `SpecCatalog`, `SpecProviders` (platform detection) and `SpecUI` (design system and screens). Dependencies point inward to `SpecCore`, and views never touch system APIs.
- **Provenance:** every value carries one of *measured*, *queried*, *catalog*, *derived*, *estimated* or *unavailable*.
- **Catalog:** a bundled, sourced, versioned **JSON hardware catalog** with a JSON Schema validated in CI. No backend.
- **Platforms:** a native macOS app (`hw.model`, IOPowerSources, `host_processor_info`, NSScreen), with App Sandbox and Hardened Runtime.
- **Liquid Glass:** adopted through standard containers on OS 26 and later, with custom glass used sparingly. Every availability check lives in one compatibility file, and older OSes fall back to native materials.

## Key decisions needed (`TECHNICAL_DECISIONS.md`)

- **Minimum OS (TD-01).**
  - **Recommended:** iOS/iPadOS 17 and macOS 14.
  - **Why not 16/13:** Xcode 27 can *build* for iOS 16 and macOS 13, but it can only run and debug on iOS 17 or later and has no iOS 16 simulator. Testing on the oldest supported OS would then need Xcode 26 and a physical iOS 16 device. `@Observable` also requires 17/14.
  - iOS 16 / macOS 13 remain feasible at that extra cost.
- **Paid Apple Developer Program (TD-09).** It is required for a notarized DMG and for Ad Hoc or TestFlight distribution. Without it, the IPA can only be self-signed by users, with profiles that expire every 7 days.
- **Others:** the target structure (TD-02), Intel Mac coverage (TD-03), whether to show unofficial RAM figures (TD-06), whether to use undocumented IORegistry values on the Mac (TD-08, recommended no), and units policy (TD-10).

## Major risks

- Catalog effort is the critical path: roughly 130–180 device records. Mac and older-device research was not done in this audit.
- iOS 16 / macOS 13 testability if those targets are kept.
- Signing and account prerequisites are unknown: no identities on this machine, and two different team IDs in the project.
- Runtime behaviour was not observed: the simulator service failed, and no physical device was available.

## Highest-value improvements, in order

1. Stop showing fabricated data. This is an optional one-day interim fix (Phase 1).
2. Build the foundations and provenance model (Phase 2).
3. Build the verified catalog (Phase 3).
4. Deliver the universal iOS/iPadOS app (Phase 4) and the native macOS app (Phase 5) in parallel.
5. Release engineering: IPA plus a notarized DMG (Phase 6).
6. Catalog browsing and comparison in 1.1 (Phase 7).

## Next steps

1. The owner reviews `TECHNICAL_DECISIONS.md` and answers at least TD-00, TD-01, TD-02, TD-09 and TD-15.
2. Approve Phase 0 (repository hygiene and CI).
3. Decide whether to ship the Phase 1 interim fix.
