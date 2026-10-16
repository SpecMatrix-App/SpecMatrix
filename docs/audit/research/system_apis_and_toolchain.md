# API / Toolchain Research for SpecMatrix audit (as of 2026-10-15)

Legend: **[DOC]** Apple documentation (fetched via developer.apple.com doc JSON), **[HDR]** header in local Xcode 27.0 (27A266a) SDK, **[DTS]** Apple staff forum reply, **[EMP]** empirically tested on this machine (MacBook Air M2 "Mac14,2", macOS 27.2 / Darwin 27.2.0) with an ad-hoc signed probe run both unsandboxed and inside App Sandbox (container created at ~/Library/Containers/com.example.sbprobe), **UNVERIFIED** = could not confirm.

Local check: `xcodebuild -version` → `Xcode 27.0 / Build version 27A266a` [EMP]; installed simulator runtimes: only `iOS 27.0 (24A434)` [EMP].

---

## A. Xcode 27 toolchain floors

Source: https://developer.apple.com/support/xcode/ and https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes

| Item | Xcode 27 / 27.1 RC / 27.2 b3 | Xcode 26.x (for comparison) | Source |
|---|---|---|---|
| Host macOS | macOS Tahoe 26.6 or later; **Apple silicon only** ("Xcode 27 will only install and run on Apple silicon Macs") | 26.0: Sequoia 15.6–Tahoe; 26.6: Tahoe 26.2+ | support/xcode; X27 release notes |
| SDKs | iOS/iPadOS/tvOS/watchOS/visionOS/macOS 27 (27.1, 27.2 in point releases) | 26.x | support/xcode |
| **Deployment targets** | **iOS 15–27, iPadOS 15–27, macOS 12–27**, tvOS 15–27, watchOS 9–27, visionOS 1–27 | iOS 15–26, macOS 11–26 | support/xcode |
| **On-device run/debug** | **iOS 17 or later** (tvOS 17+, watchOS 10+) — "Xcode 27 supports on-device debugging in iOS 17 and later" | iOS 15+ | support/xcode; X27 release notes |
| **Simulator runtimes** | **iOS 17 or later** | iOS 15+ | support/xcode |
| Instruments | requires target devices iOS 17+/watchOS 10+/tvOS 17+ (166097304) | — | X27 release notes |
| Swift | 6.4 compiler; modes 6/5/4.2/4 | 6.2/6.3 | support/xcode |
| Intel | macOS 27 SDK can still back-deploy Universal apps to macOS 12+; targets with min macOS 27.0 drop x86_64 from ARCHS by default (161837535) | — | X27 release notes |
| libc++ | min macOS deployment for C++ stdlib raised to 11.0 | — | X27 release notes |

Answers:
- **Can Xcode 27 build for iOS 16 / macOS 13?** YES. Floors are iOS 15 and macOS 12 (support page "Deployment Target" column, defined there as the range supported for uploads to App Store Connect).
- **Can Xcode 27 run/debug on an iOS 16 device?** NO. Device Support starts at iOS 17. An iOS 16 build can be produced (and archived/uploaded), but testing on iOS 16 hardware needs Xcode 26.x (Device Support iOS 15+), or an ad-hoc/TestFlight install with no debugger attached. The TestFlight/ad-hoc route is an inference: UNVERIFIED as Apple-documented.
- **iOS 16 simulator in Xcode 27?** NO. The Simulator column says iOS 17 or later, so iOS 17/18/26/27 runtimes are supported and iOS 16 is not. That iOS 17/18 runtimes are actually *offered for download* in Xcode 27's Components pane is UNVERIFIED. Only the iOS 27 runtime is installed locally.
- **macOS 13 testing**: the deployment target is fine (12+). Running Xcode 27 itself needs Tahoe 26.6+, so testing on macOS 13 needs a separate machine or VM.
- **App Store minimum SDK (context only):** since **April 28, 2026**, uploads to App Store Connect must be built with **Xcode 26+ using an iOS/iPadOS/tvOS/visionOS/watchOS 26 SDK**. https://developer.apple.com/news/upcoming-requirements/ (seen via search snippet). This limits the SDK, not the deployment target. Whether a 2027 bump to the 27 SDK has been announced is UNVERIFIED (not found).

---

## B. API-by-API

### B1. Device identity

| API | Availability | Reports | Permission / sandbox | Source |
|---|---|---|---|---|
| `uname()` → `utsname.machine` | POSIX, all | iOS device: model identifier e.g. "iPhone16,1". **Simulator: host arch ("arm64")**; the sim model is in env `SIMULATOR_MODEL_IDENTIFIER` (community-documented, UNVERIFIED by Apple doc). **macOS Apple silicon: "arm64"** [EMP] | none | [EMP]; https://forum.xojo.com/t/get-real-device-type-from-ios-device/72450 |
| `sysctlbyname("hw.model")` (macOS) | macOS | Model identifier, e.g. **"Mac14,2"** on M2 MacBook Air (so "Mac15,3"-style on M3) [EMP]. On iOS, hw.model returns the board ID (e.g. "D83AP") rather than the marketing identifier: UNVERIFIED | Works **inside App Sandbox** [EMP] | [EMP]; https://developer.apple.com/forums/thread/767659 |
| `sysctlbyname("hw.machine")` (macOS) | macOS | "arm64" on Apple silicon [EMP] (so on macOS, use hw.model, not hw.machine) | sandbox OK [EMP] | [EMP] |
| Marketing name ("MacBook Air (M2, 2022)") | — | **No public API.** IORegistry `IODeviceTree:/product` → `product-name` returns it and is readable **even in App Sandbox** [EMP], but DTS says undocumented IORegistry properties and `Apple*` classes "are not considered API… not the path to long-term binary compatibility". Ship your own identifier→name table | — | https://developer.apple.com/forums/thread/767659 [DTS]; [EMP] |

### B2. CPU topology (sysctl)

| Key | Availability | Notes | Sandbox | Source |
|---|---|---|---|---|
| `hw.nperflevels`, `hw.perflevelN.physicalcpu[_max]`, `.logicalcpu[_max]`, `.l1d/l1i/l2cachesize`, `.name` | macOS 12+ (Apple silicon and Intel). **Also documented in the iOS SDK `sys/sysctl.h`** (18 perflevel references in iPhoneOS27 SDK) | "perflevel 0 always refers to the highest performance core type". physicalcpu is the count "available in the current power management mode"; `*max` is the boot maximum | macOS sandbox OK [EMP] (M2: 2 levels, 4P+4E). iOS: readable from app sandbox is UNVERIFIED (widely used in practice) | [HDR] MacOSX27 `sys/sysctl.h` L679–692; [EMP] |
| `machdep.cpu.brand_string` | macOS: "Apple M2" on Apple silicon [EMP] | Value on iOS UNVERIFIED (reported not to exist or to be empty on iOS) | macOS sandbox OK [EMP] | [EMP] |
| `ProcessInfo.processorCount` | iOS 2 / macOS 10.5 | = `sysctl hw.ncpu` | none | https://developer.apple.com/documentation/foundation/processinfo/processorcount |
| `ProcessInfo.activeProcessorCount` | iOS 2 / macOS 10.5 | = `hw.logicalcpu`. Can be lower due to thermal throttling, boot args, etc. | none | https://developer.apple.com/documentation/foundation/processinfo/activeprocessorcount |

### B3. Memory / thermal / power

| API | Availability | Reports | Notes / restrictions | Source |
|---|---|---|---|---|
| `ProcessInfo.physicalMemory` | iOS 2, macOS 10.5 | physical RAM bytes | none | https://developer.apple.com/documentation/foundation/processinfo/physicalmemory |
| `ProcessInfo.thermalState` | iOS 11, macOS 10.10.3 | nominal/fair/serious/critical. Must read the property before registering for `thermalStateDidChangeNotification` | none | https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.property ; [HDR] NSProcessInfo.h L503 |
| `ProcessInfo.isLowPowerModeEnabled` | iOS 9, **macOS 12.0** | bool. Notification: `NSProcessInfoPowerStateDidChange` | none | https://developer.apple.com/documentation/foundation/processinfo/islowpowermodeenabled |
| `os_proc_available_memory()` | iOS 13 (**not macOS**; tvOS/watchOS/visionOS/Catalyst) | **app's** remaining headroom (limit minus footprint), not device free RAM. Returns 0 if not an app. Advisory, don't cache | none | https://developer.apple.com/documentation/os/os_proc_available_memory |
| `task_info(TASK_VM_INFO).phys_footprint` | all | app's own footprint (the value Xcode and jetsam use) | none. DTS recommends footprint for "app memory used" | https://developer.apple.com/forums/thread/118867 [DTS] |
| `host_statistics64(HOST_VM_INFO64)` | macOS; **works on iOS** | system VM page counts (free/active/inactive/wired/compressed). Page size is 16 KiB on arm64, so use `vm_kernel_page_size`/`getpagesize`, never hard-code 4096 | DTS: "host_statistics *is* available on iOS" and App Review accepts it, but "free memory" is "unlikely to be useful". Not a required-reason API category. Works in macOS sandbox [EMP] | https://developer.apple.com/forums/thread/118867 , https://developer.apple.com/forums/thread/723334 [DTS]; [EMP] |

### B4. Battery

| API | Platform | Reports | Notes | Source |
|---|---|---|---|---|
| `UIDevice.batteryLevel` | iOS 3+, Catalyst, visionOS | 0.0–1.0, or −1.0 if monitoring is off (set `isBatteryMonitoringEnabled = true`) | **Since iOS 17 it is rounded to 0.05 (5%) steps** (1% on iOS 16). Apple Frameworks Engineer: "as accurate as it is intended to be". DTS (Quinn, 2025): "The API does not specify the degree to which the battery level value is rounded"; no workaround | https://developer.apple.com/documentation/uikit/uidevice/batterylevel ; https://developer.apple.com/forums/thread/732903 [DTS] |
| `UIDevice.batteryState` | iOS 3+ | unknown/unplugged/charging/full (`unknown` if monitoring is off) | — | https://developer.apple.com/documentation/uikit/uidevice/batterystate-swift.property |
| iOS battery health / cycle count | — | **No public API.** iOS 17.4+ shows cycle count, manufacture date and first use in Settings (iPhone 15+) only | forum consensus: no API | https://developer.apple.com/forums/thread/762565 , https://developer.apple.com/forums/thread/737611 ; https://www.tomsguide.com/phones/iphones/apples-ios-174-update-features-new-insight-into-your-iphones-battery-life |
| macOS `IOPSCopyPowerSourcesInfo` / `IOPSGetPowerSourceDescription` | macOS | Public keys: `kIOPSCurrentCapacityKey` ("Current Capacity"), `kIOPSMaxCapacityKey`, `kIOPSDesignCapacityKey`, `kIOPSNominalCapacityKey`, time to empty/full, is charging/charged, `kIOPSBatteryHealthKey`, `kIOPSBatteryHealthConditionKey`. **No cycle-count key in IOPSKeys.h.** On Apple silicon, Current/Max are **percent** (42/100) [EMP]. BatteryHealth was **not** present in the dict on macOS 27 [EMP]. Keys actually returned: Current, Current Capacity, DesignCycleCount, Hardware Serial Number, Is Charging, LPM Active, Max Capacity, Name, Power Source State, Time to Empty/Full… [EMP] | Works in App Sandbox, no entitlement [EMP] | [HDR] IOKit `ps/IOPSKeys.h` L329–631; [EMP] |
| `AppleSmartBattery` IORegistry (`CycleCount`, `AppleRawMaxCapacity`, `DesignCapacity` within `BatteryData`) | macOS | Real cycle count (164 here) and raw mAh | **Readable in App Sandbox** [EMP], but it is an undocumented `Apple*` class, so DTS says it is not API (B1 link). `DesignCapacity` is top-level nil on Apple silicon; it lives inside `BatteryData` dict [EMP] | [EMP]; https://developer.apple.com/forums/thread/767659 |

### B5. Display

| API | Availability | Notes | Source |
|---|---|---|---|
| `UIScreen.main` | iOS 2 – **deprecated iOS 26.0** (also tvOS 26, visionOS 26); "Use a UIScreen instance found through context instead (i.e., view.window.windowScene.screen)" | Prior to 26 it was only "discouraged" in docs (UNVERIFIED exact first wording; formal API_DEPRECATED is 26.0). Replacement `UIWindowScene.screen` iOS 13+ | https://developer.apple.com/documentation/uikit/uiscreen/main ; [HDR] UIScreen.h L57 |
| `UIScreen.maximumFramesPerSecond` | iOS 10.3 | up to 120 on ProMotion | https://developer.apple.com/documentation/uikit/uiscreen/maximumframespersecond |
| `UIScreen.brightness` | iOS 5 | 0–1, main screen only. Settable; reverts on lock | https://developer.apple.com/documentation/uikit/uiscreen/brightness |
| `UIScreen.brightnessDidChangeNotification` | iOS 5 | object = UIScreen, no userInfo | https://developer.apple.com/documentation/uikit/uiscreen/brightnessdidchangenotification |
| `NSScreen.maximumFramesPerSecond` | **macOS 12.0** | — | https://developer.apple.com/documentation/appkit/nsscreen/maximumframespersecond |
| `NSScreen.localizedName` | macOS 10.15 | e.g. "Built-in Liquid Retina Display" | https://developer.apple.com/documentation/appkit/nsscreen/localizedname |
| `CGDisplayCopyAllDisplayModes` | macOS 10.6 | available modes (width/height/refresh). Caller releases (CF) | https://developer.apple.com/documentation/coregraphics/cgdisplaycopyalldisplaymodes(_:_:) |
| `NSScreen.maximumPotentialExtendedDynamicRangeColorComponentValue` | macOS 10.15 | >1.0 means EDR-capable. Static | https://developer.apple.com/documentation/appkit/nsscreen/maximumpotentialextendeddynamicrangecolorcomponentvalue |
| `NSScreen.maximumExtendedDynamicRangeColorComponentValue` | macOS 10.11 | current headroom. 1.0 unless EDR content is on screen | https://developer.apple.com/documentation/appkit/nsscreen/maximumextendeddynamicrangecolorcomponentvalue |

### B6. Storage

| API | Availability | Reports | Source |
|---|---|---|---|
| `URLResourceKey.volumeAvailableCapacityForImportantUsageKey` | iOS 11, macOS 10.13 | space available for "important" resources. **Includes purgeable space**, so it is larger than raw free space (322 GB vs `systemFreeSize` 315 GB here [EMP]). Best match for Settings' "available" | https://developer.apple.com/documentation/foundation/urlresourcekey/volumeavailablecapacityforimportantusagekey |
| `FileAttributeKey.systemFreeSize` (`attributesOfFileSystem`) | iOS 2, macOS 10.0 | raw `statfs()` free bytes, excluding purgeable | https://developer.apple.com/documentation/foundation/fileattributekey/systemfreesize |
| `volumeTotalCapacityKey` | iOS 4, macOS 10.6 | total volume bytes | https://developer.apple.com/documentation/foundation/urlresourcekey/volumetotalcapacitykey |
All three are **required-reason APIs (Disk space)**, see B7. All work in macOS App Sandbox [EMP].

### B7. Privacy manifest (PrivacyInfo.xcprivacy), "required reason APIs"

Doc scope: "Describe the reasons your app or third-party SDK on **iOS, iPadOS, tvOS, visionOS, or watchOS** uses these APIs". **macOS is not listed.** Enforcement: "Starting May 1, 2024, apps that don't describe their use of required reason API in their privacy manifest file aren't accepted by **App Store Connect**". So it is an App Store upload gate and has no effect on direct, Developer ID, or ad-hoc distribution (harmless to include anyway). Sources: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api , https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype

| Category (NSPrivacyAccessedAPIType) | Covered APIs relevant here | Reason codes likely for a spec app |
|---|---|---|
| `NSPrivacyAccessedAPICategoryDiskSpace` | volumeAvailableCapacityKey, volumeAvailableCapacityForImportantUsageKey, …ForOpportunisticUsageKey, volumeTotalCapacityKey, systemFreeSize, systemSize, statfs/statvfs/fstatfs/fstatvfs, getattrlist… | **85F4.1** (display disk space to the user, no off-device). E174.1 (check space before writing). 7D9E.1 (user-initiated bug report) |
| `NSPrivacyAccessedAPICategorySystemBootTime` | `systemUptime`, `mach_absolute_time()` | **35F9.1** (elapsed time between in-app events / timers). 8FFB.1 (absolute timestamps of in-app events). 3D61.1 (bug report). Note: *displaying* uptime/boot time to the user has **no listed reason**. 35F9.1 covers measuring in-app intervals only |
| `NSPrivacyAccessedAPICategoryUserDefaults` | `UserDefaults` | **CA92.1** (app-only). 1C8F.1 (App Group). AC6B.1 (MDM) |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | creationDate, modificationDate, contentModificationDateKey, creationDateKey, stat/fstat/lstat, getattrlist… | **C617.1** (files in own container). DDA9.1 (display timestamps). 3B52.1 (user-picked files) |
| `NSPrivacyAccessedAPICategoryActiveKeyboards` | activeInputModes | (not relevant) |
`sysctl hw.*`, `uname`, `host_statistics64`, ProcessInfo memory/CPU are **not** in any listed category (per the category list above).

### B8. Networking / cellular / Wi-Fi

| API | Availability | Status / notes | Source |
|---|---|---|---|
| `CTCarrier` | iOS 4 – **deprecated iOS 16.0, "Deprecated with no replacement"**. Returns placeholder values on 16.4+ (UNVERIFIED exact version; widely reported as "--"/65535) | — | https://developer.apple.com/documentation/coretelephony/ctcarrier |
| `CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology` | iOS 12 | **Not deprecated.** Dict serviceID→`CTRadioAccessTechnology*` (LTE, NRNSA, NR…), nil if not registered. No permission | https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/servicecurrentradioaccesstechnology |
| `NWPathMonitor` | iOS 12, macOS 10.14 | path status, interface types (wifi/cellular/wired), isExpensive, isConstrained. No permission. Sandbox: needs `com.apple.security.network.client` for network use. For monitoring alone, UNVERIFIED | https://developer.apple.com/documentation/network/nwpathmonitor |
| iOS Wi-Fi: `NEHotspotNetwork.fetchCurrent` | iOS 14 | SSID/BSSID/**signalStrength (0–1)**. Requires the **`com.apple.developer.networking.wifi-info` entitlement** AND one of: precise-location authorization, a NEHotspotConfiguration-configured network, an active VPN config, or an NEDNSSettingsManager config. No public API for **link speed** on iOS | https://developer.apple.com/documentation/networkextension/nehotspotnetwork/fetchcurrent(completionhandler:) |
| macOS `CoreWLAN` `CWInterface.rssiValue()` / `transmitRate()` / `ssid()` | macOS 10.7 / 10.7 / 10.6 | Header: "SSID [and BSSID, countryCode] information is not available unless Location Services is enabled and the user has authorized the calling app". **RSSI and transmitRate have no location note** and returned −51 dBm / 1200 Mbps unsandboxed with ssid=nil (no location auth) [EMP]. **In App Sandbox, `CWWiFiClient.shared().interface()` returned nil until `com.apple.security.network.client` was added**, then rssi/tx worked [EMP]. DTS: location requirement since macOS 14 | [HDR] CWInterface.h L101–204; https://developer.apple.com/forums/thread/732431 [DTS]; [EMP] |

### B9. Metal / GPU

| API | Availability | Notes | Source |
|---|---|---|---|
| `MTLDevice.supportsFamily(_:)` | iOS 13, macOS 10.15 | — | https://developer.apple.com/documentation/metal/mtldevice/supportsfamily(_:) |
| `.apple9` | case exists in iOS 17 / macOS 14 SDK era. Doc: "Apple A17, M3, and M4 GPUs" | No per-case availability macro (enum is iOS 13+), so it compiles for older targets. M2 → false [EMP] | https://developer.apple.com/documentation/metal/mtlgpufamily/apple9 ; [HDR] |
| `.apple10` | **first in the 26 SDKs** (present in MacOSX26.sdk, absent before) [HDR] | doc abstract empty. M2 → false [EMP]. Requires building with Xcode 26+ | [HDR] |
| `.apple11` | **new in the 27 SDKs** (iPhoneOS27/MacOSX27 headers) | UNVERIFIED which chips | [HDR] |
| `.metal3` | **iOS 16 / macOS 13** (API_AVAILABLE) | M2 → true | https://developer.apple.com/documentation/metal/mtlgpufamily/metal3 |
| `.metal4` | **iOS 26 / macOS 26** (API_AVAILABLE, so needs `if #available(iOS 26, macOS 26, *)`) | WWDC25: Metal 4 on M1+ and A14+. M2 → true [EMP] | https://developer.apple.com/documentation/metal/mtlgpufamily/metal4 ; https://developer.apple.com/videos/play/wwdc2025/205/ |
| `MTLDevice.name` | iOS 8, macOS 10.11 | e.g. "Apple M2" [EMP] | https://developer.apple.com/documentation/metal/mtldevice/name |
| `recommendedMaxWorkingSetSize` | **iOS 16**, macOS 10.12 | bytes GPU can use without perf hit (5.73 GB on 8 GB M2) [EMP] | https://developer.apple.com/documentation/metal/mtldevice/recommendedmaxworkingsetsize |
| GPU core count | — | **No public API on iOS or macOS** (none found in MTLDevice docs). macOS IORegistry `AGXAccelerator` → `gpu-core-count` = 10 is readable **inside App Sandbox** [EMP] but is undocumented (DTS: not API). iOS: no route (UNVERIFIED that IOKit reads are blocked; IOKit is not usable for this on iOS) | https://developer.apple.com/documentation/metal/mtldevice ; https://developer.apple.com/forums/thread/767659 ; [EMP] |

### B10. Camera (AVFoundation)

| API | Availability | Notes | Source |
|---|---|---|---|
| `AVCaptureDevice.DiscoverySession` | iOS 10, macOS 10.15, Catalyst 14 (Catalyst lists **no devices** per forum), visionOS 2.1 | device types (wide/ultraWide/telephoto/dual/triple/TrueDepth/LiDAR…), position | https://developer.apple.com/documentation/avfoundation/avcapturedevice/discoverysession ; https://developer.apple.com/forums/thread/123883 |
| `AVCaptureDevice.lensAperture` | iOS 8 (**not macOS**) | f-number, constant | https://developer.apple.com/documentation/avfoundation/avcapturedevice/lensaperture |
| `Format.videoFieldOfView` | iOS 7 (not macOS) | horizontal FOV, degrees. 0 if unknown | https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/videofieldofview |
| `Format.supportedMaxPhotoDimensions` | **iOS 16 / macOS 13** | max photo dims per format | https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/supportedmaxphotodimensions |
| Permission | — | Docs tie the prompt and authorization to **capture**: "The first time you create an AVCaptureDeviceInput … the system automatically displays an alert"; without permission, "the system only vends black video frames". `NSCameraUsageDescription` is required for requestAccess/capture. **Enumerating devices/formats without authorization: UNVERIFIED** in docs (works in practice on iOS. A forum post claims the macOS prompt is triggered on discovery-session creation, UNVERIFIED). macOS sandbox needs `com.apple.security.device.camera` to capture | https://developer.apple.com/documentation/avfoundation/avcapturedevice/requestaccess(for:completionhandler:) ; [HDR] AVCaptureInput.h L192 |

### B11. Settings deep link / SwiftUI

| Item | Status | Source |
|---|---|---|
| `App-prefs:` / `prefs:root=` | **Non-public URL scheme.** Repeated App Review rejections under **Guideline 2.5.1** ("Apps may only use public APIs"), which treats them as private entities | https://developer.apple.com/forums/thread/100471 ; https://developer.apple.com/app-store/review/guidelines/ |
| `UIApplication.openSettingsURLString` | iOS 8+. Opens **your app's** page in Settings (the only supported target). iOS 16+ also has `openNotificationSettingsURLString` (UNVERIFIED version, not fetched) | https://developer.apple.com/documentation/uikit/uiapplication/opensettingsurlstring |
| `onChange(of:initial:_:)` | **iOS 17 / macOS 14** / watchOS 10 / tvOS 17 | https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:)-8wgw9 |
| `onChange(of:perform:)` | iOS 14–**deprecated iOS 17** / macOS 11–**deprecated 14**. Behavior differs: old closure captures pre-change state, new captures post-change | https://developer.apple.com/documentation/swiftui/view/onchange(of:perform:) |
So with deployment target iOS 16 / macOS 13, code must branch with `if #available(iOS 17, macOS 14, *)` or use the deprecated form (warning only).

---

## C. macOS App Sandbox & distribution

| Question | Answer | Source |
|---|---|---|
| Sandbox required for Mac App Store? | Yes. Guideline 2.4.5(i): "They must be appropriately sandboxed" | https://developer.apple.com/app-store/review/guidelines/ |
| Sandbox required for Developer ID? | **No** | https://developer.apple.com/forums/thread/746048 (DTS) and Hardened Runtime docs |
| Hardened Runtime for notarization? | **Yes.** "To upload a macOS app to be notarized, you must enable the Hardened Runtime capability" (Hardened Runtime doc, quoted in thread). DTS: "we clearly document the hardened runtime requirement for Developer ID programs… On the Mac App Store front, AFAIK it's still optional" | https://developer.apple.com/forums/thread/746048 ; https://developer.apple.com/documentation/security/hardened-runtime |

Sandbox requirements per API (macOS 27.2, ad-hoc signed, `com.apple.security.app-sandbox` only) [EMP]:

| API | Works sandboxed? | Extra entitlement |
|---|---|---|
| sysctl hw.model / hw.machine / hw.nperflevels / hw.perflevelN.* / machdep.cpu.brand_string / hw.memsize; uname | Yes | none |
| IORegistry: `IODeviceTree:/product` product-name, `IOPlatformExpertDevice` model, `AGXAccelerator` gpu-core-count, `AppleSmartBattery` CycleCount | Yes (readable) | none (but unsupported/undocumented properties) |
| IOPSCopyPowerSourcesInfo / IOPSGetPowerSourceDescription | Yes | none |
| host_processor_info, host_statistics64 | Yes (KERN_SUCCESS) | none |
| Metal device / families / recommendedMaxWorkingSetSize | Yes | none |
| ProcessInfo (lowPower, thermal, memory, cpu counts) | Yes | none |
| FileManager volume capacity keys / systemFreeSize on "/" | Yes | none |
| CoreWLAN `CWWiFiClient.shared().interface()` rssi/transmitRate | **No without entitlement** (interface nil) → **Yes with `com.apple.security.network.client`**. SSID also needs Location authorization | `com.apple.security.network.client` (+ Location for SSID/BSSID) |
| AVCapture capture | — | `com.apple.security.device.camera` + NSCameraUsageDescription (UNVERIFIED for enumeration alone) |

---

## D. System-wide CPU utilization

| Platform | API | Status | Source |
|---|---|---|---|
| macOS | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` (per-CPU user/system/idle/nice ticks, delta between samples) | Works, including in App Sandbox (kr=0, 8 CPUs) [EMP]. Remember to `vm_deallocate` the returned array | [EMP] |
| iOS | `host_processor_info` / `host_statistics(HOST_CPU_LOAD_INFO)` | Declared in iOS SDK `mach/mach_host.h` [HDR]. DTS: no *supported* way to get system-wide load info on iOS. Use Instruments/MetricKit; Mach host APIs are for "custom testing tools". Apps are meant to see only themselves. **Whether it still returns real data on iOS 17+ devices: UNVERIFIED** (no Apple statement found; not a required-reason API; App Review acceptance of host_* APIs in general is confirmed by DTS for host_statistics memory) | https://developer.apple.com/forums/thread/696700 , https://developer.apple.com/forums/thread/11393 , https://developer.apple.com/forums/thread/118867 [DTS]; [HDR] |
| iOS (own process) | `task_threads` + `thread_info(THREAD_BASIC_INFO)` sum | supported pattern for own-app CPU | https://developer.apple.com/forums/thread/762300 |
