//
//  SpecMatrixMacApp.swift
//  SpecMatrixMac
//

import AppKit
import SwiftUI

/// SpecMatrix for Mac: this Mac's hardware as macOS reports it ("Detected"), alongside Apple's published
/// specifications for the model ("Catalog"). See docs/MACOS_HANDOFF.md.
@main
struct SpecMatrixMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = MacInfoStore()
    @StateObject private var navigation = NavigationModel()
    @AppStorage(SettingsKey.hiddenSections) private var hiddenSectionsRaw = ""

    var body: some Scene {
        Window("SpecMatrix", id: "main") {
            ContentView(store: store, navigation: navigation)
                .frame(minWidth: 760, minHeight: 480)
        }
        .defaultSize(width: 1040, height: 700)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .appInfo) {
                Button("About SpecMatrix") { AppDelegate.showAboutPanel() }
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Copy Hardware Report") {
                    if let snapshot = store.snapshot {
                        Pasteboard.copy(MacReport.text(snapshot: snapshot, network: store.network))
                    }
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(store.snapshot == nil)
            }
            CommandGroup(after: .toolbar) {
                Button("Refresh") { store.refresh() }
                    .keyboardShortcut("r", modifiers: .command)
                Divider()
                ForEach(Array(HiddenSections(rawValue: hiddenSectionsRaw).visible.prefix(9).enumerated()), id: \.element) { index, section in
                    Button(section.title) { navigation.selection = section }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
            CommandGroup(replacing: .help) {
                Button("SpecMatrix Website") { NSWorkspace.shared.open(SpecMatrixLinks.website) }
                Button("SpecMatrix on GitHub") { NSWorkspace.shared.open(SpecMatrixLinks.repository) }
                Button("Report an Issue…") { NSWorkspace.shared.open(SpecMatrixLinks.issues) }
            }
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppearancePreference.apply(UserDefaults.standard.string(forKey: SettingsKey.appearance) ?? "")
    }

    /// SpecMatrix has a single window; closing it quits, as with other single-window utilities.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    @MainActor
    static func showAboutPanel() {
        let credits = NSMutableAttributedString(
            string: "Hardware information for Apple-silicon Macs, with every value labelled by its source.\n",
            attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                         .foregroundColor: NSColor.secondaryLabelColor])
        credits.append(NSAttributedString(string: "specmatrix.me", attributes: [
            .link: SpecMatrixLinks.website, .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]))
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        credits.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: credits.length))
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "SpecMatrix",
            .credits: credits,
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}
