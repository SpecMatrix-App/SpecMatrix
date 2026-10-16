# SpecMatrix: Research Sources

All sources were accessed on **2026-10-15**, unless a different date is noted.

Full per-claim tables, with every URL, are in the appendices:
- `research/ios_ipad_devices.md`: iPhone and iPad identifiers, specifications, Metal families, simulator identifiers
- `research/system_apis_and_toolchain.md`: Xcode 27 support limits, system API availability, sandbox behaviour
- `research/liquid_glass_swiftui_distribution.md`: Liquid Glass and SwiftUI availability, distribution options, CI runners

**Tags:**
- **[A]** Apple primary source.
- **[DTS]** Answer from Apple Developer Technical Support on the developer forums.
- **[HDR]** Read from SDK headers in Xcode 27.0.
- **[X]** Read from Xcode 27.0 CoreSimulator device profiles.
- **[EMP]** Tested empirically on the audit machine (MacBook Air M2, `Mac14,2`, macOS 27.2).
- **[S]** Secondary source.

## A. Hardware facts

| Claim | Source(s) | Tag | Uncertainty |
|---|---|---|---|
| Identifier → marketing name (iPhone13,1 … iPhone19,7) | https://everymac.com/devices/by-identifier/all-iphone-model-identifiers.html ; https://gist.github.com/adamawolf/3048717 ; Xcode 27 CoreSimulator `profile.plist` | S + X | Apple does not publish this mapping. Three sources agree for every iPhone row. The gist mislabels iPad16,3–16,6. |
| iPhone 16 Pro: A18 Pro, 6-core GPU, 16-core NE, 6.3″, 460 ppi, 48 MP UW, 5x tele | https://support.apple.com/en-us/121031 | A | — |
| iPhone 16 Pro Max: 6.9″, 5x tele | https://support.apple.com/en-us/121032 | A | — |
| iPhone 16: "A18" (not Bionic), 5-core GPU, 460 ppi, UW f/2.2 | https://support.apple.com/en-us/121029 | A | — |
| iPhone 16 Plus: 460 ppi | https://support.apple.com/en-us/121030 | A | — |
| iPhone 16e: A18 with 4-core GPU | https://support.apple.com/en-us/122208 | A | — |
| iPhone 15 Plus: 460 ppi | https://support.apple.com/en-us/111830 | A | — |
| iPhone 15 Pro: front 12 MP f/1.9; A17 Pro 6-core GPU | https://support.apple.com/en-us/111829 | A | — |
| iPhone 17 / Air / 17 Pro / 17 Pro Max specifications | https://support.apple.com/en-us/125089 , /125092 , /125090 , /125091 | A | — |
| iPhone 17e (available 2026-03-11) | https://support.apple.com/en-us/126470 ; https://www.apple.com/newsroom/2026/03/apple-introduces-iphone-17e/ | A | RAM unverified |
| iPhone 18 Pro / Pro Max (available 2026-09-18), A20 Pro | https://support.apple.com/en-us/148590 , /148591 ; https://www.apple.com/newsroom/2026/09/apple-debuts-iphone-18-pro-and-iphone-18-pro-max/ | A | RAM unpublished; Metal GPU family unknown |
| No non-Pro iPhone 18 in 2026 | https://support.apple.com/en-us/108044 | A | — |
| Simulator IDs: iPhone 17 = iPhone18,3; iPhone 18 Pro = iPhone19,2; 18 Pro Max = iPhone19,3 (+19,7) | Xcode 27 CoreSimulator profiles | X | Not public documentation |
| iPhone RAM values | https://iphonescompare.com/iphone-ram-comparison ; https://9to5mac.com/2023/11/18/iphone-ram-list/ | S | Apple never publishes it |
| Metal 4 on iPhone 12 or later with iOS 26; Metal 3 from iOS 16; iPad and Mac lists | https://support.apple.com/en-us/102894 | A | Conflicts with the Feature Set Tables on Metal 3 support for the A13 / iPad 9 |
| GPU families (A14 = Apple7 … A19/M5 = Apple10) | https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf (dated 2026-05-21) | A | Predates the A20 Pro |
| iPadOS 16 compatible devices | https://support.apple.com/en-us/103267 | A | — |
| iPad specs, 2021 onward | support.apple.com tech-specs pages listed in `research/ios_ipad_devices.md` §5 | A | Pre-2021 iPad chips not re-verified |
| Mac identifier example `Mac14,2` = MacBook Air M2 | `sysctl hw.model` on the audit machine | EMP | A full Mac catalog was **not researched** |

## B. System APIs and toolchain

| Claim | Source | Tag |
|---|---|---|
| Xcode 27 deployment targets: iOS 15+, macOS 12+. On-device debugging and simulators: iOS 17+. Host requires macOS 26.6+ on Apple silicon. | https://developer.apple.com/support/xcode/ ; https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes | A |
| App Store uploads require Xcode 26+ and the 26 SDKs (since 2026-04-28) | https://developer.apple.com/news/upcoming-requirements/ | A |
| `UIScreen.main` deprecated in iOS 26; use `view.window.windowScene.screen` | https://developer.apple.com/documentation/uikit/uiscreen/main ; UIScreen.h | A, HDR |
| `onChange(of:initial:_:)` requires iOS 17 / macOS 14; `onChange(of:perform:)` deprecated | https://developer.apple.com/documentation/swiftui/view/onchange(of:perform:) | A |
| `UIDevice.batteryLevel` rounded to 5 % steps since iOS 17 | https://developer.apple.com/forums/thread/732903 | DTS |
| No public iOS API for battery health or cycle count | https://developer.apple.com/forums/thread/762565 , /737611 | Forum consensus |
| IOPS power-source keys; no cycle-count key; works in App Sandbox | IOKit `ps/IOPSKeys.h`; probe | HDR, EMP |
| Undocumented IORegistry properties are not API | https://developer.apple.com/forums/thread/767659 | DTS |
| `hw.model` gives the Mac identifier; `uname` and `hw.machine` give `arm64`; `hw.perflevel*` documented in the iOS SDK header | `sys/sysctl.h`; probe | HDR, EMP |
| `host_statistics64` is available on iOS, but its "free memory" value is not useful; use the app footprint instead | https://developer.apple.com/forums/thread/118867 | DTS |
| `os_proc_available_memory` is iOS-only and reports this app's headroom | https://developer.apple.com/documentation/os/os_proc_available_memory | A |
| No supported system-wide CPU load API on iOS; `host_processor_info` works on macOS (including sandboxed) | https://developer.apple.com/forums/thread/696700 ; probe | DTS, EMP |
| `volumeAvailableCapacityForImportantUsageKey` includes purgeable space (322 GB vs 315 GB from `systemFreeSize` on the audit Mac) | https://developer.apple.com/documentation/foundation/urlresourcekey/volumeavailablecapacityforimportantusagekey ; probe | A, EMP |
| Privacy-manifest required-reason APIs (disk space 85F4.1, UserDefaults CA92.1); enforced for App Store Connect uploads only; no approved reason for displaying uptime | https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api | A |
| `CTCarrier` deprecated in iOS 16 with no replacement; `serviceCurrentRadioAccessTechnology` not deprecated | https://developer.apple.com/documentation/coretelephony/ctcarrier | A |
| `NEHotspotNetwork.fetchCurrent` requires an entitlement plus location (or a listed condition) | https://developer.apple.com/documentation/networkextension/nehotspotnetwork/fetchcurrent(completionhandler:) | A |
| CoreWLAN in the App Sandbox needs `network.client`; SSID needs Location | CWInterface.h; probe; https://developer.apple.com/forums/thread/732431 | HDR, EMP, DTS |
| `MTLGPUFamily.metal3` requires iOS 16 / macOS 13; `.metal4` requires iOS 26 / macOS 26; `.apple10` appears in the 26 SDK and `.apple11` in the 27 SDK | https://developer.apple.com/documentation/metal/mtlgpufamily/metal4 ; headers | A, HDR |
| No public GPU core-count API | https://developer.apple.com/documentation/metal/mtldevice | A (absence) |
| `lensAperture` and `videoFieldOfView` are iOS-only; `supportedMaxPhotoDimensions` requires iOS 16 / macOS 13; camera permission is documented for capture only | AVFoundation documentation (see appendix B10) | A; enumeration without permission **unverified** |
| `App-prefs:` is a non-public URL scheme and is rejected under guideline 2.5.1 | https://developer.apple.com/forums/thread/100471 ; App Review Guidelines | Forum, A |
| SF Symbols `battery.unknown` and `battery.<n>` do not exist | `NSImage(systemSymbolName:)` probe on macOS 27.2 | EMP (iOS symbol set assumed equivalent) |
| `mach_host_self()` adds a send-right reference on every call | `mach_port_get_refs` probe | EMP (iOS assumed to behave the same; same XNU) |

## C. UI and distribution

| Claim | Source | Tag |
|---|---|---|
| Liquid Glass APIs (`glassEffect`, `Glass`, `GlassEffectContainer`, `.glass` button styles, `tabBarMinimizeBehavior`, `ToolbarSpacer`, `backgroundExtensionEffect`, `scrollEdgeEffectStyle`) require iOS, iPadOS and macOS 26.0. `tabViewBottomAccessory` is not available on macOS. `Tab(role: .search)` requires iOS 18 / macOS 15. | Apple DocC pages listed in appendix C §1.1 | A |
| Standard components adopt Liquid Glass automatically with the 26 SDK; reduce custom backgrounds | https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass | A |
| `UIDesignRequiresCompatibility` is ignored when building with the 27 SDKs | https://developer.apple.com/documentation/bundleresources/information-property-list/uidesignrequirescompatibility ; https://developer.apple.com/forums/thread/832543 | A, DTS |
| Liquid Glass changes in the 27 OS releases (system opacity slider, interactive glass on macOS) | https://developer.apple.com/videos/play/wwdc2026/269/ | A |
| HIG: use Liquid Glass in the navigation layer and standard materials in the content layer | https://developer.apple.com/design/human-interface-guidelines/materials | A |
| SwiftUI availability matrix (iOS 16/17/18) | Apple DocC; see appendix C §1.5 | A |
| Apple Developer Program fees; Enterprise eligibility | https://developer.apple.com/programs/whats-included/ ; https://developer.apple.com/programs/enterprise/ | A |
| Free Personal Team: 7-day profiles, 3 devices, 3 apps | https://developer.apple.com/support/compare-memberships/ | A |
| Ad Hoc: 100 devices per family per year | https://developer.apple.com/help/account/devices/devices-overview | A |
| TestFlight limits | https://developer.apple.com/testflight/ | A (90-day build expiry not re-verified) |
| EU Web Distribution eligibility; DPLA change effective 2026-10-01 | https://developer.apple.com/support/web-distribution-eu/ ; https://developer.apple.com/support/dma-and-apps-in-the-eu/ | A |
| Developer ID plus Hardened Runtime required for notarization; `notarytool`; stapling; signing the DMG | https://developer.apple.com/documentation/security/resolving-common-notarization-issues ; https://developer.apple.com/documentation/security/customizing-the-notarization-workflow ; https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution | A |
| Sequoia removed the Control-click Gatekeeper override | https://developer.apple.com/news/?id=saqachfa | A |
| `hdiutil create` deprecated in favour of `diskutil image create` | Local `hdiutil` output on macOS 27.2 | EMP |
| macOS 26 is the last release for Intel Macs | https://www.macrumors.com/2026/06/03/macos-27-wont-run-on-these-macs/ ; https://appleinsider.com/articles/26/06/08/macos-27-compatibility-list-focuses-entirely-on-apple-silicon | S (consistent across outlets; Apple's page not fetched) |
| Sparkle 2.10.0: EdDSA signing, sandbox support, macOS 12+ | https://sparkle-project.org/ ; https://github.com/sparkle-project/Sparkle/releases | S (project primary) |
| GitHub Actions runner images and Xcode versions; macos-14 retired 2026-11-02; openssl 4 switch | https://github.com/actions/runner-images (README files and issues #13518, #14404, #14856) | S (vendor primary) |

## D. Known gaps in the research

- Mac identifier and specification catalog: not researched.
- iPhone XS/XR/11/SE 2 and pre-2021 iPads: not re-verified.
- Whether `hw.perflevel*` can be read inside the iOS app sandbox: unverified, test on a device.
- Whether cameras can be enumerated without camera permission (iOS and macOS): unverified.
- Whether `host_processor_info` returns real data on iOS 17+: unverified. It is not recommended regardless.
- Whether Xcode 27 offers iOS 17 and 18 simulator runtimes for download: unverified.
- Install-base share of iOS 16 / macOS 13: no data.
- Status of App Store listing id6740110428: not checked.
