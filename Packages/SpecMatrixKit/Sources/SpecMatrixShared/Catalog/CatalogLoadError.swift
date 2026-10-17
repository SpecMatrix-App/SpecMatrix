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
