import Foundation
import Metal
import SpecMatrixCore
#if canImport(UIKit)
import UIKit
#endif

enum OperatingSystemReader {
    static func read() async -> OperatingSystemInfo {
        let environment = RuntimeEnvironment.current
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let versionSource = MeasurementSource(api: "ProcessInfo.operatingSystemVersion", environment: environment)

        #if os(iOS)
        // Reports "iPadOS" on iPad and "iOS" on iPhone.
        let systemName = await MainActor.run { UIDevice.current.systemName }
        let name = SpecValue.measured(systemName, MeasurementSource(api: "UIDevice.systemName", environment: environment))
        #else
        let name = SpecValue.measured("macOS", versionSource)
        #endif

        let build: SpecValue<String>
        switch Sysctl.string("kern.osversion") {
        case .success(let value) where !value.isEmpty:
            build = .measured(value, MeasurementSource(api: "sysctl kern.osversion", environment: environment))
        case .success:
            build = .unknown("The system reported an empty build number.")
        case .failure(let error):
            build = .error(error)
        }

        return OperatingSystemInfo(
            name: name,
            version: .measured(OSVersion(major: version.majorVersion, minor: version.minorVersion, patch: version.patchVersion), versionSource),
            build: build
        )
    }
}

enum ProcessorReader {
    /// In the Simulator these APIs describe the host Mac, so they are reported as unavailable.
    static func read(environment: RuntimeEnvironment) -> ProcessorReading {
        guard environment == .device else {
            return ProcessorReading(logicalCores: .unavailable(.simulator), activeLogicalCores: .unavailable(.simulator),
                                    performanceCores: .unavailable(.simulator), efficiencyCores: .unavailable(.simulator))
        }
        let info = ProcessInfo.processInfo
        let logical = SpecValue.measured(info.processorCount, MeasurementSource(api: "ProcessInfo.processorCount", environment: environment))
        let active = SpecValue.measured(info.activeProcessorCount, MeasurementSource(api: "ProcessInfo.activeProcessorCount", environment: environment))
        let (performance, efficiency) = coreClusters(environment: environment)
        return ProcessorReading(logicalCores: logical, activeLogicalCores: active,
                                performanceCores: performance, efficiencyCores: efficiency)
    }

    /// Uses `hw.perflevelN.physicalcpu_max`, the boot-time core count per cluster.
    /// Level 0 is always the highest-performance cluster.
    private static func coreClusters(environment: RuntimeEnvironment) -> (SpecValue<Int>, SpecValue<Int>) {
        func count(level: Int) -> SpecValue<Int> {
            let name = "hw.perflevel\(level).physicalcpu_max"
            switch Sysctl.integer(name) {
            case .success(let value) where value > 0:
                return .measured(value, MeasurementSource(api: "sysctl \(name)", environment: environment))
            case .success(let value):
                return .unknown("sysctl \(name) reported \(value).")
            case .failure(let error):
                return .error(error)
            }
        }
        switch Sysctl.integer("hw.nperflevels") {
        case .failure(let error):
            return (.error(error), .error(error))
        case .success(let levels) where levels >= 2:
            return (count(level: 0), count(level: 1))
        case .success(1):
            // A single core type (e.g. Intel Macs): there is no efficiency cluster.
            return (count(level: 0), .unavailable(.notSupportedByHardware))
        case .success(let levels):
            let reason = "sysctl hw.nperflevels reported \(levels)."
            return (.unknown(reason), .unknown(reason))
        }
    }
}

enum MemoryReader {
    static func physicalMemory(environment: RuntimeEnvironment) -> SpecValue<ByteCount> {
        guard environment == .device else { return .unavailable(.simulator) }
        return StorageMath.byteCount(ProcessInfo.processInfo.physicalMemory, api: "ProcessInfo.physicalMemory", environment: environment)
    }

    /// This process's physical footprint (`TASK_VM_INFO.phys_footprint`), the value Xcode reports for the app.
    static func appFootprint(environment: RuntimeEnvironment) -> SpecValue<ByteCount> {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(currentTaskPort(), task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return .error(SpecError(operation: "task_info(TASK_VM_INFO)", message: "Kernel returned \(result)."))
        }
        return StorageMath.byteCount(info.phys_footprint, api: "task_info TASK_VM_INFO.phys_footprint", environment: environment)
    }

    /// Remaining memory this app may allocate before reaching its limit (iOS only).
    static func appAvailable(environment: RuntimeEnvironment) -> SpecValue<ByteCount> {
        #if os(iOS)
        let available = os_proc_available_memory()
        // 0 means no limit applies to this process (e.g. some Simulator configurations).
        guard available > 0 else { return .unknown("The system did not report a memory limit for this process.") }
        return StorageMath.byteCount(available, api: "os_proc_available_memory()", environment: environment)
        #else
        return .unavailable(.notExposedByPlatform)
        #endif
    }
}

enum GraphicsReader {
    /// In the Simulator, Metal describes a virtual or host GPU, so values are reported as unavailable.
    static func read(environment: RuntimeEnvironment) -> GraphicsReading {
        guard environment == .device else {
            return GraphicsReading(gpuName: .unavailable(.simulator), supportsMetal3: .unavailable(.simulator),
                                   recommendedMaxWorkingSet: .unavailable(.simulator))
        }
        guard let device = MTLCreateSystemDefaultDevice() else {
            let reason = "No Metal device is available."
            return GraphicsReading(gpuName: .unknown(reason), supportsMetal3: .unknown(reason), recommendedMaxWorkingSet: .unknown(reason))
        }
        return GraphicsReading(
            gpuName: .measured(device.name, MeasurementSource(api: "MTLDevice.name", environment: environment)),
            supportsMetal3: .measured(device.supportsFamily(.metal3),
                                      MeasurementSource(api: "MTLDevice.supportsFamily(.metal3)", environment: environment)),
            recommendedMaxWorkingSet: StorageMath.byteCount(device.recommendedMaxWorkingSetSize,
                                                            api: "MTLDevice.recommendedMaxWorkingSetSize", environment: environment)
        )
    }
}

enum StorageReader {
    static let capacityAPI = "URLResourceKey.volumeTotalCapacityKey"
    static let availableAPI = "URLResourceKey.volumeAvailableCapacityForImportantUsageKey"

    /// Reads the volume containing the app's home directory.
    static func read(environment: RuntimeEnvironment) -> StorageReading {
        let url = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        do {
            let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            return StorageReading(
                capacity: StorageMath.byteCount(values.volumeTotalCapacity, api: capacityAPI, environment: environment),
                availableForImportantUsage: StorageMath.byteCount(values.volumeAvailableCapacityForImportantUsage,
                                                                  api: availableAPI, environment: environment)
            )
        } catch {
            let failure = SpecError(operation: "Read volume capacity", message: error.localizedDescription)
            return StorageReading(capacity: .error(failure), availableForImportantUsage: .error(failure))
        }
    }
}
