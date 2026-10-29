import Foundation
import SpecMatrixShared

/// A tier of CPU cores as Apple names it on a tech-specs page.
public enum MacCPUClusterKind: String, Sendable, Hashable, CaseIterable {
    /// "Super cores", Apple's highest-performance tier from M5 onwards.
    case superTier = "super"
    case performance
    case efficiency

    /// The order Apple lists tiers in, highest performance first.
    var rank: Int {
        switch self {
        case .superTier: 0
        case .performance: 1
        case .efficiency: 2
        }
    }
}

/// One tier of a published CPU configuration, e.g. "4 performance cores".
public struct MacCPUCluster: Sendable, Hashable {
    public let kind: MacCPUClusterKind
    public let cores: Int

    public init(kind: MacCPUClusterKind, cores: Int) {
        self.kind = kind
        self.cores = cores
    }
}

/// One chip configuration Apple publishes for a Mac model, e.g. "M2 with 8-core CPU and 10-core GPU".
///
/// A missing field means Apple's page does not state it for this configuration, never zero.
public struct MacChipConfiguration: Sendable, Hashable {
    /// Apple's chip name without the "Apple" prefix, e.g. `M2 Pro`.
    public let chip: String
    public let cpuCores: Int?
    /// Highest-performance tier first, as Apple lists them.
    public let cpuClusters: [MacCPUCluster]?
    public let gpuCores: Int?
    public let neuralEngineCores: Int?

    public init(chip: String, cpuCores: Int?, cpuClusters: [MacCPUCluster]?, gpuCores: Int?, neuralEngineCores: Int?) {
        self.chip = chip
        self.cpuCores = cpuCores
        self.cpuClusters = cpuClusters
        self.gpuCores = gpuCores
        self.neuralEngineCores = neuralEngineCores
    }
}

/// Built-in display specifications published for a Mac model. Desktops record none.
public struct MacDisplaySpecification: Sendable, Hashable {
    /// The diagonal as Apple publishes it.
    public let diagonal: DisplayDiagonal?
    /// Native resolution in landscape order (width ≥ height).
    public let resolution: PixelDimensions?
    public let pixelDensity: PixelDensity?
    public let maximumRefreshRate: RefreshRate?
}

/// One Mac model, which may have several model identifiers and several chip configurations.
public struct MacCatalogEntry: Sendable, Hashable {
    public let id: String
    public let identifiers: [HardwareIdentifier]
    public let marketingName: String
    public let releaseDate: CalendarDate?
    /// Every chip configuration Apple publishes for the model. Empty when none is recorded.
    public let configurations: [MacChipConfiguration]
    public let display: MacDisplaySpecification?
    public let sources: [CatalogSource]
    public let verificationStatus: CatalogVerificationStatus
    public let verifiedOn: CalendarDate

    /// The sources attributed to one field group.
    public func sources(supporting field: CatalogField) -> [CatalogSource] {
        sources.filter { $0.supports.contains(field) }
    }
}

/// The Mac hardware catalog: Apple-silicon Mac models keyed by model identifier (`hw.model`).
///
/// Separate from the iPhone/iPad catalog in `SpecMatrixCore`, with its own schema version and
/// catalog version. Loading is all-or-nothing; lookup is exact and never returns a neighbouring
/// model. A model identifier can cover several chip configurations; the catalog lists them all and
/// leaves choosing between them to `MacSpecificationResolver`, which uses what macOS reports.
public struct MacCatalog: Sendable, Equatable {
    public static let supportedSchemaVersion = 2
    public static let bundledResourceName = "MacCatalog"
    /// The field groups a Mac catalog source may support. `chip` covers the configurations.
    /// (`cameras` is not part of this schema.)
    public static let fields: [CatalogField] = [.identifiers, .marketingName, .releaseDate, .chip, .display]
    /// Model-identifier prefixes used by Macs, e.g. `Mac14,2`, `MacBookPro18,1`, `iMac21,1`.
    public static let identifierFamilies: Set<String> = ["Mac", "MacBookAir", "MacBookPro", "Macmini", "iMac", "MacPro"]

    public let catalogVersion: String
    public let entries: [MacCatalogEntry]
    private let indexByIdentifier: [HardwareIdentifier: Int]

    init(catalogVersion: String, entries: [MacCatalogEntry]) {
        self.catalogVersion = catalogVersion
        self.entries = entries
        var index: [HardwareIdentifier: Int] = [:]
        for (position, entry) in entries.enumerated() {
            for identifier in entry.identifiers { index[identifier] = position }
        }
        self.indexByIdentifier = index
    }

    /// Exact identifier lookup.
    public func entry(for identifier: HardwareIdentifier) -> MacCatalogEntry? {
        indexByIdentifier[identifier].map { entries[$0] }
    }

    /// The citation for a catalog-derived value: the entry, this catalog's version, and only the
    /// sources attributed to the value's field group.
    public func reference(for entry: MacCatalogEntry, field: CatalogField) -> CatalogReference {
        CatalogReference(entryID: entry.id, catalogVersion: catalogVersion,
                         verification: entry.verificationStatus, sources: entry.sources(supporting: field))
    }

    /// Loads the catalog bundled with SpecMatrixMacCatalog.
    public static func loadBundled() -> Result<MacCatalog, CatalogLoadError> {
        guard let url = Bundle.module.url(forResource: bundledResourceName, withExtension: "json") else {
            return .failure(.resourceMissing("\(bundledResourceName).json"))
        }
        do {
            return decode(try Data(contentsOf: url))
        } catch {
            return .failure(.unreadable(error.localizedDescription))
        }
    }

    /// Decodes and validates catalog JSON. See `MacCatalogDecoder` for the rules.
    public static func decode(_ data: Data) -> Result<MacCatalog, CatalogLoadError> {
        MacCatalogDecoder.decode(data)
    }
}
