# SpecMatrix — Distribution & Release Audit

Audit date: 2026-10-15. Sources are listed in `RESEARCH_SOURCES.md` §C. Nothing in this report has been changed in the project. Signing, provisioning and release configuration are untouched.

## 1. Current state

| Item | Finding | Evidence |
|---|---|---|
| Release history | One git tag (`v1`, on `d866a87`, 2025-01-04). The README links to GitHub Releases and an App Store listing (`id6740110428`). | `git tag`, `README.md` |
| Signing | Automatic signing. The app uses team `LSYVL36ZN3` and the test targets use `8QU4WRDSA4`. There are no entitlements file and no capabilities. | `project.pbxproj` |
| Bundle ID | `com.zacdevv.SpecMatrix`. The test targets still use `com.example.*`. | `project.pbxproj` |
| Version | `MARKETING_VERSION 1.0`, `CURRENT_PROJECT_VERSION 1`, both hard-coded per configuration | `project.pbxproj` |
| Build automation | None: no CI, no `ExportOptions.plist`, no scripts, no shared scheme | Repository listing |
| Signing identities on this Mac | `security find-identity -v -p codesigning` → **0 valid identities** | Command output |
| Toolchain | Xcode 27.0 is installed, but `xcode-select` points to the Command Line Tools. CI and scripts must set `DEVELOPER_DIR` or `xcode-select -s`. | `xcode-select -p` |
| Install guidance (README) | Recommends AltStore/SideStore and third-party certificate services (KravaSign, Feather) | `README.md` |

**Unknowns (cannot be established from the repository):**
- Whether the developer currently holds a paid Apple Developer Program membership, and which team owns `LSYVL36ZN3`.
- Whether the App Store listing is still live.
- Who controls the GitHub organisation's release permissions.

## 2. iOS / iPadOS: IPA distribution

### 2.1 What "an IPA" can and cannot do

An IPA installs on a device only if:
- it is signed by a certificate the device trusts, **and**
- its embedded provisioning profile authorises that device, or the distribution channel (App Store, TestFlight, Enterprise, EU notarised distribution) authorises it.

An unsigned or arbitrarily signed IPA **cannot** be installed on a stock device. When the README sends users to "sideload" the GitHub IPA, those users are re-signing it under their own identity.

### 2.2 Options

| Channel | Requires | Who can install | Practical limits | Fit for SpecMatrix |
|---|---|---|---|---|
| **Free Personal Team** (Xcode, Apple ID) | Apple ID only | The developer's own devices | Profiles expire after **7 days**; 3 devices; 3 apps per device | Developer testing only |
| **AltStore Classic / SideStore** (user re-signs) | Each user's free Apple ID | Anyone, self-service | The same 7-day / 3-app limits; refresh tooling needed; unsupported by Apple | Workable for enthusiasts. The project should publish an **unsigned or development-signed IPA plus checksums** and document the limits. It should not endorse paid certificate services. |
| **Development / Ad Hoc** | Paid Program ($99/yr) | Registered UDIDs only | 100 devices per product family per membership year; slots are not freed when a device is removed | Good for a closed beta of known devices |
| **TestFlight** | Paid Program plus an App Store Connect record | Up to 10,000 external testers by link | Beta App Review; builds expire (90 days, unverified); requires the Xcode 26+ SDK | **Best broad non-public option**, though it is technically App Store infrastructure |
| **Enterprise** | $299/yr; 100+ employees; legal entity; internal use only | Employees only | Public distribution prohibited | **Not eligible / not appropriate** |
| **EU Web Distribution** | Paid Program; Apple notarisation; registered domain; eligibility (2 years of membership + 1M installs, **or** alternative financial criteria) | EU users on iOS 17.5+ / iPadOS 18+ | The legal-entity requirement was removed on 2026-10-01 | Not eligible at present (install threshold); revisit later |
| **EU alternative marketplace** (e.g. AltStore PAL) | Paid Program; Apple notarisation; marketplace agreement | EU users, iOS 17.4+ | Marketplace terms | Possible future channel |
| **App Store** | Paid Program | Everyone | App Review | Out of the initial scope, but the existing listing suggests it was used before. Decision TD-09. |

### 2.3 Entitlements and capabilities the modernised app would need (iOS)

The core feature set needs **no special entitlements**. Every API in `FEATURE_AND_DETECTION_MATRIX.md` that is marked "recommended" is available to an ordinary app.
- **Camera permission** (`NSCameraUsageDescription`) is not needed to enumerate `AVCaptureDevice`s or read their formats, but it is needed to open a capture session. The recommended design does not capture. Verify on a device before release (see `RESEARCH_SOURCES.md`).
- **Wi‑Fi SSID** (`NEHotspotNetwork`) needs an entitlement and location permission. Not recommended.
- **Widgets:** a WidgetKit extension needs an App Group to share data, which adds a provisioning step. This matters for Ad Hoc and free-team users, where the 3-App-ID budget gets consumed.

## 3. macOS: `.app` in a DMG

### 3.1 Required pipeline (outside the Mac App Store)

1. **Build** the Release `.app`. Make it a universal binary (`arm64 x86_64`) if the minimum is below macOS 27, because Intel Macs top out at macOS 26.
2. **Sign** with a **Developer ID Application** certificate, enabling the **Hardened Runtime** and a secure timestamp: `codesign --options runtime --timestamp`. Notarisation fails without the Hardened Runtime.
3. **Package** the DMG. `hdiutil create` is deprecated on macOS 27.2: it prints a warning pointing to `diskutil image create`. `create-dmg` is a common wrapper.
4. **Sign the DMG** with the same Developer ID identity.
5. **Notarise** with `xcrun notarytool submit SpecMatrix.dmg --wait`, using a keychain profile or an App Store Connect API key (`--key/--key-id/--issuer`). `altool` stopped working for this on 2023-11-01.
6. **Staple** with `xcrun stapler staple SpecMatrix.dmg`.
7. **Verify** with `spctl -a -vv -t open --context context:primary-signature SpecMatrix.dmg`, then mount and run `spctl -a -vv SpecMatrix.app`.

**Gatekeeper:** since macOS 15 Sequoia, users can no longer Control‑click to open un-notarised software; they have to go through System Settings → Privacy & Security. An un-notarised DMG is therefore **not a viable public deliverable**. The free Apple ID path cannot notarise. **Developer ID requires the paid Program.**

### 3.2 App Sandbox

The sandbox is **not required** for Developer ID; the Hardened Runtime is. It is still recommended (TD-07):
- every recommended macOS data source (`sysctl`, `IOPowerSources`, Metal, `NSScreen`, `FileManager` volume keys, `NWPathMonitor`) works inside the sandbox;
- it keeps a future Mac App Store option open;
- it limits the impact of any bug.

`IORegistry` reads used for GPU core count must be verified inside the sandbox before relying on them (`RESEARCH_SOURCES.md` §B).

### 3.3 Updates

| Option | Notes |
|---|---|
| **Sparkle 2** (2.10.0, macOS 12+) | De-facto standard. EdDSA-signed appcast, delta updates, sandbox support via XPC services. Adds one SPM dependency. Recommended once there are users to update. |
| Manual check (GitHub Releases API) | Zero dependencies; a "new version available" link only. Acceptable for the first releases. |

## 4. Proposed release pipeline

**Required for a first public release:**

| Step | iOS / iPadOS | macOS |
|---|---|---|
| Versioning | One source of truth (`.xcconfig`, `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` from the git tag) | Same |
| Build | `xcodebuild archive -scheme SpecMatrix -destination 'generic/platform=iOS'` | `xcodebuild archive -scheme SpecMatrix -destination 'generic/platform=macOS'` |
| Export | `xcodebuild -exportArchive` with an `ExportOptions.plist` (`method` = `release-testing` / `debugging`, i.e. Ad Hoc / Development, depending on decision TD-09) | `method = developer-id` |
| Package | `.ipa` (from export) | DMG, signed, notarised, stapled |
| Publish | GitHub Release: IPA, DMG, SHA-256 checksums, release notes, installation guide stating the signing limits honestly | Same |

**Optional improvements:**
- GitHub Actions. Use the `xcode-27` preview runner, or `macos-26` with Xcode 26.x if the 26 SDK suffices. Use a temporary keychain and store the p12 in an encrypted secret. Notarise with an App Store Connect API key. Gate releases behind a protected environment.
- An OTA `itms-services` manifest for Ad Hoc testers.
- Sparkle appcast hosted on GitHub Pages.
- An AltStore source JSON for sideloading users.

**Watch-outs:**
- The `macos-14` runners are retired on 2026-11-02.
- `openssl` moves from 3 to 4 on the runner images between 2026-11-02 and 2026-11-08, which affects p12 conversion scripts.

## 5. Dependencies on accounts and infrastructure

| Requirement | Needed for | Owner action |
|---|---|---|
| Paid Apple Developer Program ($99/yr) | Developer ID, notarisation, Ad Hoc, TestFlight | Confirm membership and team ID (TD-09) |
| Developer ID Application certificate | DMG | Create in the developer account; export the p12 for CI |
| App Store Connect API key | `notarytool` in CI, TestFlight uploads | Create with the least privilege needed |
| GitHub repository admin | Releases, secrets, environments | `SpecMatrix-App` org owner |
| Optional: domain / GitHub Pages | Sparkle appcast, OTA manifest | — |

## 6. Findings summary

| ID | Severity | Finding |
|---|---|---|
| DR-01 | P1 | No reproducible release process: no shared scheme, no export options, no CI, no version source of truth |
| DR-02 | P1 | A DMG cannot be distributed usefully without Developer ID + notarisation, which requires the paid Program (status unknown) |
| DR-03 | P2 | Inconsistent teams and `com.example` bundle IDs will break automatic signing for anyone except the original machine |
| DR-04 | P2 | The README's install guidance recommends third-party certificate services; the project should not endorse these |
| DR-05 | P2 | Universal (x86_64) Mac build is needed if the macOS minimum is 13–26; it doubles the macOS test matrix (Intel hardware availability unknown) |
