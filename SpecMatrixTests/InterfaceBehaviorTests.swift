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

    private static func show(_ view: some View) throws -> UIWindow {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        return window
    }
}
