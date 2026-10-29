import Foundation
import SpecMatrixMacCatalog
import SpecMatrixShared
import Testing

@Suite("Bundled Mac catalog")
struct BundledMacCatalogTests {
    private let catalog: MacCatalog

    init() throws {
        catalog = try MacCatalog.loadBundled().get()
    }

    @Test func loadsWithTheDerivedRecords() {
        #expect(catalog.catalogVersion == "2026.10.1")
        #expect(catalog.entries.count == 44)
        #expect(catalog.entries.flatMap(\.identifiers).count == 58)
        #expect(catalog.entries.flatMap(\.configurations).count == 89)
        #expect(catalog.entries.allSatisfy { !$0.configurations.isEmpty })
    }

    @Test func macBookAirM2() throws {
        let identifier = try #require(HardwareIdentifier("Mac14,2"))
        let entry = try #require(catalog.entry(for: identifier))
        #expect(entry.marketingName == "MacBook Air (M2, 2022)")
        // 8- and 10-core GPU configurations share Mac14,2.
        #expect(entry.configurations.map(\.gpuCores) == [8, 10])
        #expect(entry.configurations.allSatisfy { $0.chip == "M2" && $0.cpuCores == 8 && $0.neuralEngineCores == 16 })
        #expect(entry.configurations.first?.cpuClusters == [MacCPUCluster(kind: .performance, cores: 4),
                                                            MacCPUCluster(kind: .efficiency, cores: 4)])
        #expect(entry.display?.resolution == PixelDimensions(width: 2560, height: 1664))   // landscape
        #expect(entry.display?.pixelDensity == PixelDensity(pixelsPerInch: 224))
        #expect(entry.display?.diagonal == DisplayDiagonal(inches: 13.6))
        #expect(entry.sources(supporting: .chip).allSatisfy { $0.publisher == "apple.com" })
    }

    @Test func containsOnlyMacIdentifiersAndNoCameraAttribution() {
        for entry in catalog.entries {
            #expect(entry.identifiers.allSatisfy { MacCatalog.identifierFamilies.contains($0.family) }, "\(entry.id)")
            #expect(entry.sources.allSatisfy { !$0.supports.contains(.cameras) }, "\(entry.id)")
            #expect(entry.display?.resolution.map { $0.width >= $0.height } ?? true, "\(entry.id)")
            #expect(entry.sources(supporting: .chip).contains { $0.publisher == "apple.com" }, "\(entry.id)")
        }
    }

    @Test func lookupIsExact() throws {
        for raw in ["iPhone16,1", "Mac99,9", "mac14,2", "Mac14,20"] {
            let identifier = try #require(HardwareIdentifier(raw))
            #expect(catalog.entry(for: identifier) == nil, "\(raw)")
        }
    }
}

@Suite("Mac catalog validation")
struct MacCatalogValidationTests {
    private func entry(identifier: String = "Mac14,2", supports: [String] = ["identifiers", "marketingName"],
                       display: [String: Any]? = nil) -> [String: Any] {
        var entry: [String: Any] = [
            "id": "test-mac", "identifiers": [identifier], "marketingName": "Test Mac",
            "sources": [["title": "S", "url": "https://example.com/mac", "accessed": "2026-10-15", "supports": supports]],
            "verification": ["status": "secondary-sources-only", "verifiedOn": "2026-10-15"],
        ]
        if let display { entry["display"] = display }
        return entry
    }

    private func decode(_ entries: [[String: Any]], schemaVersion: Int = 2) -> Result<MacCatalog, CatalogLoadError> {
        let root: [String: Any] = ["schemaVersion": schemaVersion, "catalogVersion": "2026.01.0", "entries": entries]
        return MacCatalog.decode(try! JSONSerialization.data(withJSONObject: root))
    }

    private func messages(_ result: Result<MacCatalog, CatalogLoadError>) -> [String] {
        guard case .failure(.invalid(let issues)) = result else { return [] }
        return issues.map(\.description)
    }

    @Test func acceptsAMinimalEntry() throws {
        let catalog = try decode([entry()]).get()
        #expect(catalog.entries.first?.marketingName == "Test Mac")
    }

    @Test func rejectsOtherSchemaVersions() {
        #expect(decode([entry()], schemaVersion: 1) == .failure(.unsupportedSchemaVersion(found: 1, supported: 2)))
        #expect(decode([entry()], schemaVersion: 3) == .failure(.unsupportedSchemaVersion(found: 3, supported: 2)))
    }

    private func entry(configurations: [[String: Any]]) -> [String: Any] {
        var entry = entry(supports: ["identifiers", "marketingName", "chip"])
        entry["configurations"] = configurations
        return entry
    }

    private func cluster(_ type: String, _ cores: Int) -> [String: Any] { ["type": type, "cores": cores] }

    @Test func acceptsConfigurations() throws {
        let configuration: [String: Any] = ["chip": "M5", "cpuCores": 10, "gpuCores": 10, "neuralEngineCores": 16,
                                            "cpuClusters": [cluster("super", 4), cluster("efficiency", 6)]]
        let catalog = try decode([entry(configurations: [configuration])]).get()
        #expect(catalog.entries.first?.configurations.first?.cpuClusters?.first == MacCPUCluster(kind: .superTier, cores: 4))
    }

    @Test func rejectsInconsistentConfigurations() {
        let sum: [String: Any] = ["chip": "M2", "cpuCores": 10, "cpuClusters": [cluster("performance", 4), cluster("efficiency", 4)]]
        #expect(messages(decode([entry(configurations: [sum])])).contains { $0.contains("add up to 8, not cpuCores 10") })
        let order: [String: Any] = ["chip": "M2", "cpuClusters": [cluster("efficiency", 4), cluster("performance", 4)]]
        #expect(messages(decode([entry(configurations: [order])])).contains { $0.contains("highest performance first") })
        let kind: [String: Any] = ["chip": "M2", "cpuClusters": [cluster("turbo", 4)]]
        #expect(messages(decode([entry(configurations: [kind])])).contains { $0.contains("\"turbo\" is not one of") })
        #expect(messages(decode([entry(configurations: [])])).contains { $0.contains("Must not be empty") })
        let duplicate: [String: Any] = ["chip": "M2", "gpuCores": 8]
        #expect(messages(decode([entry(configurations: [duplicate, duplicate])])).contains { $0.contains("Duplicates") })
    }

    @Test func configurationsNeedChipAttribution() {
        var unattributed = entry()
        unattributed["configurations"] = [["chip": "M2"]]
        #expect(messages(decode([unattributed])).contains { $0.contains("No source supports chip") })
    }

    @Test func rejectsIPhoneIdentifiers() {
        #expect(messages(decode([entry(identifier: "iPhone16,1")])).contains { $0.contains("is not a Mac model identifier") })
    }

    @Test func rejectsCameraAttribution() {
        #expect(messages(decode([entry(supports: ["identifiers", "marketingName", "cameras"])]))
                .contains { $0.contains("\"cameras\" is not one of") })
    }

    @Test func rejectsPortraitResolution() {
        let display: [String: Any] = ["pixelWidth": 1664, "pixelHeight": 2560]
        #expect(messages(decode([entry(supports: ["identifiers", "marketingName", "display"], display: display)]))
                .contains { $0.contains("landscape") })
    }

    @Test func rejectsUnknownFields() {
        var withTypo = entry()
        withTypo["marketingNmae"] = "Typo"
        #expect(messages(decode([withTypo])).contains("entries[0].marketingNmae: Unknown field."))
    }
}
