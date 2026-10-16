import Foundation

/// How well a catalog entry's data has been verified.
public enum CatalogVerificationStatus: String, Sendable, Hashable, CaseIterable {
    /// Every recorded specification is supported by a manufacturer-published source, and the
    /// hardware identifiers are supported by sources from at least two independent publishers.
    /// The decoder enforces both conditions (see `CatalogPolicy`).
    case verified
    /// At least one recorded field is supported only by secondary sources.
    case secondarySourcesOnly = "secondary-sources-only"
}

/// A group of catalog fields that a source can support.
public enum CatalogField: String, Sendable, Hashable, CaseIterable, Comparable {
    case identifiers
    case marketingName
    case releaseDate
    case chip
    case display

    public static func < (lhs: CatalogField, rhs: CatalogField) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

/// Where a source can be inspected.
public enum CatalogSourceLocation: Sendable, Hashable {
    /// An HTTPS web page.
    case web(URL)
    /// An Xcode Simulator device type, whose profile lists the hardware identifiers it represents
    /// (`representedModelIdentifiers`). Published by Apple with Xcode; inspectable on any Mac with that Xcode.
    case xcodeSimulatorDeviceType(name: String, xcodeVersion: String)
}

public struct CatalogSource: Sendable, Hashable {
    public let title: String
    public let location: CatalogSourceLocation
    public let accessed: CalendarDate
    /// The fields this source supports. A source is only attributed to these fields.
    public let supports: Set<CatalogField>

    public init(title: String, location: CatalogSourceLocation, accessed: CalendarDate, supports: Set<CatalogField>) {
        self.title = title
        self.location = location
        self.accessed = accessed
        self.supports = supports
    }

    public var url: URL? {
        if case .web(let url) = location { return url }
        return nil
    }

    /// The organisation that published the source, used to judge independence.
    /// For web pages this is the host's last two DNS labels (`support.apple.com` → `apple.com`);
    /// Xcode is published by Apple.
    public var publisher: String {
        switch location {
        case .web(let url):
            let labels = (url.host ?? "").lowercased().split(separator: ".")
            return labels.suffix(2).joined(separator: ".")
        case .xcodeSimulatorDeviceType:
            return "apple.com"
        }
    }
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
    /// The diagonal of the screen measured as a rectangle, as published by the manufacturer.
    /// For screens with rounded corners this is the "measured as a standard rectangle" figure
    /// (e.g. 6.12 in for iPhone 16), not the rounded marketing size (6.1-inch).
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

    /// The sources attributed to one field group.
    public func sources(supporting field: CatalogField) -> [CatalogSource] {
        sources.filter { $0.supports.contains(field) }
    }

    /// The field groups that hold data in this entry.
    public var populatedFields: Set<CatalogField> {
        var fields: Set<CatalogField> = [.identifiers, .marketingName]
        if releaseDate != nil { fields.insert(.releaseDate) }
        if chip != nil { fields.insert(.chip) }
        if display != nil { fields.insert(.display) }
        return fields
    }
}
