import Foundation
import Testing
@testable import SpecMatrixCore

enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    static func catalog(_ name: String) throws -> Result<DeviceCatalog, CatalogLoadError> {
        DeviceCatalog.decode(try data(name))
    }
}

private func identifier(_ raw: String) -> HardwareIdentifier { HardwareIdentifier(raw)! }

@Suite("Catalog decoding and validation")
struct CatalogDecodingTests {
    @Test func loadsValidCatalog() throws {
        let catalog = try Fixture.catalog("valid-catalog").get()
        #expect(catalog.schemaVersion == 1)
        #expect(catalog.catalogVersion == "test-1")
        #expect(catalog.entries.count == 2)
    }

    @Test func looksUpEveryIdentifierOfAnEntry() throws {
        let catalog = try Fixture.catalog("valid-catalog").get()
        guard case .found(let first) = catalog.lookup(identifier("TestPhone1,1")),
              case .found(let second) = catalog.lookup(identifier("TestPhone1,2"))
        else { Issue.record("Expected both identifiers to resolve"); return }
        #expect(first.id == "test-phone")
        #expect(second.id == "test-phone")
        #expect(first.chip?.gpuCores == 5)
        #expect(first.display?.resolution == PixelDimensions(width: 1179, height: 2556))
        #expect(first.releaseDate == CalendarDate(iso8601: "2026-01-15"))
    }

    @Test func unknownIdentifierIsNotFoundWithoutApproximation() throws {
        let catalog = try Fixture.catalog("valid-catalog").get()
        // A neighbouring identifier must not match TestPhone1,1 or TestPhone1,2.
        #expect(catalog.lookup(identifier("TestPhone1,3")) == .notFound(identifier("TestPhone1,3")))
        #expect(catalog.lookup(identifier("TestPhone2,1")) == .notFound(identifier("TestPhone2,1")))
    }

    @Test func optionalSectionsMayBeAbsent() throws {
        let catalog = try Fixture.catalog("valid-catalog").get()
        guard case .found(let tablet) = catalog.lookup(identifier("TestPad2,1")) else {
            Issue.record("Expected TestPad2,1 to resolve"); return
        }
        #expect(tablet.chip == nil)
        #expect(tablet.display == nil)
        #expect(tablet.releaseDate == nil)
        #expect(tablet.verification.status == .secondarySourcesOnly)
    }

    @Test func rejectsMalformedJSON() throws {
        guard case .failure(.malformedJSON) = try Fixture.catalog("malformed") else {
            Issue.record("Expected malformedJSON"); return
        }
    }

    @Test func rejectsUnsupportedSchemaVersion() throws {
        #expect(try Fixture.catalog("unsupported-schema") == .failure(.unsupportedSchemaVersion(found: 2, supported: 1)))
        #expect(DeviceCatalog.decode(Data(#"{"catalogVersion":"x","entries":[]}"#.utf8))
                == .failure(.unsupportedSchemaVersion(found: nil, supported: 1)))
        #expect(DeviceCatalog.decode(Data(#"{"schemaVersion":1.5,"catalogVersion":"x","entries":[]}"#.utf8))
                == .failure(.unsupportedSchemaVersion(found: nil, supported: 1)))
    }

    @Test func rejectsWrongValueTypes() throws {
        guard case .failure(.malformedJSON(let message)) = try Fixture.catalog("type-mismatch") else {
            Issue.record("Expected malformedJSON"); return
        }
        #expect(message.contains("gpuCores"))
    }

    @Test func rejectsUnknownFields() throws {
        guard case .failure(.invalid(let issues)) = try Fixture.catalog("unknown-field") else {
            Issue.record("Expected invalid"); return
        }
        #expect(issues == [CatalogIssue(path: "entries[0].ramGB", message: "Unknown field.")])
    }

    @Test func reportsEveryInvalidValue() throws {
        guard case .failure(.invalid(let issues)) = try Fixture.catalog("invalid-entries") else {
            Issue.record("Expected invalid"); return
        }
        let paths = Set(issues.map(\.path))
        let expected: Set<String> = [
            "entries[0].id",                          // not a slug
            "entries[0].identifiers[1]",              // "arm64"
            "entries[0].marketingName",               // blank
            "entries[0].releaseDate",                 // 2026-02-30
            "entries[0].chip.performanceCores",       // -2
            "entries[0].chip.gpuCores",               // 0
            "entries[0].display.diagonalInches",      // negative
            "entries[0].display",                     // landscape resolution
            "entries[0].display.pixelsPerInch",       // 0
            "entries[0].display.maximumRefreshRateHz",// 0
            "entries[0].sources[0].url",              // http
            "entries[0].sources[0].accessed",         // "yesterday"
            "entries[0].verification.status",         // "probably"
            "entries[1].identifiers[0]",              // duplicate TestPhone1,1
            "entries[1].display",                     // width without height
            "entries[1].sources",                     // empty
            "entries[2].marketingName",               // missing
            "entries[2].sources",                     // missing
            "entries[2].verification",                // missing
        ]
        #expect(paths == expected, "Unexpected issue set: \(issues)")
    }

    @Test func malformedCatalogFailsAsAWhole() throws {
        // One bad entry rejects the catalog; valid entries are not partially loaded.
        let result = try Fixture.catalog("invalid-entries")
        #expect((try? result.get()) == nil)
    }
}

@Suite("Hardware resolution")
struct HardwareResolverTests {
    private func identity(_ raw: String, _ environment: RuntimeEnvironment = .device) -> SpecValue<DeviceIdentity> {
        .measured(DeviceIdentity(identifier: identifier(raw), environment: environment),
                  MeasurementSource(api: "Test", environment: environment))
    }

    @Test func knownIdentifierYieldsCatalogValuesWithReference() throws {
        let catalog = try Fixture.catalog("valid-catalog")
        let spec = HardwareResolver.resolve(identity: identity("TestPhone1,2"), catalog: catalog)
        guard case .catalog(let name, let reference) = spec.marketingName else {
            Issue.record("Expected catalog provenance, got \(spec.marketingName)"); return
        }
        #expect(name == "Test Phone")
        #expect(reference.entryID == "test-phone")
        #expect(reference.catalogVersion == "test-1")
        #expect(reference.verification == .verified)
        #expect(reference.sources == [URL(string: "https://example.com/test-phone")!])
        #expect(spec.gpuCores.value == 5)
        #expect(spec.displayMaximumRefreshRate.value == RefreshRate(hertz: 120))
        #expect(spec.provenances.allSatisfy { $0 == .catalog })
    }

    @Test func unknownIdentifierProducesNoCatalogValues() throws {
        let catalog = try Fixture.catalog("valid-catalog")
        let spec = HardwareResolver.resolve(identity: identity("TestPhone9,9"), catalog: catalog)
        #expect(spec.provenances.allSatisfy { $0 == .unknown })
        #expect(spec.marketingName.value == nil)
        #expect(spec.chipName.value == nil)
        #expect(spec.errors.isEmpty)
    }

    @Test func fieldsMissingFromAnEntryAreUnknownNotZero() throws {
        let catalog = try Fixture.catalog("valid-catalog")
        let spec = HardwareResolver.resolve(identity: identity("TestPad2,1"), catalog: catalog)
        #expect(spec.marketingName.provenance == .catalog)
        #expect(spec.chipName.provenance == .unknown)
        #expect(spec.gpuCores.provenance == .unknown)
        #expect(spec.displayPixelDensity.provenance == .unknown)
        #expect(spec.releaseDate.provenance == .unknown)
    }

    @Test func missingIdentityProducesUnknown() throws {
        let spec = HardwareResolver.resolve(identity: .unknown("no id"), catalog: try Fixture.catalog("valid-catalog"))
        #expect(spec.provenances.allSatisfy { $0 == .unknown })
    }

    @Test func catalogFailureProducesErrorsReportedOnce() {
        let spec = HardwareResolver.resolve(identity: identity("TestPhone1,1"),
                                            catalog: .failure(.malformedJSON("bad")))
        #expect(spec.provenances.allSatisfy { $0 == .error })
        #expect(spec.errors.count == 1)
    }

    @Test func simulatedIdentifierResolvesToTheSimulatedModel() throws {
        let spec = HardwareResolver.resolve(identity: identity("TestPhone1,1", .simulator),
                                            catalog: try Fixture.catalog("valid-catalog"))
        #expect(spec.marketingName.value == "Test Phone")
    }
}

@Suite("Bundled production catalog")
struct BundledCatalogTests {
    @Test func loadsAndValidates() throws {
        let catalog = try DeviceCatalog.loadBundled().get()
        #expect(catalog.schemaVersion == DeviceCatalog.supportedSchemaVersion)
        #expect(!catalog.entries.isEmpty)
    }

    @Test func everyEntryCitesAnAppleSource() throws {
        let catalog = try DeviceCatalog.loadBundled().get()
        for entry in catalog.entries {
            #expect(entry.sources.contains { $0.url.host?.hasSuffix("apple.com") == true },
                    "\(entry.id) has no apple.com source")
        }
    }

    /// Spot-checks values corrected by the audit (docs/audit/HARDWARE_DATA_AUDIT.md §3).
    @Test func iPhone16ProMatchesAppleSpecifications() throws {
        let catalog = try DeviceCatalog.loadBundled().get()
        guard case .found(let entry) = catalog.lookup(identifier("iPhone17,1")) else {
            Issue.record("iPhone17,1 missing"); return
        }
        #expect(entry.marketingName == "iPhone 16 Pro")
        #expect(entry.chip?.name == "A18 Pro")
        #expect(entry.chip?.neuralEngineCores == 16)   // the legacy app said 18
        #expect(entry.chip?.gpuCores == 6)
        #expect(entry.display?.diagonal == DisplayDiagonal(inches: 6.3)) // the legacy app said 6.1
        #expect(entry.display?.pixelDensity == PixelDensity(pixelsPerInch: 460))
    }

    @Test func iPhone16UsesA18WithFiveCoreGPU() throws {
        let catalog = try DeviceCatalog.loadBundled().get()
        guard case .found(let entry) = catalog.lookup(identifier("iPhone17,3")) else {
            Issue.record("iPhone17,3 missing"); return
        }
        #expect(entry.chip?.name == "A18")          // the legacy app said "A18 Bionic"
        #expect(entry.chip?.gpuCores == 5)          // the legacy app said 6 in one table
        #expect(entry.display?.pixelDensity == PixelDensity(pixelsPerInch: 460)) // the legacy app said 458
        // Apple does not state a refresh rate for non-ProMotion models; the catalog must not invent one.
        #expect(entry.display?.maximumRefreshRate == nil)
    }

    @Test func doesNotContainIdentifiersTheLegacyAppInvented() throws {
        let catalog = try DeviceCatalog.loadBundled().get()
        #expect(catalog.lookup(identifier("iPhone16,3")) == .notFound(identifier("iPhone16,3")))
        #expect(catalog.lookup(identifier("iPhone16,4")) == .notFound(identifier("iPhone16,4")))
    }
}
