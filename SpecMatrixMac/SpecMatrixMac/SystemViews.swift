//
//  SystemViews.swift
//  SpecMatrixMac
//

import SpecMatrixMacCatalog
import SpecMatrixMacPlatform
import SpecMatrixShared
import SwiftUI

struct PowerView: View {
    let snapshot: MacSnapshot

    var body: some View {
        let battery = snapshot.battery
        Form {
            if battery.isAbsent {
                Section {
                    Label("This Mac has no internal battery.", systemImage: "powerplug")
                }
            } else {
                Section {
                    SpecValueRow("Charge", battery.level, format: MacFormat.percent)
                    if let level = battery.level.value {
                        ProgressView(value: level.value)
                            .accessibilityHidden(true)
                    }
                    SpecValueRow("State", battery.chargeState, format: MacFormat.chargeState)
                    SpecValueRow("Power source", battery.powerSource, format: MacFormat.powerSource)
                    SpecValueRow("Time remaining", battery.estimate, format: MacFormat.estimate)
                    SpecValueRow("Power adapter", battery.adapterWatts, format: MacFormat.watts)
                } header: {
                    Text("Battery")
                }
                Section {
                    SpecValueRow("Health", battery.health, format: MacFormat.health)
                    SpecValueRow("Service recommendation", battery.healthCondition)
                } header: {
                    Text("Health")
                } footer: {
                    Text("Health is macOS's own summary. Cycle count and maximum capacity are not shown: macOS does not provide them to apps through a public API, and SpecMatrix does not read undocumented sources.")
                }
            }
            Section("System") {
                SpecValueRow("Thermal state", snapshot.system.thermalState, format: MacFormat.thermal)
                SpecValueRow("Low Power Mode", snapshot.system.lowPowerMode, format: MacFormat.onOff)
            }
            Section {
                EmptyView()
            } footer: {
                Text("Battery values update when macOS reports a power-source change. Temperatures, fan speeds and power draw are not available to apps through public APIs.")
            }
            SourcesFooter(collectedAt: snapshot.collectedAt)
        }
        .formStyle(.grouped)
    }
}

struct NetworkView: View {
    let network: MacNetworkReading
    let collectedAt: Date

    var body: some View {
        Form {
            Section("Connection") {
                SpecValueRow("Status", network.status, format: MacFormat.networkStatus)
                SpecValueRow("Low Data Mode", network.isConstrained, format: MacFormat.onOff)
                SpecValueRow("Expensive connection", network.isExpensive, format: MacFormat.yesNo)
            }
            Section("Interfaces") {
                switch network.interfaces {
                case .measured(let interfaces, let source) where !interfaces.isEmpty:
                    ForEach(interfaces, id: \.self) { interface in
                        SpecValueRow(interface.name, SpecValue.measured(interface.kind, source), format: MacFormat.interfaceKind)
                    }
                case .measured:
                    Text("No interface is available.")
                        .foregroundColor(.secondary)
                default:
                    SpecValueRow("Interfaces", network.interfaces) { _ in "" }
                }
            }
            Section {
                SpecValueRow("IPv4", network.supportsIPv4, format: MacFormat.supported)
                SpecValueRow("IPv6", network.supportsIPv6, format: MacFormat.supported)
                SpecValueRow("DNS", network.supportsDNS, format: MacFormat.supported)
            } header: {
                Text("Protocols")
            } footer: {
                Text("Reported by macOS for the current network path; updated as soon as it changes. SpecMatrix makes no network connections and does not read IP addresses or Wi-Fi network names (which would require Location Services permission).")
            }
        }
        .formStyle(.grouped)
    }
}

struct SystemView: View {
    let snapshot: MacSnapshot
    let catalogVersion: String?

    var body: some View {
        let info = snapshot.staticInfo
        Form {
            Section("macOS") {
                SpecValueRow("Version", info.osVersion) { "macOS \($0)" }
                SpecValueRow("Build", info.osBuild)
                SpecValueRow("Darwin kernel", info.kernelRelease)
                SpecValueRow("Architecture", info.architecture)
            }
            Section("Hardware identity") {
                SpecValueRow("Model identifier", info.identifier) { $0.rawValue }
                SpecValueRow("Model", snapshot.specification.marketingName)
            }
            Section {
                LabeledContent("Version", value: "\(AppInfo.version) (\(AppInfo.build))")
                LabeledContent("Mac catalog", value: catalogVersion ?? "Not loaded")
            } header: {
                Text("SpecMatrix")
            } footer: {
                Text("SpecMatrix never reads the serial number, and it collects nothing: there is no analytics, tracking or network access.")
            }
            SourcesFooter(collectedAt: snapshot.collectedAt)
        }
        .formStyle(.grouped)
    }
}

/// The catalog record behind the published values: entry, verification and sources.
struct ModelRecordView: View {
    let snapshot: MacSnapshot
    let catalogError: CatalogLoadError?
    @Environment(\.openURL) private var openURL

    var body: some View {
        let spec = snapshot.specification
        if let catalogError {
            SpecStatusView(title: "Catalog Unavailable", systemImage: "exclamationmark.triangle",
                           message: "The Mac catalog could not be loaded: \(catalogError.description)")
        } else if let entry = spec.entry {
            Form {
                Section("Record") {
                    LabeledContent("Model", value: entry.marketingName)
                    LabeledContent("Model identifiers", value: entry.identifiers.map(\.rawValue).joined(separator: ", "))
                    LabeledContent("Entry", value: entry.id)
                    LabeledContent("Catalog version", value: spec.catalogVersion ?? "–")
                    LabeledContent("Verification", value: MacFormat.verification(entry.verificationStatus))
                    LabeledContent("Verified on", value: entry.verifiedOn.description)
                }
                .textSelection(.enabled)
                ConfigurationSection(specification: spec)
                Section {
                    ForEach(Array(entry.sources.enumerated()), id: \.offset) { _, source in
                        VStack(alignment: .leading, spacing: 2) {
                            if let url = source.url {
                                Button(source.title) { openURL(url) }
                                    .buttonStyle(.link)
                                    .help(url.absoluteString)
                            } else {
                                Text(source.title)
                            }
                            Text("Supports: \(source.supports.sorted().map(\.rawValue).joined(separator: ", ")) · accessed \(source.accessed.description)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("Sources")
                } footer: {
                    Text("Links open in your browser. SpecMatrix itself never contacts these sites.")
                }
            }
            .formStyle(.grouped)
        } else {
            SpecStatusView(title: "Not in the Catalog", systemImage: "questionmark.square.dashed",
                           message: ProvenanceText.detail(for: spec.marketingName)
                               + " Everything SpecMatrix detects from macOS is still shown; published specifications such as GPU core counts read “Unknown”.")
        }
    }
}

/// Explains the source badges and when the values were read.
struct SourcesFooter: View {
    let collectedAt: Date

    var body: some View {
        Section {
            EmptyView()
        } footer: {
            Text("Detected: read from macOS. Catalog: Apple's published specification for this model. Hover over a value for its source or the reason it is missing. Updated \(collectedAt.formatted(date: .omitted, time: .standard)).")
        }
    }
}

/// The badge legend under the dashboard.
struct SourcesLegend: View {
    let collectedAt: Date

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            ProvenanceBadge(provenance: .measured)
            Text("read from macOS")
            ProvenanceBadge(provenance: .catalog)
            Text("Apple's published specification for this model")
            Spacer()
            Text("Updated \(collectedAt.formatted(date: .omitted, time: .standard))")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .accessibilityElement(children: .combine)
    }
}
