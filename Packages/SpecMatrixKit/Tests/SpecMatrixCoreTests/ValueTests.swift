import Foundation
import Testing
@testable import SpecMatrixCore

private let deviceSource = MeasurementSource(api: "Test.api", environment: .device)

@Suite("HardwareIdentifier")
struct HardwareIdentifierTests {
    @Test func parsesFamilyAndNumbers() throws {
        let identifier = try #require(HardwareIdentifier("iPhone17,1"))
        #expect(identifier.rawValue == "iPhone17,1")
        #expect(identifier.family == "iPhone")
        #expect(identifier.major == 17)
        #expect(identifier.minor == 1)
    }

    @Test func parsesMacIdentifiersWithLongFamilies() throws {
        let identifier = try #require(HardwareIdentifier("MacBookPro18,3"))
        #expect(identifier.family == "MacBookPro")
        #expect(identifier.major == 18)
        #expect(identifier.minor == 3)
    }

    @Test func normalizesNULPaddingAndWhitespace() {
        #expect(HardwareIdentifier("iPhone18,3\0\0\0")?.rawValue == "iPhone18,3")
        #expect(HardwareIdentifier("  iPad16,4\n")?.rawValue == "iPad16,4")
    }

    @Test(arguments: ["", "arm64", "x86_64", "iPhone17", "iPhone,1", "17,1", "iPhone17,1a", "iPhone17,1,2", "iPhone17,", "iPhone12345,1"])
    func rejectsMalformedIdentifiers(_ raw: String) {
        #expect(HardwareIdentifier(raw) == nil)
    }
}

@Suite("SpecValue provenance")
struct SpecValueTests {
    @Test func classifiesEveryCase() {
        let reference = CatalogReference(entryID: "x", catalogVersion: "1", verification: .verified, sources: [])
        #expect(SpecValue.measured(1, deviceSource).provenance == .measured)
        #expect(SpecValue.catalog(1, reference).provenance == .catalog)
        #expect(SpecValue<Int>.unavailable(.notExposedByPlatform).provenance == .unavailable)
        #expect(SpecValue<Int>.unknown("why").provenance == .unknown)
        #expect(SpecValue<Int>.error(SpecError(operation: "op", message: "failed")).provenance == .error)
    }

    @Test func missingValuesHaveNoValue() {
        #expect(SpecValue<Int>.unavailable(.simulator).value == nil)
        #expect(SpecValue<Int>.unknown("why").value == nil)
        #expect(SpecValue<Int>.error(SpecError(operation: "op", message: "m")).value == nil)
        #expect(SpecValue.measured(42, deviceSource).value == 42)
    }

    @Test func mapPreservesProvenanceAndSource() {
        let mapped = SpecValue.measured(2, deviceSource).map { $0 * 10 }
        #expect(mapped == .measured(20, deviceSource))
        let missing = SpecValue<Int>.unknown("not reported").map { $0 * 10 }
        #expect(missing == .unknown("not reported"))
    }

    @Test func onlyErrorsExposeSpecError() {
        let error = SpecError(operation: "op", message: "m")
        #expect(SpecValue<Int>.error(error).specError == error)
        #expect(SpecValue<Int>.unknown("x").specError == nil)
        #expect(SpecValue.measured(1, deviceSource).specError == nil)
    }
}

@Suite("Units")
struct UnitTests {
    @Test func byteCountRejectsNegativeAndOverflow() {
        #expect(ByteCount(exactly: -1) == nil)
        #expect(ByteCount(exactly: UInt64.max) == nil)
        #expect(ByteCount(exactly: 0)?.bytes == 0)
        #expect(ByteCount(exactly: UInt64(8_000_000_000))?.bytes == 8_000_000_000)
    }

    @Test(arguments: [-0.01, 1.01, Double.nan, Double.infinity, -Double.infinity])
    func unitFractionRejectsOutOfRange(_ value: Double) {
        #expect(UnitFraction(value) == nil)
    }

    @Test func unitFractionAcceptsBoundsAndConvertsToPercent() throws {
        #expect(UnitFraction(0)?.percent == 0)
        #expect(UnitFraction(1)?.percent == 100)
        #expect(try #require(UnitFraction(0.37)).percent == 37)
    }

    @Test func positiveOnlyUnits() {
        #expect(RefreshRate(hertz: 0) == nil)
        #expect(RefreshRate(hertz: 120)?.hertz == 120)
        #expect(DisplayDiagonal(inches: 0) == nil)
        #expect(DisplayDiagonal(inches: .nan) == nil)
        #expect(PixelDensity(pixelsPerInch: -460) == nil)
        #expect(PixelDimensions(width: 0, height: 100) == nil)
        #expect(PixelDimensions(width: 1206, height: 2622)?.description == "1206 × 2622")
    }

    @Test func calendarDateValidation() {
        #expect(CalendarDate(iso8601: "2025-09-19")?.description == "2025-09-19")
        #expect(CalendarDate(iso8601: "2026-02-30") == nil)
        #expect(CalendarDate(iso8601: "2026-13-01") == nil)
        #expect(CalendarDate(iso8601: "26-01-01") == nil)
        #expect(CalendarDate(iso8601: "yesterday") == nil)
        #expect(CalendarDate(iso8601: "2024-02-29") != nil)
    }
}

@Suite("Storage calculations")
struct StorageMathTests {
    private func bytes(_ value: Int64) -> SpecValue<ByteCount> {
        .measured(ByteCount(exactly: value)!, deviceSource)
    }

    @Test func computesUsedFraction() throws {
        let fraction = StorageMath.usedFraction(capacity: bytes(256_000_000_000), available: bytes(64_000_000_000))
        #expect(fraction.provenance == .measured)
        #expect(try #require(fraction.value).value == 0.75)
    }

    @Test func zeroCapacityIsUnknownNotNaN() {
        let fraction = StorageMath.usedFraction(capacity: bytes(0), available: bytes(0))
        #expect(fraction.provenance == .unknown)
        #expect(fraction.value == nil)
    }

    @Test func availableAboveCapacityIsUnknownNotClamped() {
        let fraction = StorageMath.usedFraction(capacity: bytes(100), available: bytes(150))
        #expect(fraction.provenance == .unknown)
    }

    @Test func fullAndEmptyVolumesStayInRange() throws {
        #expect(try #require(StorageMath.usedFraction(capacity: bytes(100), available: bytes(0)).value).value == 1)
        #expect(try #require(StorageMath.usedFraction(capacity: bytes(100), available: bytes(100)).value).value == 0)
    }

    @Test func failedQueryPropagatesErrorRatherThanAMeasurement() {
        let failure = SpecError(operation: "Read volume capacity", message: "denied")
        let reading = StorageReading(capacity: .error(failure), availableForImportantUsage: .error(failure))
        #expect(reading.usedFraction == .error(failure))
        #expect(reading.capacity.value == nil)
        #expect(reading.errors == [failure, failure])
    }

    @Test func errorTakesPrecedenceOverUnknown() {
        let failure = SpecError(operation: "op", message: "m")
        #expect(StorageMath.usedFraction(capacity: .unknown("x"), available: .error(failure)) == .error(failure))
        #expect(StorageMath.usedFraction(capacity: .unavailable(.simulator), available: bytes(1)) == .unavailable(.simulator))
    }

    @Test func byteCountFromAPIRejectsMissingAndNegative() {
        #expect(StorageMath.byteCount(Int?.none, api: "k", environment: .device).provenance == .unknown)
        #expect(StorageMath.byteCount(Int64(-5), api: "k", environment: .device).provenance == .unknown)
        #expect(StorageMath.byteCount(Int(10), api: "k", environment: .device)
                == .measured(ByteCount(exactly: 10)!, MeasurementSource(api: "k", environment: .device)))
    }
}

@Suite("Battery normalization")
struct BatteryNormalizationTests {
    @Test func unknownLevelIsNeverNegativePercentage() {
        let level = BatteryNormalization.level(raw: -1, environment: .device)
        #expect(level.provenance == .unknown)
        #expect(level.value == nil)
    }

    @Test func validLevelIsMeasured() throws {
        let level = BatteryNormalization.level(raw: 0.35, environment: .device)
        #expect(level.provenance == .measured)
        #expect(abs(try #require(level.value).value - 0.35) < 0.0001)
    }

    @Test(arguments: [Float(1.5), Float.nan, Float.infinity])
    func outOfRangeLevelsAreUnknown(_ raw: Float) {
        #expect(BatteryNormalization.level(raw: raw, environment: .device).provenance == .unknown)
    }

    @Test func simulatorIsUnavailable() {
        #expect(BatteryNormalization.level(raw: -1, environment: .simulator) == .unavailable(.simulator))
        #expect(BatteryNormalization.state(rawValue: 2, environment: .simulator) == .unavailable(.simulator))
    }

    @Test func mapsBatteryStates() {
        #expect(BatteryNormalization.state(rawValue: 1, environment: .device).value == .unplugged)
        #expect(BatteryNormalization.state(rawValue: 2, environment: .device).value == .charging)
        #expect(BatteryNormalization.state(rawValue: 3, environment: .device).value == .full)
        #expect(BatteryNormalization.state(rawValue: 0, environment: .device).provenance == .unknown)
        #expect(BatteryNormalization.state(rawValue: 9, environment: .device).provenance == .unknown)
    }

    @Test func thermalStatesMapOneToOne() {
        #expect(ThermalLevel(.nominal) == .nominal)
        #expect(ThermalLevel(.fair) == .fair)
        #expect(ThermalLevel(.serious) == .serious)
        #expect(ThermalLevel(.critical) == .critical)
    }
}

@Suite("Formatting")
struct SpecFormatTests {
    private let locale = Locale(identifier: "en_US")

    @Test func storageUsesDecimalUnits() throws {
        #expect(SpecFormat.storage(try #require(ByteCount(exactly: 256_000_000_000)), locale: locale) == "256 GB")
    }

    @Test func memoryUsesBinaryUnits() throws {
        #expect(SpecFormat.memory(try #require(ByteCount(exactly: 8 * 1_073_741_824)), locale: locale) == "8 GB")
    }

    @Test func percentIsWholeNumber() throws {
        #expect(SpecFormat.percent(try #require(UnitFraction(0.374)), locale: locale) == "37%")
    }

    @Test func identityMarksSimulator() throws {
        let identifier = try #require(HardwareIdentifier("iPhone18,3"))
        #expect(SpecFormat.identity(DeviceIdentity(identifier: identifier, environment: .simulator)) == "iPhone18,3 (Simulator)")
        #expect(SpecFormat.identity(DeviceIdentity(identifier: identifier, environment: .device)) == "iPhone18,3")
    }
}
