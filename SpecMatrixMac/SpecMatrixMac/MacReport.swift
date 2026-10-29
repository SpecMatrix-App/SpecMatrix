//
//  MacReport.swift
//  SpecMatrixMac
//

import Foundation
import SpecMatrixMacPlatform
import SpecMatrixShared

/// A plain-text report of every value with its source, for the Copy Report command.
///
/// Contains no serial number, user or computer name, addresses or network names, because SpecMatrix never
/// reads them. Values are marked [detected] or [catalog]; missing values give their reason.
enum MacReport {
    static func text(snapshot: MacSnapshot, network: MacNetworkReading) -> String {
        var report = Report()
        let info = snapshot.staticInfo
        let spec = snapshot.specification

        report.heading("SpecMatrix for Mac \(AppInfo.version) — hardware report, \(MacFormat.dateTime(snapshot.collectedAt))")
        report.section("Identity")
        report.row("Model", spec.marketingName)
        report.row("Model identifier", info.identifier) { $0.rawValue }
        report.row("macOS", info.osVersion) { "\($0)" }
        report.row("macOS build", info.osBuild)

        report.section("Processor")
        report.row("Chip", info.chipName)
        report.row("Architecture", info.architecture)
        report.row("CPU cores", info.physicalCores, format: MacFormat.count)
        report.row("CPU clusters", info.coreClusters, format: MacFormat.clusterSummary)
        report.row("Neural Engine", spec.neuralEngineCores, format: MacFormat.cores)
        report.line("Configuration match: \(MacFormat.matchSummary(spec.configurationMatch))")

        report.section("Graphics")
        report.row("GPU", info.gpuName)
        report.row("GPU cores", spec.gpuCores, format: MacFormat.cores)
        report.row("Apple GPU family", info.gpuCapabilities.appleFamily, format: MacFormat.appleFamily)
        report.row("Metal 3", info.supportsMetal3, format: MacFormat.supported)
        report.row("Metal 4", info.gpuCapabilities.supportsMetal4, format: MacFormat.supported)
        report.row("Ray tracing", info.gpuCapabilities.supportsRaytracing, format: MacFormat.supported)

        report.section("Memory")
        report.row("Installed", info.physicalMemory, format: MacFormat.bytesOfMemory)
        report.row("Wired", snapshot.memory.wired, format: MacFormat.bytesOfMemory)
        report.row("Compressed", snapshot.memory.compressed, format: MacFormat.bytesOfMemory)
        report.row("Swap used", snapshot.memory.swapUsed, format: MacFormat.bytesOfMemory)

        report.section("Storage")
        report.row("Startup disk", snapshot.storage.volumeName)
        report.row("Capacity", snapshot.storage.capacity, format: MacFormat.bytesOfStorage)
        report.row("Available", snapshot.storage.availableForImportantUsage, format: MacFormat.bytesOfStorage)
        if case .measured(let volumes, _) = snapshot.volumes {
            for volume in volumes where volume.isStartup.value != true {
                report.row("Volume \(volume.name.value ?? volume.id) (\(MacFormat.volumeKind(volume)))", volume.capacity,
                           format: MacFormat.bytesOfStorage)
            }
        }

        report.section("Displays")
        for display in snapshot.displays {
            let name = (display.name.value ?? "Display") + (display.isBuiltIn.value == true ? " (built-in)" : "")
            report.row("\(name) resolution", display.resolution, format: MacFormat.pixels)
            report.row("\(name) looks like", display.pointSize, format: MacFormat.points)
            report.row("\(name) maximum refresh rate", display.maximumRefreshRate, format: MacFormat.refresh)
        }
        report.row("Built-in display (published)", spec.builtInDisplayDiagonal, format: MacFormat.diagonal)

        report.section("Battery and power")
        if snapshot.battery.isAbsent {
            report.line("No internal battery.")
        } else {
            report.row("Charge", snapshot.battery.level, format: MacFormat.percent)
            report.row("State", snapshot.battery.chargeState, format: MacFormat.chargeState)
            report.row("Health", snapshot.battery.health, format: MacFormat.health)
            report.row("Power adapter", snapshot.battery.adapterWatts, format: MacFormat.watts)
        }
        report.row("Thermal state", snapshot.system.thermalState, format: MacFormat.thermal)
        report.row("Low Power Mode", snapshot.system.lowPowerMode, format: MacFormat.onOff)

        report.section("Network")
        report.row("Status", network.status, format: MacFormat.networkStatus)
        report.row("Interfaces", network.interfaces, format: MacFormat.interfaces)

        report.section("Catalog")
        report.line("Mac catalog \(spec.catalogVersion ?? "not loaded"), entry \(spec.entryID ?? "none").")
        return report.text
    }

    private struct Report {
        private(set) var text = ""

        mutating func heading(_ title: String) { text += title + "\n" }
        mutating func section(_ title: String) { text += "\n\(title)\n" }
        mutating func line(_ line: String) { text += "  \(line)\n" }

        mutating func row<Value>(_ label: String, _ value: SpecValue<Value>, format: (Value) -> String) {
            let shown = ProvenanceText.value(value, format: format)
            let suffix: String
            switch value {
            case .measured: suffix = " [detected]"
            case .catalog: suffix = " [catalog]"
            case .unavailable, .unknown, .error: suffix = " — \(ProvenanceText.detail(for: value))"
            }
            text += "  \(label): \(shown)\(suffix)\n"
        }

        mutating func row(_ label: String, _ value: SpecValue<String>) {
            row(label, value) { $0 }
        }
    }
}
