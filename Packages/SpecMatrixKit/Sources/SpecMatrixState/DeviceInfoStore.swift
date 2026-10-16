import Combine
import Foundation
import SpecMatrixCore

/// Owns device-information loading, refresh scheduling, and observation for SwiftUI.
///
/// - All published state is main-actor isolated.
/// - Event-driven: values refresh when the source reports a change (battery, thermal state,
///   Low Power Mode, brightness) or when `refresh()` is called. There is no polling timer.
/// - Refreshes are coalesced: a request made while a refresh is running schedules exactly one
///   follow-up refresh instead of running concurrently.
/// - Observation stops on `stop()` or when the store is deallocated; stopping ends the
///   source's streams, which removes their observers and cancels the network monitor.
@MainActor
public final class DeviceInfoStore: ObservableObject {
    public enum Phase: Sendable, Equatable {
        /// Nothing has been loaded yet.
        case idle
        /// The first load is in progress.
        case loading
        /// The latest load succeeded and every attempted read succeeded.
        case loaded
        /// The latest load produced a report, but some reads failed.
        case partial(errorCount: Int)
        /// The latest load failed entirely. `report` still holds the previous snapshot, if any.
        case failed(SpecError)
    }

    @Published public private(set) var phase: Phase = .idle
    /// The latest snapshot. Check `collectedAt` before treating it as current.
    @Published public private(set) var report: DeviceReport?
    @Published public private(set) var network: SpecValue<NetworkReading>

    private let source: any DeviceInfoSource
    private let networkSource: (any NetworkPathSource)?
    private let catalog: Result<DeviceCatalog, CatalogLoadError>
    private let clock: @Sendable () -> Date

    private var staticInfo: StaticDeviceInfo?
    private var refreshTask: Task<Void, Never>?
    private var refreshRequestedWhileRunning = false
    private let observation = TaskBag()

    public init(source: any DeviceInfoSource,
                networkSource: (any NetworkPathSource)?,
                catalog: Result<DeviceCatalog, CatalogLoadError>,
                clock: @escaping @Sendable () -> Date = { Date() }) {
        self.source = source
        self.networkSource = networkSource
        self.catalog = catalog
        self.clock = clock
        self.network = Self.idleNetworkValue(hasSource: networkSource != nil)
    }

    public var isObserving: Bool { !observation.isEmpty }

    /// Starts observing changes and loads information. Has no effect if already observing.
    public func start() {
        guard observation.isEmpty else { return }

        let changes = source.changes()
        observation.add(Task { [weak self] in
            for await _ in changes {
                guard let self else { return }
                self.refresh()
            }
        })

        if let networkSource {
            let updates = networkSource.pathUpdates()
            observation.add(Task { [weak self] in
                for await reading in updates {
                    guard let self else { return }
                    self.network = .measured(reading, MeasurementSource(api: "NWPathMonitor", environment: .current))
                }
            })
        }

        refresh()
    }

    /// Stops observing and cancels any refresh in progress. The last report is kept.
    public func stop() {
        observation.cancelAll()
        refreshTask?.cancel()
        network = Self.idleNetworkValue(hasSource: networkSource != nil)
    }

    /// Requests a refresh. Returns the task performing it, which callers may await.
    @discardableResult
    public func refresh() -> Task<Void, Never> {
        if let refreshTask {
            refreshRequestedWhileRunning = true
            return refreshTask
        }
        let task = Task { [weak self] in
            guard let self else { return }
            repeat {
                // Requests made before this pass starts reading are satisfied by it.
                self.refreshRequestedWhileRunning = false
                await self.performRefresh()
            } while self.refreshRequestedWhileRunning && !Task.isCancelled
            self.refreshTask = nil
        }
        refreshTask = task
        return task
    }

    private func performRefresh() async {
        if report == nil { phase = .loading }
        do {
            let staticInfo: StaticDeviceInfo
            if let cached = self.staticInfo {
                staticInfo = cached
            } else {
                staticInfo = try await source.loadStaticInfo()
                self.staticInfo = staticInfo
            }
            let runtimeInfo = try await source.loadRuntimeInfo()
            try Task.checkCancellation()

            let report = DeviceReport(staticInfo: staticInfo, runtimeInfo: runtimeInfo,
                                      catalog: catalog, collectedAt: clock())
            self.report = report
            let errorCount = report.errors.count
            phase = errorCount == 0 ? .loaded : .partial(errorCount: errorCount)
        } catch is CancellationError {
            if report == nil { phase = .idle }
        } catch {
            phase = .failed(SpecError(operation: "Load device information", message: String(describing: error)))
        }
    }

    private static func idleNetworkValue(hasSource: Bool) -> SpecValue<NetworkReading> {
        hasSource ? .unknown("Network monitoring has not started.") : .unavailable(.notYetImplemented)
    }
}

/// Cancels its tasks when cancelled explicitly or when deallocated with its owner.
final class TaskBag: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [Task<Void, Never>] = []

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return tasks.isEmpty
    }

    func add(_ task: Task<Void, Never>) {
        lock.lock()
        defer { lock.unlock() }
        tasks.append(task)
    }

    func cancelAll() {
        lock.lock()
        let cancelled = tasks
        tasks = []
        lock.unlock()
        cancelled.forEach { $0.cancel() }
    }

    deinit {
        tasks.forEach { $0.cancel() }
    }
}
