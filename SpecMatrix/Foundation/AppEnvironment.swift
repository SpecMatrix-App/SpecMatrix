//
//  AppEnvironment.swift
//  SpecMatrix
//

import SpecMatrixCore
import SpecMatrixPlatform
import SpecMatrixState
import UIKit

/// Composition root for the SpecMatrixKit foundation: wires live platform sources and the
/// bundled catalog into stores. Views receive stores; they never call system APIs directly.
@MainActor
enum AppEnvironment {
    /// Loaded once. A load failure is surfaced as catalog errors, never replaced by fallback data.
    /// Immutable and `Sendable`, so it is readable from any isolation domain.
    nonisolated static let catalog: Result<DeviceCatalog, CatalogLoadError> = DeviceCatalog.loadBundled()

    static func makeDeviceInfoStore() -> DeviceInfoStore {
        DeviceInfoStore(
            source: LiveDeviceInfoSource(screen: { activeScreen() }),
            networkSource: LiveNetworkPathSource(),
            catalog: catalog
        )
    }

    /// The screen of the foreground window scene, without using the deprecated `UIScreen.main`.
    static func activeScreen() -> UIScreen? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return (scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)?.screen
    }
}
