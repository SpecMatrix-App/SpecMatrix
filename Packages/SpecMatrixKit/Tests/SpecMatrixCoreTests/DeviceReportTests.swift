import Foundation
import Testing
@testable import SpecMatrixCore

@Suite("Device report")
struct DeviceReportTests {
    private let source = MeasurementSource(api: "Test", environment: .device)

    private func staticInfo(identifier: String = "TestPhone1,1") -> StaticDeviceInfo {
        StaticDeviceInfo(
            identity: .measured(DeviceIdentity(identifier: HardwareIdentifier(identifier)!, environment: .device), source),
            operatingSystem: OperatingSystemInfo(name: .measured("iOS", source),
                                                 version: .measured(OSVersion(major: 17, minor: 4, patch: 0), source),
                                                 build: .measured("21E219", source)),
            processor: ProcessorReading(logicalCores: .measured(6, source), activeLogicalCores: .measured(6, source),
                                        performanceCores: .measured(2, source), efficiencyCores: .measured(4, source)),
            graphics: GraphicsReading(gpuName: .measured("Apple GPU", source), supportsMetal3: .measured(true, source),
                                      recommendedMaxWorkingSet: .unavailable(.notExposedByPlatform)),
            physicalMemory: .measured(ByteCount(exactly: 8_000_000_000)!, source)
        )
    }

    private func runtimeInfo(storage: StorageReading? = nil) -> RuntimeDeviceInfo {
        RuntimeDeviceInfo(
            storage: storage ?? StorageReading(capacity: .measured(ByteCount(exactly: 100)!, source),
                                               availableForImportantUsage: .measured(ByteCount(exactly: 40)!, source)),
            power: PowerReading(batteryLevel: .unknown("not reported"), batteryState: .measured(.charging, source),
                                thermalState: .measured(.nominal, source), lowPowerMode: .measured(false, source)),
            display: DisplayReading(allMissing: .unavailable(.notYetImplemented)),
            appFootprint: .measured(ByteCount(exactly: 1_000_000)!, source),
            appAvailableMemory: .unknown("no limit")
        )
    }

    @Test func combinesMeasuredAndCatalogValuesSeparately() throws {
        let catalog = try Fixture.catalog("valid-catalog")
        let report = DeviceReport(staticInfo: staticInfo(), runtimeInfo: runtimeInfo(), catalog: catalog,
                                  collectedAt: Date(timeIntervalSince1970: 0))
        #expect(report.hardware.marketingName.provenance == .catalog)
        #expect(report.processor.performanceCores.provenance == .measured)
        #expect(report.memory.appFootprint.value?.bytes == 1_000_000)
        #expect(try #require(report.storage.usedFraction.value).value == 0.6)
        #expect(report.errors.isEmpty)
    }

    @Test func unknownAndUnavailableAreNotErrors() throws {
        let report = DeviceReport(staticInfo: staticInfo(identifier: "TestPhone7,7"), runtimeInfo: runtimeInfo(),
                                  catalog: try Fixture.catalog("valid-catalog"), collectedAt: Date())
        #expect(report.hardware.marketingName.provenance == .unknown)
        #expect(report.power.batteryLevel.provenance == .unknown)
        #expect(report.display.brightness.provenance == .unavailable)
        #expect(report.errors.isEmpty)
    }

    @Test func collectsEveryFailedRead() throws {
        let failure = SpecError(operation: "Read volume capacity", message: "denied")
        let report = DeviceReport(staticInfo: staticInfo(),
                                  runtimeInfo: runtimeInfo(storage: StorageReading(capacity: .error(failure),
                                                                                   availableForImportantUsage: .error(failure))),
                                  catalog: .failure(.resourceMissing("DeviceCatalog.json")), collectedAt: Date())
        // Two storage reads plus one catalog failure (reported once, not per field).
        #expect(report.errors.count == 3)
    }
}
