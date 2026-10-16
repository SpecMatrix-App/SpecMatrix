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
