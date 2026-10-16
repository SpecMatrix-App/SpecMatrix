//
//  SpecsScreen.swift
//  SpecMatrix
//

import SwiftUI

/// The Specs tab: battery, system, GPU, CPU, memory and storage, each hideable in Settings.
struct SpecsScreen: View {
    let settings: DisplaySettings
    let storageInfo: StorageInfo
    let iOSInfo: String
    let gpuInfo: GPUInfo
    private let device = CatalogDeviceInfo.current()

    private var showsAnything: Bool {
        settings.showBattery || settings.showSystem || settings.showGPU
            || settings.showCPU || settings.showMemory || settings.showStorage
    }

    var body: some View {
        SpecScreen(
            title: "Device Specs",
            subtitle: device.modelName,
            hiddenNotice: showsAnything ? nil : HiddenNotice(title: "Specifications Hidden")
        ) {
            if settings.showBattery {
                BatteryInfoView()
            }
            if settings.showSystem {
                SystemInfoView(iOSInfo: iOSInfo, deviceModel: device.modelName)
            }
            if settings.showGPU {
                GPUInfoView(gpuInfo: gpuInfo)
            }
            if settings.showCPU {
                CPUInfoView(device: device)
            }
            if settings.showMemory {
                MemoryInfoView()
            }
            if settings.showStorage {
                StorageInfoView(storageInfo: storageInfo)
            }
        }
    }
}

/// Owns its monitor, so battery notifications only re-render this section.
struct BatteryInfoView: View {
    @StateObject private var monitor = BatteryMonitor()
    @State private var showingSettingsGuide = false

    var body: some View {
        let batteryInfo = monitor.batteryInfo
        SpecSection(
            title: "Battery Status",
            systemImage: batteryInfo.stateIcon,
            symbolColor: batteryInfo.stateColor,
            footer: "Battery level readings are approximate."
        ) {
            SpecRow(label: "Status", value: batteryInfo.stateDescription)
            SpecRow(label: "Level", value: batteryInfo.levelDescription)
            Button {
                showingSettingsGuide = true
            } label: {
                SpecRow(label: "Health", value: batteryInfo.healthDescription,
                        accessorySystemImage: "info.circle", isSelectable: false)
            }
            .accessibilityHint("Shows how to find battery health in Settings")
        }
        // Apple offers no documented link to the Battery page in Settings, so the alert only explains the steps.
        .alert("Battery Health", isPresented: $showingSettingsGuide) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("To view battery health:\n1. Open Settings\n2. Tap Battery\n3. Tap Battery Health")
        }
    }
}

struct SystemInfoView: View {
    let iOSInfo: String
    let deviceModel: String

    var body: some View {
        SpecSection(title: "System Information", systemImage: "iphone") {
            SpecRow(label: "Model", value: deviceModel)
            SpecRow(label: "iOS", value: iOSInfo)
        }
    }
}

struct CPUInfoView: View {
    let device: CatalogDeviceInfo

    var body: some View {
        SpecSection(title: "CPU Information", systemImage: "cpu") {
            SpecRow(label: "Chip", value: device.chipName)
            SpecRow(label: "CPU Cores", value: device.cpuCores)
            SpecRow(label: "Performance Cores", value: device.performanceCores)
            SpecRow(label: "Efficiency Cores", value: device.efficiencyCores)
            SpecRow(label: "GPU Cores", value: device.gpuCores)
            SpecRow(label: "Neural Engine", value: device.neuralEngineCores)
        }
    }
}

struct GPUInfoView: View {
    let gpuInfo: GPUInfo

    var body: some View {
        SpecSection(title: "GPU Information", systemImage: "square.grid.3x3.square") {
            SpecRow(label: "Name", value: gpuInfo.name)
            SpecRow(label: "Cores", value: gpuInfo.cores)
            SpecRow(label: "Metal Support", value: gpuInfo.metalSupported ? "Yes" : "No")
        }
    }
}

/// Owns its monitor, so the frequent memory samples only re-render this section,
/// and sampling stops while the section is hidden.
struct MemoryInfoView: View {
    @StateObject private var monitor = MemoryMonitor()

    var body: some View {
        let memoryInfo = monitor.memoryInfo
        SpecSection(title: "Memory Information", systemImage: "memorychip") {
            SpecRow(label: "Total RAM", value: memoryInfo.formattedTotal)
            SpecRow(label: "Used RAM", value: memoryInfo.formattedUsed)
            SpecRow(label: "Usage", value: String(format: "%.1f%%", memoryInfo.usagePercentage))
        }
    }
}

struct StorageInfoView: View {
    let storageInfo: StorageInfo

    var body: some View {
        SpecSection(title: "Storage Information", systemImage: "internaldrive") {
            SpecRow(label: "Total Storage", value: storageInfo.formattedTotal)
            SpecRow(label: "Used Storage", value: storageInfo.formattedUsed)
            SpecRow(label: "Available", value: storageInfo.formattedFree)
            SpecRow(label: "Usage", value: String(format: "%.1f%%", storageInfo.usagePercentage))
        }
    }
}
