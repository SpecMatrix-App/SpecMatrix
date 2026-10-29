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
    var volumes: SpecValue<[MacVolumeReading]>
    var memory: MacMemoryReading
    var battery: MacBatteryReading
    var displays: [MacDisplayReading]
    var collectedAt: Date
}

/// Owns reading this Mac's information and keeping it current while the window is open.
///
/// - Values that cannot change (identity, chip, memory size, GPU, macOS) are read once, off the main actor,
///   and resolved against the Mac catalog once.
/// - Runtime values are re-read when macOS reports a change: thermal state, Low Power Mode, display
///   configuration, power sources (IOKit notification), volume mounts; the network path is pushed by
///   `NWPathMonitor`.
/// - A 60-second refresh covers values with no change notification (free space, memory use, battery time
///   estimates). While the Memory pane is visible, memory statistics alone are re-read every 5 seconds.
/// - Refreshes are coalesced: a request made during a refresh schedules exactly one more.
/// - `stop()` removes every observer, stops both monitors and cancels both timers.
@MainActor
final class MacInfoStore: ObservableObject {
    static let catalog: Result<MacCatalog, CatalogLoadError> = MacCatalog.loadBundled()
    static let periodicRefreshInterval: Duration = .seconds(60)
    static let liveMemoryInterval: Duration = .seconds(5)

    @Published private(set) var snapshot: MacSnapshot?
    @Published private(set) var network = MacNetworkReading(allMissing: .unknown("Waiting for macOS to report the network path."))
    @Published private(set) var isRefreshing = false

    private var staticInfo: MacStaticInfo?
    private var specification: MacSpecification?
    private var refreshTask: Task<Void, Never>?
    private var refreshRequestedWhileRunning = false
    private var periodicTask: Task<Void, Never>?
    private var liveMemoryTask: Task<Void, Never>?
    private var observers: [(NotificationCenter, any NSObjectProtocol)] = []
    private var networkMonitor: MacNetworkMonitor?
    private let powerSourceMonitor = MacPowerSourceMonitor()

    var catalogError: CatalogLoadError? {
        if case .failure(let error) = Self.catalog { return error }
        return nil
    }

    var catalogVersion: String? {
        if case .success(let catalog) = Self.catalog { return catalog.catalogVersion }
        return nil
    }

    /// Starts observing and loads information. Has no effect while already observing.
    func start() {
        guard observers.isEmpty, periodicTask == nil else { return }
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        let names: [(NotificationCenter, Notification.Name)] = [
            (center, ProcessInfo.thermalStateDidChangeNotification),
            (center, .NSProcessInfoPowerStateDidChange),
            (center, NSApplication.didChangeScreenParametersNotification),
            (center, .macPowerSourcesDidChange),
            (workspace, NSWorkspace.didMountNotification),
            (workspace, NSWorkspace.didUnmountNotification),
            (workspace, NSWorkspace.didRenameVolumeNotification),
        ]
        for (notificationCenter, name) in names {
            let token = notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            observers.append((notificationCenter, token))
        }
        powerSourceMonitor.start()
        let monitor = MacNetworkMonitor { [weak self] reading in self?.network = reading }
        monitor.start()
        networkMonitor = monitor
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
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
        powerSourceMonitor.stop()
        networkMonitor?.stop()
        networkMonitor = nil
        periodicTask?.cancel()
        periodicTask = nil
        setLiveMemory(false)
    }

    /// Re-reads memory statistics every few seconds while enabled (the Memory pane is visible).
    func setLiveMemory(_ enabled: Bool) {
        liveMemoryTask?.cancel()
        liveMemoryTask = nil
        guard enabled else { return }
        liveMemoryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.liveMemoryInterval)
                guard !Task.isCancelled, let self else { return }
                let memory = await Task.detached(priority: .utility) { MacMemoryReader.read() }.value
                guard !Task.isCancelled, var snapshot = self.snapshot else { continue }
                snapshot.memory = memory
                self.snapshot = snapshot
            }
        }
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
            identifier: staticInfo.identifier, detectedChipName: staticInfo.chipName,
            detectedCoreClusters: staticInfo.coreClusters, catalog: Self.catalog)
        self.specification = specification

        let (system, storage, volumes, memory, battery) = await Task.detached(priority: .userInitiated) {
            (MacRuntimeReader.system(), MacRuntimeReader.storage(), MacVolumeReader.read(), MacMemoryReader.read(),
             MacBatteryReader.read())
        }.value
        let displays = MacDisplayReader.read()

        snapshot = MacSnapshot(staticInfo: staticInfo, specification: specification, system: system, storage: storage,
                               volumes: volumes, memory: memory, battery: battery, displays: displays, collectedAt: Date())
    }
}
