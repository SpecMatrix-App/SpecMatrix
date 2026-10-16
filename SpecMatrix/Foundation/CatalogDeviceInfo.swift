//
//  CatalogDeviceInfo.swift
//  SpecMatrix
//

import Foundation
import SpecMatrixCore
import UIKit

/// Device facts for the legacy screens, read from the bundled catalog by exact hardware identifier.
///
/// This is the only place the legacy UI turns an identifier into product information, so adding a
/// model only requires a catalog entry. Values the catalog does not record — or every value, when
/// the identifier is not catalogued — are shown as "Unknown", never as a guess or another model's data.
struct CatalogDeviceInfo {
    static let unknown = "Unknown"

    /// The identifier as reported by the system (`uname`, or the simulated model in the Simulator).
    let identifier: String
    let entry: CatalogEntry?

    init(identifier: String, catalog: Result<DeviceCatalog, CatalogLoadError>) {
        self.identifier = identifier
        if let parsed = HardwareIdentifier(identifier), case .success(let loaded) = catalog,
           case .found(let entry) = loaded.lookup(parsed) {
            self.entry = entry
        } else {
            self.entry = nil
        }
    }

    /// The running device, looked up in the catalog bundled with the app.
    static func current() -> CatalogDeviceInfo {
        CatalogDeviceInfo(identifier: UIDevice.modelIdentifier(), catalog: AppEnvironment.catalog)
    }

    var modelName: String { entry?.marketingName ?? "Unknown model (\(identifier))" }
    var chipName: String { entry?.chip?.name ?? Self.unknown }
    var gpuName: String { entry?.chip.map { "Apple \($0.name) GPU" } ?? Self.unknown }

    var cpuCores: String {
        guard let chip = entry?.chip, let performance = chip.performanceCores, let efficiency = chip.efficiencyCores
        else { return Self.unknown }
        return "\(performance + efficiency)-core"
    }

    var performanceCores: String { count(entry?.chip?.performanceCores) }
    var efficiencyCores: String { count(entry?.chip?.efficiencyCores) }
    var gpuCores: String { cores(entry?.chip?.gpuCores) }
    var neuralEngineCores: String { cores(entry?.chip?.neuralEngineCores) }

    var pixelDensity: String {
        entry?.display?.pixelDensity.map { "\($0.pixelsPerInch) PPI" } ?? Self.unknown
    }

    /// The diagonal measured as a rectangle, e.g. 6.12″ for iPhone 16 (marketed as 6.1-inch).
    var displaySize: String {
        entry?.display?.diagonal.map { "\($0.inches.formatted(.number.precision(.fractionLength(0...2))))\"" } ?? Self.unknown
    }

    // MARK: Cameras

    /// One camera section of the Camera screen. Every value comes from the catalog entry for this
    /// exact model; an uncatalogued model or side shows "Unknown" and no features.
    struct CameraSummary: Equatable {
        let title: String
        /// One line per camera, e.g. "48 MP Main" or "12 MP Telephoto (2x)".
        let resolution: String
        /// Apertures in the same order, e.g. "ƒ/1.78, ƒ/2.2, ƒ/2.8"; a variable aperture reads "ƒ/1.48–4.0".
        let aperture: String
        /// Features the manufacturer lists for this side, e.g. ["Flash", "Night Mode", "Portrait Mode"].
        let features: [String]
    }

    var backCamera: CameraSummary {
        guard let rear = entry?.cameras?.rear else { return Self.unknownCamera("Back Camera") }
        return CameraSummary(
            title: "Back Camera",
            resolution: rear.lenses.map { lens in
                let zoom = lens.opticalZoom.map { Self.zoom($0) }
                let named = zoom.map { lens.name.hasPrefix($0) } ?? true
                return "\(lens.megapixels) MP \(lens.name)" + (named ? "" : " (\(zoom!))")
            }.joined(separator: "\n"),
            aperture: rear.lenses.map { Self.aperture($0.apertures) }.joined(separator: ", "),
            features: Self.features(rear.features, flash: "Flash")
        )
    }

    var frontCamera: CameraSummary {
        guard let front = entry?.cameras?.front else { return Self.unknownCamera("Front Camera") }
        return CameraSummary(
            title: "Front Camera",
            resolution: "\(front.megapixels) MP" + (front.name.map { " \($0)" } ?? ""),
            aperture: Self.aperture(front.apertures),
            features: Self.features(front.features, flash: "Retina Flash")
        )
    }

    private static func unknownCamera(_ title: String) -> CameraSummary {
        CameraSummary(title: title, resolution: unknown, aperture: unknown, features: [])
    }

    /// f-numbers as Apple prints them: at least one decimal (ƒ/2.0), at most two (ƒ/1.78).
    private static func fNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1...2)).locale(Locale(identifier: "en_US_POSIX")))
    }

    private static func aperture(_ values: [Double]) -> String {
        guard let low = values.min(), let high = values.max() else { return unknown }
        return values.count == 1 ? "ƒ/\(fNumber(low))" : "ƒ/\(fNumber(low))–\(fNumber(high))"
    }

    private static func zoom(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "en_US_POSIX"))) + "x"
    }

    private static func features(_ features: Set<CameraFeature>, flash: String) -> [String] {
        [(CameraFeature.flash, flash), (.nightMode, "Night Mode"), (.portraitMode, "Portrait Mode")]
            .filter { features.contains($0.0) }.map(\.1)
    }

    private func count(_ value: Int?) -> String { value.map(String.init) ?? Self.unknown }
    private func cores(_ value: Int?) -> String { value.map { "\($0)-core" } ?? Self.unknown }
}
