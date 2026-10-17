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
    case cameras

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
