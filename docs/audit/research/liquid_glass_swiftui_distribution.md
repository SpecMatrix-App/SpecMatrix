# Research: Liquid Glass / SwiftUI availability and non-App Store distribution
Researched 2026-10-15. Availability data comes from Apple's DocC JSON (`https://developer.apple.com/tutorials/data/documentation/<path>.json` → `metadata.platforms[].introducedAt`), which backs the human-readable pages at `https://developer.apple.com/documentation/<path>`. **[UNVERIFIED]** marks claims that rest only on secondary sources or my inference.
Local machine check: `sw_vers` reports macOS 27.2 (build 26B5101f).

---
## PART 1: Liquid Glass and SwiftUI

### 1.1 Liquid Glass APIs: availability (all verified from Apple DocC metadata)
| API | iOS | iPadOS | macOS | Mac Catalyst | Other | Doc URL |
|---|---|---|---|---|---|---|
| `View.glassEffect(_:in:)` | 26.0 | 26.0 | 26.0 | 26.0 | tvOS 26, watchOS 26 | https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:) |
| `Glass` (struct) | 26.0 | 26.0 | 26.0 | 26.0 | tvOS/watchOS 26 | https://developer.apple.com/documentation/swiftui/glass |
| `Glass.regular` | 26.0 | 26.0 | 26.0 | 26.0 | | https://developer.apple.com/documentation/swiftui/glass/regular |
| `Glass.clear` | 26.0 | 26.0 | 26.0 | 26.0 | | https://developer.apple.com/documentation/swiftui/glass/clear |
| `Glass.tint(_:)` | 26.0 | 26.0 | 26.0 | 26.0 | | https://developer.apple.com/documentation/swiftui/glass/tint(_:) |
| `Glass.interactive(_:)` | 26.0 | 26.0 | 26.0 | 26.0 | | https://developer.apple.com/documentation/swiftui/glass/interactive(_:) |
| `GlassEffectContainer` | 26.0 | 26.0 | 26.0 | 26.0 | tvOS/watchOS 26 | https://developer.apple.com/documentation/swiftui/glasseffectcontainer |
| `glassEffectID(_:in:)` | 26.0 | 26.0 | 26.0 | 26.0 | | https://developer.apple.com/documentation/swiftui/view/glasseffectid(_:in:) |
| `glassEffectUnion(id:namespace:)` | 26.0 | 26.0 | 26.0 | 26.0 | | https://developer.apple.com/documentation/swiftui/view/glasseffectunion(id:namespace:) |
| `.buttonStyle(.glass)` | 26.0 | 26.0 | 26.0 | 26.0 | | https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass |
| `.buttonStyle(.glassProminent)` | 26.0 | 26.0 | 26.0 | 26.0 | | https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glassprominent |
| `tabBarMinimizeBehavior(_:)` | 26.0 | 26.0 | 26.0 | 26.0 | visionOS/tvOS/watchOS 26 | https://developer.apple.com/documentation/swiftui/view/tabbarminimizebehavior(_:) |
| `tabViewBottomAccessory(content:)` | 26.0 | 26.0 | **not on macOS** | 26.0 | | https://developer.apple.com/documentation/swiftui/view/tabviewbottomaccessory(content:) |
| `ToolbarSpacer` | 26.0 | 26.0 | 26.0 | 26.0 | | https://developer.apple.com/documentation/swiftui/toolbarspacer |
| `backgroundExtensionEffect()` | 26.0 | 26.0 | 26.0 | 26.0 | visionOS/tvOS/watchOS 26 | https://developer.apple.com/documentation/swiftui/view/backgroundextensioneffect() |
| `scrollEdgeEffectStyle(_:for:)` | 26.0 | 26.0 | 26.0 | 26.0 | | https://developer.apple.com/documentation/swiftui/view/scrolledgeeffectstyle(_:for:) |
| `TabRole.search` / `Tab(role: .search)` | **18.0** | **18.0** | **15.0** | 18.0 | | https://developer.apple.com/documentation/swiftui/tabrole/search |

Notes:
- `Tab(role: .search)` is **not** a 26-only API. It exists from iOS 18 / macOS 15. On the 26 SDK and OS, the system "automatically separates the search tab from other tabs and places it at the trailing end" (Adopting Liquid Glass, Search section: https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).
- `tabViewBottomAccessory` has no macOS availability, so guard it with `#if os(iOS)` in a multiplatform target.
- Usage example (`.regular.tint(.x).interactive()` chaining) matches the documented `Glass` builder methods above.

### 1.2 What apps get automatically with the 26 SDK
Source: "Adopting Liquid Glass", https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- "If your app uses standard components from SwiftUI, UIKit, or AppKit, your interface picks up the latest look and feel on the latest platform releases … build your app with the latest SDKs."
- "standard components like bars, sheets, popovers, and controls automatically adopt this material." This covers TabView tab bars, NavigationStack/NavigationSplitView toolbars and sidebars, sheets (larger corner radius, inset half sheets), popovers, menus, sliders, and toggles.
- Toolbars group items onto shared glass backgrounds. Use `ToolbarSpacer` to split groups, and hide the whole toolbar item instead of leaving an empty one.
- Apple recommends: "Reduce your use of custom backgrounds in controls and navigation elements." Remove custom bar and sheet backgrounds because they interfere with Liquid Glass and the scroll edge effect.
- Tab bar minimize-on-scroll is opt-in (`tabBarMinimizeBehavior`). `backgroundExtensionEffect` mirrors content under sidebars and inspectors.
- App icons: there is a new layered icon format built with Icon Composer, with light, dark, clear, and tinted variants (same page).
- watchOS picks up the look even without rebuilding. tvOS requires Apple TV 4K (2nd gen) or later (same page).

### 1.3 `UIDesignRequiresCompatibility`
| Fact | Source |
|---|---|
| Info.plist Boolean. `YES` means "the system runs the app using a compatibility mode for UI… as it looks when built against previous versions of the SDKs." Available iOS/iPadOS/macOS/tvOS 26.0. | https://developer.apple.com/documentation/bundleresources/information-property-list/uidesignrequirescompatibility |
| Apple: "Temporarily use this key while reviewing and refining your app's UI." | same |
| **Removed in 27:** "The system ignores this key when you build for iOS 27 or later, iPadOS 27 or later, Mac Catalyst 27 or later, macOS 27 or later, or tvOS 27 or later." | same |
| It is a link-time (SDK) check. An app linked against the iOS 26 SDK keeps the key honored when it runs on iOS 27. The key is ignored only when the app is linked against the 27 SDK (accepted DTS answer). | https://developer.apple.com/forums/thread/832543 |
| Apple has published no date that forces the 27 SDK. The current App Store floor is Xcode 26 and the 26 SDKs, effective 2026-04-28. Going by the past cadence, a Xcode 27 requirement would arrive around April 2027 **[UNVERIFIED / inference]**. | https://developer.apple.com/news/upcoming-requirements/ |

Implication: for any build made with Xcode 27, Liquid Glass is unavoidable. The key only buys time on Xcode 26.

### 1.4 iOS 27 / macOS 27 (WWDC26) changes
Source: WWDC26 "What's new in SwiftUI", session 269, https://developer.apple.com/videos/play/wwdc2026/269/
- "Apps automatically adopt the updated Liquid Glass appearance on 2027 OS releases without code changes." Liquid Glass "automatically responds to the new Liquid Glass slider to adjust its tint." This is a new system-wide user preference.
- On macOS, custom glass can be marked `interactive` so it responds to clicks. The session says this is optimized for the pointer.
- iPadOS gains an inactive-window appearance. Toolbars gain overflow menus, pinned placements, visibility priority, and minimize-on-scroll behavior (chapter list).
- Other SwiftUI additions: a new Document APIs/protocol, reordering in lists/grids/sections, swipe actions on any view, AsyncImage caching, and lazy `@State` initialization for `@Observable`, which the session says is "back-ported to iOS 17, macOS 14".
- Secondary sources mention `visibilityPriority` and a prominent tab role: https://www.infoq.com/news/2026/07/swiftui-wwdc26 , https://swiftwithmajid.com/2026/06/08/what-is-new-in-swiftui-after-wwdc26/ **[exact symbol names UNVERIFIED]**
- No Liquid Glass API was removed. The changes refine the material and add user controls. Custom glass should honor the opacity slider and the Reduce Transparency setting, so test them **[guidance from secondary source; Apple's page says to test "with different configurations of these settings"]**.

### 1.5 SwiftUI availability matrix (verified from DocC metadata)
| API | iOS/iPadOS | macOS | Bucket |
|---|---|---|---|
| `NavigationStack`, `NavigationSplitView` | 16.0 | 13.0 | 16 |
| Swift Charts (`Charts` framework) | 16.0 | 13.0 | 16 |
| `Gauge` | 16.0 | 13.0 | 16 |
| `Grid` | 16.0 | 13.0 | 16 |
| `ViewThatFits` | 16.0 | 13.0 | 16 |
| `Table` | 16.0 on iOS/iPadOS (compact width collapses to the first column) | 12.0 | 16 |
| `searchable(text:tokens:…)` | 16.0 | 13.0 | 16 |
| `ShareLink` | 16.0 | 13.0 | 16 |
| `Transferable` (CoreTransferable) | 16.0 | 13.0 | 16 |
| `MenuBarExtra` | n/a | 13.0 | macOS 13 |
| `Settings` scene | n/a | 11.0 | macOS 11 |
| `WindowGroup` | 14.0 | 11.0 | old |
| Observation `@Observable` | 17.0 | 14.0 | 17 |
| `onChange(of:initial:_:)` (2-param / zero-param closure) | 17.0 | 14.0 | 17 |
| `ContentUnavailableView` | 17.0 | 14.0 | 17 |
| `containerRelativeFrame(_:alignment:)` | 17.0 | 14.0 | 17 |
| `scrollTargetBehavior(_:)` | 17.0 | 14.0 | 17 |
| `inspector(isPresented:content:)` | 17.0 | 14.0 | 17 |
| `symbolEffect(_:options:isActive:)` / `(value:)` | 17.0 | 14.0 | 17 |
| `Tab` (new TabView API) | 18.0 | 15.0 | 18 |
| `.tabViewStyle(.sidebarAdaptable)` | 18.0 | 15.0 | 18 |
| Liquid Glass APIs (section 1.1) | 26.0 | 26.0 | 26 |

URLs follow the pattern `https://developer.apple.com/documentation/swiftui/<symbol>`, for example `/swiftui/navigationstack`, `/observation/observable()`, `/swiftui/view/onchange(of:initial:_:)`, `/swiftui/contentunavailableview`, `/charts`, `/swiftui/gauge`, `/swiftui/grid`, `/swiftui/viewthatfits`, `/swiftui/view/containerrelativeframe(_:alignment:)`, `/swiftui/view/scrolltargetbehavior(_:)`, `/swiftui/tab`, `/swiftui/tabviewstyle/sidebaradaptable`, `/swiftui/table`, `/swiftui/view/inspector(ispresented:content:)`, `/swiftui/view/searchable(text:tokens:placement:prompt:token:)`, `/swiftui/menubarextra`, `/swiftui/settings`, `/swiftui/windowgroup`, `/swiftui/sharelink`, `/coretransferable/transferable`, `/swiftui/view/symboleffect(_:options:isactive:)`.

Practical takeaway: a target of iOS 16 / macOS 13 covers Charts, NavigationStack, Grid, ShareLink, and MenuBarExtra. Raising it to **iOS 17 / macOS 14** adds `@Observable`, the new `onChange`, ContentUnavailableView, inspector, and symbolEffect, which is the largest modernization win. Raising it to **iOS 18 / macOS 15** adds the `Tab` API and sidebarAdaptable.

### 1.6 Backporting and fallback guidance
- HIG Materials: "Don't use Liquid Glass in the content layer… use standard materials for elements in the content layer." "Use Liquid Glass effects sparingly." "Only use clear Liquid Glass for components that appear over visually rich backgrounds." https://developer.apple.com/design/human-interface-guidelines/materials
- Adopting Liquid Glass: "Prefer to remove custom effects and let the system determine the background appearance." "Combine custom Liquid Glass effects [in a GlassEffectContainer] to improve rendering performance." https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- Recommended pattern: `if #available(iOS 26, macOS 26, *) { .glassEffect(...) } else { .background(.regularMaterial / .ultraThinMaterial, in: shape) }`. On older OSes, standard system components keep their pre-26 look automatically.
- **[UNVERIFIED]** I found no Apple page that explicitly says "don't imitate Liquid Glass on older OS versions." That wording is community consensus (for example https://tessl.io/registry/dpearson2699/swift-ios-skills/3.9.0/files/skills/swiftui-liquid-glass/SKILL.md). Apple's guidance about letting the system own bar and control backgrounds implies the same thing: use materials or nothing as the fallback, never a hand-rolled glass imitation.

---
## PART 2: Distribution without the App Store

### 2.1 Fees
| Program | Fee | Source |
|---|---|---|
| Apple Developer Program | 99 USD per membership year (local currency where available) | https://developer.apple.com/programs/whats-included/ |
| Apple Developer Enterprise Program | 299 USD per membership year | https://developer.apple.com/programs/enterprise/ |
| Free Personal Team | $0 | https://developer.apple.com/support/compare-memberships/ |

### 2.2 iOS / iPadOS options for distributing an IPA
| Method | Who can install | Limits / constraints | Source |
|---|---|---|---|
| **Free Personal Team** (Xcode, Apple ID only) | Your own devices, installed via Xcode | Provisioning profiles "expire 7 days from issuance". Up to 3 devices, 3 apps per device, 10 App IDs (each expires after 7 days). You must rebuild and reinstall after expiry. Many capabilities are unavailable. | https://developer.apple.com/support/compare-memberships/ |
| **Development signing** (paid) | Registered devices on the team | Device UDIDs count against the 100-per-family limit. Installed via Xcode, Devices window, or Apple Configurator. Profile valid about 1 year **[validity UNVERIFIED]**. | https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices |
| **Ad Hoc** (paid) | Only devices whose UDIDs are in the profile | "up to 100 … devices, per product family, per membership year" (iPhone, iPad, Mac, etc. counted separately). Disabling a device does not free a slot. The count resets only at membership renewal. Install via Apple Configurator, Xcode, MDM, or an OTA `itms-services` manifest over HTTPS. | https://developer.apple.com/help/account/devices/devices-overview , https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile |
| **TestFlight** (paid) | Up to 100 internal testers (team members with roles) and up to 10,000 external testers via email or public link | Requires an App Store Connect app record. External builds need Beta App Review and a beta description. The app never has to be released publicly. Builds expire after 90 days **[90-day figure from general knowledge; not re-verified on page]**. | https://developer.apple.com/testflight/ |
| **Enterprise (in-house)** | Employees only | Organization must have 100+ employees, be a legal entity (no DBAs), use the program only for proprietary internal apps, and have systems ensuring only employees can download. Public or consumer distribution is prohibited. | https://developer.apple.com/programs/enterprise/ |
| **EU Web Distribution** | EU users on iOS 17.5+ / iPadOS 18+ | App must pass **Notarization** (a subset of App Review covering accuracy, functionality, safety, security, and privacy). Install only from a domain registered in App Store Connect. Eligibility: Account Holder accepts the latest DPLA, then either (a) 2+ continuous years in the program **and** an app with more than 1M first annual installs worldwide in the prior year, or (b) alternative financial-standing criteria (a recent audit). Core Technology Commission applies. The DPLA updated 2026-08-18 (effective 2026-10-01) **removed the requirement to have a legal entity or be established in the EU** and broadened eligibility. | https://developer.apple.com/support/web-distribution-eu/ , https://developer.apple.com/support/dma-and-apps-in-the-eu/ |
| **EU alternative app marketplaces** (e.g. AltStore PAL) | EU users | App is still notarized by Apple and distributed via the marketplace. AltStore PAL requires iOS 17.4+, being physically in the EU, and an EU Apple Account. PAL apps do not expire and have no 3-app limit. | https://developer.apple.com/support/dma-and-apps-in-the-eu/ , https://faq.altstore.io/altstore-pal/what-is-altstore-pal |
| **AltStore Classic / SideStore** (third-party sideloading) | Anyone | These re-sign the IPA with the user's **free** Apple ID, so all Personal Team limits apply: apps expire after 7 days and must be refreshed (AltServer on a Mac/PC; SideStore refreshes on-device via a VPN/pairing file), with at most 3 active sideloaded apps. They are unsupported by Apple and entitlements are limited. | https://faq.altstore.io/altstore-pal/what-is-altstore-pal ; SideStore details **[UNVERIFIED, secondary source]** |

Also note: App Store Connect uploads (TestFlight included) must be built with Xcode 26+ and the 26 SDKs (since 2026-04-28) and must target iOS 13+ (since 2026-09-09). https://developer.apple.com/news/upcoming-requirements/

### 2.3 macOS distribution outside the Mac App Store
| Topic | Fact | Source |
|---|---|---|
| Certificate | You must sign with **Developer ID Application** (plus Developer ID Installer for .pkg). "You can only notarize apps that you sign with a Developer ID certificate." Mac App Distribution and self-signed certificates fail. | https://developer.apple.com/documentation/security/resolving-common-notarization-issues |
| Hardened Runtime | Required: "If you don't enable the hardened runtime, notarization fails." Use a secure timestamp (`codesign --options runtime --timestamp`). | same |
| Notarization required | "Beginning in macOS 10.15, all software built after June 1, 2019, and distributed with Developer ID must be notarized." | https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution |
| Tooling | `altool` uploads have been rejected since 2023-11-01. Use `xcrun notarytool submit … --wait`. Authenticate with `--keychain-profile` (set up via `notarytool store-credentials`), `--apple-id`/app-specific password, or an **App Store Connect API key** (`--key <.p8 path> --key-id <id> --issuer <uuid>`). The API-key flags were confirmed from local `xcrun notarytool submit --help`. | https://developer.apple.com/documentation/security/customizing-the-notarization-workflow , https://developer.apple.com/news/upcoming-requirements/ |
| Accepted containers | UDIF disk images, signed flat .pkg, and ZIP. Nested items get their own tickets. | customizing-the-notarization-workflow (above) |
| Stapling | `xcrun stapler staple MyApp.dmg` (also works on .app and .pkg). **ZIPs cannot be stapled**: staple the .app, then re-zip. Stapling enables offline Gatekeeper checks. | same |
| DMG signing | "Sign your code, and sign each nested container": sign the app, create the DMG, **sign the DMG** (`codesign -s "Developer ID Application: …" --timestamp My.dmg`), notarize, then staple. Apple notes ZIPs cannot be signed. | https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution |
| DMG creation | `hdiutil create -srcfolder … -format UDZO`. **On macOS 27.2 (local check), `hdiutil create` prints "WARNING: 'hdiutil create …' is deprecated. Please use 'diskutil image create …' instead."** The new form is `diskutil image create from <folder>`. Third-party: create-dmg/create-dmg (shell, v1.3.0, Jul 2026) https://github.com/create-dmg/create-dmg ; sindresorhus/create-dmg (Node, v8.1.0, Mar 2026) https://github.com/sindresorhus/create-dmg | local `hdiutil`/`diskutil` output; GitHub releases API |
| Gatekeeper on macOS 15+ | "In macOS Sequoia, users will no longer be able to Control-click to override Gatekeeper when opening software that isn't signed correctly or notarized. They'll need to visit System Settings > Privacy & Security." **Verified.** In practice, unnotarized builds are not viable for end users. | https://developer.apple.com/news/?id=saqachfa |
| App Sandbox | Required for the Mac App Store. **Optional** for Developer ID. Hardened Runtime is mandatory for Developer ID, the sandbox is not **[stated by Apple in App Sandbox docs and App Review Guidelines 2.4.5; not re-fetched verbatim here]**. | https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox |
| Sparkle 2 updates | Latest release is **2.10.0 (2026-09-13)**. Supports macOS 12+. Signs archives, deltas, and pkgs with **EdDSA (ed25519)** keys from `./bin/generate_keys`, and keeps the private key off the web server. Supports Apple code signing validation. Sandboxed apps are supported via bundled XPC services; follow the Sparkle 2 sandboxing guide. | https://sparkle-project.org/ , https://sparkle-project.org/documentation/ , https://sparkle-project.org/documentation/sandboxing/ , https://github.com/sparkle-project/Sparkle/releases |
| Intel support | Apple (WWDC25 Platforms State of the Union) said macOS 26 Tahoe is the **last release for Intel Macs**. macOS 27 is Apple silicon only (M1+ and the A18 Pro MacBook Neo). Intel Macs get security updates for about 3 years. Rosetta 2 stays through macOS 27. | https://www.macrumors.com/2026/06/03/macos-27-wont-run-on-these-macs/ , https://appleinsider.com/articles/26/06/08/macos-27-compatibility-list-focuses-entirely-on-apple-silicon , https://petapixel.com/2025/06/10/macos-26-tahoe-is-the-end-of-the-road-for-intel-macs/ **[Apple primary source not fetched; consistent across many outlets]** |
| Universal binary? | **If the deployment target is macOS 13 through 26, keep the x86_64 slice.** Intel Macs run macOS 13 through 26, and Xcode's default "Standard Architectures" builds arm64 + x86_64 for Release. Drop x86_64 only if the minimum is macOS 27. **[inference]** | (above) |

### 2.4 GitHub Actions macOS runners (as of 2026-10)
| Label | Arch | OS | Xcode installed (default bold) | Source |
|---|---|---|---|---|
| `macos-latest`, `macos-26`, `macos-26-xlarge` | arm64 | macOS 26.6.2 | **26.6**, 26.5, 26.4.1, 26.3, 26.2, 26.1.1, 26.0.1 | https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md |
| `macos-26-intel`, `macos-26-large`, `macos-latest-large` | x64 | macOS 26.6.1 | **26.6** … 26.0.1 | https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md |
| `macos-15`, `macos-15-xlarge` | arm64 | macOS 15.7.9 | **16.4**, 16.0–16.3, 26.0.1–26.3 | https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md |
| `macos-15-intel`, `macos-15-large` | x64 | macOS 15 | similar | https://github.com/actions/runner-images/blob/main/README.md |
| `xcode-27`, `xcode-27-xlarge` (**preview**) | arm64 | macOS 27.0.1 | **27.0**, 27.1, 27.2 beta | https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md , https://github.com/actions/runner-images/issues/14404 |
| `macos-14*` | | | deprecated, fully unsupported 2026-11-02 | https://github.com/actions/runner-images/issues/13518 |

- Policy: "only one major version of Xcode will be supported per macOS version", with all minors of that major (runner-images README). This is why Xcode 27 is on a separate `xcode-27` image.
- Upcoming change: the default `openssl` CLI switches from 3 to 4 on the macOS 26 and Xcode 27 images during 2026-11-02 to 11-08. This matters if a script uses `openssl` to decode or convert p12 files (https://github.com/actions/runner-images/issues/14856).
- Choose the Xcode version with `sudo xcode-select -s /Applications/Xcode_26.6.app` (paths listed in the READMEs).

**Secure signing in CI (best practice; general knowledge, partly verified):**
1. Store the Developer ID `.p12` as a base64 GitHub **secret**. Create a temporary keychain (`security create-keychain`, `set-keychain-settings -lut 21600`, `unlock-keychain`). Import with `security import cert.p12 -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k $KEYCHAIN`. Run `security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PW" $KEYCHAIN`. Delete the keychain in an `if: always()` step. GitHub's official guide: https://docs.github.com/en/actions/use-cases-and-examples/deploying/installing-an-apple-certificate-on-macos-runners-for-xcode-development **[URL from general knowledge, not re-fetched]**
2. Notarize with an **App Store Connect API key** (.p8 stored as a secret, written to `$RUNNER_TEMP`, then `notarytool submit --key --key-id --issuer --wait`). This avoids storing an Apple ID password or 2FA. Give the key the least role needed (Developer) **[role requirement UNVERIFIED]**.
3. Store the Sparkle EdDSA private key as a secret and sign with `sign_update` (or `generate_appcast --ed-key-file`). Never commit it.
4. Use GitHub **environments** with required reviewers for release jobs, and don't expose secrets to `pull_request` builds from forks.
