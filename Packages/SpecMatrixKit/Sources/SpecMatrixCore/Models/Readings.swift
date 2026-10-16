import Foundation

/// CPU topology and counts reported by the running system.
///
/// These are system properties, not catalog specifications. iOS and macOS do not expose
/// system-wide CPU utilization or temperatures through supported APIs for apps on iOS,
/// so no such fields exist here.
public struct ProcessorReading: Sendable, Equatable, SpecErrorReporting {
    public var logicalCores: SpecValue<Int>
    public var activeLogicalCores: SpecValue<Int>
    public var performanceCores: SpecValue<Int>
    public var efficiencyCores: SpecValue<Int>

    public init(logicalCores: SpecValue<Int>, activeLogicalCores: SpecValue<Int>,
                performanceCores: SpecValue<Int>, efficiencyCores: SpecValue<Int>) {
        self.logicalCores = logicalCores
        self.activeLogicalCores = activeLogicalCores
        self.performanceCores = performanceCores
        self.efficiencyCores = efficiencyCores
    }

    public var errors: [SpecError] {
        [logicalCores.specError, activeLogicalCores.specError,
         performanceCores.specError, efficiencyCores.specError].compactMap { $0 }
    }
}

/// Memory values. `physicalMemory` describes the device; the others describe this app's process.
public struct MemoryReading: Sendable, Equatable, SpecErrorReporting {
    /// RAM visible to the operating system (`ProcessInfo.physicalMemory`), which can be
    /// slightly lower than the marketed capacity.
    public var physicalMemory: SpecValue<ByteCount>
    /// This app's physical memory footprint.
    public var appFootprint: SpecValue<ByteCount>
    /// Memory this app can still allocate before reaching its limit (iOS only).
    public var appAvailable: SpecValue<ByteCount>

    public init(physicalMemory: SpecValue<ByteCount>, appFootprint: SpecValue<ByteCount>, appAvailable: SpecValue<ByteCount>) {
        self.physicalMemory = physicalMemory
        self.appFootprint = appFootprint
        self.appAvailable = appAvailable
    }

    public var errors: [SpecError] {
        [physicalMemory.specError, appFootprint.specError, appAvailable.specError].compactMap { $0 }
    }
}

/// GPU properties queried through Metal. GPU core counts and utilization are not exposed.
public struct GraphicsReading: Sendable, Equatable, SpecErrorReporting {
    public var gpuName: SpecValue<String>
    public var supportsMetal3: SpecValue<Bool>
    public var recommendedMaxWorkingSet: SpecValue<ByteCount>

    public init(gpuName: SpecValue<String>, supportsMetal3: SpecValue<Bool>, recommendedMaxWorkingSet: SpecValue<ByteCount>) {
        self.gpuName = gpuName
        self.supportsMetal3 = supportsMetal3
        self.recommendedMaxWorkingSet = recommendedMaxWorkingSet
    }

    public var errors: [SpecError] {
        [gpuName.specError, supportsMetal3.specError, recommendedMaxWorkingSet.specError].compactMap { $0 }
    }
}

/// Capacity of the volume containing the app's home directory.
///
/// `availableForImportantUsage` includes space the system can reclaim by purging
/// caches and other purgeable data, which matches the "available" figure in Settings.
/// It is therefore larger than the raw free space reported by `statfs`.
public struct StorageReading: Sendable, Equatable, SpecErrorReporting {
    public var capacity: SpecValue<ByteCount>
    public var availableForImportantUsage: SpecValue<ByteCount>
    /// `(capacity − available) / capacity`, or a missing value when that cannot be computed safely.
    public var usedFraction: SpecValue<UnitFraction>

    public init(capacity: SpecValue<ByteCount>, availableForImportantUsage: SpecValue<ByteCount>) {
        self.capacity = capacity
        self.availableForImportantUsage = availableForImportantUsage
        self.usedFraction = StorageMath.usedFraction(capacity: capacity, available: availableForImportantUsage)
    }

    public var errors: [SpecError] {
        // usedFraction is derived; its error, if any, repeats one of the inputs.
        [capacity.specError, availableForImportantUsage.specError].compactMap { $0 }
    }
}

public enum BatteryChargeState: String, Sendable, Hashable, CaseIterable {
    /// Running on battery power.
    case unplugged
    case charging
    /// Connected to power and fully charged.
    case full
    /// Connected to power but not charging (e.g. a Mac holding its charge level).
    case notCharging
}

public enum ThermalLevel: String, Sendable, Hashable, CaseIterable {
    case nominal, fair, serious, critical

    public init?(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: return nil
        }
    }
}

/// Battery and power state. Battery health and cycle count are not exposed on iOS.
public struct PowerReading: Sendable, Equatable, SpecErrorReporting {
    public var batteryLevel: SpecValue<UnitFraction>
    public var batteryState: SpecValue<BatteryChargeState>
    public var thermalState: SpecValue<ThermalLevel>
    public var lowPowerMode: SpecValue<Bool>

    public init(batteryLevel: SpecValue<UnitFraction>, batteryState: SpecValue<BatteryChargeState>,
                thermalState: SpecValue<ThermalLevel>, lowPowerMode: SpecValue<Bool>) {
        self.batteryLevel = batteryLevel
        self.batteryState = batteryState
        self.thermalState = thermalState
        self.lowPowerMode = lowPowerMode
    }

    public var errors: [SpecError] {
        [batteryLevel.specError, batteryState.specError, thermalState.specError, lowPowerMode.specError].compactMap { $0 }
    }
}

/// Properties of the screen showing the app, as reported by the system.
///
/// `maximumFramesPerSecond` is the current maximum, which can be lower than the
/// panel's capability (for example in Low Power Mode). Panel specifications come from the catalog.
public struct DisplayReading: Sendable, Equatable, SpecErrorReporting {
    public var nativeResolution: SpecValue<PixelDimensions>
    public var nativeScale: SpecValue<Double>
    public var maximumFramesPerSecond: SpecValue<RefreshRate>
    public var brightness: SpecValue<UnitFraction>

    public init(nativeResolution: SpecValue<PixelDimensions>, nativeScale: SpecValue<Double>,
                maximumFramesPerSecond: SpecValue<RefreshRate>, brightness: SpecValue<UnitFraction>) {
        self.nativeResolution = nativeResolution
        self.nativeScale = nativeScale
        self.maximumFramesPerSecond = maximumFramesPerSecond
        self.brightness = brightness
    }

    /// All fields share one reason, e.g. on a platform where display reading is not implemented.
    public init(allMissing reason: MissingValue) {
        self.init(nativeResolution: SpecValue(reason), nativeScale: SpecValue(reason),
                  maximumFramesPerSecond: SpecValue(reason), brightness: SpecValue(reason))
    }

    public var errors: [SpecError] {
        [nativeResolution.specError, nativeScale.specError, maximumFramesPerSecond.specError, brightness.specError].compactMap { $0 }
    }
}

public enum NetworkPathStatus: String, Sendable, Hashable {
    /// A usable network route exists. This does not guarantee Internet access.
    case satisfied
    case unsatisfied
    /// A route could be established, for example by bringing up a VPN or cellular data.
    case requiresConnection
    /// The system reported a status this version of SpecMatrix does not recognise.
    case unrecognized
}

public enum NetworkInterfaceKind: String, Sendable, Hashable, CaseIterable {
    case wifi, cellular, wiredEthernet, loopback, other
}

/// The current network path as reported by `NWPathMonitor`.
public struct NetworkReading: Sendable, Equatable {
    public var status: NetworkPathStatus
    /// Interface types the path uses, without duplicates, in a stable order.
    public var interfaces: [NetworkInterfaceKind]
    /// The path uses an interface the system considers expensive (cellular or a personal hotspot).
    public var isExpensive: Bool
    /// The user has Low Data Mode enabled for the path.
    public var isConstrained: Bool

    public init(status: NetworkPathStatus, interfaces: [NetworkInterfaceKind], isExpensive: Bool, isConstrained: Bool) {
        self.status = status
        let used = Set(interfaces)
        self.interfaces = NetworkInterfaceKind.allCases.filter(used.contains)
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
    }
}
