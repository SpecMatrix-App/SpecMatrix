import Foundation
import SpecMatrixMacCatalog
import SpecMatrixShared

/// Specifications that macOS does not expose, taken from the Mac catalog for this exact model.
///
/// Every value is `.catalog` (with its citation), `.unknown` (with the reason), or `.error` (the catalog
/// failed to load). Chip-specific catalog values are used only when the catalog's chip matches the chip
/// macOS reports, so a value from a different configuration is never shown.
public struct MacSpecification: Sendable, Equatable {
    public var marketingName: SpecValue<String>
    public var catalogChipName: SpecValue<String>
    public var gpuCores: SpecValue<Int>
    public var neuralEngineCores: SpecValue<Int>
    public var builtInDisplayDiagonal: SpecValue<DisplayDiagonal>
    public var builtInDisplayResolution: SpecValue<PixelDimensions>
    public var builtInDisplayPixelDensity: SpecValue<PixelDensity>
    public var builtInDisplayMaximumRefreshRate: SpecValue<RefreshRate>
    /// The catalog entry used, if any.
    public var entryID: String?

    public init(allMissing reason: MissingValue) {
        marketingName = SpecValue(reason)
        catalogChipName = SpecValue(reason)
        gpuCores = SpecValue(reason)
        neuralEngineCores = SpecValue(reason)
        builtInDisplayDiagonal = SpecValue(reason)
        builtInDisplayResolution = SpecValue(reason)
        builtInDisplayPixelDensity = SpecValue(reason)
        builtInDisplayMaximumRefreshRate = SpecValue(reason)
        entryID = nil
    }
}

public enum MacSpecificationResolver {
    /// - Parameters:
    ///   - identifier: The measured model identifier (`hw.model`).
    ///   - detectedChipName: The chip name macOS reports (`machdep.cpu.brand_string`, e.g. "Apple M2").
    public static func resolve(identifier: SpecValue<HardwareIdentifier>,
                               detectedChipName: SpecValue<String>,
                               catalog: Result<MacCatalog, CatalogLoadError>) -> MacSpecification {
        let loaded: MacCatalog
        switch catalog {
        case .success(let value): loaded = value
        case .failure(let error):
            return MacSpecification(allMissing: .error(SpecError(operation: "Load Mac catalog", message: error.description)))
        }
        guard let model = identifier.value else {
            return MacSpecification(allMissing: .unknown("The model identifier could not be determined."))
        }
        guard let entry = loaded.entry(for: model) else {
            return MacSpecification(allMissing: .unknown(
                "\(model) is not in the SpecMatrix Mac catalog (version \(loaded.catalogVersion))."))
        }

        func cited<T: Sendable & Equatable>(_ value: T?, _ field: CatalogField, missing: String) -> SpecValue<T> {
            guard let value else { return .unknown(missing) }
            return .catalog(value, loaded.reference(for: entry, field: field))
        }

        var spec = MacSpecification(allMissing: .unknown(""))
        spec.entryID = entry.id
        spec.marketingName = .catalog(entry.marketingName, loaded.reference(for: entry, field: .marketingName))

        let notRecorded = "Not recorded for \(entry.marketingName): Apple sells it in configurations that differ."
        if let chip = entry.chip {
            spec.catalogChipName = .catalog(chip.name, loaded.reference(for: entry, field: .chip))
            if let detected = detectedChipName.value, !chipNamesMatch(detected: detected, catalog: chip.name) {
                let mismatch = "The catalog lists \(chip.name) for \(entry.marketingName), but this Mac reports \(detected), "
                    + "so configuration-specific values are not shown."
                spec.gpuCores = .unknown(mismatch)
                spec.neuralEngineCores = .unknown(mismatch)
            } else {
                spec.gpuCores = cited(chip.gpuCores, .chip, missing: notRecorded)
                spec.neuralEngineCores = cited(chip.neuralEngineCores, .chip, missing: notRecorded)
            }
        } else {
            spec.catalogChipName = .unknown(notRecorded)
            spec.gpuCores = .unknown(notRecorded)
            spec.neuralEngineCores = .unknown(notRecorded)
        }

        let noDisplay = "\(entry.marketingName) has no built-in display recorded in the catalog."
        spec.builtInDisplayDiagonal = cited(entry.display?.diagonal, .display, missing: noDisplay)
        spec.builtInDisplayResolution = cited(entry.display?.resolution, .display, missing: noDisplay)
        spec.builtInDisplayPixelDensity = cited(entry.display?.pixelDensity, .display, missing: noDisplay)
        spec.builtInDisplayMaximumRefreshRate = cited(entry.display?.maximumRefreshRate, .display,
                                                      missing: entry.display == nil ? noDisplay
                                                          : "Apple does not state a refresh rate for this display.")
        return spec
    }

    /// "Apple M2 Pro" (macOS) matches "M2 Pro" (catalog). Comparison is exact apart from the prefix.
    public static func chipNamesMatch(detected: String, catalog: String) -> Bool {
        let trimmed = detected.trimmingCharacters(in: .whitespaces)
        let withoutPrefix = trimmed.hasPrefix("Apple ") ? String(trimmed.dropFirst("Apple ".count)) : trimmed
        return withoutPrefix == catalog
    }
}
