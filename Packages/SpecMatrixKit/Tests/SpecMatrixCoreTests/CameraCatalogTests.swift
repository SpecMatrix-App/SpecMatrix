import Foundation
import Testing
@testable import SpecMatrixCore

/// The camera data in the bundled catalog, checked against Apple's iPhone tech-specs pages
/// (support.apple.com, accessed 2026-10-16) as cited by each entry.
@Suite("Bundled camera specifications")
struct BundledCameraTests {
    private let catalog: DeviceCatalog

    init() throws {
        catalog = try DeviceCatalog.loadBundled().get()
    }

    private func cameras(_ raw: String) throws -> CameraSpecification {
        let identifier = try #require(HardwareIdentifier(raw))
        guard case .found(let entry) = catalog.lookup(identifier) else {
            Issue.record("\(raw) is not catalogued")
            throw CancellationError()
        }
        return try #require(entry.cameras, "\(raw) has no camera data")
    }

    private func lens(_ name: String, _ megapixels: Int, _ apertures: [Double], zoom: Double? = nil) -> CameraLens {
        CameraLens(name: name, megapixels: megapixels, apertures: apertures, opticalZoom: zoom)
    }

    @Test func iPhone15ProCameras() throws {
        let iPhone15Pro = try cameras("iPhone16,1")
        #expect(iPhone15Pro.rear?.lenses == [lens("Main", 48, [1.78]), lens("Ultra Wide", 12, [2.2]),
                                         lens("3x Telephoto", 12, [2.8], zoom: 3)])
        #expect(iPhone15Pro.rear?.features == [.flash, .nightMode, .portraitMode])
        #expect(iPhone15Pro.front == FrontCamera(name: "TrueDepth", megapixels: 12, apertures: [1.9],
                                             features: [.flash, .nightMode, .portraitMode]))
    }

    /// The legacy table listed a 12MP Ultra Wide and a 3x telephoto for the 16 Pro, and ƒ/2.4 for
    /// the iPhone 16 Ultra Wide. Apple lists 48MP, 5x and ƒ/2.2.
    @Test func valuesTheLegacyTableGotWrong() throws {
        #expect(try cameras("iPhone17,1").rear?.lenses == [lens("Fusion", 48, [1.78]), lens("Ultra Wide", 48, [2.2]),
                                                          lens("5x Telephoto", 12, [2.8], zoom: 5)])
        #expect(try cameras("iPhone17,3").rear?.lenses == [lens("Fusion Main", 48, [1.6]), lens("Ultra Wide", 12, [2.2])])
        #expect(try cameras("iPhone17,4").rear?.lenses == [lens("Fusion Main", 48, [1.6]), lens("Ultra Wide", 12, [2.2])])
    }

    @Test func oldestAndNewestModels() throws {
        let xs = try cameras("iPhone11,2")
        #expect(xs.rear?.lenses == [lens("Wide-angle", 12, [1.8]), lens("Telephoto", 12, [2.4], zoom: 2)])
        #expect(xs.rear?.features == [.flash, .portraitMode])   // Night mode arrived with iPhone 11
        #expect(xs.front == FrontCamera(name: "TrueDepth", megapixels: 7, apertures: [2.2], features: [.flash, .portraitMode]))

        let pro18 = try cameras("iPhone19,2")
        #expect(pro18.rear?.lenses.first == lens("Fusion Main", 48, [1.48, 1.8, 2.8, 4.0]))  // variable aperture
        #expect(pro18.rear?.lenses.last == lens("Fusion Telephoto", 48, [2.8], zoom: 4))
        #expect(pro18.front == FrontCamera(name: "Center Stage", megapixels: 18, apertures: [1.9],
                                           features: [.flash, .nightMode, .portraitMode]))
    }

    /// Single-camera and unnamed front cameras are recorded as published, not padded with defaults.
    @Test func modelsWithFewerCameras() throws {
        let se = try cameras("iPhone14,6")
        #expect(se.rear?.lenses == [lens("Main", 12, [1.8])])
        #expect(se.rear?.features == [.flash, .portraitMode])
        #expect(se.front == FrontCamera(name: nil, megapixels: 7, apertures: [2.2], features: [.flash, .portraitMode]))
        #expect(try cameras("iPhone18,4").rear?.lenses == [lens("Fusion Main", 48, [1.6])])   // iPhone Air
    }

    @Test func everyIPhoneHasAppleSourcedCamerasAndOtherFamiliesHaveNone() throws {
        let iPhones = catalog.entries.filter { $0.family == "iPhone" }
        #expect(iPhones.count == 36)
        for entry in iPhones {
            let cameras = try #require(entry.cameras, "\(entry.id)")
            #expect(cameras.rear?.lenses.isEmpty == false, "\(entry.id)")
            #expect(cameras.front != nil, "\(entry.id)")
            let sources = entry.sources(supporting: .cameras)
            #expect(!sources.isEmpty && sources.allSatisfy { $0.url?.host == "support.apple.com" }, "\(entry.id)")
        }
        #expect(catalog.entries.filter { $0.family != "iPhone" }.allSatisfy { $0.cameras == nil })
    }

    /// iPhone16,3 appeared in the legacy camera table but is not an Apple identifier.
    @Test func inventedIdentifiersAreNotCatalogued() throws {
        for raw in ["iPhone16,3", "iPhone16,4"] {
            let identifier = try #require(HardwareIdentifier(raw))
            #expect(catalog.lookup(identifier) == .notFound(identifier))
        }
    }
}

@Suite("Camera validation")
struct CameraValidationTests {
    private func decode(cameras: Any, supports: [String] = ["identifiers", "marketingName", "cameras"]) -> Result<DeviceCatalog, CatalogLoadError> {
        let entry: [String: Any] = [
            "id": "test-phone", "identifiers": ["TestPhone1,1"], "family": "TestPhone", "marketingName": "Test Phone",
            "cameras": cameras,
            "sources": [["title": "S", "url": "https://example.com/specs", "accessed": "2026-10-15", "supports": supports]],
            "verification": ["status": "secondary-sources-only", "verifiedOn": "2026-10-15"],
        ]
        let root: [String: Any] = ["schemaVersion": 3, "catalogVersion": "2026.01.0", "entries": [entry]]
        return DeviceCatalog.decode(try! JSONSerialization.data(withJSONObject: root), policy: Fixture.policy)
    }

    private func messages(_ result: Result<DeviceCatalog, CatalogLoadError>) -> [String] {
        guard case .failure(.invalid(let issues)) = result else { return [] }
        return issues.map { "\($0.path): \($0.message)" }
    }

    private let validLens: [String: Any] = ["name": "Main", "megapixels": 12, "apertures": [1.8]]

    @Test func acceptsAValidCameraSpecification() throws {
        let result = decode(cameras: [
            "rear": ["lenses": [validLens, ["name": "Telephoto", "megapixels": 12, "apertures": [2.8], "opticalZoom": 3]],
                     "features": ["flash", "nightMode"]],
            "front": ["megapixels": 7, "apertures": [2.2], "features": []],
        ])
        let cameras = try #require(try result.get().entries.first?.cameras)
        #expect(cameras.rear?.lenses.last?.opticalZoom == 3)
        #expect(cameras.front?.name == nil)
    }

    /// Each case is a `cameras` object (JSON) and a fragment of the issue path it must produce.
    @Test(arguments: [
        (#"{"rear":{"lenses":[{"name":"Main","megapixels":0,"apertures":[1.8]}]}}"#, "megapixels"),
        (#"{"rear":{"lenses":[{"name":"Main","megapixels":12,"apertures":[0.5]}]}}"#, "apertures"),
        (#"{"rear":{"lenses":[{"name":"Main","megapixels":12,"apertures":[]}]}}"#, "apertures"),
        (#"{"rear":{"lenses":[{"name":"Main","megapixels":12,"apertures":[1.8,1.8]}]}}"#, "apertures"),
        (#"{"rear":{"lenses":[{"name":"Main","megapixels":12,"apertures":[1.8],"opticalZoom":1}]}}"#, "opticalZoom"),
        (#"{"rear":{"lenses":[{"name":"Main","megapixels":12,"apertures":[1.8]},{"name":"Main","megapixels":12,"apertures":[2.4]}]}}"#, "name"),
        (#"{"rear":{"lenses":[]}}"#, "lenses"),
        (#"{"rear":{"lenses":[{"name":"Main","megapixels":12,"apertures":[1.8]}],"features":["hdr"]}}"#, "features"),
        (#"{"rear":{"lenses":[{"name":"Main","megapixels":12,"apertures":[1.8]}],"features":["flash","flash"]}}"#, "features"),
        (#"{"front":{"apertures":[2.2]}}"#, "megapixels"),
        (#"{}"#, "cameras"),
    ])
    func rejectsInvalidCameraData(json: String, field: String) throws {
        let cameras = try JSONSerialization.jsonObject(with: Data(json.utf8))
        let found = messages(decode(cameras: cameras))
        #expect(found.contains { $0.contains(field) }, "\(found)")
    }

    @Test func rejectsUnknownCameraFields() {
        let found = messages(decode(cameras: ["rear": ["lenses": [validLens.merging(["focalLength": 26]) { a, _ in a }]],
                                              "back": [:]]))
        #expect(found.contains("entries[0].cameras.back: Unknown field."))
        #expect(found.contains("entries[0].cameras.rear.lenses[0].focalLength: Unknown field."))
    }

    @Test func camerasNeedASourceAndSourcesCannotClaimMissingCameras() {
        #expect(messages(decode(cameras: ["rear": ["lenses": [validLens]]], supports: ["identifiers", "marketingName"]))
                .contains("entries[0].sources: No source supports cameras."))
        let entry: [String: Any] = [
            "id": "test-phone", "identifiers": ["TestPhone1,1"], "family": "TestPhone", "marketingName": "Test Phone",
            "sources": [["title": "S", "url": "https://example.com/specs", "accessed": "2026-10-15",
                         "supports": ["identifiers", "marketingName", "cameras"]]],
            "verification": ["status": "secondary-sources-only", "verifiedOn": "2026-10-15"],
        ]
        let root: [String: Any] = ["schemaVersion": 3, "catalogVersion": "2026.01.0", "entries": [entry]]
        let result = DeviceCatalog.decode(try! JSONSerialization.data(withJSONObject: root), policy: Fixture.policy)
        #expect(messages(result).contains("entries[0].sources[0].supports: Claims cameras, which the entry does not record."))
    }
}
