//
//  ScreenSnapshotTests.swift
//  SpecMatrixTests
//

import SwiftUI
import Testing
import UIKit
@testable import SpecMatrix

/// Renders every tab in light, dark and the largest accessibility text size and writes PNGs for
/// visual review. Runs only when `SPECMATRIX_SNAPSHOT_DIR` is set (pass it to `xcodebuild` as
/// `TEST_RUNNER_SPECMATRIX_SNAPSHOT_DIR=<dir>`); images are reviewed by a person, not compared.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["SPECMATRIX_SNAPSHOT_DIR"] != nil), .serialized)
struct ScreenSnapshotTests {
    struct Variant: Sendable {
        let name: String
        let style: UIUserInterfaceStyle
        let textSize: UIContentSizeCategory
    }

    nonisolated static let variants = [
        Variant(name: "light", style: .light, textSize: .large),
        Variant(name: "dark", style: .dark, textSize: .large),
        Variant(name: "ax5", style: .light, textSize: .accessibilityExtraExtraExtraLarge),
    ]

    static let tabs = ["specs", "network", "display", "camera", "settings"]

    @Test(arguments: variants)
    func renderEveryTab(_ variant: Variant) async throws {
        let directory = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["SPECMATRIX_SNAPSHOT_DIR"]))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)

        for (tag, tab) in Self.tabs.enumerated() {
            let window = UIWindow(windowScene: scene)
            let host = UIHostingController(rootView: ContentView(initialTab: tag))
            host.traitOverrides.preferredContentSizeCategory = variant.textSize
            window.overrideUserInterfaceStyle = variant.style
            window.rootViewController = host
            window.makeKeyAndVisible()
            try await Task.sleep(for: .seconds(2))

            try save(window, to: directory.appendingPathComponent("\(variant.name)-\(tag)-\(tab)-top.png"))
            if let scrollView = Self.mainScrollView(in: host.view) {
                let maxOffset = scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
                if maxOffset > scrollView.contentOffset.y + 20 {
                    scrollView.setContentOffset(CGPoint(x: 0, y: maxOffset), animated: false)
                    try await Task.sleep(for: .seconds(1))
                    try save(window, to: directory.appendingPathComponent("\(variant.name)-\(tag)-\(tab)-bottom.png"))
                }
            }
            window.isHidden = true
        }
    }

    /// The notice each tab shows when its information is hidden in Settings. The stored settings are
    /// replaced with all-hidden ones while rendering and restored byte for byte afterwards.
    @Test func renderHiddenNotices() async throws {
        let directory = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["SPECMATRIX_SNAPSHOT_DIR"]))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let key = "displaySettings"
        let original = UserDefaults.standard.data(forKey: key)
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        let hidden = DisplaySettings(showBattery: false, showSystem: false, showCPU: false, showGPU: false,
                                     showMemory: false, showStorage: false, showNetwork: false,
                                     showDisplay: false, showCamera: false)
        UserDefaults.standard.set(try JSONEncoder().encode(hidden), forKey: key)

        for (tag, tab) in Self.tabs.enumerated().dropLast() {
            let window = UIWindow(windowScene: scene)
            window.rootViewController = UIHostingController(rootView: ContentView(initialTab: tag))
            window.makeKeyAndVisible()
            try await Task.sleep(for: .seconds(2))
            try save(window, to: directory.appendingPathComponent("hidden-\(tag)-\(tab).png"))
            window.isHidden = true
        }
    }

    private func save(_ window: UIWindow, to url: URL) throws {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try #require(image.pngData()).write(to: url)
    }

    /// The largest visible vertically scrolling view: the screen's list.
    private static func mainScrollView(in view: UIView) -> UIScrollView? {
        var best: UIScrollView?
        func visit(_ view: UIView) {
            if let scroll = view as? UIScrollView, !scroll.isHidden, scroll.window != nil,
               scroll.bounds.height > (best?.bounds.height ?? 0) {
                best = scroll
            }
            view.subviews.forEach(visit)
        }
        visit(view)
        return best
    }
}
