//
//  ContentView.swift
//  SpecMatrixMac
//

import SwiftUI

/// The sidebar sections of the main window.
enum MacSection: String, CaseIterable, Identifiable, Hashable {
    case overview, processor, graphics, memory, storage, battery, displays

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .processor: "Processor"
        case .graphics: "Graphics"
        case .memory: "Memory"
        case .storage: "Storage"
        case .battery: "Battery"
        case .displays: "Displays"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "info.circle"
        case .processor: "cpu"
        case .graphics: "cube.transparent"
        case .memory: "memorychip"
        case .storage: "internaldrive"
        case .battery: "battery.100"
        case .displays: "display"
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: MacInfoStore
    @State private var selection: MacSection? = .overview

    var body: some View {
        NavigationSplitView {
            List(MacSection.allCases, selection: $selection) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.systemImage)
                }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 200)
        } detail: {
            detail(for: selection ?? .overview)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Read the current values again (⌘R)")
                .disabled(store.isRefreshing)
            }
        }
        .onAppear { store.start() }
        .onDisappear { store.stop() }
    }

    @ViewBuilder
    private func detail(for section: MacSection) -> some View {
        if let snapshot = store.snapshot {
            Group {
                switch section {
                case .overview: OverviewSection(snapshot: snapshot, catalogError: store.catalogError)
                case .processor: ProcessorSection(snapshot: snapshot)
                case .graphics: GraphicsSection(snapshot: snapshot)
                case .memory: MemorySection(snapshot: snapshot)
                case .storage: StorageSection(snapshot: snapshot)
                case .battery: BatterySection(snapshot: snapshot)
                case .displays: DisplaysSection(snapshot: snapshot)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(section.title)
            .navigationSubtitle(snapshot.specification.marketingName.value ?? "This Mac")
        } else {
            VStack(spacing: 12) {
                ProgressView()
                Text("Reading this Mac…")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(section.title)
        }
    }
}
