import Foundation
import Network
import SpecMatrixCore
#if os(iOS)
import UIKit
#endif

/// Reads device information from the running system through supported public APIs.
public struct LiveDeviceInfoSource: DeviceInfoSource {
    #if os(iOS)
    private let screen: @MainActor @Sendable () -> UIScreen?

    /// - Parameter screen: Returns the screen currently showing the app (from its window scene).
    public init(screen: @escaping @MainActor @Sendable () -> UIScreen?) {
        self.screen = screen
    }
    #else
    public init() {}
    #endif

    public func loadStaticInfo() async throws -> StaticDeviceInfo {
        let environment = RuntimeEnvironment.current
        let identity = IdentityReader.read()
        let operatingSystem = await OperatingSystemReader.read()
        try Task.checkCancellation()
        return StaticDeviceInfo(
            identity: identity,
            operatingSystem: operatingSystem,
            processor: ProcessorReader.read(environment: environment),
            graphics: GraphicsReader.read(environment: environment),
            physicalMemory: MemoryReader.physicalMemory(environment: environment)
        )
    }

    public func loadRuntimeInfo() async throws -> RuntimeDeviceInfo {
        let environment = RuntimeEnvironment.current
        let power = await PowerReader.read(environment: environment)
        #if os(iOS)
        let screen = self.screen
        let display = await MainActor.run { DisplayReader.read(screen: screen(), environment: environment) }
        #else
        let display = DisplayReading(allMissing: .unavailable(.notYetImplemented))
        #endif
        try Task.checkCancellation()
        return RuntimeDeviceInfo(
            storage: StorageReader.read(environment: environment),
            power: power,
            display: display,
            appFootprint: MemoryReader.appFootprint(environment: environment),
            appAvailableMemory: MemoryReader.appAvailable(environment: environment)
        )
    }

    public func changes() -> AsyncStream<DeviceInfoChange> {
        ChangeNotifications.stream()
    }
}

/// Reports network path changes from `NWPathMonitor`. Makes no network requests.
public struct LiveNetworkPathSource: NetworkPathSource {
    public init() {}

    public func pathUpdates() -> AsyncStream<NetworkReading> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                continuation.yield(NetworkPathMapping.reading(from: path))
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "SpecMatrix.NetworkPathMonitor"))
        }
    }
}

enum NetworkPathMapping {
    static func reading(from path: NWPath) -> NetworkReading {
        let types: [NWInterface.InterfaceType] = [.wifi, .cellular, .wiredEthernet, .loopback, .other]
        return NetworkReading(
            status: status(path.status),
            interfaces: types.filter(path.usesInterfaceType).map(kind),
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained
        )
    }

    static func status(_ status: NWPath.Status) -> NetworkPathStatus {
        switch status {
        case .satisfied: .satisfied
        case .unsatisfied: .unsatisfied
        case .requiresConnection: .requiresConnection
        @unknown default: .unrecognized
        }
    }

    static func kind(_ type: NWInterface.InterfaceType) -> NetworkInterfaceKind {
        switch type {
        case .wifi: .wifi
        case .cellular: .cellular
        case .wiredEthernet: .wiredEthernet
        case .loopback: .loopback
        case .other: .other
        @unknown default: .other
        }
    }
}
