import Foundation
import SpecMatrixShared

/// A CPU cluster as macOS reports it (`hw.perflevelN`), highest-performance first.
public struct MacCoreCluster: Sendable, Hashable {
    /// The name macOS gives the cluster, e.g. "Performance" or "Efficiency".
    public let name: String
    public let cores: Int

    public init(name: String, cores: Int) {
        self.name = name
        self.cores = cores
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

    public init(identifier: SpecValue<HardwareIdentifier>, isAppleSilicon: SpecValue<Bool>, chipName: SpecValue<String>,
                logicalCores: SpecValue<Int>, coreClusters: SpecValue<[MacCoreCluster]>, physicalMemory: SpecValue<ByteCount>,
                gpuName: SpecValue<String>, hasUnifiedMemory: SpecValue<Bool>, supportsMetal3: SpecValue<Bool>,
                gpuRecommendedWorkingSet: SpecValue<ByteCount>, osVersion: SpecValue<OSVersion>, osBuild: SpecValue<String>) {
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

/// The internal battery. On a Mac without one, every value is `.unavailable(.notSupportedByHardware)`.
public struct MacBatteryReading: Sendable, Equatable {
    public var level: SpecValue<UnitFraction>
    public var chargeState: SpecValue<BatteryChargeState>
    public var powerSource: SpecValue<MacPowerSource>
    public var estimate: SpecValue<MacBatteryEstimate>

    public init(level: SpecValue<UnitFraction>, chargeState: SpecValue<BatteryChargeState>,
                powerSource: SpecValue<MacPowerSource>, estimate: SpecValue<MacBatteryEstimate>) {
        self.level = level
        self.chargeState = chargeState
        self.powerSource = powerSource
        self.estimate = estimate
    }

    public init(allMissing reason: MissingValue) {
        level = SpecValue(reason)
        chargeState = SpecValue(reason)
        powerSource = SpecValue(reason)
        estimate = SpecValue(reason)
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

    public init(id: UInt32, name: SpecValue<String>, isBuiltIn: SpecValue<Bool>, resolution: SpecValue<PixelDimensions>,
                pointSize: SpecValue<PixelDimensions>, scale: SpecValue<Double>, maximumRefreshRate: SpecValue<RefreshRate>,
                diagonal: SpecValue<DisplayDiagonal>, extendedDynamicRangeHeadroom: SpecValue<Double>) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.resolution = resolution
        self.pointSize = pointSize
        self.scale = scale
        self.maximumRefreshRate = maximumRefreshRate
        self.diagonal = diagonal
        self.extendedDynamicRangeHeadroom = extendedDynamicRangeHeadroom
    }
}
