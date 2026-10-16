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
import Metal

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

// GPU details: name and core count from the bundled catalog, Metal support measured on the device.
struct GPUInfo {
    let name: String
    let cores: String
    let metalSupported: Bool

    static func getInfo(for model: String) -> GPUInfo {
        let device = CatalogDeviceInfo.current()
        return GPUInfo(
            name: device.gpuName,
            cores: device.gpuCores,
            metalSupported: MTLCreateSystemDefaultDevice() != nil
        )
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
    
    /// "Unknown" when the system reports no level (-1, e.g. in the Simulator), never a negative percentage.
    var levelDescription: String {
        level < 0 ? "Unknown" : "\(Int(level * 100))%"
    }

    /// Only names that exist in SF Symbols: the level is shown in quarter steps.
    var stateIcon: String {
        switch state {
        case .charging: return "battery.100.bolt"
        case .full: return "battery.100"
        case .unplugged, .unknown:
            guard level >= 0 else { return "battery.0" }
            return "battery.\(min(Int((level * 4).rounded()) * 25, 100))"
        @unknown default: return "battery.0"
        }
    }
    
    var stateColor: Color {
        // An unknown level is not a low level.
        if level < 0 {
            return SpecColors.neutral
        }
        if state == .charging || state == .full {
            return SpecColors.good
        }
        
        if level <= 0.1 {
            return SpecColors.critical
        } else if level <= 0.2 {
            return SpecColors.warning
        } else if level <= 0.5 {
            return SpecColors.caution
        } else {
            // A normal level is not a status to call out: the accent colour, as for other section icons.
            return Color.accentColor
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
    
    /// The `UserDefaults` key holding the chosen theme's raw value ("Light", "Dark" or "System").
    static let storageKey = "selectedTheme"
    
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

/// A `Codable` value stored as JSON data in `UserDefaults.standard` under `key`.
/// Backed by `@AppStorage`, so views that read it update when it changes.
@propertyWrapper
struct CodableAppStorage<T: Codable>: DynamicProperty {
    @AppStorage private var data: Data?
    private let defaultValue: T
    
    init(wrappedValue: T, _ key: String) {
        self._data = AppStorage(key)
        self.defaultValue = wrappedValue
    }
    
    var wrappedValue: T {
        get {
            guard let data else { return defaultValue }
            return (try? JSONDecoder().decode(T.self, from: data)) ?? defaultValue
        }
        nonmutating set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                data = encoded
            }
        }
    }
    
    var projectedValue: Binding<T> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}

/// The marketed model name from the bundled catalog, or "Unknown model (<identifier>)".
func getDetailedDeviceModel() -> String {
    CatalogDeviceInfo.current().modelName
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
        isConnected ? SpecColors.good : SpecColors.critical
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

// Add ScreenInfo structure
struct ScreenInfo {
    let size: CGSize
    let scale: CGFloat
    let nativeScale: CGFloat
    let brightness: CGFloat
    let refreshRate: Double
    
    /// From the bundled catalog; "Unknown" when the model or the value is not catalogued.
    var ppi: String { CatalogDeviceInfo.current().pixelDensity }

    var physicalSize: String { CatalogDeviceInfo.current().displaySize }

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
    /// Restored on launch; a missing or unrecognised stored value means System.
    @AppStorage private var selectedTheme: AppTheme
    @State private var selectedTab: Int
    @CodableAppStorage(wrappedValue: DisplaySettings(), "displaySettings") private var displaySettings
    
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
    
    
    /// `initialTab` is the tag of the tab shown first (0 = Specs). `preferences` holds the saved theme.
    init(initialTab: Int = 0, preferences: UserDefaults = .standard) {
        _selectedTab = State(initialValue: initialTab)
        _selectedTheme = AppStorage(wrappedValue: .system, AppTheme.storageKey, store: preferences)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SpecsScreen(settings: displaySettings, storageInfo: storageInfo, iOSInfo: iOSInfo, gpuInfo: gpuInfo)
                .tabItem { Label("Specs", systemImage: "cpu") }
                .tag(0)
            
            NetworkScreen(isVisible: displaySettings.showNetwork)
                .tabItem { Label("Network", systemImage: "network") }
                .tag(1)
            
            DisplayScreen(isVisible: displaySettings.showDisplay, screenInfo: screenInfo)
                .tabItem { Label("Display", systemImage: "display") }
                .tag(2)
            
            CameraScreen(isVisible: displaySettings.showCamera, device: .current())
                .tabItem { Label("Camera", systemImage: "camera") }
                .tag(3)
            
            SettingsView(settings: $displaySettings, selectedTheme: $selectedTheme)
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(4)
        }
        // Hidden-section notices offer a shortcut to Settings (tag 4). It only changes the selected tab.
        .environment(\.showSettingsTab, { selectedTab = 4 })
        .specTabBarMinimizesOnScroll()
        .preferredColorScheme(selectedTheme.colorScheme)
        .onAppear {
            print("DEBUG - ContentView appeared")
            print("DEBUG - Current device model:", getDetailedDeviceModel())
        }
    }
}

#Preview {
    ContentView()
}
