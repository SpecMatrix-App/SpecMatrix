import Foundation
import Testing
@testable import SpecMatrixCore

enum Fixture {
    /// Fixtures use reserved example domains, so the "manufacturer" in tests is example.com.
    static let policy = CatalogPolicy(manufacturerPublisher: "example.com")

    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    static func catalog(_ name: String) throws -> Result<DeviceCatalog, CatalogLoadError> {
        DeviceCatalog.decode(try data(name), policy: policy)
    }
}

private func identifier(_ raw: String) -> HardwareIdentifier { HardwareIdentifier(raw)! }

private func issues(_ result: Result<DeviceCatalog, CatalogLoadError>) -> [CatalogIssue] {
    guard case .failure(.invalid(let issues)) = result else {
        Issue.record("Expected .invalid, got \(result)")
        return []
    }
    return issues
}

/// One entry whose fields can be edited before encoding, for single-rule tests.
private func catalogJSON(status: String = "verified", sources: [[String: Any]], display: [String: Any]? = nil,
                         catalogVersion: String = "2026.01.0") -> Data {
    var entry: [String: Any] = [
        "id": "test-phone", "identifiers": ["TestPhone1,1"], "family": "TestPhone", "marketingName": "Test Phone",
        "sources": sources, "verification": ["status": status, "verifiedOn": "2026-10-15"],
    ]
    if let display { entry["display"] = display }
    let root: [String: Any] = ["schemaVersion": 3, "catalogVersion": catalogVersion, "entries": [entry]]
    return try! JSONSerialization.data(withJSONObject: root)
}

private func web(_ url: String, _ supports: [String]) -> [String: Any] {
    ["title": "Source", "url": url, "accessed": "2026-10-15", "supports": supports]
}

@Suite("Catalog decoding and validation")
struct CatalogDecodingTests {
    @Test func loadsValidCatalog() throws {
        let catalog = try Fixture.catalog("valid-catalog").get()
        #expect(catalog.schemaVersion == 3)
        #expect(catalog.catalogVersion == "2026.01.0")
        #expect(catalog.entries.count == 2)
    }

    @Test func decodesBothSourceLocationsAndTheirAttribution() throws {
        let catalog = try Fixture.catalog("valid-catalog").get()
        let entry = try #require(catalog.entries.first)
        #expect(entry.sources.map(\.location) == [
            .web(URL(string: "https://example.com/test-phone")!),
            .xcodeSimulatorDeviceType(name: "Test Phone", xcodeVersion: "1.0 (1A1)"),
            .web(URL(string: "https://example.org/identifiers")!),
        ])
        #expect(entry.sources[0].supports == [.marketingName, .releaseDate, .chip, .display])
        #expect(entry.sources(supporting: .identifiers).map(\.publisher) == ["apple.com", "example.org"])
        #expect(entry.sources[1].url == nil)
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
        #expect(try Fixture.catalog("unsupported-schema") == .failure(.unsupportedSchemaVersion(found: 4, supported: 3)))
        #expect(DeviceCatalog.decode(Data(#"{"catalogVersion":"x","entries":[]}"#.utf8))
                == .failure(.unsupportedSchemaVersion(found: nil, supported: 3)))
        #expect(DeviceCatalog.decode(Data(#"{"schemaVersion":1.5,"catalogVersion":"x","entries":[]}"#.utf8))
                == .failure(.unsupportedSchemaVersion(found: nil, supported: 3)))
    }

    /// Schema 1 sources carried no field attribution; a version 1 file must not be read as version 2.
    @Test func rejectsSchemaVersion1Catalogs() {
        let v1 = #"{"schemaVersion":1,"catalogVersion":"2026.10.0","entries":[]}"#
        #expect(DeviceCatalog.decode(Data(v1.utf8)) == .failure(.unsupportedSchemaVersion(found: 1, supported: 3)))
    }

    @Test func rejectsWrongValueTypes() throws {
        guard case .failure(.malformedJSON(let message)) = try Fixture.catalog("type-mismatch") else {
            Issue.record("Expected malformedJSON"); return
        }
        #expect(message.contains("gpuCores"))
    }

    @Test func rejectsIntegersThatOverflow() {
        let json = #"{"schemaVersion":3,"catalogVersion":"2026.01.0","entries":[{"id":"x","identifiers":["TestPhone1,1"],"family":"TestPhone","marketingName":"X","display":{"pixelWidth":99999999999999999999,"pixelHeight":2}}]}"#
        // JSONDecoder reports this without a coding path, so only the rejection is asserted.
        guard case .failure(.malformedJSON) = DeviceCatalog.decode(Data(json.utf8)) else {
            Issue.record("Expected malformedJSON"); return
        }
    }

    @Test func rejectsUnknownFields() throws {
        #expect(issues(try Fixture.catalog("unknown-field")) == [CatalogIssue(path: "entries[0].ramGB", message: "Unknown field.")])
        let misspelt = catalogJSON(status: "secondary-sources-only",
                                   sources: [["title": "S", "url": "https://example.com", "accessed": "2026-10-15",
                                              "suports": ["identifiers"]]])
        #expect(issues(DeviceCatalog.decode(misspelt, policy: Fixture.policy)).map(\.path)
                .contains("entries[0].sources[0].suports"))
    }

    @Test func reportsEveryInvalidValue() throws {
        let paths = Set(issues(try Fixture.catalog("invalid-entries")).map(\.path))
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
        #expect(paths == expected)
    }

    @Test func reportsEveryInconsistency() throws {
        let found = issues(try Fixture.catalog("inconsistent-entries"))
        let expected: [String: Int] = [
            "catalogVersion": 1,                      // month 13
            "entries[0].identifiers[1]": 1,           // TestPad1,1 in the TestPhone family
            "entries[0].releaseDate": 1,              // after verifiedOn
            "entries[0].display.pixelsPerInch": 1,    // 400 ppi vs ~460 computed
            "entries[0].sources[0].accessed": 1,      // after verifiedOn
            "entries[0].sources[1]": 1,               // same URL cited twice
            "entries[0].verification.status": 1,      // identifiers from one publisher only
            "entries[1].marketingName": 1,            // duplicate of entry 0
            "entries[1].sources[0]": 1,               // url and Xcode location together
            "entries[1].sources[1].xcodeVersion": 1,  // missing
            "entries[1].sources[2].supports": 2,      // Xcode source claiming chip; chip not recorded
            "entries[1].sources[3].supports": 2,      // unknown "colour"; display not recorded
            "entries[1].sources[4]": 1,               // no location
            "entries[1].sources[5].supports": 1,      // empty
            "entries[1].sources": 1,                  // nothing supports marketingName
            "entries[3].chip.neuralEngineCores": 1,   // Shared Chip: 16 cores in entry 2, 8 here
        ]
        let counts = Dictionary(grouping: found, by: \.path).mapValues(\.count)
        #expect(counts == expected, "Unexpected issues: \(found)")
        #expect(found.contains { $0.message.contains("which gives 459.9 ppi") })
    }

    @Test func malformedCatalogFailsAsAWhole() throws {
        // One bad entry rejects the catalog; valid entries are not partially loaded.
        #expect((try? Fixture.catalog("invalid-entries").get()) == nil)
        #expect((try? Fixture.catalog("inconsistent-entries").get()) == nil)
    }
}

@Suite("Verification policy")
struct VerificationPolicyTests {
    private let identifierSources = [
        ["title": "Simulator", "xcodeSimulatorDeviceType": "Test Phone", "xcodeVersion": "1.0 (1A1)",
         "accessed": "2026-10-15", "supports": ["identifiers"]] as [String: Any],
        web("https://example.org/ids", ["identifiers"]),
    ]

    @Test func verifiedEntryNeedsAManufacturerSourceForEachRecordedGroup() {
        let data = catalogJSON(sources: identifierSources + [web("https://example.net/specs", ["marketingName"])])
        let found = issues(DeviceCatalog.decode(data, policy: Fixture.policy))
        #expect(found == [CatalogIssue(path: "entries[0].verification.status",
                                       message: "verified requires a example.com source for marketingName.")])
        // The same data is acceptable when it does not claim to be verified.
        let secondary = catalogJSON(status: "secondary-sources-only",
                                    sources: identifierSources + [web("https://example.net/specs", ["marketingName"])])
        #expect((try? DeviceCatalog.decode(secondary, policy: Fixture.policy).get()) != nil)
    }

    @Test func verifiedEntryNeedsIdentifiersFromTwoPublishers() {
        // Two pages from the same publisher are not independent.
        let data = catalogJSON(sources: [web("https://example.com/specs", ["marketingName"]),
                                         web("https://example.org/ids", ["identifiers"]),
                                         web("https://www.example.org/more-ids", ["identifiers"])])
        #expect(issues(DeviceCatalog.decode(data, policy: Fixture.policy)).map(\.message)
                == ["verified requires identifiers supported by 2 independent publishers (found 1)."])
        let independent = catalogJSON(sources: identifierSources + [web("https://example.com/specs", ["marketingName"])])
        #expect((try? DeviceCatalog.decode(independent, policy: Fixture.policy).get()) != nil)
    }

    /// The production policy only accepts Apple-published sources for specifications.
    @Test func applePolicyRejectsNonAppleSpecifications() {
        let data = catalogJSON(sources: identifierSources + [web("https://example.com/specs", ["marketingName"])])
        #expect(issues(DeviceCatalog.decode(data)).map(\.message)
                == ["verified requires a apple.com source for marketingName."])
    }

    @Test func publisherIgnoresSubdomains() {
        let support = CatalogSource(title: "", location: .web(URL(string: "https://support.apple.com/en-us/1")!),
                                    accessed: CalendarDate(iso8601: "2026-10-15")!, supports: [.chip])
        let gist = CatalogSource(title: "", location: .web(URL(string: "https://gist.github.com/x")!),
                                 accessed: CalendarDate(iso8601: "2026-10-15")!, supports: [.identifiers])
        #expect(support.publisher == "apple.com")
        #expect(gist.publisher == "github.com")
    }
}

@Suite("Display consistency")
struct DisplayConsistencyTests {
    private func decode(diagonal: Double, width: Int = 1179, height: Int = 2556, ppi: Int = 460) -> [CatalogIssue] {
        let data = catalogJSON(status: "secondary-sources-only",
                               sources: [web("https://example.com", ["identifiers", "marketingName", "display"])],
                               display: ["diagonalInches": diagonal, "pixelWidth": width, "pixelHeight": height, "pixelsPerInch": ppi])
        guard case .failure(.invalid(let issues)) = DeviceCatalog.decode(data, policy: Fixture.policy) else { return [] }
        return issues
    }

    @Test func acceptsPublishedRoundingOfDiagonalAndDensity() {
        #expect(decode(diagonal: 6.12).isEmpty)                     // iPhone 16: 459.9 ppi computed
        #expect(decode(diagonal: 7.9, width: 1536, height: 2048, ppi: 326).isEmpty) // iPad mini (5th gen): 324.1
    }

    @Test func rejectsDensityThatContradictsResolutionAndDiagonal() {
        #expect(decode(diagonal: 6.12, ppi: 326).map(\.path) == ["entries[0].display.pixelsPerInch"])
        #expect(decode(diagonal: 6.9).map(\.path) == ["entries[0].display.pixelsPerInch"]) // wrong model's diagonal
        #expect(decode(diagonal: 6.12, width: 1290, height: 2796).map(\.path) == ["entries[0].display.pixelsPerInch"])
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
        #expect(reference.catalogVersion == "2026.01.0")
        #expect(reference.verification == .verified)
        #expect(spec.gpuCores.value == 5)
        #expect(spec.displayMaximumRefreshRate.value == RefreshRate(hertz: 120))
        #expect(spec.provenances.allSatisfy { $0 == .catalog })
    }

    /// Regression: schema 1 attached every source of an entry to every value, implying that an
    /// identifier list verified chip specifications. Each value now cites only its field's sources.
    @Test func eachValueCitesOnlyTheSourcesAttributedToItsField() throws {
        let spec = HardwareResolver.resolve(identity: identity("TestPhone1,1"), catalog: try Fixture.catalog("valid-catalog"))
        guard case .catalog(_, let chipReference) = spec.gpuCores,
              case .catalog(_, let nameReference) = spec.marketingName
        else { Issue.record("Expected catalog values"); return }
        #expect(chipReference.sources.map(\.url) == [URL(string: "https://example.com/test-phone")!])
        #expect(nameReference.sources.count == 1)
        #expect(!chipReference.sources.contains { $0.supports == [.identifiers] })
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
    private func catalog() throws -> DeviceCatalog { try DeviceCatalog.loadBundled().get() }

    private func entry(_ raw: String) throws -> CatalogEntry {
        guard case .found(let entry) = try catalog().lookup(identifier(raw)) else {
            throw CatalogTestError.missing(raw)
        }
        return entry
    }

    private enum CatalogTestError: Error { case missing(String) }

    @Test func loadsAndValidatesUnderTheApplePolicy() throws {
        let catalog = try catalog()
        #expect(catalog.schemaVersion == DeviceCatalog.supportedSchemaVersion)
        #expect(catalog.catalogVersion == "2026.10.3")
    }

    /// Pins the documented coverage so that an accidental deletion fails a test.
    /// Update together with Packages/SpecMatrixKit/README.md when entries are added.
    @Test func coverageMatchesTheDocumentedCounts() throws {
        let entries = try catalog().entries
        let byFamily = Dictionary(grouping: entries, by: \.family)
        #expect(entries.count == 112)
        #expect(byFamily["iPhone"]?.count == 36)
        #expect(byFamily["iPad"]?.count == 32)
        #expect(byFamily["Mac"]?.count == 44)
        #expect(Set(byFamily.keys) == ["iPhone", "iPad", "Mac"])
        #expect(entries.reduce(0) { $0 + $1.identifiers.count } == 168)
        #expect(byFamily["Mac"]?.reduce(0) { $0 + $1.identifiers.count } == 58)
        #expect(entries.allSatisfy { $0.verification.status == .verified })
    }

    @Test func everyIdentifierResolvesToItsOwnEntry() throws {
        let catalog = try catalog()
        for entry in catalog.entries {
            for id in entry.identifiers {
                #expect(catalog.lookup(id) == .found(entry), "\(id) does not resolve to \(entry.id)")
            }
        }
    }

    /// Identifiers cite Apple first-party data — the Xcode Simulator profile for iPhone and iPad, Apple's
    /// "Identify your Mac" page for Macs — plus at least one independent reference.
    @Test func identifiersCiteAppleDataAndAnIndependentReference() throws {
        for entry in try catalog().entries {
            let sources = entry.sources(supporting: .identifiers)
            let simulatorProfile = sources.contains { if case .xcodeSimulatorDeviceType = $0.location { true } else { false } }
            if entry.family == "Mac" {
                #expect(sources.contains { $0.url?.host == "support.apple.com" }, "\(entry.id)")
            } else {
                #expect(simulatorProfile, "\(entry.id)")
            }
            #expect(sources.contains { $0.publisher != "apple.com" }, "\(entry.id)")
        }
    }

    @Test func identifiersThatAreNotCataloguedStayUnknown() throws {
        let catalog = try catalog()
        let notCatalogued = [
            "iPhone10,1",  // iPhone 8: not supported by iOS 17, not catalogued
            "iPhone19,1",  // between catalogued iPhone18,5 and iPhone19,2
            "iPhone19,4",  // between iPhone19,3 and iPhone19,7 (both iPhone 18 Pro Max)
            "iPhone16,3", "iPhone16,4", // invented by the legacy app
            "iPad7,7",     // between iPad Pro (10.5-inch) and iPad (6th generation)
            "iPad17,5",    // after the last iPad Pro (M5) identifier
            "Mac16,4",     // between catalogued iMac Mac16,3 and MacBook Pro Mac16,5
            "MacBookPro16,1", "iMac20,1", // Intel Macs: not catalogued (Apple silicon only)
            // Product families SpecMatrix does not target.
            "Watch7,3", "AppleTV14,1", "RealityDevice14,1", "iPod9,1",
        ]
        for raw in notCatalogued {
            #expect(catalog.lookup(identifier(raw)) == .notFound(identifier(raw)), "\(raw)")
            let spec = HardwareResolver.resolve(
                identity: .measured(DeviceIdentity(identifier: identifier(raw), environment: .device),
                                    MeasurementSource(api: "Test", environment: .device)),
                catalog: .success(catalog))
            #expect(spec.provenances.allSatisfy { $0 == .unknown }, "\(raw) inherited catalog values")
        }
    }

    // MARK: Values checked against Apple's technical specifications (see the README's coverage notes)

    /// Regression: the catalog records the diagonal measured as a rectangle (6.27 in), as Apple
    /// publishes for every rounded-corner screen, not the rounded marketing size (6.3-inch).
    @Test func iPhone16ProMatchesAppleSpecifications() throws {
        let entry = try entry("iPhone17,1")
        #expect(entry.marketingName == "iPhone 16 Pro")
        #expect(entry.chip?.name == "A18 Pro")
        #expect(entry.chip?.neuralEngineCores == 16)   // the legacy app said 18
        #expect(entry.chip?.gpuCores == 6)
        #expect(entry.display?.diagonal == DisplayDiagonal(inches: 6.27))
        #expect(entry.display?.pixelDensity == PixelDensity(pixelsPerInch: 460))
    }

    @Test func iPhone16UsesA18WithFiveCoreGPU() throws {
        let entry = try entry("iPhone17,3")
        #expect(entry.chip?.name == "A18")          // the legacy app said "A18 Bionic"
        #expect(entry.chip?.gpuCores == 5)          // the legacy app said 6 in one table
        #expect(entry.display?.diagonal == DisplayDiagonal(inches: 6.12))
        #expect(entry.display?.pixelDensity == PixelDensity(pixelsPerInch: 460)) // the legacy app said 458
        // Apple does not state a refresh rate for non-ProMotion models; the catalog must not invent one.
        #expect(entry.display?.maximumRefreshRate == nil)
    }

    /// The same chip name can ship with different GPU core counts; each model keeps its own.
    @Test func binnedChipsKeepPerModelCoreCounts() throws {
        #expect(try entry("iPhone17,5").chip?.gpuCores == 4)   // iPhone 16e, A18
        #expect(try entry("iPhone14,5").chip?.gpuCores == 4)   // iPhone 13, A15 Bionic
        #expect(try entry("iPhone14,2").chip?.gpuCores == 5)   // iPhone 13 Pro, A15 Bionic
        #expect(try entry("iPhone18,4").chip?.gpuCores == 5)   // iPhone Air, A19 Pro
        #expect(try entry("iPhone18,1").chip?.gpuCores == 6)   // iPhone 17 Pro, A19 Pro
    }

    /// Apple describes the A20 Pro CPU as "2 super cores and 4 efficiency cores" and its Neural Engine
    /// as "Dual 16-core"; neither maps onto the schema without interpretation, so both are unrecorded.
    @Test func iPhone18ProRecordsOnlyUnambiguousChipFields() throws {
        let entry = try entry("iPhone19,2")
        #expect(entry.marketingName == "iPhone 18 Pro")
        #expect(entry.chip?.name == "A20 Pro")
        #expect(entry.chip?.performanceCores == nil)
        #expect(entry.chip?.efficiencyCores == 4)
        #expect(entry.chip?.gpuCores == 7)
        #expect(entry.chip?.neuralEngineCores == nil)
        #expect(try self.entry("iPhone19,7").marketingName == "iPhone 18 Pro Max")
    }

    /// M4 iPad Pro ships with a 9-core (3P + 6E) or 10-core (4P + 6E) CPU depending on storage,
    /// under the same identifiers, so only the efficiency-core count is recorded.
    @Test func configurationDependentCoreCountsAreNotRecorded() throws {
        for raw in ["iPad16,3", "iPad16,6", "iPad17,1", "iPad17,4"] {
            let chip = try #require(try entry(raw).chip)
            #expect(chip.performanceCores == nil, "\(raw)")
            #expect(chip.efficiencyCores == 6, "\(raw)")
            #expect(chip.gpuCores == 10, "\(raw)")
        }
        // Pages that give only a total ("5-core CPU") record no split either.
        #expect(try entry("iPad15,7").chip?.performanceCores == nil)
    }

    @Test func iPadValuesAreStoredInPortrait() throws {
        let entry = try entry("iPad16,4")
        #expect(entry.marketingName == "iPad Pro 11-inch (M4)")
        #expect(entry.display?.resolution == PixelDimensions(width: 1668, height: 2420))
        #expect(entry.display?.diagonal == DisplayDiagonal(inches: 11.1))
        #expect(entry.display?.maximumRefreshRate == RefreshRate(hertz: 120))
    }

    /// Apple's pages for older ProMotion iPads say "ProMotion technology" without a rate.
    @Test func refreshRateIsOnlyRecordedWhereAppleStatesIt() throws {
        #expect(try entry("iPad7,3").display?.maximumRefreshRate == nil)   // iPad Pro (10.5-inch)
        #expect(try entry("iPad14,3").display?.maximumRefreshRate == nil)  // iPad Pro 11-inch (4th generation)
        #expect(try entry("iPhone14,2").display?.maximumRefreshRate == RefreshRate(hertz: 120))
    }

    @Test func variantsWithIdenticalRecordedSpecificationsShareAnEntry() throws {
        // XS Max has two identifiers; the 2018 iPad Pro 11-inch has four (Wi-Fi/cellular × 1 TB).
        #expect(try entry("iPhone11,4").id == entry("iPhone11,6").id)
        #expect(Set(try entry("iPad8,1").identifiers.map(\.rawValue)) == ["iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4"])
    }

    @Test func releaseDatesAreOnlyRecordedWithAnAppleNewsroomSource() throws {
        for entry in try catalog().entries where entry.releaseDate != nil {
            let sources = entry.sources(supporting: .releaseDate)
            #expect(sources.allSatisfy { $0.url?.absoluteString.hasPrefix("https://www.apple.com/newsroom/") == true }, "\(entry.id)")
        }
        #expect(try entry("iPhone18,3").releaseDate == CalendarDate(iso8601: "2025-09-19"))
        #expect(try entry("iPhone17,3").releaseDate == nil)
    }

    @Test func chipValuesCiteOnlyAppleSources() throws {
        let catalog = try catalog()
        let spec = HardwareResolver.specification(for: try entry("iPhone13,3"), catalogVersion: catalog.catalogVersion)
        guard case .catalog(16, let reference) = spec.neuralEngineCores else {
            Issue.record("Expected a 16-core Neural Engine from the catalog"); return
        }
        // iPhone 12 Pro: name from the tech specs page, Neural Engine count from the newsroom article.
        #expect(Set(reference.sources.compactMap(\.url?.host)) == ["support.apple.com", "www.apple.com"])
        #expect(spec.gpuCores.provenance == .unknown)
    }
}
