//
//  StorageDisplayViews.swift
//  SpecMatrixMac
//

import SpecMatrixMacPlatform
import SpecMatrixShared
import SwiftUI

struct StorageView: View {
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
                Text("Storage is shown in decimal units, as Apple advertises it. “Available” includes space macOS can free up on demand.")
            }
            switch snapshot.volumes {
            case .measured(let volumes, _):
                let others = volumes.filter { $0.isStartup.value != true }
                if others.isEmpty {
                    Section("Other volumes") {
                        Text("No other volumes are mounted.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(others) { volume in
                        Section {
                            SpecValueRow("Format", volume.format)
                            SpecValueRow("Location", volume.isLocal.map { local in
                                local ? (volume.isInternal.value == true ? "Internal" : "External") : "Network"
                            })
                            SpecValueRow("Mount point", SpecValue<String>.measured(volume.id, MeasurementSource(
                                api: "FileManager.mountedVolumeURLs", environment: .device)))
                            SpecValueRow("Capacity", volume.capacity, format: MacFormat.bytesOfStorage)
                            SpecValueRow("Available", volume.available, format: MacFormat.bytesOfStorage)
                            SpecValueRow("Used", volume.usedFraction, format: MacFormat.percent)
                            SpecValueRow("Read-only", volume.isReadOnly, format: MacFormat.yesNo)
                            SpecValueRow("Ejectable", volume.isEjectable, format: MacFormat.yesNo)
                        } header: {
                            Text(volume.name.value ?? volume.id)
                        }
                    }
                }
            default:
                Section("Other volumes") {
                    SpecValueRow("Volumes", snapshot.volumes) { _ in "" }
                }
            }
            Section {
                EmptyView()
            } footer: {
                Text("Volumes update when a disk is mounted, ejected or renamed. Some volumes, such as network shares, may not report every value inside the App Sandbox; those values read “Unknown” or “Error”.")
            }
            SourcesFooter(collectedAt: snapshot.collectedAt)
        }
        .formStyle(.grouped)
    }
}

struct DisplaysView: View {
    let snapshot: MacSnapshot

    var body: some View {
        let spec = snapshot.specification
        if snapshot.displays.isEmpty {
            SpecStatusView(title: "No Displays", systemImage: "display.trianglebadge.exclamationmark",
                           message: "macOS reported no connected displays.")
        } else {
            Form {
                ForEach(snapshot.displays) { display in
                    Section {
                        SpecValueRow("Resolution", display.resolution, format: MacFormat.pixels)
                        SpecValueRow("Looks like", display.pointSize, format: MacFormat.points)
                        SpecValueRow("Scale", display.scale, format: MacFormat.scale)
                        SpecValueRow("Largest available mode", display.largestModeResolution, format: MacFormat.pixels)
                        SpecValueRow("Maximum refresh rate", display.maximumRefreshRate, format: MacFormat.refresh)
                        SpecValueRow("Current mode refresh rate", display.currentRefreshRate, format: MacFormat.hertz)
                        SpecValueRow("Size (reported by the display)", display.diagonal, format: MacFormat.diagonal)
                        SpecValueRow("Dynamic range", display.extendedDynamicRangeHeadroom, format: MacFormat.dynamicRange)
                        SpecValueRow("Color profile", display.colorSpace)
                        SpecValueRow("Main display", display.isMain, format: MacFormat.yesNo)
                        SpecValueRow("Mirrored", display.isMirrored, format: MacFormat.yesNo)
                        SpecValueRow("Rotation", display.rotation, format: MacFormat.degrees)
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
                Section {
                    EmptyView()
                } footer: {
                    Text("“Looks like” is the desktop size in points. A display's own size is derived from the physical dimensions it reports and may be approximate for external displays. “Published” values are Apple's specifications for this model's built-in display.")
                }
                SourcesFooter(collectedAt: snapshot.collectedAt)
            }
            .formStyle(.grouped)
        }
    }

    private func displayTitle(_ display: MacDisplayReading) -> String {
        let name = display.name.value ?? "Display"
        return display.isBuiltIn.value == true ? "\(name) (built-in)" : name
    }
}
