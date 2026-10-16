//
//  SpecMatrixTests.swift
//  SpecMatrixTests
//
//  Created by Zachary Aflalo on 2025-01-02.
//

import Foundation
import SpecMatrixCore
import SpecMatrixState
import Testing
import UIKit
@testable import SpecMatrix

/// App-level integration tests. Unit tests for the foundation live in Packages/SpecMatrixKit/Tests.
@MainActor
struct AppIntegrationTests {
    /// Verifies the catalog resource is embedded in the built app and passes validation there.
    @Test func bundledCatalogLoadsInsideTheApp() throws {
        let catalog = try AppEnvironment.catalog.get()
        #expect(catalog.schemaVersion == DeviceCatalog.supportedSchemaVersion)
        #expect(!catalog.entries.isEmpty)
    }

    @Test func compositionRootCreatesAnIdleStoreWithoutStartingWork() {
        let store = AppEnvironment.makeDeviceInfoStore()
        #expect(store.phase == .idle)
        #expect(store.report == nil)
        #expect(!store.isObserving)
    }

    /// Exercises the live providers end to end in whatever environment runs the tests.
    /// Assertions are about provenance consistency, not the host's actual values.
    @Test func liveRefreshProducesAReportWithConsistentProvenance() async throws {
        let store = AppEnvironment.makeDeviceInfoStore()
        await store.refresh().value
        let report = try #require(store.report)

        // In the Simulator, hardware values describe the host Mac and must not be presented as measured.
        if case .measured(let identity, _) = report.identity, identity.environment == .simulator {
            #expect(report.processor.performanceCores == .unavailable(.simulator))
            #expect(report.memory.physicalMemory == .unavailable(.simulator))
            #expect(report.power.batteryLevel == .unavailable(.simulator))
        }
        // Battery level is never a negative or out-of-range percentage.
        if let level = report.power.batteryLevel.value {
            #expect((0...1).contains(level.value))
        }
        // Storage usage is either a valid fraction or an explicit missing value.
        if let used = report.storage.usedFraction.value {
            #expect(used.value.isFinite && (0...1).contains(used.value))
        }
        // Catalog fields are catalog-derived or explicitly unknown — never measured.
        #expect(report.hardware.provenances.allSatisfy { $0 == .catalog || $0 == .unknown })
        #expect(store.phase == .loaded || { if case .partial = store.phase { return true }; return false }())
    }

    // MARK: Legacy screens (CatalogDeviceInfo)

    /// The legacy screens read iPhone16,1 from the bundled catalog, not from a hardcoded table.
    @Test func legacyScreensShowCatalogValuesForIPhone16_1() {
        let device = CatalogDeviceInfo(identifier: "iPhone16,1", catalog: AppEnvironment.catalog)
        #expect(device.modelName == "iPhone 15 Pro")
        #expect(device.chipName == "A17 Pro")
        #expect(device.gpuName == "Apple A17 Pro GPU")
        #expect(device.cpuCores == "6-core")
        #expect(device.performanceCores == "2")
        #expect(device.efficiencyCores == "4")
        #expect(device.gpuCores == "6-core")
        #expect(device.neuralEngineCores == "16-core")
        #expect(device.pixelDensity == "460 PPI")
        #expect(device.displaySize == "6.12\"")
    }

    /// Previously every device showed "A17 Pro" in the CPU section and mismapped identifiers
    /// such as iPhone15,4 (iPhone 15) to "iPhone 15 Pro".
    @Test func legacyScreensUseTheRightModelForEachIdentifier() {
        let catalog = AppEnvironment.catalog
        #expect(CatalogDeviceInfo(identifier: "iPhone15,4", catalog: catalog).modelName == "iPhone 15")
        #expect(CatalogDeviceInfo(identifier: "iPhone15,4", catalog: catalog).chipName == "A16 Bionic")
        #expect(CatalogDeviceInfo(identifier: "iPhone11,2", catalog: catalog).chipName == "A12 Bionic")
        #expect(CatalogDeviceInfo(identifier: "iPad16,4", catalog: catalog).modelName == "iPad Pro 11-inch (M4)")
        #expect(CatalogDeviceInfo(identifier: "Mac14,2", catalog: catalog).modelName == "MacBook Air (M2, 2022)")
    }

    /// Values the catalog does not record are "Unknown", never another model's value.
    @Test func legacyScreensShowUnknownInsteadOfGuessing() {
        let catalog = AppEnvironment.catalog
        let iPhone18Pro = CatalogDeviceInfo(identifier: "iPhone19,2", catalog: catalog)
        #expect(iPhone18Pro.modelName == "iPhone 18 Pro")
        #expect(iPhone18Pro.performanceCores == "Unknown")   // Apple says "super cores"
        #expect(iPhone18Pro.cpuCores == "Unknown")
        #expect(iPhone18Pro.efficiencyCores == "4")

        for raw in ["Watch7,3", "iPhone10,1", "iPhone16,3", "arm64", ""] {
            let device = CatalogDeviceInfo(identifier: raw, catalog: catalog)
            #expect(device.entry == nil, "\(raw)")
            #expect(device.modelName == "Unknown model (\(raw))")
            #expect([device.chipName, device.gpuName, device.cpuCores, device.gpuCores,
                     device.pixelDensity, device.displaySize].allSatisfy { $0 == "Unknown" }, "\(raw)")
        }

        let failed = CatalogDeviceInfo(identifier: "iPhone16,1", catalog: .failure(.resourceMissing("DeviceCatalog.json")))
        #expect(failed.entry == nil)
        #expect(failed.chipName == "Unknown")
    }

    // MARK: Interface

    /// Every SF Symbol the interface names exists; an unknown name renders as nothing.
    @Test func interfaceSymbolsExist() {
        let fixed = ["cpu", "network", "display", "camera", "gear", "iphone", "square.grid.3x3.square",
                     "memorychip", "internaldrive", "battery.100", "eye", "eye.slash", "stethoscope", "link",
                     "envelope", "doc.text", "arrow.up.right", "info.circle", "checkmark.circle.fill",
                     "camera.fill", "camera.fill.badge.ellipsis"]
        let themes = AppTheme.allCases.map(\.icon)
        let network = [true, false].flatMap { connected in
            ["WiFi", "Cellular", "Unknown"].map { NetworkInfo(isConnected: connected, type: $0, cellularInfo: nil).statusIcon }
        }
        let states: [UIDevice.BatteryState] = [.unknown, .unplugged, .charging, .full]
        let battery = states.flatMap { state in
            stride(from: Float(-1), through: 1, by: 0.01).map { BatteryInfo(level: $0, state: state, health: -1).stateIcon }
        }
        for name in Set(fixed + themes + network + battery) {
            #expect(UIImage(systemName: name) != nil, "\(name)")
        }
    }

    /// The Simulator and some devices report -1 when the level is unknown; it must not read "-100%".
    @Test func batteryLevelText() {
        #expect(BatteryInfo(level: -1, state: .unknown, health: -1).levelDescription == "Unknown")
        #expect(BatteryInfo(level: 0.5, state: .unplugged, health: -1).levelDescription == "50%")
        #expect(BatteryInfo(level: 1, state: .full, health: -1).levelDescription == "100%")
    }

    /// Settings saved by earlier versions (JSON data in UserDefaults) are read unchanged, and writes
    /// keep that format.
    @Test func displaySettingsKeepTheirStoredFormat() throws {
        let key = "displaySettings.test.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: key) }
        var saved = DisplaySettings()
        saved.showCamera = false
        UserDefaults.standard.set(try JSONEncoder().encode(saved), forKey: key)

        let storage = CodableAppStorage(wrappedValue: DisplaySettings(), key)
        #expect(storage.wrappedValue.showCamera == false)
        #expect(storage.wrappedValue.showNetwork == true)

        storage.projectedValue.wrappedValue.showNetwork = false
        let data = try #require(UserDefaults.standard.data(forKey: key))
        let decoded = try JSONDecoder().decode(DisplaySettings.self, from: data)
        #expect(decoded.showNetwork == false && decoded.showCamera == false)
    }

    /// The running (or simulated) model's identifier resolves through the catalog bundled in the app:
    /// a catalogued identifier yields that entry's values, any other identifier yields unknown values.
    @Test func runningModelResolvesThroughTheBundledCatalog() async throws {
        let store = AppEnvironment.makeDeviceInfoStore()
        await store.refresh().value
        let report = try #require(store.report)
        let identifier = try #require(report.identity.value?.identifier)
        switch try AppEnvironment.catalog.get().lookup(identifier) {
        case .found(let entry):
            #expect(report.hardware.marketingName.value == entry.marketingName)
            #expect(report.hardware.chipName.value == entry.chip?.name)
        case .notFound:
            #expect(report.hardware.provenances.allSatisfy { $0 == .unknown })
        }
    }
}
