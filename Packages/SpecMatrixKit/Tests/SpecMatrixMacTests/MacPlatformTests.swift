import Foundation
import SpecMatrixMacCatalog
import SpecMatrixMacPlatform
import SpecMatrixShared
import Testing

@Suite("Mac specification resolver")
struct MacSpecificationResolverTests {
    private let catalog = MacCatalog.loadBundled()
    private let source = MeasurementSource(api: "Test", environment: .device)

    private func resolve(_ identifier: String, chip: String?) throws -> MacSpecification {
        let chipValue: SpecValue<String> = chip.map { .measured($0, source) } ?? .unknown("Not reported.")
        let model = try #require(HardwareIdentifier(identifier))
        return MacSpecificationResolver.resolve(identifier: .measured(model, source), detectedChipName: chipValue, catalog: catalog)
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
    }

    @Test func configurationDependentValuesStayUnknown() throws {
        let spec = try resolve("Mac14,2", chip: "Apple M2")
        #expect(spec.gpuCores.provenance == .unknown)     // not recorded: 8- or 10-core GPU
        #expect(spec.neuralEngineCores.value == 16)
        #expect(spec.builtInDisplayResolution.value == PixelDimensions(width: 2560, height: 1664))
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

    @Test func absentBatteryIsUnavailableNotZero() {
        let absent = MacBatteryReading(allMissing: .unavailable(.notSupportedByHardware))
        #expect(absent.isAbsent)
        #expect(absent.level.value == nil)
    }
}
