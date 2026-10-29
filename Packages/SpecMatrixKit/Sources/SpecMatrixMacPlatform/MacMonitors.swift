#if os(macOS)
import CoreFoundation
import Foundation
import IOKit.ps
import Network
import SpecMatrixShared

/// Watches the network path with `NWPathMonitor` and reports each change on the main actor.
///
/// Reads only what the path itself describes (status, interface names and types, expensive/constrained,
/// IPv4/IPv6/DNS support). No addresses, Wi-Fi network names or traffic are read, so no permission or
/// network entitlement is needed and nothing is sent anywhere.
@MainActor
public final class MacNetworkMonitor {
    private var monitor: NWPathMonitor?
    private let onChange: @MainActor (MacNetworkReading) -> Void

    public init(onChange: @escaping @MainActor (MacNetworkReading) -> Void) {
        self.onChange = onChange
    }

    /// Has no effect while already monitoring.
    public func start() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let reading = MacNetworkMapping.reading(from: path)
            Task { @MainActor in self?.onChange(reading) }
        }
        monitor.start(queue: DispatchQueue(label: "SpecMatrix.NetworkPath", qos: .utility))
        self.monitor = monitor
    }

    public func stop() {
        monitor?.cancel()
        monitor = nil
    }
}

enum MacNetworkMapping {
    static func reading(from path: NWPath) -> MacNetworkReading {
        let source = MeasurementSource(api: "NWPathMonitor", environment: .device)
        let status: MacNetworkStatus
        switch path.status {
        case .satisfied: status = .connected
        case .unsatisfied: status = .notConnected
        case .requiresConnection: status = .requiresConnection
        @unknown default:
            return MacNetworkReading(allMissing: .unknown("macOS reported an unrecognised network status."))
        }
        let interfaces = path.availableInterfaces.map { interface in
            MacNetworkInterface(name: interface.name, kind: kind(interface.type))
        }
        return MacNetworkReading(status: .measured(status, source),
                                 interfaces: .measured(interfaces, source),
                                 isExpensive: .measured(path.isExpensive, source),
                                 isConstrained: .measured(path.isConstrained, source),
                                 supportsIPv4: .measured(path.supportsIPv4, source),
                                 supportsIPv6: .measured(path.supportsIPv6, source),
                                 supportsDNS: .measured(path.supportsDNS, source))
    }

    static func kind(_ type: NWInterface.InterfaceType) -> MacNetworkInterfaceKind {
        switch type {
        case .wifi: .wifi
        case .wiredEthernet: .wiredEthernet
        case .cellular: .cellular
        case .loopback: .loopback
        case .other: .other
        @unknown default: .other
        }
    }
}

extension Notification.Name {
    /// Posted on the main thread when macOS reports a change to any power source (charge level, adapter, state).
    public static let macPowerSourcesDidChange = Notification.Name("SpecMatrixMacPowerSourcesDidChange")
}

/// Turns IOKit power-source change notifications (`IOPSNotificationCreateRunLoopSource`) into
/// `.macPowerSourcesDidChange`, so battery values update when macOS reports a change instead of on a timer.
@MainActor
public final class MacPowerSourceMonitor {
    private var runLoopSource: CFRunLoopSource?

    public init() {}

    /// Has no effect while already monitoring. On a Mac without power-source notifications nothing is posted.
    public func start() {
        guard runLoopSource == nil else { return }
        // A C callback cannot capture context; it posts a notification that observers handle on the main actor.
        let callback: IOPowerSourceCallbackType = { _ in
            NotificationCenter.default.post(name: .macPowerSourcesDidChange, object: nil)
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, nil)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = source
    }

    public func stop() {
        guard let source = runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        CFRunLoopSourceInvalidate(source)
        runLoopSource = nil
    }
}
#endif
