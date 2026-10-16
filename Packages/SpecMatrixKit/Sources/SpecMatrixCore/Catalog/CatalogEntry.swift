import Foundation

/// How well a catalog entry's data has been verified.
public enum CatalogVerificationStatus: String, Sendable, Hashable, CaseIterable {
    /// Specifications come from the manufacturer's published specifications and the
    /// hardware identifiers are confirmed by at least two independent references.
    case verified
    /// Specifications or identifiers are supported only by secondary sources.
    case secondarySourcesOnly = "secondary-sources-only"
}

public struct CatalogSource: Sendable, Hashable {
    public let title: String
    public let url: URL
    public let accessed: CalendarDate
}

public struct CatalogVerification: Sendable, Hashable {
    public let status: CatalogVerificationStatus
    public let verifiedOn: CalendarDate
}

/// Chip specifications as published for a device. Every field other than `name` is optional:
/// a missing field means the catalog does not record it, never that it is zero.
public struct ChipSpecification: Sendable, Hashable {
    public let name: String
    public let performanceCores: Int?
    public let efficiencyCores: Int?
    public let gpuCores: Int?
    public let neuralEngineCores: Int?
}

/// Display specifications as published for a device. Resolution is in portrait orientation.
public struct DisplaySpecification: Sendable, Hashable {
    public let diagonal: DisplayDiagonal?
    public let resolution: PixelDimensions?
    public let pixelDensity: PixelDensity?
    public let maximumRefreshRate: RefreshRate?
}

/// A validated catalog entry describing one product, which may have several hardware identifiers.
public struct CatalogEntry: Sendable, Hashable {
    public let id: String
    public let identifiers: [HardwareIdentifier]
    public let family: String
    public let marketingName: String
    public let releaseDate: CalendarDate?
    public let chip: ChipSpecification?
    public let display: DisplaySpecification?
    public let sources: [CatalogSource]
    public let verification: CatalogVerification
}
