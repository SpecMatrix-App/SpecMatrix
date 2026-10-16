import Foundation

/// A complete snapshot of everything SpecMatrix knows about the running device.
public struct DeviceReport: Sendable, Equatable {
    public var identity: SpecValue<DeviceIdentity>
    /// Catalog-derived specifications, kept separate from measured values.
    public var hardware: HardwareSpecification
    public var operatingSystem: OperatingSystemInfo
    public var processor: ProcessorReading
    public var memory: MemoryReading
    public var graphics: GraphicsReading
    public var storage: StorageReading
    public var power: PowerReading
    public var display: DisplayReading
    public var collectedAt: Date

    public init(staticInfo: StaticDeviceInfo, runtimeInfo: RuntimeDeviceInfo,
                catalog: Result<DeviceCatalog, CatalogLoadError>, collectedAt: Date) {
        identity = staticInfo.identity
        hardware = HardwareResolver.resolve(identity: staticInfo.identity, catalog: catalog)
        operatingSystem = staticInfo.operatingSystem
        processor = staticInfo.processor
        memory = MemoryReading(physicalMemory: staticInfo.physicalMemory,
                               appFootprint: runtimeInfo.appFootprint,
                               appAvailable: runtimeInfo.appAvailableMemory)
        graphics = staticInfo.graphics
        storage = runtimeInfo.storage
        power = runtimeInfo.power
        display = runtimeInfo.display
        self.collectedAt = collectedAt
    }

    /// Every attempted read that failed. Unknown and unavailable values are not errors.
    public var errors: [SpecError] {
        [identity.specError].compactMap { $0 }
            + hardware.errors + operatingSystem.errors + processor.errors + memory.errors
            + graphics.errors + storage.errors + power.errors + display.errors
    }
}
