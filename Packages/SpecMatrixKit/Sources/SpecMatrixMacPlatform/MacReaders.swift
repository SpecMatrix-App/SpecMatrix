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
        let physical: SpecValue<Int>
        switch MacSysctl.integer("hw.physicalcpu_max") {
        case .success(let value) where value > 0: physical = .measured(value, source("sysctl hw.physicalcpu_max"))
        case .success(let value): physical = .unknown("sysctl hw.physicalcpu_max reported \(value).")
        case .failure(let error): physical = .error(error)
        }
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
            osBuild: nonEmptyString("kern.osversion"),
            architecture: architecture(),
            physicalCores: physical,
            kernelRelease: nonEmptyString("kern.osrelease"),
            gpuCapabilities: gpuCapabilities()
        )
    }

    /// The machine field of `uname`, e.g. `arm64`.
    static func architecture() -> SpecValue<String> {
        var name = utsname()
        guard uname(&name) == 0 else {
            return .error(SpecError(operation: "uname", message: String(cString: strerror(errno))))
        }
        let machine = withUnsafeBytes(of: name.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
        return machine.isEmpty ? .unknown("uname reported an empty machine name.") : .measured(machine, source("uname"))
    }

    static func gpuCapabilities() -> MacGPUCapabilities {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return MacGPUCapabilities(allMissing: .unknown("No Metal device is available."))
        }
        // MTLGPUFamily.appleN has the raw value 1000 + N. Probing by raw value keeps this compiling against SDKs
        // that do not yet name the newest families (Apple10 and Apple11 are in the macOS 27 SDK headers).
        let family: SpecValue<Int> = (1...11).reversed()
            .first { MTLGPUFamily(rawValue: 1000 + $0).map(device.supportsFamily) == true }
            .map { .measured($0, source("MTLDevice.supportsFamily(.appleN)")) }
            ?? .unknown("The GPU supports none of the Apple GPU families this version of SpecMatrix knows.")
        let metal4: SpecValue<Bool>
        if #available(macOS 26.0, *) {
            metal4 = .measured(device.supportsFamily(.metal4), source("MTLDevice.supportsFamily(.metal4)"))
        } else {
            metal4 = .unavailable(.notExposedByPlatform)
        }
        let threads = device.maxThreadsPerThreadgroup
        return MacGPUCapabilities(
            appleFamily: family,
            supportsMetal3: .measured(device.supportsFamily(.metal3), source("MTLDevice.supportsFamily(.metal3)")),
            supportsMetal4: metal4,
            supportsRaytracing: .measured(device.supportsRaytracing, source("MTLDevice.supportsRaytracing")),
            maximumBufferLength: byteCount(device.maxBufferLength, api: "MTLDevice.maxBufferLength"),
            maximumThreadsPerThreadgroup: threads.width > 0
                ? .measured(threads.width, source("MTLDevice.maxThreadsPerThreadgroup"))
                : .unknown("The GPU reported no threadgroup size.")
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
                // Cache sizes are optional extras: a missing key leaves the field nil rather than failing the cluster.
                func size(_ key: String) -> ByteCount? {
                    guard case .success(let value) = MacSysctl.integer("hw.perflevel\(level).\(key)"), value > 0 else { return nil }
                    return ByteCount(exactly: value)
                }
                let perL2: Int? = {
                    guard case .success(let value) = MacSysctl.integer("hw.perflevel\(level).cpusperl2"), value > 0 else { return nil }
                    return value
                }()
                clusters.append(MacCoreCluster(name: name, cores: count, l1InstructionCache: size("l1icachesize"),
                                               l1DataCache: size("l1dcachesize"), l2Cache: size("l2cachesize"),
                                               coresPerL2: perL2))
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

/// Every visible mounted volume. Hidden system volumes (Preboot, VM, the Data volume behind `/`) are skipped.
public enum MacVolumeReader {
    private static let keys: [URLResourceKey] = [
        .volumeLocalizedNameKey, .volumeIsRootFileSystemKey, .volumeIsInternalKey, .volumeIsRemovableKey,
        .volumeIsEjectableKey, .volumeIsReadOnlyKey, .volumeIsLocalKey, .volumeLocalizedFormatDescriptionKey,
        .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey,
    ]

    public static func read() -> SpecValue<[MacVolumeReading]> {
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                                               options: [.skipHiddenVolumes]) else {
            return .error(SpecError(operation: "FileManager.mountedVolumeURLs", message: "macOS returned no volume list."))
        }
        let volumes = urls.map(reading)
            .sorted { ($0.isStartup.value == true ? 0 : 1, $0.id) < ($1.isStartup.value == true ? 0 : 1, $1.id) }
        return .measured(volumes, source("FileManager.mountedVolumeURLs"))
    }

    static func reading(_ url: URL) -> MacVolumeReading {
        let path = url.path
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: Set(keys))
        } catch {
            let failure = SpecError(operation: "Read volume information", message: error.localizedDescription)
            return MacVolumeReading(id: path, name: .measured(url.lastPathComponent.isEmpty ? path : url.lastPathComponent,
                                                              source("URL.lastPathComponent")),
                                    isStartup: .error(failure), isInternal: .error(failure), isRemovable: .error(failure),
                                    isEjectable: .error(failure), isReadOnly: .error(failure), isLocal: .error(failure),
                                    format: .error(failure), capacity: .error(failure), available: .error(failure))
        }
        func flag(_ value: Bool?, _ key: String) -> SpecValue<Bool> {
            value.map { .measured($0, source("URLResourceKey.\(key)")) } ?? .unknown("The volume did not report \(key).")
        }
        let available: SpecValue<ByteCount>
        if let important = values.volumeAvailableCapacityForImportantUsage, important > 0 {
            available = byteCount(important, api: "URLResourceKey.volumeAvailableCapacityForImportantUsageKey")
        } else {
            available = byteCount(values.volumeAvailableCapacity, api: "URLResourceKey.volumeAvailableCapacityKey")
        }
        return MacVolumeReading(
            id: path,
            name: values.volumeLocalizedName.flatMap { $0.isEmpty ? nil : $0 }
                .map { .measured($0, source("URLResourceKey.volumeLocalizedNameKey")) } ?? .unknown("The volume did not report a name."),
            isStartup: flag(values.volumeIsRootFileSystem, "volumeIsRootFileSystemKey"),
            isInternal: flag(values.volumeIsInternal, "volumeIsInternalKey"),
            isRemovable: flag(values.volumeIsRemovable, "volumeIsRemovableKey"),
            isEjectable: flag(values.volumeIsEjectable, "volumeIsEjectableKey"),
            isReadOnly: flag(values.volumeIsReadOnly, "volumeIsReadOnlyKey"),
            isLocal: flag(values.volumeIsLocal, "volumeIsLocalKey"),
            format: values.volumeLocalizedFormatDescription.flatMap { $0.isEmpty ? nil : $0 }
                .map { .measured($0, source("URLResourceKey.volumeLocalizedFormatDescriptionKey")) }
                ?? .unknown("The volume did not report its format."),
            capacity: byteCount(values.volumeTotalCapacity, api: "URLResourceKey.volumeTotalCapacityKey"),
            available: available
        )
    }
}

/// System-wide memory statistics. Cheap to read; still only read when the app refreshes.
public enum MacMemoryReader {
    public static func read() -> MacMemoryReading {
        let pageSize: Int
        switch MacSysctl.integer("hw.pagesize") {
        case .success(let value) where value > 0: pageSize = value
        case .success(let value):
            return MacMemoryReading(allMissing: .unknown("sysctl hw.pagesize reported \(value)."))
        case .failure(let error):
            return MacMemoryReading(allMissing: .error(error))
        }

        var statistics = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let api = "host_statistics64(HOST_VM_INFO64)"
        func pages<T: BinaryInteger>(_ value: T) -> SpecValue<ByteCount> {
            guard let bytes = ByteCount(exactly: Int64(value) * Int64(pageSize)) else {
                return .unknown("\(api) reported an out-of-range value.")
            }
            return .measured(bytes, source(api))
        }
        var reading: MacMemoryReading
        if result == KERN_SUCCESS {
            reading = MacMemoryReading(wired: pages(statistics.wire_count), active: pages(statistics.active_count),
                                       inactive: pages(statistics.inactive_count),
                                       compressed: pages(statistics.compressor_page_count),
                                       free: pages(statistics.free_count),
                                       swapUsed: .unknown(""), swapTotal: .unknown(""))
        } else {
            reading = MacMemoryReading(allMissing: .error(SpecError(operation: api, message: "Kernel error \(result).")))
        }

        switch MacSysctl.value("vm.swapusage", as: xsw_usage.self) {
        case .success(let usage):
            reading.swapUsed = byteCount(usage.xsu_used, api: "sysctl vm.swapusage")
            reading.swapTotal = byteCount(usage.xsu_total, api: "sysctl vm.swapusage")
        case .failure(let error):
            reading.swapUsed = .error(error)
            reading.swapTotal = .error(error)
        }
        return reading
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
