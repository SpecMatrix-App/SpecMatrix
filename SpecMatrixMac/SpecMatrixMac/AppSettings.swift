//
//  AppSettings.swift
//  SpecMatrixMac
//

import AppKit
import SwiftUI

/// User preferences, stored in the app's own defaults (`UserDefaults.standard`, via `@AppStorage`).
/// Nothing here leaves the Mac.
enum SettingsKey {
    static let appearance = "appearance"
    static let hiddenSections = "hiddenSections"
    static let showSourceBadges = "showSourceBadges"
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Applied app-wide through AppKit so the main window, Settings and the About panel all follow it.
    /// `nil` follows the system setting.
    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    @MainActor
    static func apply(_ rawValue: String) {
        NSApp.appearance = (AppearancePreference(rawValue: rawValue) ?? .system).appearance
    }
}

/// The sidebar sections of the main window.
enum MacSection: String, CaseIterable, Identifiable, Hashable {
    case overview, processor, graphics, memory, storage, displays, power, network, system, catalog

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .processor: "Processor"
        case .graphics: "Graphics"
        case .memory: "Memory"
        case .storage: "Storage"
        case .displays: "Displays"
        case .power: "Battery & Power"
        case .network: "Network"
        case .system: "macOS"
        case .catalog: "Model Record"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .processor: "cpu"
        case .graphics: "cube.transparent"
        case .memory: "memorychip"
        case .storage: "internaldrive"
        case .displays: "display.2"
        case .power: "battery.75"
        case .network: "network"
        case .system: "apple.logo"
        case .catalog: "books.vertical"
        }
    }

    /// Overview is always shown so the window is never empty.
    var canBeHidden: Bool { self != .overview }

    enum Group: String, CaseIterable {
        case thisMac = "This Mac", hardware = "Hardware", software = "Software"
    }

    var group: Group {
        switch self {
        case .overview: .thisMac
        case .processor, .graphics, .memory, .storage, .displays, .power: .hardware
        case .network, .system, .catalog: .software
        }
    }
}

/// Hidden sections are stored as a comma-separated list of raw values so `@AppStorage` can hold them.
struct HiddenSections {
    var rawValue: String

    var sections: Set<MacSection> {
        Set(rawValue.split(separator: ",").compactMap { MacSection(rawValue: String($0)) }.filter(\.canBeHidden))
    }

    func contains(_ section: MacSection) -> Bool { sections.contains(section) }

    mutating func set(_ section: MacSection, hidden: Bool) {
        var updated = sections
        if hidden, section.canBeHidden { updated.insert(section) } else { updated.remove(section) }
        rawValue = MacSection.allCases.filter(updated.contains).map(\.rawValue).joined(separator: ",")
    }

    var visible: [MacSection] { MacSection.allCases.filter { !contains($0) } }
}

/// The selected sidebar section, shared by the window and the View menu's section commands.
@MainActor
final class NavigationModel: ObservableObject {
    @Published var selection: MacSection? = .overview
}

/// Project links. The app opens them in the default browser; it makes no network requests itself.
enum SpecMatrixLinks {
    static let website = URL(string: "https://specmatrix.me")!
    static let repository = URL(string: "https://github.com/SpecMatrix-App/SpecMatrix")!
    static let issues = URL(string: "https://github.com/SpecMatrix-App/SpecMatrix/issues")!
}

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
    }
}
