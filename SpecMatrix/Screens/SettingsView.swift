//
//  SettingsView.swift
//  SpecMatrix
//

import SwiftUI

/// The Settings tab: appearance, which information each tab shows, and about links.
struct SettingsView: View {
    @Binding var settings: DisplaySettings
    @Binding var selectedTheme: AppTheme

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Appearance", selection: $selectedTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Label(theme.rawValue, systemImage: theme.icon)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Spec Settings") {
                    Toggle(isOn: $settings.showBattery) { Label("Battery Information", systemImage: "battery.100") }
                    Toggle(isOn: $settings.showSystem) { Label("System Information", systemImage: "iphone") }
                    Toggle(isOn: $settings.showCPU) { Label("CPU Information", systemImage: "cpu") }
                    Toggle(isOn: $settings.showGPU) { Label("GPU Information", systemImage: "square.grid.3x3.square") }
                    Toggle(isOn: $settings.showMemory) { Label("Memory Information", systemImage: "memorychip") }
                    Toggle(isOn: $settings.showStorage) { Label("Storage Information", systemImage: "internaldrive") }
                }

                Section("Network Settings") {
                    Toggle(isOn: $settings.showNetwork) { Label("Network Information", systemImage: "network") }
                }

                Section("Display Settings") {
                    Toggle(isOn: $settings.showDisplay) { Label("Display Information", systemImage: "display") }
                }

                Section("Camera Settings") {
                    Toggle(isOn: $settings.showCamera) { Label("Camera Information", systemImage: "camera") }
                }

                Section {
                    Button(action: showAll) {
                        Label("Show All", systemImage: "eye")
                    }
                    Button(role: .destructive, action: hideAll) {
                        Label("Hide All", systemImage: "eye.slash")
                    }
                }

                #if DEBUG
                Section("Developer") {
                    NavigationLink {
                        FoundationDiagnosticsView()
                    } label: {
                        Label("Foundation Diagnostics", systemImage: "stethoscope")
                    }
                }
                #endif

                Section {
                    LabeledContent("Created by", value: "Zachary Aflalo")

                    Link(destination: URL(string: "https://github.com/Belligerently/SpecMatrix")!) {
                        ExternalLinkLabel(title: "GitHub Repository", systemImage: "link")
                    }

                    Link(destination: URL(string: "mailto:spec.matrix.app@gmail.com")!) {
                        ExternalLinkLabel(title: "Contact", systemImage: "envelope", detail: "spec.matrix.app@gmail.com")
                    }

                    Link(destination: URL(string: "https://github.com/Belligerently/SpecMatrix/blob/main/LICENSE")!) {
                        ExternalLinkLabel(title: "Licensed under MIT", systemImage: "doc.text")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
    }

    private func showAll() {
        settings.showBattery = true
        settings.showSystem = true
        settings.showCPU = true
        settings.showGPU = true
        settings.showMemory = true
        settings.showStorage = true
        settings.showNetwork = true
        settings.showDisplay = true
        settings.showCamera = true
    }

    private func hideAll() {
        settings.showBattery = false
        settings.showSystem = false
        settings.showCPU = false
        settings.showGPU = false
        settings.showMemory = false
        settings.showStorage = false
        settings.showNetwork = false
        settings.showDisplay = false
        settings.showCamera = false
    }
}

/// A row that leaves the app: a title, then either a detail (such as the address) or a trailing arrow.
/// At accessibility text sizes the detail moves below the title, where it can wrap instead of being
/// truncated beside it.
private struct ExternalLinkLabel: View {
    let title: String
    let systemImage: String
    var detail: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let detail, dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: systemImage)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        } else {
            row
        }
    }

    private var row: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            if let detail {
                Text(detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }
}
