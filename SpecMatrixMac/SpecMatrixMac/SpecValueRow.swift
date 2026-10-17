//
//  SpecValueRow.swift
//  SpecMatrixMac
//

import SpecMatrixMacPlatform
import SpecMatrixShared
import SwiftUI

/// One labelled value with its source: "Detected" (read from macOS), "Catalog" (published specification),
/// or the reason it is missing. The tooltip names the API or the catalog citation.
struct SpecValueRow<Value: Sendable & Equatable>: View {
    let label: String
    let value: SpecValue<Value>
    let format: (Value) -> String

    init(_ label: String, _ value: SpecValue<Value>, format: @escaping (Value) -> String) {
        self.label = label
        self.value = value
        self.format = format
    }

    var body: some View {
        LabeledContent {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(valueText)
                    .monospacedDigit()
                    .foregroundColor(value.value == nil ? .secondary : .primary)
                    .textSelection(.enabled)
                ProvenanceBadge(value: value)
            }
        } label: {
            Text(label)
        }
        .help(ProvenanceText.detail(for: value))
    }

    private var valueText: String {
        switch value {
        case .measured(let known, _), .catalog(let known, _): format(known)
        case .unavailable: "Not available"
        case .unknown: "Unknown"
        case .error: "Error"
        }
    }
}

extension SpecValueRow where Value == String {
    init(_ label: String, _ value: SpecValue<String>) {
        self.init(label, value) { $0 }
    }
}

/// The short source label shown after a value.
struct ProvenanceBadge<Value: Sendable & Equatable>: View {
    let value: SpecValue<Value>

    var body: some View {
        if let title = ProvenanceText.badge(for: value.provenance) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .overlay { Capsule().strokeBorder(.tertiary) }
                .accessibilityLabel("Source: \(title)")
        }
    }
}

enum ProvenanceText {
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
