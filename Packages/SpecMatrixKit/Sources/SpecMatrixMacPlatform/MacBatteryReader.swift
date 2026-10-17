import Foundation
import SpecMatrixShared
#if os(macOS)
import IOKit.ps
#endif

#if os(macOS)
/// Reads the internal battery through the public IOKit power-source API (`IOPSCopyPowerSourcesInfo`),
/// which works inside the App Sandbox. Battery cycle count and health are not read: cycle count is not
/// a public power-source key, and health was not approved for this phase.
public enum MacBatteryReader {
    public static func read() -> MacBatteryReading {
        let api = "IOPSCopyPowerSourcesInfo"
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return MacBatteryReading(allMissing: .error(SpecError(operation: api, message: "The power-source list could not be read.")))
        }
        for powerSource in list {
            guard let description = IOPSGetPowerSourceDescription(blob, powerSource)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }
            return MacBatteryMapping.reading(from: PowerSourceDescription(description))
        }
        return MacBatteryReading(allMissing: .unavailable(.notSupportedByHardware))
    }
}

extension PowerSourceDescription {
    init(_ description: [String: Any]) {
        self.init(currentCapacity: description[kIOPSCurrentCapacityKey] as? Int,
                  maximumCapacity: description[kIOPSMaxCapacityKey] as? Int,
                  powerSourceState: description[kIOPSPowerSourceStateKey] as? String,
                  isCharging: description[kIOPSIsChargingKey] as? Bool,
                  isCharged: description[kIOPSIsChargedKey] as? Bool,
                  minutesToEmpty: description[kIOPSTimeToEmptyKey] as? Int,
                  minutesToFull: description[kIOPSTimeToFullChargeKey] as? Int)
    }
}
#endif

/// The power-source keys SpecMatrix uses, decoupled from IOKit so the mapping can be tested.
public struct PowerSourceDescription: Sendable, Equatable {
    /// The IOKit values of `kIOPSPowerSourceStateKey`.
    public static let acPower = "AC Power"
    public static let batteryPower = "Battery Power"

    public var currentCapacity: Int?
    public var maximumCapacity: Int?
    public var powerSourceState: String?
    public var isCharging: Bool?
    public var isCharged: Bool?
    /// Minutes; -1 while macOS is still calculating.
    public var minutesToEmpty: Int?
    public var minutesToFull: Int?

    public init(currentCapacity: Int?, maximumCapacity: Int?, powerSourceState: String?, isCharging: Bool?,
                isCharged: Bool?, minutesToEmpty: Int?, minutesToFull: Int?) {
        self.currentCapacity = currentCapacity
        self.maximumCapacity = maximumCapacity
        self.powerSourceState = powerSourceState
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.minutesToEmpty = minutesToEmpty
        self.minutesToFull = minutesToFull
    }
}

/// Maps a power-source description to battery values without inventing any.
public enum MacBatteryMapping {
    public static func reading(from description: PowerSourceDescription) -> MacBatteryReading {
        let source = MeasurementSource(api: "IOPSGetPowerSourceDescription", environment: .device)

        let level: SpecValue<UnitFraction>
        if let current = description.currentCapacity, let maximum = description.maximumCapacity, maximum > 0,
           let fraction = UnitFraction(Double(current) / Double(maximum)) {
            level = .measured(fraction, source)
        } else {
            level = .unknown("The battery did not report a valid charge level.")
        }

        let powerSource: SpecValue<MacPowerSource>
        let chargeState: SpecValue<BatteryChargeState>
        if description.powerSourceState == PowerSourceDescription.batteryPower {
            powerSource = .measured(.battery, source)
            chargeState = .measured(.unplugged, source)
        } else if description.powerSourceState == PowerSourceDescription.acPower {
            powerSource = .measured(.powerAdapter, source)
            switch (description.isCharging, description.isCharged) {
            case (true?, _): chargeState = .measured(.charging, source)
            case (_, true?): chargeState = .measured(.full, source)
            case (false?, _): chargeState = .measured(.notCharging, source)
            case (nil, _): chargeState = .unknown("The battery did not report whether it is charging.")
            }
        } else {
            powerSource = .unknown("The battery reported an unrecognised power source.")
            chargeState = .unknown("The battery reported an unrecognised power source.")
        }

        let estimate: SpecValue<MacBatteryEstimate>
        switch chargeState.value {
        case .unplugged?:
            estimate = minutes(description.minutesToEmpty, source: source).map { .untilEmpty(minutes: $0) }
        case .charging?:
            estimate = minutes(description.minutesToFull, source: source).map { .untilFull(minutes: $0) }
        default:
            estimate = .unknown("There is no time estimate while the battery is neither charging nor discharging.")
        }
        return MacBatteryReading(level: level, chargeState: chargeState, powerSource: powerSource, estimate: estimate)
    }

    private static func minutes(_ value: Int?, source: MeasurementSource) -> SpecValue<Int> {
        guard let value else { return .unknown("The battery did not report a time estimate.") }
        guard value >= 0 else { return .unknown("macOS is still calculating the time estimate.") }
        return .measured(value, source)
    }
}
