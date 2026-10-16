//
//  FoundationDiagnosticsView.swift
//  SpecMatrix
//

#if DEBUG
import SpecMatrixCore
import SpecMatrixState
import SwiftUI

/// Developer-only screen for checking the SpecMatrixKit providers on a real device.
/// It is compiled only into Debug builds and is not part of the product interface.
struct FoundationDiagnosticsView: View {
    @StateObject private var store: DeviceInfoStore

    init() {
        _store = StateObject(wrappedValue: AppEnvironment.makeDeviceInfoStore())
    }

    var body: some View {
        List {
            Section {
                Text(verbatim: phaseDescription)
                if let report = store.report {
                    Text(verbatim: "Collected \(report.collectedAt.formatted(date: .omitted, time: .standard))")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(verbatim: "Status")
            }
            if let report = store.report {
                reportSections(report)
            }
            Section {
                row("Path", store.network) { reading in
                    ([reading.status.rawValue] + reading.interfaces.map(\.rawValue)).joined(separator: ", ")
                }
                row("Expensive", store.network.map(\.isExpensive), yesNo)
                row("Low Data Mode", store.network.map(\.isConstrained), yesNo)
            } header: {
                Text(verbatim: "Network")
            }
        }
        .navigationTitle(Text(verbatim: "Foundation Diagnostics"))
        .toolbar {
            Button {
                store.refresh()
            } label: {
                Text(verbatim: "Refresh")
            }
        }
        .onAppear { store.start() }
        .onDisappear { store.stop() }
    }

    @ViewBuilder
    private func reportSections(_ report: DeviceReport) -> some View {
        section("Identity") {
            row("Hardware identifier", report.identity, SpecFormat.identity)
        }
        section("Catalog specifications") {
            row("Model", report.hardware.marketingName) { $0 }
            row("Released", report.hardware.releaseDate, \.description)
            row("Chip", report.hardware.chipName) { $0 }
            row("Performance cores", report.hardware.performanceCores, String.init)
            row("Efficiency cores", report.hardware.efficiencyCores, String.init)
            row("GPU cores", report.hardware.gpuCores, String.init)
            row("Neural Engine cores", report.hardware.neuralEngineCores, String.init)
            row("Display size", report.hardware.displayDiagonal, \.description)
            row("Display resolution", report.hardware.displayResolution, \.description)
            row("Pixel density", report.hardware.displayPixelDensity, \.description)
            row("Maximum refresh rate", report.hardware.displayMaximumRefreshRate, \.description)
        }
        section("Operating system") {
            row("Name", report.operatingSystem.name) { $0 }
            row("Version", report.operatingSystem.version, \.description)
            row("Build", report.operatingSystem.build) { $0 }
        }
        section("Processor") {
            row("Logical cores", report.processor.logicalCores, String.init)
            row("Active logical cores", report.processor.activeLogicalCores, String.init)
            row("Performance cores", report.processor.performanceCores, String.init)
            row("Efficiency cores", report.processor.efficiencyCores, String.init)
        }
        section("Memory") {
            row("Physical memory", report.memory.physicalMemory) { SpecFormat.memory($0) }
            row("App footprint", report.memory.appFootprint) { SpecFormat.memory($0) }
            row("App available", report.memory.appAvailable) { SpecFormat.memory($0) }
        }
        section("Graphics") {
            row("GPU", report.graphics.gpuName) { $0 }
            row("Metal 3", report.graphics.supportsMetal3, yesNo)
            row("Recommended working set", report.graphics.recommendedMaxWorkingSet) { SpecFormat.memory($0) }
        }
        section("Storage") {
            row("Capacity", report.storage.capacity) { SpecFormat.storage($0) }
            row("Available", report.storage.availableForImportantUsage) { SpecFormat.storage($0) }
            row("Used", report.storage.usedFraction) { SpecFormat.percent($0) }
        }
        section("Power") {
            row("Battery level", report.power.batteryLevel) { SpecFormat.percent($0) }
            row("Battery state", report.power.batteryState, \.rawValue)
            row("Thermal state", report.power.thermalState, \.rawValue)
            row("Low Power Mode", report.power.lowPowerMode, yesNo)
        }
        section("Display (current screen)") {
            row("Native resolution", report.display.nativeResolution, \.description)
            row("Native scale", report.display.nativeScale) { String(format: "%.2f×", $0) }
            row("Maximum frame rate now", report.display.maximumFramesPerSecond, \.description)
            row("Brightness", report.display.brightness) { SpecFormat.percent($0) }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Section {
            content()
        } header: {
            Text(verbatim: title)
        }
    }

    private func row<Value>(_ label: String, _ value: SpecValue<Value>, _ format: (Value) -> String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: label)
                Spacer()
                Text(verbatim: valueText(value, format))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(value.value == nil ? .secondary : .primary)
            }
            Text(verbatim: provenanceText(value))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func valueText<Value>(_ value: SpecValue<Value>, _ format: (Value) -> String) -> String {
        switch value {
        case .measured(let known, _), .catalog(let known, _): format(known)
        case .unavailable(let reason): reason.explanation
        case .unknown(let reason): reason
        case .error(let error): error.description
        }
    }

    private func provenanceText<Value>(_ value: SpecValue<Value>) -> String {
        switch value {
        case .measured(_, let source):
            "Measured · \(source.api)" + (source.environment == .simulator ? " · Simulator" : "")
        case .catalog(_, let reference):
            "Catalog \(reference.catalogVersion) · \(reference.entryID) · \(reference.verification.rawValue)"
        case .unavailable: "Unavailable"
        case .unknown: "Unknown"
        case .error: "Error"
        }
    }

    private func yesNo(_ flag: Bool) -> String { flag ? "Yes" : "No" }

    private var phaseDescription: String {
        switch store.phase {
        case .idle: "Idle"
        case .loading: "Loading…"
        case .loaded: "Loaded"
        case .partial(let count): "Loaded with \(count) failed read(s)"
        case .failed(let error): "Failed: \(error.description)"
        }
    }
}
#endif
