//
//  SpecMatrixMacApp.swift
//  SpecMatrixMac
//

import SwiftUI

/// SpecMatrix for Mac: a dashboard of this Mac's hardware. Values read from macOS are shown as
/// "Detected"; published specifications from the Mac catalog as "Catalog". See docs/MACOS_PHASE2_HANDOFF.md.
@main
struct SpecMatrixMacApp: App {
    @StateObject private var store = MacInfoStore()

    var body: some Scene {
        Window("SpecMatrix", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 720, minHeight: 460)
        }
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh") { store.refresh() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
