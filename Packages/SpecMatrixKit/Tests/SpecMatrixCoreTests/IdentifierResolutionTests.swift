import Foundation
import Testing
@testable import SpecMatrixCore

/// Identifier → model resolution against the bundled catalog, across every catalogued family.
/// Expected names and identifiers come from Apple's pages and Xcode Simulator profiles
/// (see the catalog section of Packages/SpecMatrixKit/README.md).
@Suite("Identifier resolution")
struct IdentifierResolutionTests {
    private let catalog: DeviceCatalog

    init() throws {
        catalog = try DeviceCatalog.loadBundled().get()
    }

    private func entry(_ raw: String) -> CatalogEntry? {
        guard let identifier = HardwareIdentifier(raw) else {
            Issue.record("\(raw) is not a valid identifier")
            return nil
        }
        guard case .found(let entry) = catalog.lookup(identifier) else {
            Issue.record("\(raw) is not catalogued")
            return nil
        }
        return entry
    }

    private func name(_ raw: String) -> String? { entry(raw)?.marketingName }

    // MARK: iPhone16,1

    /// iPhone16,1 is the iPhone 15 Pro. It was missing from the 8-model catalog of 2026.10.0, and
    /// the legacy screens used a separate hardcoded table instead of the catalog.
    @Test func iPhone16_1IsTheIPhone15Pro() throws {
        let resolved = try #require(entry("iPhone16,1"))
        #expect(resolved.id == "iphone-15-pro")
        #expect(resolved.marketingName == "iPhone 15 Pro")
        #expect(resolved.family == "iPhone")
        #expect(resolved.identifiers.map(\.rawValue) == ["iPhone16,1"])
        #expect(resolved.chip == ChipSpecification(name: "A17 Pro", performanceCores: 2, efficiencyCores: 4,
                                                gpuCores: 6, neuralEngineCores: 16))
        #expect(resolved.display?.diagonal == DisplayDiagonal(inches: 6.12))
        #expect(resolved.display?.resolution == PixelDimensions(width: 1179, height: 2556))
        #expect(resolved.display?.pixelDensity == PixelDensity(pixelsPerInch: 460))
        #expect(resolved.display?.maximumRefreshRate == RefreshRate(hertz: 120))
    }

    /// The legacy ContentView table mapped these identifiers to the wrong products (or invented them).
    @Test func identifiersTheLegacyTableGotWrong() {
        let expected = [
            "iPhone16,2": "iPhone 15 Pro Max",   // legacy: "iPhone 15 Plus"
            "iPhone15,4": "iPhone 15",           // legacy: "iPhone 15 Pro"
            "iPhone15,5": "iPhone 15 Plus",      // legacy: "iPhone 15 Pro Max"
            "iPhone15,2": "iPhone 14 Pro",       // legacy: "iPhone 15"
            "iPhone15,3": "iPhone 14 Pro Max",   // legacy: "iPhone 15 Plus"
            "iPhone14,4": "iPhone 13 mini",      // legacy: "iPhone 14 Pro"
            "iPhone14,5": "iPhone 13",           // legacy: "iPhone 14 Pro Max"
            "iPhone13,1": "iPhone 12 mini",      // legacy: "iPhone 13 mini"
            "iPhone13,2": "iPhone 12",           // legacy: "iPhone 13"
            "iPhone13,3": "iPhone 12 Pro",       // legacy: "iPhone 13 Pro"
            "iPhone13,4": "iPhone 12 Pro Max",   // legacy: "iPhone 13 Pro Max"
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
        ]
        for (raw, marketingName) in expected {
            #expect(name(raw) == marketingName, "\(raw)")
        }
        // The legacy table also listed iPhone16,3 and iPhone16,4, which Apple never shipped.
        for raw in ["iPhone16,3", "iPhone16,4"] {
            #expect(catalog.lookup(HardwareIdentifier(raw)!) == .notFound(HardwareIdentifier(raw)!))
        }
    }

    // MARK: Families and generations

    @Test func representativeIPhonesFromOldestToNewest() {
        #expect(name("iPhone11,2") == "iPhone XS")             // 2018, oldest iOS 17 iPhone
        #expect(name("iPhone11,8") == "iPhone XR")
        #expect(name("iPhone12,8") == "iPhone SE (2nd generation)")
        #expect(name("iPhone14,6") == "iPhone SE (3rd generation)")
        #expect(name("iPhone17,5") == "iPhone 16e")
        #expect(name("iPhone18,4") == "iPhone Air")
        #expect(name("iPhone18,5") == "iPhone 17e")
        #expect(name("iPhone19,2") == "iPhone 18 Pro")
        #expect(name("iPhone19,3") == "iPhone 18 Pro Max")
    }

    @Test func representativeIPads() {
        #expect(name("iPad7,5") == "iPad (6th generation)")
        #expect(name("iPad15,8") == "iPad (A16)")
        #expect(name("iPad11,1") == "iPad mini (5th generation)")
        #expect(name("iPad16,2") == "iPad mini (A17 Pro)")
        #expect(name("iPad11,3") == "iPad Air (3rd generation)")
        #expect(name("iPad16,11") == "iPad Air 13-inch (M4)")
        #expect(name("iPad7,3") == "iPad Pro (10.5-inch)")
        #expect(name("iPad13,4") == "iPad Pro 11-inch (3rd generation)")
        #expect(name("iPad17,4") == "iPad Pro 13-inch (M5)")
    }

    @Test func representativeMacs() {
        #expect(name("MacBookAir10,1") == "MacBook Air (M1, 2020)")
        #expect(name("Mac14,2") == "MacBook Air (M2, 2022)")
        #expect(name("Mac17,4") == "MacBook Air (15-inch, M5)")
        #expect(name("MacBookPro17,1") == "MacBook Pro (13-inch, M1, 2020)")
        #expect(name("Mac16,1") == "MacBook Pro (14-inch, M4, 2024)")
        #expect(name("Mac16,5") == "MacBook Pro (16-inch, 2024)")
        #expect(name("Mac16,3") == "iMac (24-inch, 2024, Four ports)")
        #expect(name("Macmini9,1") == "Mac mini (M1, 2020)")
        #expect(name("Mac18,5") == "Mac mini (M6)")
        #expect(name("Mac13,2") == "Mac Studio (2022)")
        #expect(name("Mac14,8") == "Mac Pro (2023)")
    }

    @Test func everyCataloguedIdentifierUsesItsFamilysPrefix() {
        let prefixes: [String: Set<String>] = [
            "iPhone": ["iPhone"], "iPad": ["iPad"],
            "Mac": ["Mac", "MacBookAir", "MacBookPro", "Macmini", "iMac"],
        ]
        for entry in catalog.entries {
            for identifier in entry.identifiers {
                #expect(prefixes[entry.family]?.contains(identifier.family) == true, "\(identifier) in \(entry.id)")
            }
        }
    }

    // MARK: Multiple identifiers per product

    @Test func variantsResolveToOneEntry() throws {
        let cases: [(identifiers: [String], name: String)] = [
            (["iPhone11,4", "iPhone11,6"], "iPhone XS Max"),
            (["iPhone19,3", "iPhone19,7"], "iPhone 18 Pro Max"),
            (["iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4"], "iPad Pro 11-inch (1st generation)"),
            (["iPad16,3", "iPad16,4"], "iPad Pro 11-inch (M4)"),
            (["Mac15,6", "Mac15,8", "Mac15,10"], "MacBook Pro (14-inch, M3 Pro or M3 Max, Nov 2023)"),
            (["iMac21,1", "iMac21,2"], "iMac (24-inch, M1, 2021)"),
        ]
        for (identifiers, marketingName) in cases {
            let entries = identifiers.compactMap { entry($0) }
            #expect(entries.count == identifiers.count)
            #expect(Set(entries.map(\.id)).count == 1, "\(identifiers) split across entries")
            #expect(entries.first?.marketingName == marketingName)
            #expect(Set(entries.first?.identifiers.map(\.rawValue) ?? []) == Set(identifiers))
        }
    }

    /// Apple reuses some names; the entries are kept apart by chip, and each identifier keeps its own chip.
    @Test func sharedAppleNamesAreDistinguishedByChip() throws {
        let max = try #require(entry("Mac14,13")), ultra = try #require(entry("Mac14,14"))
        #expect(max.marketingName == "Mac Studio (2023)" && ultra.marketingName == "Mac Studio (2023)")
        #expect(max.id != ultra.id)
        #expect(max.chip?.name == "M2 Max" && max.chip?.neuralEngineCores == 16)
        #expect(ultra.chip?.name == "M2 Ultra" && ultra.chip?.neuralEngineCores == 32)
        #expect(entry("Mac14,3")?.chip?.name == "M2")
        #expect(entry("Mac14,12")?.chip?.name == "M2 Pro")
    }

    /// Where Apple groups identifiers as "M4 Pro or M4 Max", no chip is recorded rather than a guess.
    @Test func groupedChipsAreNotAssignedToIdentifiers() throws {
        for raw in ["Mac16,6", "Mac16,8", "Mac15,7", "MacBookPro18,1", "Mac16,10"] {
            #expect(try #require(entry(raw)).chip == nil, "\(raw)")
        }
    }

    @Test func macDisplaysAndDesktopsWithoutDisplays() throws {
        let macBookPro = try #require(entry("Mac16,1"))
        #expect(macBookPro.display?.diagonal == DisplayDiagonal(inches: 14.2))
        #expect(macBookPro.display?.resolution == PixelDimensions(width: 1964, height: 3024))
        #expect(macBookPro.display?.pixelDensity == PixelDensity(pixelsPerInch: 254))
        #expect(macBookPro.display?.maximumRefreshRate == RefreshRate(hertz: 120))
        // iMac is marketed as 24-inch; Apple gives the actual diagonal as 23.5 in.
        #expect(entry("Mac15,4")?.display?.diagonal == DisplayDiagonal(inches: 23.5))
        // Mac mini, Mac Studio and Mac Pro have no built-in display.
        for raw in ["Macmini9,1", "Mac16,9", "Mac14,8"] {
            #expect(try #require(entry(raw)).display == nil, "\(raw)")
        }
    }

    // MARK: Unknown and malformed identifiers

    @Test func malformedIdentifiersAreRejectedBeforeLookup() {
        for raw in ["", "iPhone16", "iPhone16,", ",1", "16,1", "iPhone16,1,2", "iPhone 16,1", "iPhone16.1",
                    "arm64", "x86_64", "iPhone12345,1"] {
            #expect(HardwareIdentifier(raw) == nil, "\(raw)")
        }
        // NUL padding from `uname` and surrounding whitespace are trimmed; the identifier still resolves.
        #expect(HardwareIdentifier("iPhone16,1\0\0").flatMap { catalog.lookup($0) } == catalog.lookup(HardwareIdentifier("iPhone16,1")!))
    }

    @Test func lookupIsExactAndCaseSensitive() {
        for raw in ["iphone16,1", "IPHONE16,1", "iPhone016,1", "iPhone16,01"] {
            let identifier = HardwareIdentifier(raw)!
            #expect(catalog.lookup(identifier) == .notFound(identifier), "\(raw)")
        }
    }
}

@Suite("Duplicate and conflicting entries")
struct DuplicateEntryTests {
    private func decode(_ entries: [[String: Any]]) -> Result<DeviceCatalog, CatalogLoadError> {
        let root: [String: Any] = ["schemaVersion": 3, "catalogVersion": "2026.01.0", "entries": entries]
        return DeviceCatalog.decode(try! JSONSerialization.data(withJSONObject: root), policy: Fixture.policy)
    }

    private func entry(_ id: String, _ identifier: String, name: String, chip: String?) -> [String: Any] {
        var entry: [String: Any] = [
            "id": id, "identifiers": [identifier], "family": "TestPhone", "marketingName": name,
            "sources": [["title": "S", "url": "https://example.com/\(id)", "accessed": "2026-10-15",
                         "supports": ["identifiers", "marketingName"] + (chip == nil ? [] : ["chip"])]],
            "verification": ["status": "secondary-sources-only", "verifiedOn": "2026-10-15"],
        ]
        if let chip { entry["chip"] = ["name": chip] }
        return entry
    }

    @Test func sameNameWithDifferentChipsIsAllowed() {
        let result = decode([entry("a", "TestPhone1,1", name: "Test (2023)", chip: "Chip Max"),
                             entry("b", "TestPhone1,2", name: "Test (2023)", chip: "Chip Ultra")])
        #expect((try? result.get())?.entries.count == 2)
    }

    @Test func sameNameAndChipIsRejected() {
        let result = decode([entry("a", "TestPhone1,1", name: "Test (2023)", chip: "Chip"),
                             entry("b", "TestPhone1,2", name: "Test (2023)", chip: "Chip")])
        guard case .failure(.invalid(let issues)) = result else { Issue.record("Expected invalid"); return }
        #expect(issues.map(\.path) == ["entries[1].marketingName"])
    }

    @Test func sameNameWithAnUnrecordedChipIsRejected() {
        let result = decode([entry("a", "TestPhone1,1", name: "Test (2023)", chip: "Chip"),
                             entry("b", "TestPhone1,2", name: "Test (2023)", chip: nil)])
        guard case .failure(.invalid(let issues)) = result else { Issue.record("Expected invalid"); return }
        #expect(issues.map(\.path) == ["entries[1].marketingName"])
    }

    @Test func oneIdentifierMappedToTwoEntriesIsRejected() {
        let result = decode([entry("a", "TestPhone1,1", name: "A", chip: nil),
                             entry("b", "TestPhone1,1", name: "B", chip: nil)])
        guard case .failure(.invalid(let issues)) = result else { Issue.record("Expected invalid"); return }
        #expect(issues == [CatalogIssue(path: "entries[1].identifiers[0]", message: "TestPhone1,1 is already assigned to entry \"a\".")])
    }

    @Test func duplicateEntryIDIsRejected() {
        let result = decode([entry("a", "TestPhone1,1", name: "A", chip: nil),
                             entry("a", "TestPhone1,2", name: "B", chip: nil)])
        guard case .failure(.invalid(let issues)) = result else { Issue.record("Expected invalid"); return }
        #expect(issues.map(\.path) == ["entries[1].id"])
    }
}
