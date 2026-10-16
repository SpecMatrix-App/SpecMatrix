import Foundation

/// Catalog-derived specifications for the running device.
///
/// Every field is `.catalog` (from a validated entry), `.unknown` (identifier not in the
/// catalog, or the entry does not record the field), or `.error` (the catalog failed to load).
/// Values are never borrowed from a different model.
public struct HardwareSpecification: Sendable, Equatable, SpecErrorReporting {
    public var marketingName: SpecValue<String>
    public var family: SpecValue<String>
    public var releaseDate: SpecValue<CalendarDate>
    public var chipName: SpecValue<String>
    public var performanceCores: SpecValue<Int>
    public var efficiencyCores: SpecValue<Int>
    public var gpuCores: SpecValue<Int>
    public var neuralEngineCores: SpecValue<Int>
    public var displayDiagonal: SpecValue<DisplayDiagonal>
    public var displayResolution: SpecValue<PixelDimensions>
    public var displayPixelDensity: SpecValue<PixelDensity>
    public var displayMaximumRefreshRate: SpecValue<RefreshRate>

    /// Every field missing for the same reason.
    public init(allMissing reason: MissingValue) {
        marketingName = SpecValue(reason)
        family = SpecValue(reason)
        releaseDate = SpecValue(reason)
        chipName = SpecValue(reason)
        performanceCores = SpecValue(reason)
        efficiencyCores = SpecValue(reason)
        gpuCores = SpecValue(reason)
        neuralEngineCores = SpecValue(reason)
        displayDiagonal = SpecValue(reason)
        displayResolution = SpecValue(reason)
        displayPixelDensity = SpecValue(reason)
        displayMaximumRefreshRate = SpecValue(reason)
    }

    public var errors: [SpecError] {
        // All fields share the same failure when the catalog fails to load; report it once.
        marketingName.specError.map { [$0] } ?? []
    }

    public var provenances: [Provenance] {
        [marketingName.provenance, family.provenance, releaseDate.provenance, chipName.provenance,
         performanceCores.provenance, efficiencyCores.provenance, gpuCores.provenance, neuralEngineCores.provenance,
         displayDiagonal.provenance, displayResolution.provenance, displayPixelDensity.provenance,
         displayMaximumRefreshRate.provenance]
    }
}

/// Resolves the running device's identity against the catalog.
public enum HardwareResolver {
    public static func resolve(identity: SpecValue<DeviceIdentity>,
                               catalog: Result<DeviceCatalog, CatalogLoadError>) -> HardwareSpecification {
        guard let identifier = identity.value?.identifier else {
            return HardwareSpecification(allMissing: .unknown("The hardware identifier could not be determined."))
        }
        let loaded: DeviceCatalog
        switch catalog {
        case .success(let value):
            loaded = value
        case .failure(let error):
            return HardwareSpecification(allMissing: .error(SpecError(operation: "Load device catalog", message: error.description)))
        }
        guard case .found(let entry) = loaded.lookup(identifier) else {
            return HardwareSpecification(allMissing: .unknown(
                "\(identifier) is not in the SpecMatrix device catalog (version \(loaded.catalogVersion))."
            ))
        }
        return specification(for: entry, catalogVersion: loaded.catalogVersion)
    }

    static func specification(for entry: CatalogEntry, catalogVersion: String) -> HardwareSpecification {
        // Each value cites only the sources attributed to its field group.
        func field<T: Sendable & Equatable>(_ value: T?, _ group: CatalogField) -> SpecValue<T> {
            guard let value else { return .unknown("Not recorded in the catalog entry for \(entry.marketingName).") }
            return .catalog(value, CatalogReference(entryID: entry.id, catalogVersion: catalogVersion,
                                                    verification: entry.verification.status,
                                                    sources: entry.sources(supporting: group)))
        }
        var spec = HardwareSpecification(allMissing: .unknown(""))
        spec.marketingName = field(entry.marketingName, .marketingName)
        spec.family = field(entry.family, .marketingName)
        spec.releaseDate = field(entry.releaseDate, .releaseDate)
        spec.chipName = field(entry.chip?.name, .chip)
        spec.performanceCores = field(entry.chip?.performanceCores, .chip)
        spec.efficiencyCores = field(entry.chip?.efficiencyCores, .chip)
        spec.gpuCores = field(entry.chip?.gpuCores, .chip)
        spec.neuralEngineCores = field(entry.chip?.neuralEngineCores, .chip)
        spec.displayDiagonal = field(entry.display?.diagonal, .display)
        spec.displayResolution = field(entry.display?.resolution, .display)
        spec.displayPixelDensity = field(entry.display?.pixelDensity, .display)
        spec.displayMaximumRefreshRate = field(entry.display?.maximumRefreshRate, .display)
        return spec
    }
}
