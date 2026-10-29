import Foundation
import SpecMatrixMacCatalog
import SpecMatrixMacPlatform
import SpecMatrixShared
import Testing

@Suite("Mac specification resolver")
struct MacSpecificationResolverTests {
    private let catalog = MacCatalog.loadBundled()
    private let source = MeasurementSource(api: "Test", environment: .device)

    private func resolve(_ identifier: String, chip: String?, clusters: [Int]? = nil) throws -> MacSpecification {
        let chipValue: SpecValue<String> = chip.map { .measured($0, source) } ?? .unknown("Not reported.")
        let clusterValue: SpecValue<[MacCoreCluster]> = clusters
            .map { .measured($0.enumerated().map { MacCoreCluster(name: "Level \($0.offset)", cores: $0.element) }, source) }
            ?? .unknown("Not reported.")
        let model = try #require(HardwareIdentifier(identifier))
        return MacSpecificationResolver.resolve(identifier: .measured(model, source), detectedChipName: chipValue,
                                                detectedCoreClusters: clusterValue, catalog: catalog)
    }

    @Test func matchingChipUsesCatalogValuesWithCitations() throws {
        let spec = try resolve("Mac17,4", chip: "Apple M5")
        #expect(spec.marketingName.value == "MacBook Air (15-inch, M5)")
        #expect(spec.marketingName.provenance == .catalog)
        #expect(spec.gpuCores.value == 10)
        #expect(spec.neuralEngineCores.value == 16)
        guard case .catalog(_, let reference) = spec.gpuCores else { Issue.record("Expected a catalog value"); return }
        #expect(reference.catalogVersion == "2026.10.0")
        #expect(reference.sources.allSatisfy { $0.supports.contains(.chip) })
    }

    @Test func mismatchedChipShowsNoConfigurationValues() throws {
        let spec = try resolve("Mac17,4", chip: "Apple M5 Pro")
        #expect(spec.marketingName.value == "MacBook Air (15-inch, M5)")
        #expect(spec.gpuCores.provenance == .unknown)
        #expect(spec.neuralEngineCores.provenance == .unknown)
        guard case .noMatch = spec.configurationMatch else { Issue.record("Expected no match"); return }
    }

    @Test func configurationDependentValuesStayUnknown() throws {
        let spec = try resolve("Mac14,2", chip: "Apple M2", clusters: [4, 4])
        #expect(spec.configurationMatch.candidates.count == 2)   // 8- or 10-core GPU; macOS does not say which
        #expect(spec.gpuCores.provenance == .unknown)
        #expect(spec.neuralEngineCores.value == 16)
        #expect(spec.catalogChipName.value == "M2")
        #expect(spec.builtInDisplayResolution.value == PixelDimensions(width: 2560, height: 1664))
    }

    @Test func detectedClustersSelectTheConfiguration() throws {
        // MacBook Pro (14-inch, M4 Pro or M4 Max): the M4 Pro is sold as 12-core/16-core GPU or 14-core/20-core GPU.
        let base = try resolve("Mac16,8", chip: "Apple M4 Pro", clusters: [8, 4])
        #expect(base.gpuCores.value == 16)
        let upgraded = try resolve("Mac16,8", chip: "Apple M4 Pro", clusters: [10, 4])
        #expect(upgraded.gpuCores.value == 20)
        let unpublished = try resolve("Mac16,8", chip: "Apple M4 Pro", clusters: [9, 4])
        #expect(unpublished.gpuCores.provenance == .unknown)
        guard case .noMatch = unpublished.configurationMatch else { Issue.record("Expected no match"); return }
    }

    @Test func threeTierClustersMatch() throws {
        let spec = try resolve("Mac18,5", chip: "Apple M6", clusters: [2, 4, 6])
        #expect(spec.gpuCores.value == 12)
        #expect(spec.neuralEngineCores.provenance == .unknown)   // Apple states "Dual 16-core Neural Engine"
    }

    @Test func uncataloguedModelIsUnknownNotGuessed() throws {
        let spec = try resolve("Mac99,1", chip: "Apple M9")
        #expect(spec.entryID == nil)
        #expect(spec.marketingName.provenance == .unknown)
        #expect(spec.gpuCores.provenance == .unknown)
    }

    @Test func catalogFailureIsReportedAsAnError() throws {
        let model = try #require(HardwareIdentifier("Mac14,2"))
        let spec = MacSpecificationResolver.resolve(identifier: .measured(model, source),
                                                    detectedChipName: .measured("Apple M2", source),
                                                    catalog: .failure(.resourceMissing("MacCatalog.json")))
        #expect(spec.marketingName.provenance == .error)
    }

    @Test func chipNameMatchingIgnoresOnlyTheApplePrefix() {
        #expect(MacSpecificationResolver.chipNamesMatch(detected: "Apple M2 Pro", catalog: "M2 Pro"))
        #expect(MacSpecificationResolver.chipNamesMatch(detected: "M2", catalog: "M2"))
        #expect(!MacSpecificationResolver.chipNamesMatch(detected: "Apple M2 Pro", catalog: "M2"))
        #expect(!MacSpecificationResolver.chipNamesMatch(detected: "Apple M2", catalog: "M2 Max"))
    }
}

@Suite("Mac battery mapping")
struct MacBatteryMappingTests {
    private func description(state: String?, charging: Bool? = nil, charged: Bool? = nil,
                             toEmpty: Int? = nil, toFull: Int? = nil) -> PowerSourceDescription {
        PowerSourceDescription(currentCapacity: 50, maximumCapacity: 100, powerSourceState: state, isCharging: charging,
                               isCharged: charged, minutesToEmpty: toEmpty, minutesToFull: toFull)
    }

    @Test func onBattery() {
        let reading = MacBatteryMapping.reading(from: description(state: PowerSourceDescription.batteryPower, toEmpty: 120))
        #expect(reading.level.value == UnitFraction(0.5))
        #expect(reading.chargeState.value == .unplugged)
        #expect(reading.powerSource.value == .battery)
        #expect(reading.estimate.value == .untilEmpty(minutes: 120))
    }

    @Test func chargingFullAndHeld() {
        let charging = MacBatteryMapping.reading(from: description(state: PowerSourceDescription.acPower, charging: true, toFull: 30))
        #expect(charging.chargeState.value == .charging)
        #expect(charging.estimate.value == .untilFull(minutes: 30))
        let full = MacBatteryMapping.reading(from: description(state: PowerSourceDescription.acPower, charging: false, charged: true))
        #expect(full.chargeState.value == .full)
        let held = MacBatteryMapping.reading(from: description(state: PowerSourceDescription.acPower, charging: false))
        #expect(held.chargeState.value == .notCharging)
        #expect(held.estimate.provenance == .unknown)
    }

    @Test func calculatingEstimateAndInvalidCapacityAreUnknown() {
        let calculating = MacBatteryMapping.reading(from: description(state: PowerSourceDescription.batteryPower, toEmpty: -1))
        #expect(calculating.estimate.provenance == .unknown)
        let invalid = MacBatteryMapping.reading(from: PowerSourceDescription(
            currentCapacity: 10, maximumCapacity: 0, powerSourceState: PowerSourceDescription.batteryPower,
            isCharging: false, isCharged: false, minutesToEmpty: nil, minutesToFull: nil))
        #expect(invalid.level.provenance == .unknown)
    }

    @Test func healthIsReportedOnlyWhenMacOSStatesIt() {
        var reported = description(state: PowerSourceDescription.acPower, charging: false)
        reported.health = "Good"
        reported.healthCondition = "Check Battery"
        let reading = MacBatteryMapping.reading(from: reported)
        #expect(reading.health.value == .good)
        #expect(reading.healthCondition.value == "Check Battery")
        let silent = MacBatteryMapping.reading(from: description(state: PowerSourceDescription.acPower, charging: false))
        #expect(silent.health.provenance == .unknown)
        #expect(silent.healthCondition.provenance == .unknown)
    }

    @Test func absentBatteryIsUnavailableNotZero() {
        let absent = MacBatteryReading(allMissing: .unavailable(.notSupportedByHardware))
        #expect(absent.isAbsent)
        #expect(absent.level.value == nil)
    }
}
