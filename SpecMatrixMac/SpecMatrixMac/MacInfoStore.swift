//
//  MacInfoStore.swift
//  SpecMatrixMac
//

import AppKit
import Combine
import SpecMatrixMacCatalog
import SpecMatrixMacPlatform
import SpecMatrixShared

/// Everything the window shows, collected at one moment.
struct MacSnapshot: Equatable {
    var staticInfo: MacStaticInfo
    var specification: MacSpecification
    var system: MacSystemReading
    var storage: MacStorageReading
    var battery: MacBatteryReading
    var displays: [MacDisplayReading]
    var collectedAt: Date
}

/// Owns reading this Mac's information and keeping it current while the window is open.
///
/// - Values that cannot change (identity, chip, memory, GPU) are read once.
/// - Runtime values (thermal state, Low Power Mode, storage, battery, displays) are re-read when the
///   system posts a thermal, power-mode or display-configuration change, every 60 seconds while the
///   window is open (macOS posts no simple notification for battery level), and on demand.
/// - Refreshes are coalesced: a request made during a refresh schedules exactly one more.
/// - `stop()` removes every observer and cancels the timer; observers hold the store weakly.
@MainActor
final class MacInfoStore: ObservableObject {
    static let catalog: Result<MacCatalog, CatalogLoadError> = MacCatalog.loadBundled()
    static let periodicRefreshInterval: Duration = .seconds(60)

    @Published private(set) var snapshot: MacSnapshot?
    @Published private(set) var isRefreshing = false

    private var staticInfo: MacStaticInfo?
    private var specification: MacSpecification?
    private var refreshTask: Task<Void, Never>?
    private var refreshRequestedWhileRunning = false
    private var periodicTask: Task<Void, Never>?
    private var observers: [any NSObjectProtocol] = []

    var catalogError: CatalogLoadError? {
        if case .failure(let error) = Self.catalog { return error }
        return nil
    }

    /// Starts observing and loads information. Has no effect while already observing.
    func start() {
        guard observers.isEmpty, periodicTask == nil else { return }
        let names: [Notification.Name] = [
            ProcessInfo.thermalStateDidChangeNotification,
            .NSProcessInfoPowerStateDidChange,
            NSApplication.didChangeScreenParametersNotification,
        ]
        for name in names {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in self.refresh() }
            })
        }
        periodicTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.periodicRefreshInterval)
                guard !Task.isCancelled, let self else { return }
                self.refresh()
            }
        }
        refresh()
    }

    /// Stops observing. The last snapshot is kept.
    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        periodicTask?.cancel()
        periodicTask = nil
    }

    /// Reads the current values again.
    func refresh() {
        if refreshTask != nil {
            refreshRequestedWhileRunning = true
            return
        }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            repeat {
                self.refreshRequestedWhileRunning = false
                await self.performRefresh()
            } while self.refreshRequestedWhileRunning && !Task.isCancelled
            self.refreshTask = nil
        }
    }

    private func performRefresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let staticInfo: MacStaticInfo
        if let cached = self.staticInfo {
            staticInfo = cached
        } else {
            staticInfo = await Task.detached(priority: .userInitiated) { MacStaticReader.read() }.value
            self.staticInfo = staticInfo
        }
        let specification = self.specification ?? MacSpecificationResolver.resolve(
            identifier: staticInfo.identifier, detectedChipName: staticInfo.chipName, catalog: Self.catalog)
        self.specification = specification

        let (system, storage, battery) = await Task.detached(priority: .userInitiated) {
            (MacRuntimeReader.system(), MacRuntimeReader.storage(), MacBatteryReader.read())
        }.value
        let displays = MacDisplayReader.read()

        snapshot = MacSnapshot(staticInfo: staticInfo, specification: specification, system: system, storage: storage,
                               battery: battery, displays: displays, collectedAt: Date())
    }
}
