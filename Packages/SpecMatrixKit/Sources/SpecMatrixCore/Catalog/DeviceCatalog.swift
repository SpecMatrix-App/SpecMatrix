import Foundation

/// A problem found while validating catalog data.
public struct CatalogIssue: Sendable, Hashable, CustomStringConvertible {
    /// A JSON path such as `entries[2].chip.gpuCores`.
    public let path: String
    public let message: String

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }

    public var description: String { "\(path): \(message)" }
}

public enum CatalogLoadError: Error, Sendable, Equatable, CustomStringConvertible {
    case resourceMissing(String)
    case unreadable(String)
    case malformedJSON(String)
    case unsupportedSchemaVersion(found: Int?, supported: Int)
    case invalid([CatalogIssue])

    public var description: String {
        switch self {
        case .resourceMissing(let name): "Catalog resource \(name) is missing."
        case .unreadable(let message): "Catalog could not be read: \(message)"
        case .malformedJSON(let message): "Catalog is not valid JSON for the schema: \(message)"
        case .unsupportedSchemaVersion(let found, let supported):
            "Catalog schema version \(found.map(String.init) ?? "missing") is not supported (expected \(supported))."
        case .invalid(let issues): "Catalog failed validation with \(issues.count) issue(s): "
            + issues.map(\.description).joined(separator: "; ")
        }
    }
}

public enum CatalogLookup: Sendable, Equatable {
    case found(CatalogEntry)
    case notFound(HardwareIdentifier)
}

/// Rules that decide whether an entry may claim `CatalogVerificationStatus.verified`.
public struct CatalogPolicy: Sendable, Equatable {
    /// The publisher (see `CatalogSource.publisher`) whose sources count as manufacturer-published.
    public var manufacturerPublisher: String
    /// The number of independent publishers that must support an entry's identifiers.
    public var minimumIdentifierPublishers: Int

    public init(manufacturerPublisher: String, minimumIdentifierPublishers: Int = 2) {
        self.manufacturerPublisher = manufacturerPublisher
        self.minimumIdentifierPublishers = minimumIdentifierPublishers
    }

    public static let apple = CatalogPolicy(manufacturerPublisher: "apple.com")
}

/// A validated, versioned set of device specifications keyed by hardware identifier.
///
/// Loading is all-or-nothing: if any entry is invalid, the whole catalog is rejected and
/// every issue is reported. The bundled catalog is authored with the app, so a single
/// invalid entry indicates a defect that should fail tests rather than be skipped silently.
public struct DeviceCatalog: Sendable, Equatable {
    public static let supportedSchemaVersion = 3
    public static let bundledResourceName = "DeviceCatalog"

    public let schemaVersion: Int
    public let catalogVersion: String
    public let entries: [CatalogEntry]
    private let indexByIdentifier: [HardwareIdentifier: Int]

    init(schemaVersion: Int, catalogVersion: String, entries: [CatalogEntry]) {
        self.schemaVersion = schemaVersion
        self.catalogVersion = catalogVersion
        self.entries = entries
        var index: [HardwareIdentifier: Int] = [:]
        for (position, entry) in entries.enumerated() {
            for identifier in entry.identifiers { index[identifier] = position }
        }
        self.indexByIdentifier = index
    }

    /// Exact identifier lookup. Never returns an approximate or neighbouring model.
    public func lookup(_ identifier: HardwareIdentifier) -> CatalogLookup {
        guard let position = indexByIdentifier[identifier] else { return .notFound(identifier) }
        return .found(entries[position])
    }

    /// Loads the catalog bundled with SpecMatrixCore.
    public static func loadBundled() -> Result<DeviceCatalog, CatalogLoadError> {
        guard let url = Bundle.module.url(forResource: bundledResourceName, withExtension: "json") else {
            return .failure(.resourceMissing("\(bundledResourceName).json"))
        }
        return load(contentsOf: url)
    }

    public static func load(contentsOf url: URL) -> Result<DeviceCatalog, CatalogLoadError> {
        do {
            return decode(try Data(contentsOf: url))
        } catch {
            return .failure(.unreadable(error.localizedDescription))
        }
    }

    /// Decodes and validates catalog JSON.
    public static func decode(_ data: Data, policy: CatalogPolicy = .apple) -> Result<DeviceCatalog, CatalogLoadError> {
        CatalogDecoder.decode(data, policy: policy)
    }
}
