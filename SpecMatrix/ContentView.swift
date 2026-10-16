//
//  ContentView.swift
//  SpecMatrix
//
//  Created by Zachary Aflalo on 2025-01-02.
//

import SwiftUI
import Foundation
import Network
import CoreTelephony
import Darwin

extension UIDevice {
    static func modelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        #if targetEnvironment(simulator)
        return ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? identifier
        #else
        return identifier
        #endif
    }
}

// Add GPU info structure
struct GPUInfo {
    let name: String
    let cores: Int
    let metalSupported: Bool
    let metalVersion: String
    
    static func getInfo(for model: String) -> GPUInfo {
        let identifier = UIDevice.modelIdentifier()
        print("DEBUG - GPU Check - Device Identifier:", identifier)
        
        switch identifier {
        case "iPhone17,1": // iPhone 16 Pro
            return GPUInfo(
                name: "Apple A18 Pro GPU",
                cores: 6,
                metalSupported: true,
                metalVersion: "Metal 3"
            )
        case "iPhone17,2": // iPhone 16 Pro Max
            return GPUInfo(
                name: "Apple A18 Pro GPU",
                cores: 6,
                metalSupported: true,
                metalVersion: "Metal 3"
            )
        case "iPhone17,3", "iPhone17,4": // iPhone 16, 16 Plus
            return GPUInfo(
                name: "Apple A18 GPU",
                cores: 6,
                metalSupported: true,
                metalVersion: "Metal 3"
            )
        case "iPhone16,1": // iPhone 15 Pro
            return GPUInfo(
                name: "Apple A17 Pro GPU",
                cores: 6,
                metalSupported: true,
                metalVersion: "Metal 3"
            )
        case "iPhone16,2": // iPhone 15 Plus
            return GPUInfo(
                name: "Apple A16 GPU",
                cores: 5,
                metalSupported: true,
                metalVersion: "Metal 3"
            )
        case "iPhone16,3": // iPhone 15 Pro
            return GPUInfo(
                name: "Apple A17 Pro GPU",
                cores: 6,
                metalSupported: true,
                metalVersion: "Metal 3"
            )
        case "iPhone16,4": // iPhone 15 Pro Max
            return GPUInfo(
                name: "Apple A17 Pro GPU",
                cores: 6,
                metalSupported: true,
                metalVersion: "Metal 3"
            )
        case "iPhone15,4", "iPhone15,5": // iPhone 15 Pro, Pro Max
            return GPUInfo(
                name: "Apple A17 Pro GPU",
                cores: 6,
                metalSupported: true,
                metalVersion: "Metal 3"
            )
        case "iPhone15,2", "iPhone15,3": // iPhone 15, 15 Plus
            return GPUInfo(
                name: "Apple A16 GPU",
                cores: 5,
                metalSupported: true,
                metalVersion: "Metal 3"
            )
        case "iPhone14,7", "iPhone14,8": // iPhone 14, 14 Plus
            return GPUInfo(
                name: "Apple A15 GPU",
                cores: 5,
                metalSupported: true,
                metalVersion: "Metal 3"
            )
        case "iPhone14,4", "iPhone14,5": // iPhone 14 Pro, Pro Max
            return GPUInfo(
                name: "Apple A16 GPU",
                cores: 5,
                metalSupported: true,
                metalVersion: "Metal 3"
            )
        case "iPhone13,1", "iPhone13,2": // iPhone 13, 13 mini
            return GPUInfo(
                name: "Apple A15 GPU",
                cores: 4,
                metalSupported: true,
                metalVersion: "Metal 3"
            )
        case "iPhone13,3", "iPhone13,4": // iPhone 13 Pro, Pro Max
            return GPUInfo(
                name: "Apple A15 GPU",
                cores: 5,
                metalSupported: true,
                metalVersion: "Metal 3"
            )
        default:
            print("DEBUG - GPU: Unrecognized device:", identifier)
            return GPUInfo(
                name: "Apple GPU",
                cores: 4,
                metalSupported: true,
                metalVersion: "Metal 3"
            )
        }
    }
}

// Add battery info structure
struct BatteryInfo {
    let level: Float
    let state: UIDevice.BatteryState
    let health: Int
    
    var stateDescription: String {
        switch state {
        case .charging: return "Charging"
        case .full: return "Fully Charged"
        case .unplugged: return "Battery"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
    
    var healthDescription: String {
        return "View in Settings"
    }
    
    var stateIcon: String {
        switch state {
        case .charging: return "battery.100.bolt"
        case .full: return "battery.100"
        case .unplugged: return "battery.\(Int(level * 100))"
        case .unknown: return "battery.unknown"
        @unknown default: return "battery.unknown"
        }
    }
    
    var stateColor: Color {
        if state == .charging || state == .full {
            return .green
        }
        
        if level <= 0.1 {
            return .red
        } else if level <= 0.2 {
            return .orange
        } else if level <= 0.5 {
            return .yellow
        } else {
            return .blue
        }
    }
    
    static func getCurrentBatteryInfo() -> BatteryInfo {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = Float(exactly: UIDevice.current.batteryLevel) ?? -1.0
        let state = UIDevice.current.batteryState
        
        if level < 0 {
            return BatteryInfo(level: 1.0, state: state, health: -1)
        }
        
        return BatteryInfo(level: level, state: state, health: -1)
    }
}

// Add theme settings structure
enum AppTheme: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "gear"
        }
    }
}

// Add settings model
struct DisplaySettings: Codable {
    var showBattery: Bool = true
    var showSystem: Bool = true
    var showCPU: Bool = true
    var showGPU: Bool = true
    var showMemory: Bool = true
    var showStorage: Bool = true
    var showNetwork: Bool = true
    var showDisplay: Bool = true
    var showCamera: Bool = true
}

// Add memory info structure before ContentView
struct MemoryInfo {
    let totalMemory: UInt64
    let usedMemory: UInt64
    
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalMemory), countStyle: .memory)
    }
    
    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(usedMemory), countStyle: .memory)
    }
    
    var usagePercentage: Double {
        Double(usedMemory) / Double(totalMemory) * 100
    }
    
    static func getCurrentMemoryInfo() -> MemoryInfo {
        // Get total RAM
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) { statsPtr -> kern_return_t in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { pointer in
                host_statistics64(hostPort,
                                HOST_VM_INFO64,
                                pointer,
                                &size)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = vm_kernel_page_size
            
            // Calculate memory usage components
            let active = UInt64(stats.active_count) * UInt64(pageSize)
            let wired = UInt64(stats.wire_count) * UInt64(pageSize)
            
            // Only count active and wired memory as "used"
            // Exclude compressed memory to show more accurate usage
            let usedMemory = active + wired
            
            return MemoryInfo(
                totalMemory: totalMemory,
                usedMemory: usedMemory
            )
        }
        
        // Fallback to a simpler calculation if detailed stats fail
        return MemoryInfo(
            totalMemory: totalMemory,
            usedMemory: totalMemory / 4  // Estimate 25% usage as fallback
        )
    }
}

// Add StorageInfo structure (move it outside ContentView)
struct StorageInfo {
    let totalSpace: Int64
    let usedSpace: Int64
    let freeSpace: Int64
    
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalSpace, countStyle: .file)
    }
    
    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedSpace, countStyle: .file)
    }
    
    var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file)
    }
    
    var usagePercentage: Double {
        Double(usedSpace) / Double(totalSpace) * 100
    }
}

// Update CodableAppStorage to properly handle mutations
@propertyWrapper
struct CodableAppStorage<T: Codable> {
    private let key: String
    private let defaultValue: T
    
    init(wrappedValue: T, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
    }
    
    var wrappedValue: T {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else {
                return defaultValue
            }
            return (try? JSONDecoder().decode(T.self, from: data)) ?? defaultValue
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
    
    var projectedValue: Binding<T> {
        return Binding(
            get: { self.wrappedValue },
            set: { newValue in
                if let data = try? JSONEncoder().encode(newValue) {
                    UserDefaults.standard.set(data, forKey: self.key)
                }
            }
        )
    }
}

// Add the individual view components before the ContentView struct

struct BatteryInfoView: View {
    let batteryInfo: BatteryInfo
    @State private var showingSettingsGuide = false
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: batteryInfo.stateIcon)
                        .font(.title2)
                        .foregroundColor(batteryInfo.stateColor)
                    Text("Battery Status")
                        .font(.headline)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(label: "Status", value: batteryInfo.stateDescription)
                    InfoRow(label: "Level", value: "\(Int(batteryInfo.level * 100))%")
                    Button(action: {
                        showingSettingsGuide = true
                    }) {
                        InfoRow(label: "Health", value: batteryInfo.healthDescription)
                            .foregroundColor(.blue)
                    }
                    
                    Text("Note: Battery level readings are approximate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }
            }
            .padding(.horizontal, 5)
        }
        .padding(.horizontal)
        .alert("Battery Health", isPresented: $showingSettingsGuide) {
            Button("Open Settings") {
                if let url = URL(string: "App-prefs:") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To view battery health:\n1. Open Settings\n2. Tap Battery\n3. Tap Battery Health")
        }
    }
}

func getDetailedDeviceModel() -> String {
    let identifier = UIDevice.modelIdentifier()
    print("DEBUG - Device Model Identifier:", identifier)
    
    switch identifier {
    case "iPhone17,3": return "iPhone 16"
    case "iPhone17,4": return "iPhone 16 Plus"
    case "iPhone17,1": return "iPhone 16 Pro"
    case "iPhone17,2": return "iPhone 16 Pro Max"
    case "iPhone16,1": return "iPhone 15 Pro"
    case "iPhone16,2": return "iPhone 15 Plus"
    case "iPhone16,3": return "iPhone 15 Pro"
    case "iPhone16,4": return "iPhone 15 Pro Max"
    case "iPhone15,4": return "iPhone 15 Pro"
    case "iPhone15,5": return "iPhone 15 Pro Max"
    case "iPhone15,2": return "iPhone 15"
    case "iPhone15,3": return "iPhone 15 Plus"
    case "iPhone14,7": return "iPhone 14"
    case "iPhone14,8": return "iPhone 14 Plus"
    case "iPhone14,4": return "iPhone 14 Pro"
    case "iPhone14,5": return "iPhone 14 Pro Max"
    case "iPhone13,1": return "iPhone 13 mini"
    case "iPhone13,2": return "iPhone 13"
    case "iPhone13,3": return "iPhone 13 Pro"
    case "iPhone13,4": return "iPhone 13 Pro Max"
    default: 
        print("DEBUG - Unrecognized identifier:", identifier)
        return "iPhone"
    }
}

// Add this helper function to get device identifier
private func getDeviceIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    return machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
    }
}

struct SystemInfoView: View {
    let iOSInfo: String
    let deviceModel: String
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "iphone")
                        .font(.title2)
                    Text("System Information")
                        .font(.headline)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(label: "Model", value: deviceModel)
                    InfoRow(label: "iOS", value: iOSInfo)
                }
            }
            .padding(.horizontal, 5)
        }
        .padding(.horizontal)
    }
}

struct CPUInfoView: View {
    let processorInfo: String
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "cpu")
                        .font(.title2)
                    Text("CPU Information")
                        .font(.headline)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(label: "Chip", value: "A17 Pro")
                    InfoRow(label: "CPU Cores", value: "6-core")
                    InfoRow(label: "Performance Cores", value: "2")
                    InfoRow(label: "Efficiency Cores", value: "4")
                    InfoRow(label: "GPU Cores", value: "6-core")
                    InfoRow(label: "Neural Engine", value: "16-core")
                }
            }
            .padding(.horizontal, 5)
        }
        .padding(.horizontal)
    }
}

struct GPUInfoView: View {
    let gpuInfo: GPUInfo
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "square.grid.3x3.square")
                        .font(.title2)
                    Text("GPU Information")
                        .font(.headline)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(label: "Name", value: gpuInfo.name)
                    InfoRow(label: "Cores", value: "\(gpuInfo.cores)")
                    InfoRow(label: "Metal Support", value: gpuInfo.metalSupported ? "Yes" : "No")
                }
            }
            .padding(.horizontal, 5)
        }
        .padding(.horizontal)
    }
}

struct MemoryInfoView: View {
    let memoryInfo: MemoryInfo
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "memorychip")
                        .font(.title2)
                    Text("Memory Information")
                        .font(.headline)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(label: "Total RAM", value: memoryInfo.formattedTotal)
                    InfoRow(label: "Used RAM", value: memoryInfo.formattedUsed)
                    InfoRow(label: "Usage", value: String(format: "%.1f%%", memoryInfo.usagePercentage))
                }
            }
            .padding(.horizontal, 5)
        }
        .padding(.horizontal)
    }
}

struct StorageInfoView: View {
    let storageInfo: StorageInfo
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "internaldrive")
                        .font(.title2)
                    Text("Storage Information")
                        .font(.headline)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(label: "Total Storage", value: storageInfo.formattedTotal)
                    InfoRow(label: "Used Storage", value: storageInfo.formattedUsed)
                    InfoRow(label: "Available", value: storageInfo.formattedFree)
                    InfoRow(label: "Usage", value: String(format: "%.1f%%", storageInfo.usagePercentage))
                }
            }
            .padding(.horizontal, 5)
        }
        .padding(.horizontal)
    }
}

// Add NetworkInfo structure before NetworkMonitor class
struct NetworkInfo {
    let isConnected: Bool
    let type: String
    let cellularInfo: CellularInfo?

    struct CellularInfo {
        let carrier: String
        let technology: String
        let signalStrength: Int
        let radioTech: String?
        
        var displayTechnology: String {
            if technology.contains("5G") {
                return "5G"
            } else if technology.contains("LTE") {
                return "4G"
            } else if technology.contains("3G") {
                return "3G"
            } else {
                return technology
            }
        }
    }
    
    var statusDescription: String {
        isConnected ? "Connected" : "Disconnected"
    }
    
    var statusIcon: String {
        if !isConnected {
            return "wifi.slash"
        }
        switch type {
        case "WiFi": return "wifi"
        case "Cellular": return "antenna.radiowaves.left.and.right"
        default: return "network"
        }
    }
    
    var statusColor: Color {
        isConnected ? .green : .red
    }
}

// Add NetworkMonitor class
class NetworkMonitor: ObservableObject {
    @Published var networkInfo: NetworkInfo
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private let telephonyInfo = CTTelephonyNetworkInfo()

    init() {
        networkInfo = NetworkInfo(
            isConnected: false,
            type: "Unknown",
            cellularInfo: nil
        )
        setupMonitor()
    }
    
    private func setupMonitor() {
        let pathMonitor = NWPathMonitor()
        monitor = pathMonitor
        
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            var type = "Unknown"
            var cellularInfo: NetworkInfo.CellularInfo? = nil
            
            if path.usesInterfaceType(.wifi) {
                type = "WiFi"
            } else if path.usesInterfaceType(.cellular) {
                type = "Cellular"
                cellularInfo = self?.getCellularInfo()
            }
            
            let updatedInfo = NetworkInfo(
                isConnected: isConnected,
                type: type,
                cellularInfo: cellularInfo
            )

            DispatchQueue.main.async {
                self?.networkInfo = updatedInfo
            }
        }
        
        pathMonitor.start(queue: queue)
    }
    
    private func getCellularInfo() -> NetworkInfo.CellularInfo? {
        // Get cellular technology
        let technology: String
        if let radioTech = telephonyInfo.serviceCurrentRadioAccessTechnology?.values.first {
            switch radioTech {
            case CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA:
                technology = "5G"
            case CTRadioAccessTechnologyLTE:
                technology = "4G LTE"
            case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA:
                technology = "3G"
            case CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyGPRS:
                technology = "2G"
            default:
                technology = "Cellular"
            }
        } else {
            technology = "Cellular"
        }
        
        return NetworkInfo.CellularInfo(
            carrier: "Cellular",
            technology: technology,
            signalStrength: 3,
            radioTech: telephonyInfo.serviceCurrentRadioAccessTechnology?.values.first
        )
    }
    
    deinit {
        monitor?.cancel()
    }
}

// Add NetworkInfoView
struct NetworkInfoView: View {
    let networkInfo: NetworkInfo
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: networkInfo.statusIcon)
                        .font(.title2)
                        .foregroundColor(networkInfo.statusColor)
                    Text("Network Status")
                        .font(.headline)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(label: "Status", value: networkInfo.statusDescription)
                    InfoRow(label: "Type", value: networkInfo.type)
                }
            }
            .padding(.horizontal, 5)
        }
        .padding(.horizontal)
    }
}

// Add ScreenInfo structure
struct ScreenInfo {
    let size: CGSize
    let scale: CGFloat
    let nativeScale: CGFloat
    let brightness: CGFloat
    let refreshRate: Double
    
    var ppi: Int {
        // Calculate PPI based on device
        let identifier = UIDevice.modelIdentifier()
        switch identifier {
        case "iPhone17,1", "iPhone17,2": return 460  // iPhone 16 Pro, Pro Max
        case "iPhone17,3", "iPhone17,4": return 458  // iPhone 16, 16 Plus
        case "iPhone16,1", "iPhone16,3": return 460  // iPhone 15 Pro
        case "iPhone16,2": return 458    // iPhone 15 Plus
        case "iPhone16,4": return 460    // iPhone 15 Pro Max
        default: return 458
        }
    }
    
    var physicalSize: String {
        let identifier = UIDevice.modelIdentifier()
        switch identifier {
        case "iPhone17,2", "iPhone16,4": return "6.7\""  // Pro Max models
        case "iPhone17,4", "iPhone16,2": return "6.7\""  // Plus models
        case "iPhone17,1", "iPhone16,1", "iPhone16,3": return "6.1\""  // Pro models
        case "iPhone17,3": return "6.1\""  // Base model
        default: return "6.1\""
        }
    }
    
    var resolution: String {
        let pixelWidth = Int(size.width * scale)
        let pixelHeight = Int(size.height * scale)
        return "\(pixelWidth) × \(pixelHeight)"
    }
    
    static func getCurrentScreenInfo() -> ScreenInfo {
        let screen = UIScreen.main
        return ScreenInfo(
            size: screen.bounds.size,
            scale: screen.scale,
            nativeScale: screen.nativeScale,
            brightness: screen.brightness,
            refreshRate: Double(screen.maximumFramesPerSecond)
        )
    }
}

// Add ScreenInfoView
struct ScreenInfoView: View {
    let screenInfo: ScreenInfo
    @StateObject private var brightnessMonitor = BrightnessMonitor()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "display")
                        .font(.title2)
                    Text("Display Information")
                        .font(.headline)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(label: "Resolution", value: screenInfo.resolution)
                    InfoRow(label: "Scale Factor", value: String(format: "%.1fx", screenInfo.scale))
                    InfoRow(label: "Native Scale", value: String(format: "%.1fx", screenInfo.nativeScale))
                    InfoRow(label: "Pixel Density", value: "\(screenInfo.ppi) PPI")
                    InfoRow(label: "Physical Size", value: screenInfo.physicalSize)
                    InfoRow(label: "Refresh Rate", value: "\(Int(screenInfo.refreshRate))Hz")
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Brightness")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(brightnessMonitor.brightness * 100))%")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 8)
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: geometry.size.width * brightnessMonitor.brightness, height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
            .padding(.horizontal, 5)
        }
        .padding(.horizontal)
    }
}

// Add InfoRow view for consistent formatting
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// First, add camera info structure
struct CameraInfo {
    struct Camera {
        let position: String
        let resolution: String
        let aperture: String
        let hasFlash: Bool
        let hasNightMode: Bool
        let hasPortraitMode: Bool
        
        var features: [String] {
            var features: [String] = []
            if hasFlash { features.append("Flash") }
            if hasNightMode { features.append("Night Mode") }
            if hasPortraitMode { features.append("Portrait Mode") }
            return features
        }
    }
    
    let backCamera: Camera
    let frontCamera: Camera
}

// Add camera info view
struct CameraInfoView: View {
    let camera: CameraInfo.Camera
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: camera.position == "Front" ? "camera.fill" : "camera.fill.badge.ellipsis")
                        .foregroundColor(.blue)
                    Text("\(camera.position) Camera")
                        .font(.headline)
                }
                
                Divider()
                
                HStack {
                    Text("Resolution:")
                    Spacer()
                    Text(camera.resolution)
                }
                
                HStack {
                    Text("Aperture:")
                    Spacer()
                    Text(camera.aperture)
                }
                
                if !camera.features.isEmpty {
                    Divider()
                    Text("Features:")
                        .font(.subheadline)
                    ForEach(camera.features, id: \.self) { feature in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(feature)
                        }
                    }
                }
            }
            .padding(.horizontal, 5)
        }
        .padding(.horizontal)
    }
}

// Add this implementation for CameraInfo.getInfo()
extension CameraInfo {
    static func getInfo() -> CameraInfo {
        let identifier = UIDevice.modelIdentifier()
        print("Camera identifier: \(identifier)")
        
        switch identifier {
        case "iPhone17,1": // iPhone 16 Pro
            return CameraInfo(
                backCamera: Camera(
                    position: "Back",
                    resolution: "48 MP Main (f/1.78)\n12 MP Ultra Wide (f/2.2)\n12 MP 3x Telephoto",
                    aperture: "ƒ/1.78, ƒ/2.2, ƒ/2.8",
                    hasFlash: true,
                    hasNightMode: true,
                    hasPortraitMode: true
                ),
                frontCamera: Camera(
                    position: "Front",
                    resolution: "12 MP TrueDepth",
                    aperture: "ƒ/1.9",
                    hasFlash: false,
                    hasNightMode: true,
                    hasPortraitMode: true
                )
            )
        case "iPhone17,2": // iPhone 16 Pro Max
            return CameraInfo(
                backCamera: Camera(
                    position: "Back",
                    resolution: "48 MP Main (f/1.78)\n12 MP Ultra Wide (f/2.2)\n12 MP 5x Telephoto",
                    aperture: "ƒ/1.78, ƒ/2.2, ƒ/2.8",
                    hasFlash: true,
                    hasNightMode: true,
                    hasPortraitMode: true
                ),
                frontCamera: Camera(
                    position: "Front",
                    resolution: "12 MP TrueDepth",
                    aperture: "ƒ/1.9",
                    hasFlash: false,
                    hasNightMode: true,
                    hasPortraitMode: true
                )
            )
        case "iPhone17,3", "iPhone17,4": // iPhone 16, 16 Plus
            return CameraInfo(
                backCamera: Camera(
                    position: "Back",
                    resolution: "48 MP Main (f/1.6)\n12 MP Ultra Wide (f/2.4)",
                    aperture: "ƒ/1.6, ƒ/2.4",
                    hasFlash: true,
                    hasNightMode: true,
                    hasPortraitMode: true
                ),
                frontCamera: Camera(
                    position: "Front",
                    resolution: "12 MP TrueDepth",
                    aperture: "ƒ/1.9",
                    hasFlash: false,
                    hasNightMode: true,
                    hasPortraitMode: true
                )
            )
        case "iPhone16,1", "iPhone16,3": // iPhone 15 Pro
            return CameraInfo(
                backCamera: Camera(
                    position: "Back",
                    resolution: "48 MP Main (f/1.78)\n12 MP Ultra Wide (f/2.2)\n12 MP 3x Telephoto",
                    aperture: "ƒ/1.78, ƒ/2.2, ƒ/2.8",
                    hasFlash: true,
                    hasNightMode: true,
                    hasPortraitMode: true
                ),
                frontCamera: Camera(
                    position: "Front",
                    resolution: "12 MP TrueDepth",
                    aperture: "ƒ/1.9",
                    hasFlash: false,
                    hasNightMode: true,
                    hasPortraitMode: true
                )
            )
        default:
            print("Unrecognized device identifier: \(identifier)")
            return CameraInfo(
                backCamera: Camera(
                    position: "Back",
                    resolution: "12 MP Main",
                    aperture: "ƒ/1.8",
                    hasFlash: true,
                    hasNightMode: true,
                    hasPortraitMode: true
                ),
                frontCamera: Camera(
                    position: "Front",
                    resolution: "12 MP TrueDepth",
                    aperture: "ƒ/2.2",
                    hasFlash: false,
                    hasNightMode: false,
                    hasPortraitMode: true
                )
            )
        }
    }
}

// Add MemoryMonitor class
class MemoryMonitor: ObservableObject {
    @Published var memoryInfo: MemoryInfo
    private var timer: Timer?
    
    init() {
        // Get initial memory info
        self.memoryInfo = MemoryInfo.getCurrentMemoryInfo()
        // Update immediately
        self.updateMemoryInfo()
        // Start monitoring
        startMonitoring()
    }
    
    private func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateMemoryInfo()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func updateMemoryInfo() {
        let newInfo = MemoryInfo.getCurrentMemoryInfo()
        DispatchQueue.main.async { [weak self] in
            self?.memoryInfo = newInfo
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct ProcessorInfo {
    let chip: String
    let cpuCores: String
    let performanceCores: String
    let efficiencyCores: String
    let gpuCores: String
    let neuralEngine: String
}

// Update the processor info property
let processorInfo: ProcessorInfo = {
    let identifier = UIDevice.modelIdentifier()
    switch identifier {
    case "iPhone17,1", "iPhone17,2": // iPhone 16 Pro, Pro Max
        return ProcessorInfo(
            chip: "A18 Pro",
            cpuCores: "6-core",
            performanceCores: "2",
            efficiencyCores: "4",
            gpuCores: "6-core",
            neuralEngine: "18-core"
        )
    case "iPhone17,3", "iPhone17,4": // iPhone 16, 16 Plus
        return ProcessorInfo(
            chip: "A18 Bionic",
            cpuCores: "6-core",
            performanceCores: "2",
            efficiencyCores: "4",
            gpuCores: "5-core",
            neuralEngine: "16-core"
        )
    case "iPhone16,1", "iPhone16,3", "iPhone16,4": // iPhone 15 Pro models
        return ProcessorInfo(
            chip: "A17 Pro",
            cpuCores: "6-core",
            performanceCores: "2",
            efficiencyCores: "4",
            gpuCores: "6-core",
            neuralEngine: "16-core"
        )
    default:
        return ProcessorInfo(
            chip: "Apple Silicon",
            cpuCores: "6-core",
            performanceCores: "2",
            efficiencyCores: "4",
            gpuCores: "5-core",
            neuralEngine: "16-core"
        )
    }
}()

// Add BrightnessMonitor class
class BrightnessMonitor: ObservableObject {
    @Published var brightness: CGFloat = UIScreen.main.brightness
    private var observer: NSObjectProtocol?
    
    init() {
        // Observe screen brightness changes
        observer = NotificationCenter.default.addObserver(
            forName: UIScreen.brightnessDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.brightness = UIScreen.main.brightness
        }
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// Add BatteryMonitor class
class BatteryMonitor: ObservableObject {
    @Published private(set) var batteryInfo: BatteryInfo
    private var levelObserver: NSObjectProtocol?
    private var stateObserver: NSObjectProtocol?
    
    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        self.batteryInfo = BatteryInfo(
            level: UIDevice.current.batteryLevel,
            state: UIDevice.current.batteryState,
            health: -1
        )
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        levelObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let level = UIDevice.current.batteryLevel
            let state = UIDevice.current.batteryState
            self?.batteryInfo = BatteryInfo(level: level, state: state, health: -1)
        }
        
        stateObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let level = UIDevice.current.batteryLevel
            let state = UIDevice.current.batteryState
            self?.batteryInfo = BatteryInfo(level: level, state: state, health: -1)
        }
    }
    
    private func stopMonitoring() {
        if let levelObserver = levelObserver {
            NotificationCenter.default.removeObserver(levelObserver)
        }
        if let stateObserver = stateObserver {
            NotificationCenter.default.removeObserver(stateObserver)
        }
        UIDevice.current.isBatteryMonitoringEnabled = false
    }
}

struct ContentView: View {
    @State private var selectedTheme: AppTheme = .system
    @State private var selectedTab = 0
    @CodableAppStorage(wrappedValue: DisplaySettings(), "displaySettings") private var displaySettings
    @StateObject private var batteryMonitor = BatteryMonitor()
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var memoryMonitor = MemoryMonitor()
    
    // Add processor info property
    let processorInfo: String = {
        let device = UIDevice.current
        let processorCount = ProcessInfo.processInfo.processorCount
        let activeProcessorCount = ProcessInfo.processInfo.activeProcessorCount
        
        var model = device.model
        
        // Check for specific device types to show processor info
        if device.userInterfaceIdiom == .phone {
            let identifier = UIDevice.modelIdentifier()
            switch identifier {
            case "iPhone17,1", "iPhone17,2": // iPhone 16 Pro, Pro Max
                return """
                    A18 Pro chip
                    6-core CPU with 2 performance and 4 efficiency cores
                    6-core GPU
                    18-core Neural Engine
                    Total Cores: \(processorCount) (Active: \(activeProcessorCount))
                    """
            case "iPhone17,3", "iPhone17,4": // iPhone 16, 16 Plus
                return """
                    A18 Bionic chip
                    6-core CPU with 2 performance and 4 efficiency cores
                    5-core GPU
                    16-core Neural Engine
                    Total Cores: \(processorCount) (Active: \(activeProcessorCount))
                    """
            case "iPhone16,1", "iPhone16,3", "iPhone16,4": // iPhone 15 Pro models
                return """
                    A17 Pro chip
                    6-core CPU with 2 performance and 4 efficiency cores
                    6-core GPU
                    16-core Neural Engine
                    Total Cores: \(processorCount) (Active: \(activeProcessorCount))
                    """
            case "iPhone16,2": // iPhone 15 Plus
                return """
                    A16 Bionic chip
                    6-core CPU with 2 performance and 4 efficiency cores
                    5-core GPU
                    16-core Neural Engine
                    Total Cores: \(processorCount) (Active: \(activeProcessorCount))
                    """
            default:
                return """
                    Processor Information
                    Total Cores: \(processorCount)
                    Active Cores: \(activeProcessorCount)
                    """
            }
        }
        
        return """
            Processor Information
            Total Cores: \(processorCount)
            Active Cores: \(activeProcessorCount)
            """
    }()
    
    // Add storage info structure
    let storageInfo: StorageInfo = {
        let fileManager = FileManager.default
        do {
            let rootPath = NSHomeDirectory()
            guard fileManager.fileExists(atPath: rootPath) else {
                print("DEBUG - Root path not accessible")
                return StorageInfo(totalSpace: 0, usedSpace: 0, freeSpace: 0)
            }
            
            let systemAttributes = try fileManager.attributesOfFileSystem(forPath: rootPath)
            
            let totalSpace = (systemAttributes[.systemSize] as? NSNumber)?.int64Value ?? 0
            let freeSpace = (systemAttributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            let usedSpace = totalSpace - freeSpace
            
            // Validate values
            guard totalSpace > 0, freeSpace >= 0, usedSpace >= 0 else {
                print("DEBUG - Invalid storage values")
                return StorageInfo(totalSpace: 0, usedSpace: 0, freeSpace: 0)
            }
            
            return StorageInfo(totalSpace: totalSpace, usedSpace: usedSpace, freeSpace: freeSpace)
        } catch {
            print("DEBUG - Storage info error: \(error.localizedDescription)")
            return StorageInfo(totalSpace: 0, usedSpace: 0, freeSpace: 0)
        }
    }()
    
    // Add GPU info property
    let gpuInfo: GPUInfo = {
        return GPUInfo.getInfo(for: UIDevice.modelIdentifier())
    }()
    
    // Add iOS version info
    let iOSInfo: String = {
        let systemVersion = UIDevice.current.systemVersion
        return systemVersion
    }()
    
    // Add screen info property with proper initialization
    let screenInfo: ScreenInfo = {
        let screen = UIScreen.main
        return ScreenInfo(
            size: screen.bounds.size,
            scale: screen.scale,
            nativeScale: screen.nativeScale,
            brightness: screen.brightness,
            refreshRate: Double(screen.maximumFramesPerSecond)
        )
    }()
    
    // Add camera info property
    let cameraInfo = CameraInfo.getInfo()
    
    private func safeGetDeviceInfo() -> (model: String, gpu: GPUInfo, camera: CameraInfo) {
        let identifier = UIDevice.modelIdentifier()
        print("DEBUG - Safe Device Info - Starting with identifier:", identifier)
        
        // Use default values if anything fails
        let model = getDetailedDeviceModel()
        let gpu = GPUInfo.getInfo(for: identifier)
        let camera = CameraInfo.getInfo()
        
        // Validate the retrieved information
        if model == "iPhone" {
            print("DEBUG - Warning: Using generic iPhone model name")
        }
        
        if gpu.name == "Apple GPU" {
            print("DEBUG - Warning: Using generic GPU info")
        }
        
        print("DEBUG - Safe Device Info - Successfully got device info")
        return (model, gpu, camera)
    }
    
    private func saveTheme(_ theme: AppTheme) {
        UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme")
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Specs View (tag: 0)
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    Image(systemName: "cpu")
                .imageScale(.large)
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("Device Specifications")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(UIDevice.current.model)
                        .font(.headline)
                    
                    // Conditional sections
                    if displaySettings.showBattery {
                        BatteryInfoView(batteryInfo: batteryMonitor.batteryInfo)
                    }
                    
                    if displaySettings.showSystem || displaySettings.showGPU {
                        let deviceInfo = safeGetDeviceInfo()
                        
                        if displaySettings.showSystem {
                            SystemInfoView(
                                iOSInfo: iOSInfo,
                                deviceModel: deviceInfo.model
                            )
                        }
                        
                        if displaySettings.showGPU {
                            GPUInfoView(gpuInfo: deviceInfo.gpu)
                        }
                    }
                    
                    if displaySettings.showCPU {
                        CPUInfoView(processorInfo: processorInfo)
                    }
                    
                    if displaySettings.showMemory {
                        MemoryInfoView(memoryInfo: memoryMonitor.memoryInfo)
                    }
                    
                    if displaySettings.showStorage {
                        StorageInfoView(storageInfo: storageInfo)
                    }
                    
                    Spacer()
        }
        .padding()
                .onAppear {
                    print("DEBUG - ContentView appeared")
                    print("DEBUG - Current device model:", getDetailedDeviceModel())
                }
                .onChange(of: selectedTheme) { oldValue, newValue in
                    saveTheme(newValue)
                }
            }
            .tabItem {
                Image(systemName: "cpu")
                Text("Specs")
            }
            .tag(0)
            
            // Network View (tag: 1)
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    Image(systemName: "network")
                        .imageScale(.large)
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("Network Status")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if displaySettings.showNetwork {
                        NetworkInfoView(
                            networkInfo: networkMonitor.networkInfo
                        )
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "eye.slash")
                                .imageScale(.large)
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            
                            Text("Network Information Hidden")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Text("Enable in Settings")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }
                }
                .padding()
            }
            .tabItem {
                Image(systemName: "network")
                Text("Network")
            }
            .tag(1)
            
            // Display View (tag: 2)
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    Image(systemName: "display")
                        .imageScale(.large)
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("Display Information")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if displaySettings.showDisplay {
                        ScreenInfoView(screenInfo: screenInfo)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "eye.slash")
                                .imageScale(.large)
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            
                            Text("Display Information Hidden")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Text("Enable in Settings")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }
                }
                .padding()
            }
            .tabItem {
                Image(systemName: "display")
                Text("Display")
            }
            .tag(2)
            
            // Camera View (tag: 3)
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    Image(systemName: "camera")
                        .imageScale(.large)
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("Camera System")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if displaySettings.showCamera {
                        CameraInfoView(camera: cameraInfo.backCamera)
                        CameraInfoView(camera: cameraInfo.frontCamera)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "eye.slash")
                                .imageScale(.large)
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            
                            Text("Camera Information Hidden")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Text("Enable in Settings")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }
                }
                .padding()
            }
            .tabItem {
                Image(systemName: "camera")
                Text("Camera")
            }
            .tag(3)
            
            // Settings View (tag: 4)
            SettingsView(settings: $displaySettings, selectedTheme: $selectedTheme)
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(4)
        }
        .preferredColorScheme(selectedTheme.colorScheme)
        .onAppear {
            print("DEBUG - ContentView appeared")
            print("DEBUG - Current device model:", getDetailedDeviceModel())
        }
        .onChange(of: selectedTheme) { oldValue, newValue in
            saveTheme(newValue)
        }
    }
}

// Update SettingsView to use projected value
struct SettingsView: View {
    @Binding var settings: DisplaySettings
    @Binding var selectedTheme: AppTheme
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Appearance")) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        HStack {
                            Image(systemName: theme.icon)
                                .foregroundColor(selectedTheme == theme ? .blue : .primary)
                            Text(theme.rawValue)
                            Spacer()
                            if selectedTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTheme = theme
                        }
                    }
                }
                
                Section(header: Text("Spec Settings")) {
                    Toggle("Battery Information", isOn: $settings.showBattery)
                    Toggle("System Information", isOn: $settings.showSystem)
                    Toggle("CPU Information", isOn: $settings.showCPU)
                    Toggle("GPU Information", isOn: $settings.showGPU)
                    Toggle("Memory Information", isOn: $settings.showMemory)
                    Toggle("Storage Information", isOn: $settings.showStorage)
                }
                
                Section(header: Text("Network Settings")) {
                    Toggle("Network Information", isOn: $settings.showNetwork)
                }
                
                Section(header: Text("Display Settings")) {
                    Toggle("Display Information", isOn: $settings.showDisplay)
                }
                
                Section(header: Text("Camera Settings")) {
                    Toggle("Camera Information", isOn: $settings.showCamera)
                }
                
                Section {
                    Button(action: showAll) {
                        HStack {
                            Image(systemName: "eye")
                            Text("Show All")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: hideAll) {
                        HStack {
                            Image(systemName: "eye.slash")
                            Text("Hide All")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                #if DEBUG
                Section(header: Text("Developer")) {
                    NavigationLink("Foundation Diagnostics") {
                        FoundationDiagnosticsView()
                    }
                }
                #endif

                Section {
                    HStack {
                        Text("Created by:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Zachary Aflalo")
                            .fontWeight(.medium)
                    }
                    
                    Link(destination: URL(string: "https://github.com/Belligerently/SpecMatrix")!) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                            Text("GitHub Repository")
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Link(destination: URL(string: "mailto:spec.matrix.app@gmail.com")!) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.blue)
                            Text("Contact")
                                .foregroundColor(.blue)
                            Spacer()
                            Text("spec.matrix.app@gmail.com")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://github.com/Belligerently/SpecMatrix/blob/main/LICENSE")!) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                            Text("Licensed under MIT")
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
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

#Preview {
    ContentView()
}
