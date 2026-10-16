//
//  InterfaceBehaviorTests.swift
//  SpecMatrixTests
//

import Combine
import SwiftUI
import Testing
import UIKit
@testable import SpecMatrix

/// Runtime checks for the two behaviour changes made with the Phase 3 interface:
/// settings storage that views observe, and monitors owned by the sections that show them.
@MainActor
@Suite(.serialized)
struct InterfaceBehaviorTests {
    /// Counts body evaluations and records the last value a probe view saw.
    final class Recorder {
        var evaluations = 0
        var lastShowNetwork: Bool?
    }

    struct SettingsReader: View {
        let storage: CodableAppStorage<DisplaySettings>
        let recorder: Recorder

        init(key: String, recorder: Recorder) {
            storage = CodableAppStorage(wrappedValue: DisplaySettings(), key)
            self.recorder = recorder
        }

        var body: some View {
            let showNetwork = storage.wrappedValue.showNetwork
            recorder.evaluations += 1
            recorder.lastShowNetwork = showNetwork
            return Text(verbatim: showNetwork ? "shown" : "hidden")
        }
    }

    struct Sibling: View {
        let recorder: Recorder

        var body: some View {
            recorder.evaluations += 1
            return Text(verbatim: "sibling")
        }
    }

    /// A view reading the settings re-renders when another view writes them (as a Settings toggle
    /// does), without any other source of redraws.
    @Test func settingsChangesReachViewsThatReadThem() async throws {
        let key = "displaySettings.observation.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: key) }
        let recorder = Recorder()
        let window = try Self.show(SettingsReader(key: key, recorder: recorder))
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(500))
        #expect(recorder.lastShowNetwork == true)

        let writer = CodableAppStorage(wrappedValue: DisplaySettings(), key)
        writer.projectedValue.wrappedValue.showNetwork = false
        try await Task.sleep(for: .milliseconds(500))
        #expect(recorder.lastShowNetwork == false)
    }

    /// Memory samples re-render only the memory section: a sibling section is not re-evaluated
    /// while the monitor ticks.
    @Test func memorySamplesDoNotRedrawOtherSections() async throws {
        let recorder = Recorder()
        let window = try Self.show(List {
            Section { Sibling(recorder: recorder) }
            MemoryInfoView()
        })
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(500))
        let settled = recorder.evaluations
        try await Task.sleep(for: .seconds(1))
        #expect(settled >= 1)
        #expect(recorder.evaluations == settled)
    }

    /// The memory monitor keeps its existing sampling: it publishes several times per second.
    @Test func memoryMonitorStillPublishesFrequently() async throws {
        let monitor = MemoryMonitor()
        var changes = 0
        let subscription = monitor.objectWillChange.sink { changes += 1 }
        defer { subscription.cancel() }
        try await Task.sleep(for: .seconds(1))
        #expect(changes >= 5)
        #expect(monitor.memoryInfo.totalMemory > 0)
    }

    // MARK: Theme

    private static func preferences(theme: String?) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "SpecMatrixTests.theme.\(UUID().uuidString)")!
        if let theme { defaults.set(theme, forKey: AppTheme.storageKey) }
        return defaults
    }

    /// The style ContentView resolves to with the given saved theme.
    private static func resolvedStyle(theme: String?) async throws -> UIUserInterfaceStyle {
        let window = try show(ContentView(initialTab: 4, preferences: preferences(theme: theme)))
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(500))
        // SwiftUI applies `preferredColorScheme` to the hosting controller, whose view every
        // SwiftUI view inherits its appearance from; a test window does not take it on itself.
        let root = window.rootViewController?.view
        return root?.traitCollection.userInterfaceStyle ?? .unspecified
    }

    /// A saved Light or Dark choice is applied when the interface is first shown.
    @Test func savedThemeIsRestored() async throws {
        #expect(try await Self.resolvedStyle(theme: "Dark") == .dark)
        #expect(try await Self.resolvedStyle(theme: "Light") == .light)
    }

    /// "System", no saved value and an unrecognised value all follow the system appearance,
    /// in both system appearances.
    @Test func systemMissingAndInvalidThemesFollowTheSystem() async throws {
        for systemStyle in [UIUserInterfaceStyle.light, .dark] {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let windows = scene.windows
            windows.forEach { $0.overrideUserInterfaceStyle = systemStyle }
            defer { windows.forEach { $0.overrideUserInterfaceStyle = .unspecified } }
            for stored in ["System", nil, "Purple", ""] {
                let window = try Self.show(ContentView(initialTab: 4, preferences: Self.preferences(theme: stored)))
                // Stand in for the system setting on this window, as above for existing windows.
                window.overrideUserInterfaceStyle = systemStyle
                try await Task.sleep(for: .milliseconds(500))
                #expect(window.rootViewController?.view.traitCollection.userInterfaceStyle == systemStyle,
                        "\(stored ?? "nil") with system \(systemStyle.rawValue)")
                window.isHidden = true
            }
        }
    }

    /// Choosing a theme stores its raw value under the existing key and format.
    @Test func choosingAThemeStoresItsRawValue() {
        let defaults = Self.preferences(theme: nil)
        let storage = AppStorage(wrappedValue: AppTheme.system, AppTheme.storageKey, store: defaults)
        storage.wrappedValue = .dark
        #expect(defaults.string(forKey: "selectedTheme") == "Dark")
        storage.wrappedValue = .system
        #expect(defaults.string(forKey: "selectedTheme") == "System")
    }

    private static func show(_ view: some View) throws -> UIWindow {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        return window
    }
}
