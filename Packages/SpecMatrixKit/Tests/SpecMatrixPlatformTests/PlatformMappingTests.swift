import Foundation
import Network
import Testing
@testable import SpecMatrixCore
@testable import SpecMatrixPlatform
#if os(macOS)
import IOKit.ps
#endif

@Suite("Identity parsing")
struct IdentityParsingTests {
    @Test func decodesNULTerminatedBytes() {
        let bytes: [UInt8] = Array("iPhone17,1".utf8) + [0, 0, 65, 66]
        #expect(CString.decode(bytes) == "iPhone17,1")
        #expect(CString.decode([UInt8]()) == "")
    }

    @Test func validIdentifierIsMeasuredWithItsAPI() {
        let identity = IdentityReader.identity(fromRaw: "iPad16,4", api: "uname().machine", environment: .device)
        guard case .measured(let value, let source) = identity else {
            Issue.record("Expected measured identity"); return
        }
        #expect(value.identifier.rawValue == "iPad16,4")
        #expect(value.environment == .device)
        #expect(source.api == "uname().machine")
    }

    @Test func architectureStringIsNotTreatedAsAModel() {
        // On Apple silicon Macs and in the Simulator, uname reports "arm64".
        let identity = IdentityReader.identity(fromRaw: "arm64", api: "uname().machine", environment: .device)
        #expect(identity.provenance == .unknown)
    }
}

@Suite("Network path mapping")
struct NetworkPathMappingTests {
    @Test func mapsStatuses() {
        #expect(NetworkPathMapping.status(.satisfied) == .satisfied)
        #expect(NetworkPathMapping.status(.unsatisfied) == .unsatisfied)
        #expect(NetworkPathMapping.status(.requiresConnection) == .requiresConnection)
    }

    @Test func mapsInterfaceTypes() {
        #expect(NetworkPathMapping.kind(.wifi) == .wifi)
        #expect(NetworkPathMapping.kind(.cellular) == .cellular)
        #expect(NetworkPathMapping.kind(.wiredEthernet) == .wiredEthernet)
        #expect(NetworkPathMapping.kind(.loopback) == .loopback)
        #expect(NetworkPathMapping.kind(.other) == .other)
    }

    @Test func readingDeduplicatesAndOrdersInterfaces() {
        let reading = NetworkReading(status: .satisfied, interfaces: [.cellular, .wifi, .cellular],
                                     isExpensive: true, isConstrained: false)
        #expect(reading.interfaces == [.wifi, .cellular])
    }
}

@Suite("Change notifications")
struct ChangeNotificationTests {
    @Test func translatesNotificationsIntoChanges() async {
        let center = NotificationCenter()
        var iterator = ChangeNotifications.stream(center: center).makeAsyncIterator()
        center.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        center.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
        #expect(await iterator.next() == .thermal)
        #expect(await iterator.next() == .lowPowerMode)
    }

    @Test func removesObserversWhenConsumerIsCancelled() async {
        let center = NotificationCenter()
        let registry = ObserverTokens(center: center)
        let stream = ChangeNotifications.stream(center: center, registry: registry)
        #expect(registry.count == ChangeNotifications.observed.count)

        let consumer = Task {
            for await _ in stream {}
        }
        consumer.cancel()
        await consumer.value
        #expect(registry.count == 0)
    }
}

#if os(macOS)
@Suite("macOS battery mapping")
struct MacBatteryMappingTests {
    private func reading(_ description: [String: Any]) -> (SpecValue<UnitFraction>, SpecValue<BatteryChargeState>) {
        MacBatteryMapping.reading(description: description, environment: .device)
    }

    @Test func onBatteryPower() throws {
        let (level, state) = reading([kIOPSCurrentCapacityKey: 42, kIOPSMaxCapacityKey: 100,
                                      kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue, kIOPSIsChargingKey: false])
        #expect(try #require(level.value).value == 0.42)
        #expect(state.value == .unplugged)
    }

    @Test func chargingFullAndHeld() {
        #expect(reading([kIOPSPowerSourceStateKey: kIOPSACPowerValue, kIOPSIsChargingKey: true]).1.value == .charging)
        #expect(reading([kIOPSPowerSourceStateKey: kIOPSACPowerValue, kIOPSIsChargingKey: false,
                         kIOPSIsChargedKey: true]).1.value == .full)
        #expect(reading([kIOPSPowerSourceStateKey: kIOPSACPowerValue, kIOPSIsChargingKey: false]).1.value == .notCharging)
    }

    @Test func invalidCapacityIsUnknownNotZero() {
        #expect(reading([kIOPSCurrentCapacityKey: 50, kIOPSMaxCapacityKey: 0]).0.provenance == .unknown)
        #expect(reading([kIOPSCurrentCapacityKey: 150, kIOPSMaxCapacityKey: 100]).0.provenance == .unknown)
        #expect(reading([:]).0.provenance == .unknown)
        #expect(reading([:]).1.provenance == .unknown)
    }
}
#endif
