import Foundation
import SpecMatrixShared

/// Values that describe the device and do not change while the app runs.
public struct StaticDeviceInfo: Sendable, Equatable {
    public var identity: SpecValue<DeviceIdentity>
    public var operatingSystem: OperatingSystemInfo
    public var processor: ProcessorReading
    public var graphics: GraphicsReading
    public var physicalMemory: SpecValue<ByteCount>

    public init(identity: SpecValue<DeviceIdentity>, operatingSystem: OperatingSystemInfo,
                processor: ProcessorReading, graphics: GraphicsReading, physicalMemory: SpecValue<ByteCount>) {
        self.identity = identity
        self.operatingSystem = operatingSystem
        self.processor = processor
        self.graphics = graphics
        self.physicalMemory = physicalMemory
    }
}

/// Values that change while the app runs and are re-read on refresh.
public struct RuntimeDeviceInfo: Sendable, Equatable {
    public var storage: StorageReading
    public var power: PowerReading
    public var display: DisplayReading
    public var appFootprint: SpecValue<ByteCount>
    public var appAvailableMemory: SpecValue<ByteCount>

    public init(storage: StorageReading, power: PowerReading, display: DisplayReading,
                appFootprint: SpecValue<ByteCount>, appAvailableMemory: SpecValue<ByteCount>) {
        self.storage = storage
        self.power = power
        self.display = display
        self.appFootprint = appFootprint
        self.appAvailableMemory = appAvailableMemory
    }
}

/// A system event after which runtime values may have changed.
public enum DeviceInfoChange: Sendable, Equatable {
    case power
    case thermal
    case lowPowerMode
    case display
}

/// Reads device information from the running system. Implemented per platform in
/// `SpecMatrixPlatform`; tests supply deterministic fakes.
public protocol DeviceInfoSource: Sendable {
    func loadStaticInfo() async throws -> StaticDeviceInfo
    func loadRuntimeInfo() async throws -> RuntimeDeviceInfo
    /// Emits when event-driven values may have changed. Ending iteration (or cancelling the
    /// consuming task) must remove any observers the stream registered.
    func changes() -> AsyncStream<DeviceInfoChange>
}

/// Reports network path changes. Ending iteration must stop the underlying monitor.
public protocol NetworkPathSource: Sendable {
    func pathUpdates() -> AsyncStream<NetworkReading>
}
