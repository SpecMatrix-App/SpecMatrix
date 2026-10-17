#if os(macOS)
import Darwin
import Foundation
import Metal
import SpecMatrixShared

/// Reads values that do not change while the app runs. Uses only public APIs; never reads the
/// serial number or undocumented IORegistry properties.
public enum MacStaticReader {
    public static func read() -> MacStaticInfo {
        let (gpuName, unifiedMemory, metal3, workingSet) = graphics()
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return MacStaticInfo(
            identifier: identifier(),
            isAppleSilicon: appleSilicon(),
            chipName: chipName(),
            logicalCores: .measured(ProcessInfo.processInfo.processorCount, source("ProcessInfo.processorCount")),
            coreClusters: coreClusters(),
            physicalMemory: byteCount(ProcessInfo.processInfo.physicalMemory, api: "ProcessInfo.physicalMemory"),
            gpuName: gpuName,
            hasUnifiedMemory: unifiedMemory,
            supportsMetal3: metal3,
            gpuRecommendedWorkingSet: workingSet,
            osVersion: .measured(OSVersion(major: version.majorVersion, minor: version.minorVersion, patch: version.patchVersion),
                                 source("ProcessInfo.operatingSystemVersion")),
            osBuild: nonEmptyString("kern.osversion")
        )
    }

    static func identifier() -> SpecValue<HardwareIdentifier> {
        switch MacSysctl.string("hw.model") {
        case .success(let raw):
            guard let identifier = HardwareIdentifier(raw) else {
                return .unknown("sysctl hw.model returned \"\(raw)\", which is not a recognised model identifier.")
            }
            return .measured(identifier, source("sysctl hw.model"))
        case .failure(let error):
            return .error(error)
        }
    }

    static func appleSilicon() -> SpecValue<Bool> {
        switch MacSysctl.integer("hw.optional.arm64") {
        case .success(let value): return .measured(value == 1, source("sysctl hw.optional.arm64"))
        // Intel Macs do not define the key.
        case .failure: return .measured(false, source("sysctl hw.optional.arm64"))
        }
    }

    static func chipName() -> SpecValue<String> {
        nonEmptyString("machdep.cpu.brand_string")
    }

    /// `hw.perflevelN.physicalcpu_max` and `.name` for each of `hw.nperflevels` clusters.
    static func coreClusters() -> SpecValue<[MacCoreCluster]> {
        let levels: Int
        switch MacSysctl.integer("hw.nperflevels") {
        case .success(let value): levels = value
        case .failure(let error): return .error(error)
        }
        guard (1...8).contains(levels) else { return .unknown("sysctl hw.nperflevels reported \(levels).") }
        var clusters: [MacCoreCluster] = []
        for level in 0..<levels {
            let countName = "hw.perflevel\(level).physicalcpu_max"
            let nameName = "hw.perflevel\(level).name"
            switch (MacSysctl.integer(countName), MacSysctl.string(nameName)) {
            case (.success(let count), .success(let name)) where count > 0 && !name.isEmpty:
                clusters.append(MacCoreCluster(name: name, cores: count))
            case (.failure(let error), _), (_, .failure(let error)):
                return .error(error)
            default:
                return .unknown("sysctl reported an empty CPU cluster at level \(level).")
            }
        }
        return .measured(clusters, source("sysctl hw.perflevelN"))
    }

    static func graphics() -> (SpecValue<String>, SpecValue<Bool>, SpecValue<Bool>, SpecValue<ByteCount>) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            let reason = "No Metal device is available."
            return (.unknown(reason), .unknown(reason), .unknown(reason), .unknown(reason))
        }
        return (.measured(device.name, source("MTLDevice.name")),
                .measured(device.hasUnifiedMemory, source("MTLDevice.hasUnifiedMemory")),
                .measured(device.supportsFamily(.metal3), source("MTLDevice.supportsFamily(.metal3)")),
                byteCount(device.recommendedMaxWorkingSetSize, api: "MTLDevice.recommendedMaxWorkingSetSize"))
    }

    private static func nonEmptyString(_ name: String) -> SpecValue<String> {
        switch MacSysctl.string(name) {
        case .success(let value) where !value.isEmpty: return .measured(value, source("sysctl \(name)"))
        case .success: return .unknown("sysctl \(name) returned an empty value.")
        case .failure(let error): return .error(error)
        }
    }
}

/// Reads values that can change while the app runs.
public enum MacRuntimeReader {
    public static func system() -> MacSystemReading {
        let info = ProcessInfo.processInfo
        let thermal: SpecValue<ThermalLevel> = ThermalLevel(info.thermalState).map {
            .measured($0, source("ProcessInfo.thermalState"))
        } ?? .unknown("The system reported an unrecognised thermal state.")
        return MacSystemReading(thermalState: thermal,
                                lowPowerMode: .measured(info.isLowPowerModeEnabled, source("ProcessInfo.isLowPowerModeEnabled")))
    }

    /// The volume containing the app's home directory.
    public static func storage() -> MacStorageReading {
        let url = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        do {
            let values = try url.resourceValues(forKeys: [.volumeLocalizedNameKey, .volumeTotalCapacityKey,
                                                          .volumeAvailableCapacityForImportantUsageKey])
            let name: SpecValue<String> = values.volumeLocalizedName.flatMap { $0.isEmpty ? nil : $0 }
                .map { .measured($0, source("URLResourceKey.volumeLocalizedNameKey")) }
                ?? .unknown("The volume did not report a name.")
            return MacStorageReading(
                volumeName: name,
                capacity: byteCount(values.volumeTotalCapacity, api: "URLResourceKey.volumeTotalCapacityKey"),
                availableForImportantUsage: byteCount(values.volumeAvailableCapacityForImportantUsage,
                                                      api: "URLResourceKey.volumeAvailableCapacityForImportantUsageKey"))
        } catch {
            let failure = SpecError(operation: "Read volume capacity", message: error.localizedDescription)
            return MacStorageReading(volumeName: .error(failure), capacity: .error(failure), availableForImportantUsage: .error(failure))
        }
    }
}

func source(_ api: String) -> MeasurementSource {
    MeasurementSource(api: api, environment: .device)
}

func byteCount<T: BinaryInteger>(_ value: T?, api: String) -> SpecValue<ByteCount> {
    guard let value else { return .unknown("\(api) did not report a value.") }
    guard let bytes = ByteCount(exactly: value) else { return .unknown("\(api) reported an out-of-range value (\(value)).") }
    return .measured(bytes, source(api))
}
#endif
