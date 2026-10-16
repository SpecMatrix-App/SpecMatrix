import Foundation

/// The category of a displayed value: where it came from, or why it is missing.
public enum Provenance: String, Sendable, Hashable, CaseIterable {
    /// Read directly from a supported system API on the running device.
    case measured
    /// Taken from a validated catalog entry for the device's hardware identifier.
    case catalog
    /// The platform does not expose the value through a supported API.
    case unavailable
    /// The value cannot be determined reliably (e.g. no catalog entry, out-of-range API value).
    case unknown
    /// A supported operation was attempted and failed.
    case error
}

/// Whether a measurement was taken on real hardware or inside the Simulator.
public enum RuntimeEnvironment: String, Sendable, Hashable {
    case device
    case simulator

    /// The environment of the current process.
    public static var current: RuntimeEnvironment {
        #if targetEnvironment(simulator)
        return .simulator
        #else
        return .device
        #endif
    }
}

/// Identifies the API a measured value was read from.
public struct MeasurementSource: Sendable, Hashable {
    /// The API or system property, e.g. `"ProcessInfo.physicalMemory"`.
    public let api: String
    public let environment: RuntimeEnvironment

    public init(api: String, environment: RuntimeEnvironment) {
        self.api = api
        self.environment = environment
    }
}

/// Identifies the catalog entry a catalog-derived value was taken from.
public struct CatalogReference: Sendable, Hashable {
    public let entryID: String
    public let catalogVersion: String
    public let verification: CatalogVerificationStatus
    public let sources: [URL]

    public init(entryID: String, catalogVersion: String, verification: CatalogVerificationStatus, sources: [URL]) {
        self.entryID = entryID
        self.catalogVersion = catalogVersion
        self.verification = verification
        self.sources = sources
    }
}

/// Why a value is not available on this platform or device.
public enum UnavailableReason: Sendable, Hashable {
    /// No supported public API exposes this value.
    case notExposedByPlatform
    /// This device does not have the relevant hardware (e.g. a desktop Mac has no battery).
    case notSupportedByHardware
    /// The value would describe the host Mac or a placeholder, not the simulated device.
    case simulator
    /// A supported API exists but SpecMatrix does not read it yet.
    case notYetImplemented

    public var explanation: String {
        switch self {
        case .notExposedByPlatform: "This platform does not expose this value to apps."
        case .notSupportedByHardware: "This device does not have the relevant hardware."
        case .simulator: "Not meaningful in the Simulator."
        case .notYetImplemented: "Not yet supported by SpecMatrix on this platform."
        }
    }
}

/// A failed attempt to read a value through a supported API.
public struct SpecError: Error, Sendable, Hashable, CustomStringConvertible {
    public let operation: String
    public let message: String

    public init(operation: String, message: String) {
        self.operation = operation
        self.message = message
    }

    public var description: String { "\(operation): \(message)" }
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

/// The reason a value is absent, independent of the value's type.
/// Used when several fields are missing for the same reason.
public enum MissingValue: Sendable, Equatable {
    case unavailable(UnavailableReason)
    case unknown(String)
    case error(SpecError)
}

/// Types that contain `SpecValue` fields and can report the failed ones.
public protocol SpecErrorReporting {
    var errors: [SpecError] { get }
}
