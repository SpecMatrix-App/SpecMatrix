import Foundation

/// Identifies the catalog entry a catalog-derived value was taken from.
public struct CatalogReference: Sendable, Hashable {
    public let entryID: String
    public let catalogVersion: String
    public let verification: CatalogVerificationStatus
    /// Only the sources attributed to this value's field, not every source of the entry.
    public let sources: [CatalogSource]

    public init(entryID: String, catalogVersion: String, verification: CatalogVerificationStatus, sources: [CatalogSource]) {
        self.entryID = entryID
        self.catalogVersion = catalogVersion
        self.verification = verification
        self.sources = sources
    }
}

/// A value together with its provenance. Missing values are never represented by
/// placeholders such as `0`, `-1`, or another device's specification.
public enum SpecValue<Value: Sendable & Equatable>: Sendable, Equatable {
    case measured(Value, MeasurementSource)
    case catalog(Value, CatalogReference)
    case unavailable(UnavailableReason)
    case unknown(String)
    case error(SpecError)

    /// The value if one is known, regardless of whether it was measured or catalog-derived.
    public var value: Value? {
        switch self {
        case .measured(let value, _), .catalog(let value, _): value
        case .unavailable, .unknown, .error: nil
        }
    }

    public var provenance: Provenance {
        switch self {
        case .measured: .measured
        case .catalog: .catalog
        case .unavailable: .unavailable
        case .unknown: .unknown
        case .error: .error
        }
    }

    public var specError: SpecError? {
        if case .error(let error) = self { return error }
        return nil
    }

    /// Transforms a known value while preserving its provenance.
    public func map<T: Sendable & Equatable>(_ transform: (Value) -> T) -> SpecValue<T> {
        switch self {
        case .measured(let value, let source): .measured(transform(value), source)
        case .catalog(let value, let reference): .catalog(transform(value), reference)
        case .unavailable(let reason): .unavailable(reason)
        case .unknown(let reason): .unknown(reason)
        case .error(let error): .error(error)
        }
    }

    public init(_ missing: MissingValue) {
        switch missing {
        case .unavailable(let reason): self = .unavailable(reason)
        case .unknown(let reason): self = .unknown(reason)
        case .error(let error): self = .error(error)
        }
    }
}
