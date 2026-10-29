//
//  HardwareViews.swift
//  SpecMatrixMac
//

import SpecMatrixMacCatalog
import SpecMatrixMacPlatform
import SpecMatrixShared
import SwiftUI

struct ProcessorView: View {
    let snapshot: MacSnapshot

    var body: some View {
        let info = snapshot.staticInfo
        let spec = snapshot.specification
        Form {
            Section("Chip") {
                SpecValueRow("Chip", info.chipName)
                SpecValueRow("Chip in the catalog", spec.catalogChipName)
                SpecValueRow("Architecture", info.architecture)
                SpecValueRow("Apple silicon", info.isAppleSilicon, format: MacFormat.yesNo)
                SpecValueRow("Neural Engine", spec.neuralEngineCores, format: MacFormat.cores)
            }
            Section {
                SpecValueRow("CPU cores", info.physicalCores, format: MacFormat.count)
                SpecValueRow("Logical processors", info.logicalCores, format: MacFormat.count)
                switch info.coreClusters {
                case .measured(let clusters, _):
                    ForEach(clusters, id: \.self) { cluster in
                        SpecValueRow("\(cluster.name) cores", info.coreClusters.map { _ in cluster.cores }, format: MacFormat.count)
                    }
                default:
                    SpecValueRow("Core types", info.coreClusters) { _ in "" }
                }
            } header: {
                Text("CPU")
            } footer: {
                Text("Cluster names are the ones macOS reports. Apple silicon has one logical processor per core.")
            }
            if case .measured(let clusters, _) = info.coreClusters, clusters.contains(where: { $0.l2Cache != nil }) {
                ForEach(clusters, id: \.self) { cluster in
                    Section("\(cluster.name) cluster caches") {
                        let measured = { (value: ByteCount?) -> SpecValue<ByteCount> in
                            value.map { .measured($0, MeasurementSource(api: "sysctl hw.perflevelN cache sizes", environment: .device)) }
                                ?? .unknown("macOS did not report this cache size.")
                        }
                        SpecValueRow("L1 instruction cache (per core)", measured(cluster.l1InstructionCache), format: MacFormat.kilobytes)
                        SpecValueRow("L1 data cache (per core)", measured(cluster.l1DataCache), format: MacFormat.kilobytes)
                        SpecValueRow("L2 cache", measured(cluster.l2Cache), format: MacFormat.kilobytes)
                        if let perL2 = cluster.coresPerL2 {
                            SpecValueRow("Cores sharing each L2", SpecValue<Int>.measured(
                                perL2, MeasurementSource(api: "sysctl hw.perflevelN.cpusperl2", environment: .device)), format: MacFormat.count)
                        }
                    }
                }
            }
            ConfigurationSection(specification: spec)
            SourcesFooter(collectedAt: snapshot.collectedAt)
        }
        .formStyle(.grouped)
    }
}

/// The published configurations for this model, with the ones consistent with this Mac marked.
struct ConfigurationSection: View {
    let specification: MacSpecification

    var body: some View {
        if let entry = specification.entry, !entry.configurations.isEmpty {
            let candidates = specification.configurationMatch.candidates
            Section {
                ForEach(Array(entry.configurations.enumerated()), id: \.offset) { _, configuration in
                    let matches = candidates.contains(configuration)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: matches ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(matches ? .accentColor : .secondary)
                            .accessibilityHidden(true)
                        Text(MacFormat.configuration(configuration))
                            .textSelection(.enabled)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(matches ? "Matches this Mac" : "")
                }
            } header: {
                Text("Configurations Apple publishes for \(entry.marketingName)")
            } footer: {
                Text(MacFormat.matchSummary(specification.configurationMatch))
            }
        }
    }
}

struct GraphicsView: View {
    let snapshot: MacSnapshot

    var body: some View {
        let info = snapshot.staticInfo
        let gpu = info.gpuCapabilities
        Form {
            Section("GPU") {
                SpecValueRow("GPU", info.gpuName)
                SpecValueRow("GPU cores", snapshot.specification.gpuCores, format: MacFormat.cores)
                SpecValueRow("Unified memory", info.hasUnifiedMemory, format: MacFormat.yesNo)
                SpecValueRow("Recommended working set", info.gpuRecommendedWorkingSet, format: MacFormat.bytesOfMemory)
            }
            Section {
                SpecValueRow("Apple GPU family", gpu.appleFamily, format: MacFormat.appleFamily)
                SpecValueRow("Metal 3", info.supportsMetal3, format: MacFormat.supported)
                SpecValueRow("Metal 4", gpu.supportsMetal4, format: MacFormat.supported)
                SpecValueRow("Hardware ray tracing", gpu.supportsRaytracing, format: MacFormat.supported)
                SpecValueRow("Largest buffer", gpu.maximumBufferLength, format: MacFormat.bytesOfMemory)
                SpecValueRow("Threads per threadgroup", gpu.maximumThreadsPerThreadgroup, format: MacFormat.count)
            } header: {
                Text("Metal")
            } footer: {
                Text("GPU core counts come from the catalog: macOS does not report them through a public API. When Apple sells the same chip with different GPU core counts, the value stays unknown.")
            }
            SourcesFooter(collectedAt: snapshot.collectedAt)
        }
        .formStyle(.grouped)
    }
}

struct MemoryView: View {
    let snapshot: MacSnapshot
    @ObservedObject var store: MacInfoStore

    var body: some View {
        let memory = snapshot.memory
        Form {
            Section {
                SpecValueRow("Installed memory", snapshot.staticInfo.physicalMemory, format: MacFormat.bytesOfMemory)
                SpecValueRow("Unified with the GPU", snapshot.staticInfo.hasUnifiedMemory, format: MacFormat.yesNo)
            } footer: {
                Text("Memory is shown in binary units, as macOS reports it.")
            }
            Section {
                if let segments = MemoryBar.segments(memory) {
                    MemoryBar(segments: segments)
                }
                SpecValueRow("Wired", memory.wired, format: MacFormat.bytesOfMemory)
                SpecValueRow("Active", memory.active, format: MacFormat.bytesOfMemory)
                SpecValueRow("Inactive", memory.inactive, format: MacFormat.bytesOfMemory)
                SpecValueRow("Compressed", memory.compressed, format: MacFormat.bytesOfMemory)
                SpecValueRow("Free", memory.free, format: MacFormat.bytesOfMemory)
            } header: {
                Text("Current use")
            } footer: {
                Text("Kernel page counts (host_statistics64), updated every 5 seconds while this pane is open. They are not the same categories as Activity Monitor's “Memory Used”. “Compressed” is the space the compressor occupies.")
            }
            Section("Swap") {
                SpecValueRow("Swap used", memory.swapUsed, format: MacFormat.bytesOfMemory)
                SpecValueRow("Swap size", memory.swapTotal, format: MacFormat.bytesOfMemory)
            }
            SourcesFooter(collectedAt: snapshot.collectedAt)
        }
        .formStyle(.grouped)
        .onAppear { store.setLiveMemory(true) }
        .onDisappear { store.setLiveMemory(false) }
    }
}

/// A stacked bar of measured memory categories. Shown only when every category was measured.
struct MemoryBar: View {
    struct Segment: Identifiable {
        let id: String
        let bytes: Int64
        let color: Color
    }

    let segments: [Segment]

    static func segments(_ memory: MacMemoryReading) -> [Segment]? {
        let parts: [(String, SpecValue<ByteCount>, Color)] = [
            ("Wired", memory.wired, .orange), ("Active", memory.active, .accentColor),
            ("Inactive", memory.inactive, .teal), ("Compressed", memory.compressed, .purple),
            ("Free", memory.free, Color(nsColor: .quaternaryLabelColor)),
        ]
        let segments = parts.compactMap { name, value, color in value.value.map { Segment(id: name, bytes: $0.bytes, color: color) } }
        return segments.count == parts.count && segments.contains { $0.bytes > 0 } ? segments : nil
    }

    var body: some View {
        let total = max(segments.reduce(0) { $0 + $1.bytes }, 1)
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                HStack(spacing: 1) {
                    ForEach(segments) { segment in
                        segment.color
                            .frame(width: max(0, proxy.size.width * CGFloat(segment.bytes) / CGFloat(total) - 1))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            HStack(spacing: 12) {
                ForEach(segments) { segment in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(segment.color).frame(width: 10, height: 10)
                        Text(segment.id).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }
}
