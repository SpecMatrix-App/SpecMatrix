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

    private func count(_ value: Int?) -> String { value.map(String.init) ?? Self.unknown }
    private func cores(_ value: Int?) -> String { value.map { "\($0)-core" } ?? Self.unknown }
}
