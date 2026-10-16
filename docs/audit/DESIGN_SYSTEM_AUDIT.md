# SpecMatrix: Design System Audit

Audit date: 2026-10-15. API availability comes from Apple DocC metadata; see `RESEARCH_SOURCES.md` §C.
**Limitation:** no screenshots of the running app could be captured, because the simulator service failed (`TESTING_STRATEGY.md` §8). This assessment is based on reading the SwiftUI source only.

## 1. Existing design assessment

| Aspect | Current implementation | Assessment |
|---|---|---|
| Navigation | A 5-tab `TabView` (Specs, Network, Display, Camera, Settings). Each tab is a `ScrollView` with a hero symbol and title. There is no `NavigationStack`, except a deprecated `NavigationView` in Settings. | Workable on iPhone, but it does not scale to iPad or Mac. There are no navigation bars, no search, and no drill-down. "Camera" and "Display" each hold one card, which is too little to justify a tab of their own. |
| Layout | Single column `VStack(spacing: 20)`; every card uses `GroupBox` + `.padding(.horizontal)` | Consistent, but there is no width constraint, so cards would stretch edge-to-edge on iPad. The iPhone landscape orientation is enabled but has not been designed for. |
| Cards | The `GroupBox` → icon + headline → `Divider` → `InfoRow` pattern is repeated in 8 views (BatteryInfoView, SystemInfoView, CPUInfoView, GPUInfoView, MemoryInfoView, StorageInfoView, NetworkInfoView, ScreenInfoView). `CameraInfoView` deviates. | The pattern is good and should become a component. It is currently copied about 8 times. |
| Rows | `InfoRow(label:value:)`: secondary subheadline label, medium-weight value | The right primitive. It is missing units handling, a provenance/"estimated" badge, an accessibility combination, and selection/copy support. |
| Colour | Hard-coded `.blue`, `.green`, `.red`, `.orange`, `.yellow`, `.secondary`; `AccentColor` is empty | There are no semantic tokens, and battery state is conveyed by colour alone. |
| Typography | Text styles (`.headline`, `.subheadline`, `.title`), plus a fixed `.system(size: 60)` for the hero icons | Mostly Dynamic Type friendly. The hero icons do not scale and take up the first screen. |
| Iconography | SF Symbols. `battery.unknown` and `battery.<n>` are **invalid names**, so they render blank (verified, CB-04). | Fix the mappings. |
| Data visualisation | One custom brightness bar (GeometryReader + Rectangles) | No accessibility value. Swift Charts and `Gauge` (iOS 16) are unused. |
| Empty/unavailable states | A "Hidden — enable in Settings" placeholder repeated 3 times; no loading or error states; zeros and `nan%` on failure | Missing. |
| Appearance | A Light/Dark/System picker, which is not persisted (CB-09) | Fine conceptually; keep it as a setting backed by `@AppStorage`. |
| Accessibility | Theme rows use `onTapGesture`, so they are not buttons; decorative icons are not hidden; there are no `accessibilityLabel` combinations on rows | Needs work (CB-19). |
| Liquid Glass | None. The project was created in Xcode 16.2. Building with Xcode 26+ makes the standard `TabView` adopt Liquid Glass automatically on 26+. Under Xcode 27 the `UIDesignRequiresCompatibility` opt-out is ignored. | Adoption is effectively mandatory for any rebuild with the current toolchain. |

## 2. Recommended interface architecture

### 2.1 Information architecture (all platforms)

Replace "one tab per hardware area" with a structure built around **the host device** and **the catalog**:

| Section | Content | iPhone | iPad / Mac |
|---|---|---|---|
| **This Device** | Identity header (marketing name, identifier, OS), then grouped sections: Chip, Memory, Storage, Battery, Display, Cameras, Connectivity, System state | Tab 1 → `NavigationStack` list of sections → detail | Sidebar item → content column of sections → detail column |
| **Live** (monitoring) | Thermal state, Low Power Mode, battery level/state, app memory footprint, storage, network path; on macOS also CPU load | Tab 2 | Sidebar item; on Mac optionally a menu bar extra |
| **Catalog** (Phase 4+) | Browse and search Apple devices; detail pages; compare | Tab 3 (with a search role) | Sidebar with search; a `Table` on iPad regular width and on Mac |
| **Settings** | Appearance, units, about, data sources and catalog version | Tab 4 | iPad: sheet or sidebar item. Mac: the `Settings` scene (⌘,) |

Drop the per-section "hide" toggles. If customisation is wanted, offer an "Edit Live dashboard" mode later.

### 2.2 Component inventory (shared SwiftUI, in a design-system module)

| Component | Purpose | Notes |
|---|---|---|
| `SpecSection` | Titled group of rows (replaces the GroupBox cards) | On iOS, renders as a `Section` in an inset-grouped `List`. On Mac, as `Form(.grouped)`. Gives native density and platform behaviour for free. |
| `SpecRow` | Label / value / optional unit / **provenance badge** | Badge values: *Measured*, *Catalog*, *Derived*, *Estimated*, *Unavailable*. Supports `.textSelection(.enabled)` and copy, plus a combined accessibility element (“Chip, A18 Pro, from catalog”). |
| `ProvenanceBadge` | Small glyph or caption explaining the source | Tap or hover for an explanation popover. This is the core of the app's honesty story. |
| `MetricGauge` | Battery, storage, app-memory gauges | `Gauge` (iOS 16 / macOS 13), with an accessibility value |
| `LiveSparkline` | Short history for sampled values | Swift Charts (iOS 16 / macOS 13) |
| `UnavailableNotice` | “Not available to apps on iOS” with the reason | A `ContentUnavailableView` look-alike built from basic views on iOS 16 / macOS 13; the real `ContentUnavailableView` on 17+ via the compat layer |
| `DeviceHeader` | Product symbol, name, identifier, OS | Uses SF Symbols device glyphs such as `iphone.gen3` and `macbook` (validate the names). |

### 2.3 Tokens

- **Colour:** semantic tokens in the asset catalog (`StatusGood`, `StatusWarning`, `StatusCritical`, `ProvenanceCatalog`, `ProvenanceEstimated`), each with light, dark, and increased-contrast variants. Fill `AccentColor`. Avoid raw `.blue`.
- **Typography:** text styles only. Show numeric values with `.monospacedDigit()`. Never use fixed point sizes.
- **Spacing:** rely on `List`/`Form` platform metrics. Define three custom spacing constants at most, and only for dashboards.
- **Formatting:** one `SpecFormatters` set (`Measurement` + `FormatStyle`, `ByteCountFormatStyle` with an explicit decimal/binary policy, locale-aware percent). Units must be consistent: storage in decimal GB (matching Apple's marketing), RAM in GB as marketed for catalog values, measured RAM labelled “GiB, as visible to the OS”. Write the policy down (TD-10).

## 3. Liquid Glass strategy (OS 26 and later)

Principles from Apple's “Adopting Liquid Glass” and the HIG Materials guidance:
- Liquid Glass belongs to the **navigation and control layer**, not to content.
- Prefer system components, and remove custom bar backgrounds.
- Use custom glass sparingly, and group it in `GlassEffectContainer`.
- Use clear glass only over rich backgrounds.

| Element | OS 26+ behaviour | How |
|---|---|---|
| Tab bar, toolbars, sidebars, sheets, popovers, menus | **Automatic** when built with the 26/27 SDK | Use standard `TabView`, `NavigationStack`, `NavigationSplitView`, `.toolbar`, `.sheet`. No custom backgrounds. |
| Tab bar minimise on scroll (iPhone) | Opt-in | `.tabBarMinimizeBehavior(.onScrollDown)`, behind `#available(iOS 26, *)` |
| Search tab | Moves to the trailing edge automatically on 26 | `Tab(role: .search)` (iOS 18+), with a fallback for 16/17 |
| Live dashboard summary chips (thermal, LPM, power) floating over a scroll view | Custom glass | `GlassEffectContainer` + `.glassEffect(.regular, in: .capsule)`, in a single wrapper |
| Spec rows, tables, charts | **No glass.** Content layer, readability first | Standard list backgrounds |
| Toolbar groups (Compare, Share/Export, Refresh) | Automatic grouping | `ToolbarSpacer` (26+) to separate groups |
| Sidebar hero/header image on iPad/Mac | Optional | `.backgroundExtensionEffect()` (26+) only if a hero image exists; not needed initially |

WWDC26 notes for the 27 OSes: there is a system-wide Liquid Glass opacity/tint slider, which custom glass picks up automatically, and custom interactive glass now responds to clicks on macOS. Test custom glass against the slider and against **Reduce Transparency** and **Increase Contrast**.

## 4. Fallback strategy (iOS/iPadOS 16–18, macOS 13–15)

- Standard components keep their pre-26 appearance automatically. Do nothing special.
- Custom glass surfaces fall back to `.regularMaterial` (or `.bar`) inside the same shape. Do **not** imitate glass with blur, specular highlights, or gradients. The fallback should be an intentional, flat, native design.
- **Centralise every availability check** in one file in the design-system module, for example:

```swift
extension View {
    @ViewBuilder func smSurface<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26, macOS 26, *) { self.glassEffect(.regular, in: shape) }
        else { self.background(.regularMaterial, in: shape) }
    }
}
```

  Do the same for `smTabBarMinimize()`, `smContentUnavailable(...)`, `smOnChange(of:)` (which wraps the iOS 17 two-parameter `onChange`), and `smSearchTab`. Screens never contain `#available` checks.
- A screen has **one implementation**. Platform differences are expressed through layout containers (`NavigationSplitView` vs `NavigationStack`, chosen by size class or platform), not through duplicated screens.

## 5. Platform-specific layout guidance

| Platform / class | Layout |
|---|---|
| iPhone (compact) | `TabView` with 3–4 tabs, `NavigationStack` per tab, inset-grouped lists, Live dashboard as a single column of gauges |
| iPhone landscape / iPad compact (Slide Over, narrow Split View) | The same compact composition. Do not show a sidebar. |
| iPad regular | `TabView` with `.sidebarAdaptable` on iOS 18+, or `NavigationSplitView` (sidebar → sections → detail) on 16/17. Live dashboard as a 2–3 column `Grid`/`LazyVGrid` of cards, constrained to a readable width. Catalog as a `Table` with sortable columns. Keyboard shortcuts via `.keyboardShortcut` and `commands`. Pointer hover effects come from standard controls. |
| Mac | `NavigationSplitView` with a sidebar. A minimum window size (about 720 × 480). A toolbar with Refresh, Export and Compare. A `Settings` scene. Menu commands (View → Refresh ⌘R, File → Export Report ⌘E). An optional `MenuBarExtra` with live thermal, battery and CPU (macOS 13+). `Table` for the catalog. `Form(.grouped)` for spec sections. Right-click → Copy on rows. |

## 6. Accessibility and appearance requirements

- **VoiceOver:** each `SpecRow` is one element reading “label, value, unit, source”. Decorative symbols are hidden. Gauges expose a value. Live values use `.accessibilityValue` and do not trigger repeated announcements.
- **Dynamic Type:** test up to AX5. Rows switch to stacked label/value at accessibility sizes (`ViewThatFits` or a `dynamicTypeSize` check).
- **Colour:** never use colour alone. Status always has text or a glyph. Increased-contrast colour variants are required.
- **Reduce Motion:** disable sparkline animation and glass morphing.
- **Reduce Transparency:** verify that the glass and material surfaces remain legible.
- **Keyboard:** full keyboard navigation on iPad and Mac. Focus rings are visible.
- **Localisation readiness:** a String Catalog from day one, no concatenated strings, and units via `Measurement`.
- **Appearance:** Light, Dark and System, persisted. Tinted and dark app icons, plus an Icon Composer `.icon` for 26+ (CB-23).

## 7. Findings

| ID | Sev | Finding | Recommendation |
|---|---|---|---|
| DS-01 | P1 | No reusable components; the card pattern is duplicated about 8 times | `SpecSection`/`SpecRow` in a design-system module |
| DS-02 | P1 | No way to tell measured values from catalog or estimated ones | `ProvenanceBadge` on every row |
| DS-03 | P1 | Information architecture does not scale to iPad or Mac | Sidebar/stack architecture (§2.1, §5) |
| DS-04 | P2 | Invalid SF Symbols render blank (CB-04) | Use symbol constants with a unit test that checks they exist |
| DS-05 | P2 | No semantic colour tokens; meaning carried by colour alone | Tokens + text/glyph pairing |
| DS-06 | P2 | No loading, error or unavailable states | `UnavailableNotice` + explicit state enum |
| DS-07 | P2 | Fixed 60 pt hero icons dominate the first screen | Remove; use a `DeviceHeader` |
| DS-08 | P2 | App icon variants are identical copies | New dark, tinted and layered icons |
| DS-09 | P3 | Inconsistent row styling in `CameraInfoView` | Superseded by `SpecRow` |
