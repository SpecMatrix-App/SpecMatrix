import Foundation
import SpecMatrixCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import IOKit.ps
#endif

enum PowerReader {
    static func read(environment: RuntimeEnvironment) async -> PowerReading {
        let info = ProcessInfo.processInfo
        let thermal: SpecValue<ThermalLevel> = ThermalLevel(info.thermalState).map {
            .measured($0, MeasurementSource(api: "ProcessInfo.thermalState", environment: environment))
        } ?? .unknown("The system reported an unrecognised thermal state.")
        let lowPower = SpecValue.measured(info.isLowPowerModeEnabled,
                                          MeasurementSource(api: "ProcessInfo.isLowPowerModeEnabled", environment: environment))
        #if os(iOS)
        let (level, state) = await battery(environment: environment)
        #else
        let (level, state) = battery(environment: environment)
        #endif
        return PowerReading(batteryLevel: level, batteryState: state, thermalState: thermal, lowPowerMode: lowPower)
    }

    #if os(iOS)
    /// Enables battery monitoring (required for values and change notifications) and reads it.
    /// Monitoring is left enabled; it is a process-wide setting also used by the legacy UI.
    @MainActor
    private static func battery(environment: RuntimeEnvironment) -> (SpecValue<UnitFraction>, SpecValue<BatteryChargeState>) {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        return (BatteryNormalization.level(raw: device.batteryLevel, environment: environment),
                BatteryNormalization.state(rawValue: device.batteryState.rawValue, environment: environment))
    }
    #elseif os(macOS)
    /// Reads the internal battery through IOKit power-source APIs (works inside the App Sandbox).
    /// Desktop Macs without a battery report `notSupportedByHardware`.
    private static func battery(environment: RuntimeEnvironment) -> (SpecValue<UnitFraction>, SpecValue<BatteryChargeState>) {
        let api = "IOPSCopyPowerSourcesInfo"
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else {
            let error = SpecError(operation: api, message: "The power-source list could not be read.")
            return (.error(error), .error(error))
        }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }
            return MacBatteryMapping.reading(description: description, environment: environment)
        }
        return (.unavailable(.notSupportedByHardware), .unavailable(.notSupportedByHardware))
    }
    #endif
}

#if os(macOS)
/// Maps an IOKit power-source description dictionary to battery values.
enum MacBatteryMapping {
    static func reading(description: [String: Any], environment: RuntimeEnvironment)
        -> (SpecValue<UnitFraction>, SpecValue<BatteryChargeState>) {
        let source = MeasurementSource(api: "IOPSGetPowerSourceDescription", environment: environment)

        let level: SpecValue<UnitFraction>
        if let current = description[kIOPSCurrentCapacityKey] as? Int,
           let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0,
           let fraction = UnitFraction(Double(current) / Double(maximum)) {
            level = .measured(fraction, source)
        } else {
            level = .unknown("The power source did not report a valid capacity.")
        }

        let state: SpecValue<BatteryChargeState>
        let isCharging = description[kIOPSIsChargingKey] as? Bool
        let isCharged = description[kIOPSIsChargedKey] as? Bool
        switch (description[kIOPSPowerSourceStateKey] as? String, isCharging, isCharged) {
        case (kIOPSBatteryPowerValue, _, _): state = .measured(.unplugged, source)
        case (kIOPSACPowerValue, true, _): state = .measured(.charging, source)
        case (kIOPSACPowerValue, _, true): state = .measured(.full, source)
        case (kIOPSACPowerValue, false, _): state = .measured(.notCharging, source)
        default: state = .unknown("The power source did not report a recognised state.")
        }
        return (level, state)
    }
}
#endif
