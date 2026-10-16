import Foundation
import SpecMatrixCore
#if os(iOS)
import UIKit
#endif

/// Converts system notifications into a `DeviceInfoChange` stream.
/// Observers are registered when the stream is created and removed when it terminates.
enum ChangeNotifications {
    static var observed: [(Notification.Name, DeviceInfoChange)] {
        var names: [(Notification.Name, DeviceInfoChange)] = [
            (ProcessInfo.thermalStateDidChangeNotification, .thermal),
            (.NSProcessInfoPowerStateDidChange, .lowPowerMode),
        ]
        #if os(iOS)
        names += [
            (UIDevice.batteryLevelDidChangeNotification, .power),
            (UIDevice.batteryStateDidChangeNotification, .power),
            (UIScreen.brightnessDidChangeNotification, .display),
        ]
        #endif
        return names
    }

    /// - Parameter registry: Receives the observer tokens; injectable so tests can verify cleanup.
    static func stream(center: NotificationCenter = .default, registry: ObserverTokens? = nil) -> AsyncStream<DeviceInfoChange> {
        AsyncStream(bufferingPolicy: .bufferingNewest(8)) { continuation in
            let tokens = registry ?? ObserverTokens(center: center)
            for (name, change) in observed {
                tokens.add(center.addObserver(forName: name, object: nil, queue: nil) { _ in
                    continuation.yield(change)
                })
            }
            continuation.onTermination = { _ in tokens.removeAll() }
        }
    }
}

/// Holds observer tokens so they can be removed from the stream's `@Sendable` termination handler.
final class ObserverTokens: @unchecked Sendable {
    private let lock = NSLock()
    private let center: NotificationCenter
    private var tokens: [any NSObjectProtocol] = []

    init(center: NotificationCenter) {
        self.center = center
    }

    func add(_ token: any NSObjectProtocol) {
        lock.lock()
        defer { lock.unlock() }
        tokens.append(token)
    }

    func removeAll() {
        lock.lock()
        let removed = tokens
        tokens = []
        lock.unlock()
        removed.forEach(center.removeObserver)
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return tokens.count
    }
}
