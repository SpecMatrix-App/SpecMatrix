//
//  OverviewView.swift
//  SpecMatrixMac
//

import SpecMatrixMacPlatform
import SpecMatrixShared
import SwiftUI

/// The dashboard: the model and a card per area. Each card opens its section.
struct OverviewView: View {
    let snapshot: MacSnapshot
    let network: MacNetworkReading
    let catalogError: CatalogLoadError?
    @ObservedObject var navigation: NavigationModel
    @AppStorage(SettingsKey.hiddenSections) private var hiddenSectionsRaw = ""

    private var info: MacStaticInfo { snapshot.staticInfo }
    private var spec: MacSpecification { snapshot.specification }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let catalogError {
                    Label("The Mac catalog could not be loaded, so published specifications are not shown.",
                          systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .help(catalogError.description)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16, alignment: .top)],
                          alignment: .leading, spacing: 16) {
                    ForEach(cards, id: \.section) { card in card }
                }
                SourcesLegend(collectedAt: snapshot.collectedAt)
            }
            .padding(24)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: modelSymbol)
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(spec.marketingName.value ?? "Unidentified Mac")
                    .font(.largeTitle.weight(.semibold))
                    .textSelection(.enabled)
                    .help(ProvenanceText.detail(for: spec.marketingName))
                HStack(spacing: 8) {
                    ForEach(headerFacts, id: \.self) { fact in
                        Text(fact)
                            .font(.callout.monospacedDigit())
                            .textSelection(.enabled)
                            .specCapsuleBackground()
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var headerFacts: [String] {
        [info.identifier.value?.rawValue, info.chipName.value, info.physicalMemory.value.map { "\(MacFormat.bytesOfMemory($0)) memory" },
         info.osVersion.value.map { "macOS \($0)" }].compactMap { $0 }
    }

    /// A generic symbol for the model's family; the identifier family does not distinguish laptops from desktops
    /// for `Mac` identifiers, so the catalog name is used when available.
    private var modelSymbol: String {
        let name = spec.marketingName.value ?? ""
        if name.hasPrefix("MacBook") { return "laptopcomputer" }
        if name.hasPrefix("iMac") { return "desktopcomputer" }
        if name.hasPrefix("Mac mini") { return "macmini" }
        if name.hasPrefix("Mac Studio") { return "macstudio" }
        if name.hasPrefix("Mac Pro") { return "macpro.gen3" }
        return "desktopcomputer"
    }

    private var hidden: HiddenSections { HiddenSections(rawValue: hiddenSectionsRaw) }

    private var cards: [DashboardCard] {
        let all: [DashboardCard] = [
            DashboardCard(section: .processor, navigation: navigation, rows: [
                .init("Chip", info.chipName.map { $0 }),
                .init("CPU", info.coreClusters.map { MacFormat.clusterSummary($0) }),
                .init("GPU cores", spec.gpuCores.map(MacFormat.cores)),
                .init("Neural Engine", spec.neuralEngineCores.map(MacFormat.cores)),
            ]),
            DashboardCard(section: .memory, navigation: navigation, rows: [
                .init("Installed", info.physicalMemory.map(MacFormat.bytesOfMemory)),
                .init("Compressed", snapshot.memory.compressed.map(MacFormat.bytesOfMemory)),
                .init("Swap used", snapshot.memory.swapUsed.map(MacFormat.bytesOfMemory)),
            ]),
            DashboardCard(section: .storage, navigation: navigation, rows: [
                .init("Startup disk", snapshot.storage.volumeName),
                .init("Available", snapshot.storage.availableForImportantUsage.map(MacFormat.bytesOfStorage)),
                .init("Capacity", snapshot.storage.capacity.map(MacFormat.bytesOfStorage)),
            ], gauge: snapshot.storage.usedFraction.value?.value),
            DashboardCard(section: .displays, navigation: navigation, rows: displayRows),
            DashboardCard(section: .power, navigation: navigation, rows: powerRows,
                          gauge: snapshot.battery.level.value?.value),
            DashboardCard(section: .network, navigation: navigation, rows: [
                .init("Status", network.status.map(MacFormat.networkStatus)),
                .init("Interfaces", network.interfaces.map(MacFormat.interfaces)),
            ]),
            DashboardCard(section: .graphics, navigation: navigation, rows: [
                .init("GPU", info.gpuName),
                .init("Metal family", info.gpuCapabilities.appleFamily.map(MacFormat.appleFamily)),
                .init("Ray tracing", info.gpuCapabilities.supportsRaytracing.map(MacFormat.supported)),
            ]),
            DashboardCard(section: .system, navigation: navigation, rows: [
                .init("macOS", info.osVersion.map { "\($0)" }),
                .init("Build", info.osBuild),
                .init("Thermal state", snapshot.system.thermalState.map(MacFormat.thermal)),
            ]),
        ]
        return all.filter { !hidden.contains($0.section) }
    }

    private var displayRows: [DashboardCard.Row] {
        guard !snapshot.displays.isEmpty else {
            return [.init("Displays", SpecValue<String>.unknown("macOS reported no connected displays."))]
        }
        let main = snapshot.displays.first { $0.isMain.value == true } ?? snapshot.displays[0]
        return [
            .init("Connected", .measured("\(snapshot.displays.count)", MeasurementSource(api: "NSScreen.screens", environment: .device))),
            .init("Main display", main.name),
            .init("Resolution", main.resolution.map(MacFormat.pixels)),
            .init("Refresh rate", main.maximumRefreshRate.map(MacFormat.refresh)),
        ]
    }

    private var powerRows: [DashboardCard.Row] {
        let battery = snapshot.battery
        if battery.isAbsent {
            return [
                .init("Battery", SpecValue<String>.unavailable(.notSupportedByHardware)),
                .init("Low Power Mode", snapshot.system.lowPowerMode.map(MacFormat.onOff)),
            ]
        }
        return [
            .init("Charge", battery.level.map(MacFormat.percent)),
            .init("State", battery.chargeState.map(MacFormat.chargeState)),
            .init("Health", battery.health.map(MacFormat.health)),
        ]
    }
}

/// A summary card on the dashboard. The whole card is a button that opens its section.
struct DashboardCard: View {
    struct Row {
        let label: String
        let value: SpecValue<String>

        init(_ label: String, _ value: SpecValue<String>) {
            self.label = label
            self.value = value
        }
    }

    let section: MacSection
    @ObservedObject var navigation: NavigationModel
    let rows: [Row]
    var gauge: Double?
    @AppStorage(SettingsKey.showSourceBadges) private var showBadges = true

    var body: some View {
        Button {
            navigation.selection = section
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(section.title, systemImage: section.systemImage)
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
                if let gauge {
                    ProgressView(value: gauge)
                        .accessibilityHidden(true)
                }
                ForEach(rows, id: \.label) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.label)
                            .foregroundColor(.secondary)
                        Spacer(minLength: 12)
                        Text(ProvenanceText.value(row.value) { $0 })
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(row.value.value == nil ? .secondary : .primary)
                        if showBadges, row.value.value != nil {
                            ProvenanceBadge(provenance: row.value.provenance)
                        }
                    }
                    .help(ProvenanceText.detail(for: row.value))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .specCardBackground()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows \(section.title)")
    }
}
