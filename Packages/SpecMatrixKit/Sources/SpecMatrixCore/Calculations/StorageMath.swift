import Foundation
import SpecMatrixShared

/// Validated storage calculations. Never produces NaN, infinity, negative values, or percentages outside 0–100 %.
public enum StorageMath {
    /// Converts an optional integer reported by an API into a byte count.
    /// `nil` and negative values become `.unknown` rather than `0`.
    public static func byteCount<T: BinaryInteger>(_ reported: T?, api: String, environment: RuntimeEnvironment) -> SpecValue<ByteCount> {
        guard let reported else {
            return .unknown("\(api) was not reported.")
        }
        guard let bytes = ByteCount(exactly: reported) else {
            return .unknown("\(api) reported an invalid value (\(reported)).")
        }
        return .measured(bytes, MeasurementSource(api: api, environment: environment))
    }

    /// `(capacity − available) / capacity`, validated.
    ///
    /// - A zero capacity yields `.unknown` (no division by zero).
    /// - Available space larger than capacity yields `.unknown` (inconsistent API values are not clamped).
    /// - A missing input propagates its reason; errors take precedence over other missing states.
    public static func usedFraction(capacity: SpecValue<ByteCount>, available: SpecValue<ByteCount>) -> SpecValue<UnitFraction> {
        guard case .measured(let total, let totalSource) = capacity,
              case .measured(let free, _) = available
        else {
            for input in [capacity, available] {
                if let error = input.specError { return .error(error) }
            }
            for input in [capacity, available] {
                switch input {
                case .unavailable(let reason): return .unavailable(reason)
                case .unknown(let reason): return .unknown(reason)
                default: continue
                }
            }
            return .unknown("Storage usage can only be computed from measured values.")
        }
        guard total.bytes > 0 else {
            return .unknown("The volume reported a capacity of zero.")
        }
        guard free <= total else {
            return .unknown("The volume reported more available space than its total capacity.")
        }
        let used = Double(total.bytes - free.bytes) / Double(total.bytes)
        guard let fraction = UnitFraction(used) else {
            return .unknown("Storage usage could not be computed.")
        }
        return .measured(fraction, MeasurementSource(
            api: "derived: volumeTotalCapacity − volumeAvailableCapacityForImportantUsage",
            environment: totalSource.environment
        ))
    }
}
