import Foundation
import SpecMatrixCore

/// Reads the hardware identifier of the running device.
///
/// - iOS / iPadOS device: `uname().machine` (e.g. `iPhone17,1`).
/// - Simulator: the `SIMULATOR_MODEL_IDENTIFIER` environment variable, because `uname`
///   reports the host Mac's architecture there.
/// - macOS: `sysctl hw.model` (e.g. `Mac14,2`), because `uname` reports `arm64` on Apple silicon.
enum IdentityReader {
    static func read() -> SpecValue<DeviceIdentity> {
        let environment = RuntimeEnvironment.current
        let api: String
        let raw: String

        #if targetEnvironment(simulator)
        api = "SIMULATOR_MODEL_IDENTIFIER"
        guard let value = ProcessInfo.processInfo.environment[api] else {
            return .unknown("The Simulator did not report \(api).")
        }
        raw = value
        #elseif os(macOS)
        api = "sysctl hw.model"
        switch Sysctl.string("hw.model") {
        case .success(let value): raw = value
        case .failure(let error): return .error(error)
        }
        #else
        api = "uname().machine"
        var info = utsname()
        guard uname(&info) == 0 else {
            return .error(SpecError(operation: api, message: String(cString: strerror(errno))))
        }
        raw = withUnsafeBytes(of: info.machine) { CString.decode($0) }
        #endif

        return identity(fromRaw: raw, api: api, environment: environment)
    }

    static func identity(fromRaw raw: String, api: String, environment: RuntimeEnvironment) -> SpecValue<DeviceIdentity> {
        guard let identifier = HardwareIdentifier(raw) else {
            return .unknown("\(api) returned \"\(raw)\", which is not a recognised hardware identifier format.")
        }
        return .measured(DeviceIdentity(identifier: identifier, environment: environment),
                         MeasurementSource(api: api, environment: environment))
    }
}
