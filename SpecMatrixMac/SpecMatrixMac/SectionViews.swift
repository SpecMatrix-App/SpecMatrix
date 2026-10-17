//
//  SectionViews.swift
//  SpecMatrixMac
//

import SpecMatrixMacPlatform
import SpecMatrixShared
import SwiftUI

/// The model, its key specifications and the system state.
struct OverviewSection: View {
    let snapshot: MacSnapshot
    let catalogError: CatalogLoadError?

    var body: some View {
        let info = snapshot.staticInfo
        let spec = snapshot.specification
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(spec.marketingName.value ?? "Unidentified Mac")
                        .font(.title2.weight(.semibold))
                    Text([info.identifier.value?.rawValue, info.chipName.value].compactMap { $0 }.joined(separator: " · "))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
            Section("Identity") {
                SpecValueRow("Model", spec.marketingName)
                SpecValueRow("Model identifier", info.identifier) { $0.rawValue }
                SpecValueRow("Chip", info.chipName)
                SpecValueRow("Apple silicon", info.isAppleSilicon, format: MacFormat.yesNo)
                SpecValueRow("Memory", info.physicalMemory, format: MacFormat.bytesOfMemory)
                SpecValueRow("macOS", info.osVersion) { "\($0)" }
                SpecValueRow("macOS build", info.osBuild)
            }
            Section("System state") {
                SpecValueRow("Thermal state", snapshot.system.thermalState, format: MacFormat.thermal)
                SpecValueRow("Low Power Mode", snapshot.system.lowPowerMode) { $0 ? "On" : "Off" }
            }
            if let catalogError {
                Section("Mac catalog") {
                    Label("The Mac catalog could not be loaded, so published specifications are not shown.",
                          systemImage: "exclamationmark.triangle")
                        .help(catalogError.description)
                }
            }
            SourcesFooter(collectedAt: snapshot.collectedAt)
        }
    }
}

struct ProcessorSection: View {
    let snapshot: MacSnapshot

    var body: some View {
        let info = snapshot.staticInfo
        Form {
            Section("Chip") {
                SpecValueRow("Chip", info.chipName)
                SpecValueRow("Chip in the catalog", snapshot.specification.catalogChipName)
            }
            Section("CPU") {
                SpecValueRow("CPU cores", info.logicalCores, format: MacFormat.count)
                switch info.coreClusters {
                case .measured(let clusters, _):
                    ForEach(clusters, id: \.self) { cluster in
                        SpecValueRow("\(cluster.name) cores", info.coreClusters.map { _ in cluster.cores }, format: MacFormat.count)
                    }
                default:
                    SpecValueRow("Core types", info.coreClusters) { _ in "" }
                }
            }
            Section("Neural Engine") {
                SpecValueRow("Neural Engine", snapshot.specification.neuralEngineCores, format: MacFormat.cores)
            }
            SourcesFooter(collectedAt: snapshot.collectedAt)
        }
    }
}

struct GraphicsSection: View {
    let snapshot: MacSnapshot

    var body: some View {
        let info = snapshot.staticInfo
        Form {
            Section("GPU") {
                SpecValueRow("GPU", info.gpuName)
                SpecValueRow("GPU cores", snapshot.specification.gpuCores, format: MacFormat.cores)
                SpecValueRow("Unified memory", info.hasUnifiedMemory, format: MacFormat.yesNo)
                SpecValueRow("Metal 3", info.supportsMetal3) { $0 ? "Supported" : "Not supported" }
                SpecValueRow("Recommended working set", info.gpuRecommendedWorkingSet, format: MacFormat.bytesOfMemory)
            }
            SourcesFooter(collectedAt: snapshot.collectedAt)
        }
    }
}

struct MemorySection: View {
    let snapshot: MacSnapshot

    var body: some View {
        Form {
            Section {
                SpecValueRow("Installed memory", snapshot.staticInfo.physicalMemory, format: MacFormat.bytesOfMemory)
                SpecValueRow("Unified with the GPU", snapshot.staticInfo.hasUnifiedMemory, format: MacFormat.yesNo)
            } footer: {
                Text("Memory is shown in binary units, as macOS reports it.")
            }
            SourcesFooter(collectedAt: snapshot.collectedAt)
        }
    }
}

struct StorageSection: View {
    let snapshot: MacSnapshot

    var body: some View {
        let storage = snapshot.storage
        Form {
            Section {
                SpecValueRow("Volume", storage.volumeName)
                SpecValueRow("Capacity", storage.capacity, format: MacFormat.bytesOfStorage)
                SpecValueRow("Available", storage.availableForImportantUsage, format: MacFormat.bytesOfStorage)
                SpecValueRow("Used", storage.usedFraction, format: MacFormat.percent)
                if let used = storage.usedFraction.value {
                    ProgressView(value: used.value)
                        .accessibilityHidden(true)
                }
            } header: {
                Text("Startup disk")
            } footer: {
                Text("Storage is shown in decimal units, as Apple advertises it. \"Available\" includes space macOS can free up on demand. Other volumes are not shown.")
            }
            SourcesFooter(collectedAt: snapshot.collectedAt)
        }
    }
}

struct BatterySection: View {
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
                    SpecValueRow("Time remaining", battery.estimate) { estimate in
                        switch estimate {
                        case .untilEmpty(let minutes): "\(MacFormat.minutes(minutes)) until empty"
                        case .untilFull(let minutes): "\(MacFormat.minutes(minutes)) until full"
                        }
                    }
                } footer: {
                    Text("Battery health and cycle count are not shown: macOS does not provide cycle count through a public API.")
                }
            }
            SourcesFooter(collectedAt: snapshot.collectedAt)
        }
    }
}

struct DisplaysSection: View {
    let snapshot: MacSnapshot

    var body: some View {
        let spec = snapshot.specification
        Form {
            if snapshot.displays.isEmpty {
                Section {
                    Label("macOS reported no connected displays.", systemImage: "display")
                }
            }
            ForEach(snapshot.displays) { display in
                Section {
                    SpecValueRow("Resolution", display.resolution, format: MacFormat.pixels)
                    SpecValueRow("Looks like", display.pointSize, format: MacFormat.points)
                    SpecValueRow("Scale", display.scale, format: MacFormat.scale)
                    SpecValueRow("Maximum refresh rate", display.maximumRefreshRate, format: MacFormat.refresh)
                    SpecValueRow("Size (reported by the display)", display.diagonal, format: MacFormat.diagonal)
                    SpecValueRow("Dynamic range", display.extendedDynamicRangeHeadroom, format: MacFormat.dynamicRange)
                    if display.isBuiltIn.value == true {
                        SpecValueRow("Published size", spec.builtInDisplayDiagonal, format: MacFormat.diagonal)
                        SpecValueRow("Published resolution", spec.builtInDisplayResolution, format: MacFormat.pixels)
                        SpecValueRow("Published pixel density", spec.builtInDisplayPixelDensity, format: MacFormat.density)
                        SpecValueRow("Published refresh rate", spec.builtInDisplayMaximumRefreshRate, format: MacFormat.refresh)
                    }
                } header: {
                    Text(displayTitle(display))
                }
            }
            SourcesFooter(collectedAt: snapshot.collectedAt)
        }
    }

    private func displayTitle(_ display: MacDisplayReading) -> String {
        let name = display.name.value ?? "Display"
        return display.isBuiltIn.value == true ? "\(name) (built-in)" : name
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
