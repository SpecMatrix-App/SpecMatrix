import Foundation

/// Converts raw battery values from `UIDevice` into validated values.
///
/// `UIDevice.batteryLevel` is `-1.0` when the level is unknown (e.g. monitoring is
/// disabled, or in the Simulator). Since iOS 17 it is rounded to 5 % steps.
public enum BatteryNormalization {
    public static let levelAPI = "UIDevice.batteryLevel"
    public static let stateAPI = "UIDevice.batteryState"

    public static func level(raw: Float, environment: RuntimeEnvironment) -> SpecValue<UnitFraction> {
        if environment == .simulator {
            return .unavailable(.simulator)
        }
        guard raw.isFinite else {
            return .unknown("The system reported a non-numeric battery level.")
        }
        guard raw >= 0 else {
            return .unknown("The system did not report a battery level.")
        }
        guard let fraction = UnitFraction(Double(raw)) else {
            return .unknown("The system reported an out-of-range battery level (\(raw)).")
        }
        return .measured(fraction, MeasurementSource(api: levelAPI, environment: environment))
    }

    /// Maps the raw value of `UIDevice.BatteryState`:
    /// 0 unknown, 1 unplugged, 2 charging, 3 full.
    public static func state(rawValue: Int, environment: RuntimeEnvironment) -> SpecValue<BatteryChargeState> {
        if environment == .simulator {
            return .unavailable(.simulator)
        }
        let source = MeasurementSource(api: stateAPI, environment: environment)
        switch rawValue {
        case 1: return .measured(.unplugged, source)
        case 2: return .measured(.charging, source)
        case 3: return .measured(.full, source)
        case 0: return .unknown("The system did not report a battery state.")
        default: return .unknown("The system reported an unrecognised battery state (\(rawValue)).")
        }
    }
}
