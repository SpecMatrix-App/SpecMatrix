//
//  SpecValueRow.swift
//  SpecMatrixMac
//

import AppKit
import SpecMatrixMacCatalog
import SpecMatrixMacPlatform
import SpecMatrixShared
import SwiftUI

/// One labelled value with its source: "Detected" (read from macOS), "Catalog" (published specification),
/// or the reason it is missing. The tooltip names the API or the catalog citation; the value is selectable
/// and the context menu copies it.
struct SpecValueRow<Value: Sendable & Equatable>: View {
    let label: String
    let value: SpecValue<Value>
    let format: (Value) -> String
    @AppStorage(SettingsKey.showSourceBadges) private var showBadges = true

    init(_ label: String, _ value: SpecValue<Value>, format: @escaping (Value) -> String) {
        self.label = label
        self.value = value
        self.format = format
    }

    var body: some View {
        let text = ProvenanceText.value(value, format: format)
        LabeledContent {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(text)
                    .monospacedDigit()
                    .foregroundColor(value.value == nil ? .secondary : .primary)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
                if showBadges {
                    ProvenanceBadge(provenance: value.provenance)
                }
            }
        } label: {
            Text(label)
        }
        .help(ProvenanceText.detail(for: value))
        .contextMenu {
            Button("Copy Value") { Pasteboard.copy(text) }
            Button("Copy “\(label)” and Value") { Pasteboard.copy("\(label): \(text)") }
            Divider()
            Button("Copy Source") { Pasteboard.copy(ProvenanceText.detail(for: value)) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(ProvenanceText.spoken(value, text: text))
        .accessibilityHint(value.value == nil ? ProvenanceText.detail(for: value) : "")
    }
}

enum Pasteboard {
    @MainActor
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

extension SpecValueRow where Value == String {
    init(_ label: String, _ value: SpecValue<String>) {
        self.init(label, value) { $0 }
    }
}

/// The short source label shown after a value.
struct ProvenanceBadge: View {
    let provenance: Provenance

    var body: some View {
        if let title = ProvenanceText.badge(for: provenance) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .overlay { Capsule().strokeBorder(Color(nsColor: .tertiaryLabelColor)) }
                .accessibilityLabel("Source: \(title)")
        }
    }
}

enum ProvenanceText {
    /// The displayed text: the formatted value, or the kind of missing value.
    static func value<Value: Sendable & Equatable>(_ value: SpecValue<Value>, format: (Value) -> String) -> String {
        switch value {
        case .measured(let known, _), .catalog(let known, _): format(known)
        case .unavailable: "Not available"
        case .unknown: "Unknown"
        case .error: "Error"
        }
    }

    /// VoiceOver: the value followed by where it came from.
    static func spoken<Value: Sendable & Equatable>(_ value: SpecValue<Value>, text: String) -> String {
        switch value.provenance {
        case .measured: "\(text), detected"
        case .catalog: "\(text), from the catalog"
        case .unavailable, .unknown, .error: text
        }
    }

    static func badge(for provenance: Provenance) -> String? {
        switch provenance {
        case .measured: "Detected"
        case .catalog: "Catalog"
        case .unavailable, .unknown, .error: nil
        }
    }

    /// The tooltip: where a value came from, or why it is missing.
    static func detail<Value: Sendable & Equatable>(for value: SpecValue<Value>) -> String {
        switch value {
        case .measured(_, let source):
            return "Read from macOS: \(source.api)"
        case .catalog(_, let reference):
            let sources = reference.sources.map(\.title).joined(separator: "; ")
            return "From the SpecMatrix Mac catalog \(reference.catalogVersion), entry \(reference.entryID)"
                + (sources.isEmpty ? "" : ". Sources: \(sources)")
        case .unavailable(let reason):
            return reason.explanation
        case .unknown(let reason):
            return reason
        case .error(let error):
            return error.description
        }
    }
}

/// Text for the value types the app displays.
enum MacFormat {
    static func dateTime(_ value: Date) -> String { value.formatted(date: .abbreviated, time: .standard) }

    /// "8 (4 Performance + 4 Efficiency)", using macOS's own cluster names.
    static func clusterSummary(_ clusters: [MacCoreCluster]) -> String {
        let total = clusters.reduce(0) { $0 + $1.cores }
        guard clusters.count > 1 else { return "\(total)-core" }
        return "\(total)-core (" + clusters.map { "\($0.cores) \($0.name)" }.joined(separator: " + ") + ")"
    }

    static func estimate(_ value: MacBatteryEstimate) -> String {
        switch value {
        case .untilEmpty(let minutes): "\(MacFormat.minutes(minutes)) until empty"
        case .untilFull(let minutes): "\(MacFormat.minutes(minutes)) until full"
        }
    }

    static func verification(_ value: CatalogVerificationStatus) -> String {
        switch value {
        case .verified: "Verified against Apple's published specifications"
        case .secondarySourcesOnly: "Secondary sources only"
        }
    }

    static func matchSummary(_ match: MacConfigurationMatch) -> String {
        switch match {
        case .unresolved(let reason), .noMatch(let reason): reason
        case .notRecorded: "The catalog records no chip configurations for this model."
        case .matched(let candidates) where candidates.count == 1:
            "✓ marks the configuration that matches the chip and CPU cores macOS reports."
        case .matched:
            "✓ marks the configurations consistent with the chip and CPU cores macOS reports. macOS does not report what distinguishes them (usually the GPU core count), so values that differ between them read “Unknown”."
        }
    }

    static func bytesOfMemory(_ value: ByteCount) -> String { SpecFormat.memory(value) }
    static func bytesOfStorage(_ value: ByteCount) -> String { SpecFormat.storage(value) }
    static func percent(_ value: UnitFraction) -> String { SpecFormat.percent(value) }
    static func pixels(_ value: PixelDimensions) -> String { "\(value.width) × \(value.height)" }
    static func points(_ value: PixelDimensions) -> String { "\(value.width) × \(value.height) points" }
    static func diagonal(_ value: DisplayDiagonal) -> String {
        "\(value.inches.formatted(.number.precision(.fractionLength(1)))) in"
    }
    static func density(_ value: PixelDensity) -> String { "\(value.pixelsPerInch) ppi" }
    static func refresh(_ value: RefreshRate) -> String { "\(value.hertz) Hz" }
    static func scale(_ value: Double) -> String { "\(value.formatted(.number.precision(.fractionLength(0...1))))×" }
    static func count(_ value: Int) -> String { value.formatted() }
    static func cores(_ value: Int) -> String { "\(value.formatted())-core" }
    static func kilobytes(_ value: ByteCount) -> String { SpecFormat.memory(value) }
    static func onOff(_ value: Bool) -> String { value ? "On" : "Off" }
    static func supported(_ value: Bool) -> String { value ? "Supported" : "Not supported" }
    static func hertz(_ value: Double) -> String { "\(value.formatted(.number.precision(.fractionLength(0...2)))) Hz" }
    static func degrees(_ value: Int) -> String { value == 0 ? "None" : "\(value)°" }
    static func appleFamily(_ value: Int) -> String { "Apple \(value)" }
    static func watts(_ value: Int) -> String { "\(value) W" }

    static func health(_ value: MacBatteryHealth) -> String {
        switch value {
        case .good: "Good"
        case .fair: "Fair"
        case .poor: "Poor"
        }
    }

    static func networkStatus(_ value: MacNetworkStatus) -> String {
        switch value {
        case .connected: "Connected"
        case .notConnected: "Not connected"
        case .requiresConnection: "Waiting for a connection"
        }
    }

    static func interfaceKind(_ value: MacNetworkInterfaceKind) -> String {
        switch value {
        case .wifi: "Wi-Fi"
        case .wiredEthernet: "Ethernet"
        case .cellular: "Cellular"
        case .loopback: "Loopback"
        case .other: "Other"
        }
    }

    static func interfaces(_ value: [MacNetworkInterface]) -> String {
        value.isEmpty ? "None" : value.map { "\(interfaceKind($0.kind)) (\($0.name))" }.joined(separator: ", ")
    }

    static func clusterKind(_ value: MacCPUClusterKind) -> String {
        switch value {
        case .superTier: "super"
        case .performance: "performance"
        case .efficiency: "efficiency"
        }
    }

    /// "M2 Pro · 12-core CPU (8 performance + 4 efficiency) · 19-core GPU · 16-core Neural Engine".
    static func configuration(_ value: MacChipConfiguration) -> String {
        var parts = [value.chip]
        if let cpu = value.cpuCores {
            let split = value.cpuClusters.map { " (" + $0.map { "\($0.cores) \(clusterKind($0.kind))" }.joined(separator: " + ") + ")" } ?? ""
            parts.append("\(cpu)-core CPU\(split)")
        }
        if let gpu = value.gpuCores { parts.append("\(gpu)-core GPU") }
        if let neural = value.neuralEngineCores { parts.append("\(neural)-core Neural Engine") }
        return parts.joined(separator: " · ")
    }

    /// "Volume (APFS, internal)" style summary used in the report.
    static func volumeKind(_ volume: MacVolumeReading) -> String {
        var parts: [String] = []
        if let format = volume.format.value { parts.append(format) }
        if volume.isLocal.value == false {
            parts.append("network")
        } else if volume.isInternal.value == true {
            parts.append("internal")
        } else if volume.isInternal.value == false {
            parts.append("external")
        }
        if volume.isReadOnly.value == true { parts.append("read-only") }
        return parts.joined(separator: ", ")
    }
    static func yesNo(_ value: Bool) -> String { value ? "Yes" : "No" }

    static func thermal(_ value: ThermalLevel) -> String {
        switch value {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        }
    }

    static func chargeState(_ value: BatteryChargeState) -> String {
        switch value {
        case .unplugged: "Discharging"
        case .charging: "Charging"
        case .full: "Fully charged"
        case .notCharging: "Not charging"
        }
    }

    static func powerSource(_ value: MacPowerSource) -> String {
        switch value {
        case .battery: "Battery"
        case .powerAdapter: "Power adapter"
        }
    }

    static func dynamicRange(_ headroom: Double) -> String {
        headroom > 1 ? "Up to \(headroom.formatted(.number.precision(.fractionLength(0...1))))× standard brightness"
                     : "Standard dynamic range"
    }

    static func minutes(_ value: Int) -> String {
        Duration.seconds(value * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
