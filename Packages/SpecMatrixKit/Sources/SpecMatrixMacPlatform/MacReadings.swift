import Foundation
import SpecMatrixShared

/// A CPU cluster as macOS reports it (`hw.perflevelN`), highest-performance first.
public struct MacCoreCluster: Sendable, Hashable {
    /// The name macOS gives the cluster, e.g. "Performance" or "Efficiency".
    public let name: String
    public let cores: Int
    /// Per-core L1 instruction and data cache and the shared L2 cache, in bytes (`hw.perflevelN.*cachesize`).
    /// `nil` when macOS does not report them.
    public let l1InstructionCache: ByteCount?
    public let l1DataCache: ByteCount?
    public let l2Cache: ByteCount?
    /// How many of the cluster's cores share one L2 cache (`hw.perflevelN.cpusperl2`).
    public let coresPerL2: Int?

    public init(name: String, cores: Int, l1InstructionCache: ByteCount? = nil, l1DataCache: ByteCount? = nil,
                l2Cache: ByteCount? = nil, coresPerL2: Int? = nil) {
        self.name = name
        self.cores = cores
        self.l1InstructionCache = l1InstructionCache
        self.l1DataCache = l1DataCache
        self.l2Cache = l2Cache
        self.coresPerL2 = coresPerL2
    }
}

/// Metal capabilities of the system GPU.
public struct MacGPUCapabilities: Sendable, Equatable {
    /// The highest `MTLGPUFamily.appleN` the GPU supports, e.g. 8 for `.apple8`.
    public var appleFamily: SpecValue<Int>
    public var supportsMetal3: SpecValue<Bool>
    /// `MTLGPUFamily.metal4`; unavailable before macOS 26.
    public var supportsMetal4: SpecValue<Bool>
    public var supportsRaytracing: SpecValue<Bool>
    public var maximumBufferLength: SpecValue<ByteCount>
    public var maximumThreadsPerThreadgroup: SpecValue<Int>

    public init(allMissing reason: MissingValue) {
        appleFamily = SpecValue(reason)
        supportsMetal3 = SpecValue(reason)
        supportsMetal4 = SpecValue(reason)
        supportsRaytracing = SpecValue(reason)
        maximumBufferLength = SpecValue(reason)
        maximumThreadsPerThreadgroup = SpecValue(reason)
    }

    public init(appleFamily: SpecValue<Int>, supportsMetal3: SpecValue<Bool>, supportsMetal4: SpecValue<Bool>,
                supportsRaytracing: SpecValue<Bool>, maximumBufferLength: SpecValue<ByteCount>,
                maximumThreadsPerThreadgroup: SpecValue<Int>) {
        self.appleFamily = appleFamily
        self.supportsMetal3 = supportsMetal3
        self.supportsMetal4 = supportsMetal4
        self.supportsRaytracing = supportsRaytracing
        self.maximumBufferLength = maximumBufferLength
        self.maximumThreadsPerThreadgroup = maximumThreadsPerThreadgroup
    }
}

/// Values that do not change while the app runs.
public struct MacStaticInfo: Sendable, Equatable {
    /// The model identifier from `sysctl hw.model`, e.g. `Mac14,2`.
    public var identifier: SpecValue<HardwareIdentifier>
    /// Whether the hardware is Apple silicon (`hw.optional.arm64`).
    public var isAppleSilicon: SpecValue<Bool>
    /// The chip name as macOS reports it, e.g. "Apple M2" (`machdep.cpu.brand_string`).
    public var chipName: SpecValue<String>
    public var logicalCores: SpecValue<Int>
    public var coreClusters: SpecValue<[MacCoreCluster]>
    public var physicalMemory: SpecValue<ByteCount>
    public var gpuName: SpecValue<String>
    public var hasUnifiedMemory: SpecValue<Bool>
    public var supportsMetal3: SpecValue<Bool>
    public var gpuRecommendedWorkingSet: SpecValue<ByteCount>
    public var osVersion: SpecValue<OSVersion>
    public var osBuild: SpecValue<String>
    /// The processor architecture the app runs on (`uname` machine), e.g. `arm64`.
    public var architecture: SpecValue<String>
    /// Physical CPU cores (`hw.physicalcpu_max`).
    public var physicalCores: SpecValue<Int>
    /// The Darwin kernel release (`kern.osrelease`), e.g. `25.1.0`.
    public var kernelRelease: SpecValue<String>
    public var gpuCapabilities: MacGPUCapabilities

    public init(identifier: SpecValue<HardwareIdentifier>, isAppleSilicon: SpecValue<Bool>, chipName: SpecValue<String>,
                logicalCores: SpecValue<Int>, coreClusters: SpecValue<[MacCoreCluster]>, physicalMemory: SpecValue<ByteCount>,
                gpuName: SpecValue<String>, hasUnifiedMemory: SpecValue<Bool>, supportsMetal3: SpecValue<Bool>,
                gpuRecommendedWorkingSet: SpecValue<ByteCount>, osVersion: SpecValue<OSVersion>, osBuild: SpecValue<String>,
                architecture: SpecValue<String> = .unknown("Not read."), physicalCores: SpecValue<Int> = .unknown("Not read."),
                kernelRelease: SpecValue<String> = .unknown("Not read."),
                gpuCapabilities: MacGPUCapabilities = MacGPUCapabilities(allMissing: .unknown("Not read."))) {
        self.identifier = identifier
        self.isAppleSilicon = isAppleSilicon
        self.chipName = chipName
        self.logicalCores = logicalCores
        self.coreClusters = coreClusters
        self.physicalMemory = physicalMemory
        self.gpuName = gpuName
        self.hasUnifiedMemory = hasUnifiedMemory
        self.supportsMetal3 = supportsMetal3
        self.gpuRecommendedWorkingSet = gpuRecommendedWorkingSet
        self.osVersion = osVersion
        self.osBuild = osBuild
        self.architecture = architecture
        self.physicalCores = physicalCores
        self.kernelRelease = kernelRelease
        self.gpuCapabilities = gpuCapabilities
    }
}

/// Where the Mac is drawing power from.
public enum MacPowerSource: String, Sendable, Hashable {
    case battery
    case powerAdapter
}

/// A time estimate reported by the power-source API.
public enum MacBatteryEstimate: Sendable, Hashable {
    case untilEmpty(minutes: Int)
    case untilFull(minutes: Int)
}

/// The battery's health as macOS summarises it (`kIOPSBatteryHealthKey`).
public enum MacBatteryHealth: String, Sendable, Hashable {
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
}

/// The internal battery. On a Mac without one, every value is `.unavailable(.notSupportedByHardware)`.
///
/// Cycle count and maximum capacity in milliamp-hours are not included: they are not public
/// power-source keys on Apple-silicon Macs.
public struct MacBatteryReading: Sendable, Equatable {
    public var level: SpecValue<UnitFraction>
    public var chargeState: SpecValue<BatteryChargeState>
    public var powerSource: SpecValue<MacPowerSource>
    public var estimate: SpecValue<MacBatteryEstimate>
    public var health: SpecValue<MacBatteryHealth>
    /// A service recommendation such as "Check Battery" (`kIOPSBatteryHealthConditionKey`), when macOS reports one.
    public var healthCondition: SpecValue<String>
    /// The connected power adapter's rated wattage (`IOPSCopyExternalPowerAdapterDetails`).
    public var adapterWatts: SpecValue<Int>

    public init(level: SpecValue<UnitFraction>, chargeState: SpecValue<BatteryChargeState>,
                powerSource: SpecValue<MacPowerSource>, estimate: SpecValue<MacBatteryEstimate>,
                health: SpecValue<MacBatteryHealth> = .unknown("Not read."),
                healthCondition: SpecValue<String> = .unknown("Not read."),
                adapterWatts: SpecValue<Int> = .unknown("Not read.")) {
        self.level = level
        self.chargeState = chargeState
        self.powerSource = powerSource
        self.estimate = estimate
        self.health = health
        self.healthCondition = healthCondition
        self.adapterWatts = adapterWatts
    }

    public init(allMissing reason: MissingValue) {
        level = SpecValue(reason)
        chargeState = SpecValue(reason)
        powerSource = SpecValue(reason)
        estimate = SpecValue(reason)
        health = SpecValue(reason)
        healthCondition = SpecValue(reason)
        adapterWatts = SpecValue(reason)
    }

    /// True when the Mac has no internal battery.
    public var isAbsent: Bool {
        level == .unavailable(.notSupportedByHardware)
    }
}

/// The volume holding the app's home directory (inside the sandbox container on the startup disk).
public struct MacStorageReading: Sendable, Equatable {
    public var volumeName: SpecValue<String>
    public var capacity: SpecValue<ByteCount>
    public var availableForImportantUsage: SpecValue<ByteCount>

    public init(volumeName: SpecValue<String>, capacity: SpecValue<ByteCount>, availableForImportantUsage: SpecValue<ByteCount>) {
        self.volumeName = volumeName
        self.capacity = capacity
        self.availableForImportantUsage = availableForImportantUsage
    }

    /// Used fraction, when both figures are measured and consistent.
    public var usedFraction: SpecValue<UnitFraction> {
        guard let total = capacity.value, let available = availableForImportantUsage.value else {
            return .unknown("Capacity or available space is not known.")
        }
        guard total.bytes > 0, available.bytes <= total.bytes,
              let fraction = UnitFraction(Double(total.bytes - available.bytes) / Double(total.bytes))
        else {
            return .unknown("The reported capacity and available space are inconsistent.")
        }
        return .measured(fraction, MeasurementSource(api: "URLResourceValues (volume capacity)", environment: .device))
    }
}

/// System state that can change while the app runs.
public struct MacSystemReading: Sendable, Equatable {
    public var thermalState: SpecValue<ThermalLevel>
    public var lowPowerMode: SpecValue<Bool>

    public init(thermalState: SpecValue<ThermalLevel>, lowPowerMode: SpecValue<Bool>) {
        self.thermalState = thermalState
        self.lowPowerMode = lowPowerMode
    }
}

/// One connected display, as macOS reports it.
public struct MacDisplayReading: Sendable, Equatable, Identifiable {
    /// The CoreGraphics display ID; stable while the display stays connected.
    public let id: UInt32
    public var name: SpecValue<String>
    public var isBuiltIn: SpecValue<Bool>
    /// The current mode in physical pixels.
    public var resolution: SpecValue<PixelDimensions>
    /// The size the desktop uses, in points ("looks like").
    public var pointSize: SpecValue<PixelDimensions>
    public var scale: SpecValue<Double>
    public var maximumRefreshRate: SpecValue<RefreshRate>
    /// Derived from the physical size the display reports (EDID); may be approximate for external displays.
    public var diagonal: SpecValue<DisplayDiagonal>
    /// The maximum potential extended-dynamic-range headroom; 1.0 means standard dynamic range only.
    public var extendedDynamicRangeHeadroom: SpecValue<Double>
    /// Whether this is the main display (the one with the menu bar).
    public var isMain: SpecValue<Bool>
    /// Whether the display mirrors, or is mirrored by, another display.
    public var isMirrored: SpecValue<Bool>
    /// Rotation in degrees (0, 90, 180 or 270).
    public var rotation: SpecValue<Int>
    /// The current mode's refresh rate. Variable-refresh (ProMotion) displays report none.
    public var currentRefreshRate: SpecValue<Double>
    /// The display's color space, e.g. "Color LCD" or "Display P3".
    public var colorSpace: SpecValue<String>
    /// The largest pixel resolution among the modes macOS offers for this display.
    public var largestModeResolution: SpecValue<PixelDimensions>

    public init(id: UInt32, name: SpecValue<String>, isBuiltIn: SpecValue<Bool>, resolution: SpecValue<PixelDimensions>,
                pointSize: SpecValue<PixelDimensions>, scale: SpecValue<Double>, maximumRefreshRate: SpecValue<RefreshRate>,
                diagonal: SpecValue<DisplayDiagonal>, extendedDynamicRangeHeadroom: SpecValue<Double>,
                isMain: SpecValue<Bool> = .unknown("Not read."), isMirrored: SpecValue<Bool> = .unknown("Not read."),
                rotation: SpecValue<Int> = .unknown("Not read."), currentRefreshRate: SpecValue<Double> = .unknown("Not read."),
                colorSpace: SpecValue<String> = .unknown("Not read."),
                largestModeResolution: SpecValue<PixelDimensions> = .unknown("Not read.")) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.resolution = resolution
        self.pointSize = pointSize
        self.scale = scale
        self.maximumRefreshRate = maximumRefreshRate
        self.diagonal = diagonal
        self.extendedDynamicRangeHeadroom = extendedDynamicRangeHeadroom
        self.isMain = isMain
        self.isMirrored = isMirrored
        self.rotation = rotation
        self.currentRefreshRate = currentRefreshRate
        self.colorSpace = colorSpace
        self.largestModeResolution = largestModeResolution
    }
}

/// One mounted volume (`FileManager.mountedVolumeURLs`, hidden system volumes skipped).
public struct MacVolumeReading: Sendable, Equatable, Identifiable {
    /// The mount point, e.g. `/` or `/Volumes/Backup`.
    public let id: String
    public var name: SpecValue<String>
    /// The startup volume (`volumeIsRootFileSystemKey`).
    public var isStartup: SpecValue<Bool>
    public var isInternal: SpecValue<Bool>
    public var isRemovable: SpecValue<Bool>
    public var isEjectable: SpecValue<Bool>
    public var isReadOnly: SpecValue<Bool>
    /// False for network volumes.
    public var isLocal: SpecValue<Bool>
    /// The file system as macOS describes it, e.g. "APFS".
    public var format: SpecValue<String>
    public var capacity: SpecValue<ByteCount>
    /// Space available for important data, including space macOS can free on demand; falls back to the plain
    /// available capacity on volumes that do not report it.
    public var available: SpecValue<ByteCount>

    public init(id: String, name: SpecValue<String>, isStartup: SpecValue<Bool>, isInternal: SpecValue<Bool>,
                isRemovable: SpecValue<Bool>, isEjectable: SpecValue<Bool>, isReadOnly: SpecValue<Bool>,
                isLocal: SpecValue<Bool>, format: SpecValue<String>, capacity: SpecValue<ByteCount>,
                available: SpecValue<ByteCount>) {
        self.id = id
        self.name = name
        self.isStartup = isStartup
        self.isInternal = isInternal
        self.isRemovable = isRemovable
        self.isEjectable = isEjectable
        self.isReadOnly = isReadOnly
        self.isLocal = isLocal
        self.format = format
        self.capacity = capacity
        self.available = available
    }

    public var usedFraction: SpecValue<UnitFraction> {
        MacStorageReading(volumeName: name, capacity: capacity, availableForImportantUsage: available).usedFraction
    }
}

/// System-wide memory use from the kernel's virtual-memory statistics (`host_statistics64`, `HOST_VM_INFO64`)
/// and swap use (`sysctl vm.swapusage`). Page counts are converted to bytes with the kernel page size.
public struct MacMemoryReading: Sendable, Equatable {
    /// Memory that cannot be paged out, used by macOS itself.
    public var wired: SpecValue<ByteCount>
    /// Recently used memory.
    public var active: SpecValue<ByteCount>
    /// Memory not used recently, available for reuse.
    public var inactive: SpecValue<ByteCount>
    /// Memory occupied by the compressor (the compressed size, not the original size).
    public var compressed: SpecValue<ByteCount>
    public var free: SpecValue<ByteCount>
    public var swapUsed: SpecValue<ByteCount>
    public var swapTotal: SpecValue<ByteCount>

    public init(wired: SpecValue<ByteCount>, active: SpecValue<ByteCount>, inactive: SpecValue<ByteCount>,
                compressed: SpecValue<ByteCount>, free: SpecValue<ByteCount>, swapUsed: SpecValue<ByteCount>,
                swapTotal: SpecValue<ByteCount>) {
        self.wired = wired
        self.active = active
        self.inactive = inactive
        self.compressed = compressed
        self.free = free
        self.swapUsed = swapUsed
        self.swapTotal = swapTotal
    }

    public init(allMissing reason: MissingValue) {
        self.init(wired: SpecValue(reason), active: SpecValue(reason), inactive: SpecValue(reason),
                  compressed: SpecValue(reason), free: SpecValue(reason), swapUsed: SpecValue(reason),
                  swapTotal: SpecValue(reason))
    }
}

/// The kind of a network interface, as the Network framework classifies it.
public enum MacNetworkInterfaceKind: String, Sendable, Hashable {
    case wifi, wiredEthernet, cellular, loopback, other
}

public struct MacNetworkInterface: Sendable, Hashable {
    /// The BSD name, e.g. `en0`.
    public let name: String
    public let kind: MacNetworkInterfaceKind

    public init(name: String, kind: MacNetworkInterfaceKind) {
        self.name = name
        self.kind = kind
    }
}

public enum MacNetworkStatus: String, Sendable, Hashable {
    case connected, notConnected, requiresConnection
}

/// The current network path (`NWPathMonitor`). No addresses, network names or traffic are read.
public struct MacNetworkReading: Sendable, Equatable {
    public var status: SpecValue<MacNetworkStatus>
    /// The interfaces the path can use, in the system's order of preference.
    public var interfaces: SpecValue<[MacNetworkInterface]>
    public var isExpensive: SpecValue<Bool>
    /// Low Data Mode.
    public var isConstrained: SpecValue<Bool>
    public var supportsIPv4: SpecValue<Bool>
    public var supportsIPv6: SpecValue<Bool>
    public var supportsDNS: SpecValue<Bool>

    public init(status: SpecValue<MacNetworkStatus>, interfaces: SpecValue<[MacNetworkInterface]>,
                isExpensive: SpecValue<Bool>, isConstrained: SpecValue<Bool>, supportsIPv4: SpecValue<Bool>,
                supportsIPv6: SpecValue<Bool>, supportsDNS: SpecValue<Bool>) {
        self.status = status
        self.interfaces = interfaces
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.supportsIPv4 = supportsIPv4
        self.supportsIPv6 = supportsIPv6
        self.supportsDNS = supportsDNS
    }

    public init(allMissing reason: MissingValue) {
        self.init(status: SpecValue(reason), interfaces: SpecValue(reason), isExpensive: SpecValue(reason),
                  isConstrained: SpecValue(reason), supportsIPv4: SpecValue(reason), supportsIPv6: SpecValue(reason),
                  supportsDNS: SpecValue(reason))
    }
}
