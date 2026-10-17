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
