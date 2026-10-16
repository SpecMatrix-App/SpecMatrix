import Foundation
import Testing
@testable import SpecMatrixCore
@testable import SpecMatrixState

// MARK: - Fakes

private let source = MeasurementSource(api: "Fake", environment: .device)

private func makeStaticInfo(identifier: String = "TestPhone1,1") -> StaticDeviceInfo {
    StaticDeviceInfo(
        identity: .measured(DeviceIdentity(identifier: HardwareIdentifier(identifier)!, environment: .device), source),
        operatingSystem: OperatingSystemInfo(name: .measured("iOS", source),
                                             version: .measured(OSVersion(major: 17, minor: 0, patch: 0), source),
                                             build: .measured("21A1", source)),
        processor: ProcessorReading(logicalCores: .measured(6, source), activeLogicalCores: .measured(6, source),
                                    performanceCores: .measured(2, source), efficiencyCores: .measured(4, source)),
        graphics: GraphicsReading(gpuName: .measured("GPU", source), supportsMetal3: .measured(true, source),
                                  recommendedMaxWorkingSet: .measured(ByteCount(exactly: 1)!, source)),
        physicalMemory: .measured(ByteCount(exactly: 8_000_000_000)!, source)
    )
}

private func makeRuntimeInfo(batteryLevel: Double = 0.5, storageError: SpecError? = nil) -> RuntimeDeviceInfo {
    let storage = storageError.map { StorageReading(capacity: .error($0), availableForImportantUsage: .error($0)) }
        ?? StorageReading(capacity: .measured(ByteCount(exactly: 100)!, source),
                          availableForImportantUsage: .measured(ByteCount(exactly: 25)!, source))
    return RuntimeDeviceInfo(
        storage: storage,
        power: PowerReading(batteryLevel: .measured(UnitFraction(batteryLevel)!, source),
                            batteryState: .measured(.unplugged, source),
                            thermalState: .measured(.nominal, source), lowPowerMode: .measured(false, source)),
        display: DisplayReading(allMissing: .unavailable(.notYetImplemented)),
        appFootprint: .measured(ByteCount(exactly: 1)!, source),
        appAvailableMemory: .unknown("n/a")
    )
}

private struct FakeFailure: Error, CustomStringConvertible {
    var description: String { "simulated failure" }
}

/// A controllable `DeviceInfoSource`. Thread-safe so it can satisfy `Sendable`.
private final class FakeSource: DeviceInfoSource, @unchecked Sendable {
    private let lock = NSLock()
    private var _staticResult: Result<StaticDeviceInfo, FakeFailure> = .success(makeStaticInfo())
    private var _runtimeResult: Result<RuntimeDeviceInfo, FakeFailure> = .success(makeRuntimeInfo())
    private var _staticLoads = 0
    private var _runtimeLoads = 0
    private var _subscriptions = 0
    private var _terminations = 0
    private var continuations: [AsyncStream<DeviceInfoChange>.Continuation] = []
    private var paused = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    private func locked<T>(_ body: () -> T) -> T { lock.lock(); defer { lock.unlock() }; return body() }

    var staticLoads: Int { locked { _staticLoads } }
    var runtimeLoads: Int { locked { _runtimeLoads } }
    var subscriptions: Int { locked { _subscriptions } }
    var terminations: Int { locked { _terminations } }

    func setStatic(_ result: Result<StaticDeviceInfo, FakeFailure>) { locked { _staticResult = result } }
    func setRuntime(_ result: Result<RuntimeDeviceInfo, FakeFailure>) { locked { _runtimeResult = result } }

    /// Makes subsequent runtime loads suspend until `resume()`.
    func pause() { locked { paused = true } }
    func resume() {
        let toResume: [CheckedContinuation<Void, Never>] = locked {
            paused = false
            defer { waiting = [] }
            return waiting
        }
        toResume.forEach { $0.resume() }
    }

    func emit(_ change: DeviceInfoChange) {
        locked { continuations }.forEach { $0.yield(change) }
    }

    func loadStaticInfo() async throws -> StaticDeviceInfo {
        try locked { _staticLoads += 1; return _staticResult }.get()
    }

    func loadRuntimeInfo() async throws -> RuntimeDeviceInfo {
        locked { _runtimeLoads += 1 }
        await withCheckedContinuation { continuation in
            let mustWait = locked { () -> Bool in
                if paused { waiting.append(continuation); return true }
                return false
            }
            if !mustWait { continuation.resume() }
        }
        return try locked { _runtimeResult }.get()
    }

    private func recordTermination() { locked { _terminations += 1 } }

    func changes() -> AsyncStream<DeviceInfoChange> {
        AsyncStream { continuation in
            locked {
                _subscriptions += 1
                continuations.append(continuation)
            }
            continuation.onTermination = { [weak self] _ in
                self?.recordTermination()
            }
        }
    }
}

private final class FakeNetworkSource: NetworkPathSource, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<NetworkReading>.Continuation?

    func pathUpdates() -> AsyncStream<NetworkReading> {
        AsyncStream { continuation in
            lock.lock(); self.continuation = continuation; lock.unlock()
        }
    }

    func send(_ reading: NetworkReading) {
        lock.lock(); let continuation = self.continuation; lock.unlock()
        continuation?.yield(reading)
    }
}

/// Yields to other tasks until `condition` holds, failing after a bounded number of attempts.
@MainActor
private func waitUntil(_ description: String, _ condition: () -> Bool) async {
    for _ in 0..<2_000 {
        if condition() { return }
        await Task.yield()
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
    Issue.record("Timed out waiting until \(description)")
}

private let catalog = DeviceCatalog.decode(Data("""
{"schemaVersion":1,"catalogVersion":"store-test","entries":[{"id":"test-phone","identifiers":["TestPhone1,1"],
"family":"TestPhone","marketingName":"Test Phone",
"sources":[{"title":"Fixture","url":"https://example.com/x","accessed":"2026-10-15"}],
"verification":{"status":"verified","verifiedOn":"2026-10-15"}}]}
""".utf8))

// MARK: - Tests

@Suite("DeviceInfoStore")
@MainActor
struct DeviceInfoStoreTests {
    @Test func startsIdleWithoutLoading() {
        let fake = FakeSource()
        let store = DeviceInfoStore(source: fake, networkSource: nil, catalog: catalog)
        #expect(store.phase == .idle)
        #expect(store.report == nil)
        #expect(fake.staticLoads == 0)
        #expect(store.network == .unavailable(.notYetImplemented))
    }

    @Test func successfulRefreshPublishesLoadedReport() async throws {
        let fake = FakeSource()
        let store = DeviceInfoStore(source: fake, networkSource: nil, catalog: catalog,
                                    clock: { Date(timeIntervalSince1970: 1_000) })
        await store.refresh().value
        #expect(store.phase == .loaded)
        let report = try #require(store.report)
        #expect(report.hardware.marketingName.value == "Test Phone")
        #expect(report.collectedAt == Date(timeIntervalSince1970: 1_000))
    }

    @Test func failedReadsProducePartialPhase() async throws {
        let fake = FakeSource()
        fake.setRuntime(.success(makeRuntimeInfo(storageError: SpecError(operation: "Read volume capacity", message: "denied"))))
        let store = DeviceInfoStore(source: fake, networkSource: nil, catalog: catalog)
        await store.refresh().value
        #expect(store.phase == .partial(errorCount: 2))
        #expect(try #require(store.report).storage.usedFraction.provenance == .error)
    }

    @Test func totalFailureProducesFailedPhaseAndRecovers() async {
        let fake = FakeSource()
        fake.setStatic(.failure(FakeFailure()))
        let store = DeviceInfoStore(source: fake, networkSource: nil, catalog: catalog)
        await store.refresh().value
        guard case .failed(let error) = store.phase else {
            Issue.record("Expected failed, got \(store.phase)"); return
        }
        #expect(error.message == "simulated failure")
        #expect(store.report == nil)

        fake.setStatic(.success(makeStaticInfo()))
        await store.refresh().value
        #expect(store.phase == .loaded)
        #expect(store.report != nil)
    }

    @Test func staticInfoIsLoadedOnce() async {
        let fake = FakeSource()
        let store = DeviceInfoStore(source: fake, networkSource: nil, catalog: catalog)
        await store.refresh().value
        await store.refresh().value
        #expect(fake.staticLoads == 1)
        #expect(fake.runtimeLoads == 2)
    }

    @Test func requestsDuringARefreshAreCoalescedIntoOneFollowUp() async {
        let fake = FakeSource()
        let store = DeviceInfoStore(source: fake, networkSource: nil, catalog: catalog)
        fake.pause()
        let first = store.refresh()
        await waitUntil("the first runtime load starts") { fake.runtimeLoads == 1 }
        let second = store.refresh()
        let third = store.refresh()
        fake.resume()
        await first.value
        await second.value
        await third.value
        // Three requests: the first load, plus exactly one follow-up for the two requests made during it.
        #expect(fake.runtimeLoads == 2)
        #expect(store.phase == .loaded)
    }

    @Test func followUpRefreshPublishesTheNewerValue() async throws {
        let fake = FakeSource()
        let store = DeviceInfoStore(source: fake, networkSource: nil, catalog: catalog)
        fake.pause()
        let task = store.refresh()
        await waitUntil("the first runtime load starts") { fake.runtimeLoads == 1 }
        fake.setRuntime(.success(makeRuntimeInfo(batteryLevel: 0.2)))
        store.refresh()
        fake.resume()
        await task.value
        #expect(try #require(store.report).power.batteryLevel.value == UnitFraction(0.2))
    }

    @Test func startIsIdempotentAndChangesTriggerRefresh() async {
        let fake = FakeSource()
        let store = DeviceInfoStore(source: fake, networkSource: nil, catalog: catalog)
        store.start()
        store.start()
        #expect(fake.subscriptions == 1)
        #expect(store.isObserving)
        await waitUntil("the initial load completes") { store.phase == .loaded }
        let loadsBefore = fake.runtimeLoads

        fake.emit(.power)
        await waitUntil("a change triggers a refresh") { fake.runtimeLoads == loadsBefore + 1 }
        store.stop()
    }

    @Test func stopEndsObservationAndRemovesSubscriptions() async {
        let fake = FakeSource()
        let store = DeviceInfoStore(source: fake, networkSource: nil, catalog: catalog)
        store.start()
        await waitUntil("the initial load completes") { store.phase == .loaded }
        store.stop()
        #expect(!store.isObserving)
        await waitUntil("the change stream terminates") { fake.terminations == 1 }

        let loads = fake.runtimeLoads
        fake.emit(.thermal)
        try? await Task.sleep(nanoseconds: 20_000_000)
        #expect(fake.runtimeLoads == loads)
        #expect(store.phase == .loaded, "The last report is kept after stopping")
    }

    @Test func publishesNetworkPathUpdates() async {
        let fake = FakeSource()
        let network = FakeNetworkSource()
        let store = DeviceInfoStore(source: fake, networkSource: network, catalog: catalog)
        #expect(store.network.provenance == .unknown)
        store.start()
        let reading = NetworkReading(status: .satisfied, interfaces: [.wifi], isExpensive: false, isConstrained: false)
        await waitUntil("the network stream is subscribed") {
            network.send(reading)
            return store.network.value == reading
        }
        #expect(store.network.provenance == .measured)
        store.stop()
        #expect(store.network.value == nil, "A stopped monitor does not keep presenting the last path as current")
    }

    @Test func releasingTheStoreEndsObservation() async {
        let fake = FakeSource()
        var store: DeviceInfoStore? = DeviceInfoStore(source: fake, networkSource: nil, catalog: catalog)
        store?.start()
        await waitUntil("the initial load completes") { store?.phase == .loaded }
        weak var weakStore: DeviceInfoStore?
        weakStore = store
        store = nil
        #expect(weakStore == nil)
        await waitUntil("the change stream terminates after release") { fake.terminations == 1 }
    }
}
