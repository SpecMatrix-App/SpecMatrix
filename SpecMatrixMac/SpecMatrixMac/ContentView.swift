//
//  ContentView.swift
//  SpecMatrixMac
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var store: MacInfoStore
    @ObservedObject var navigation: NavigationModel
    @AppStorage(SettingsKey.hiddenSections) private var hiddenSectionsRaw = ""

    private var hidden: HiddenSections { HiddenSections(rawValue: hiddenSectionsRaw) }

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.selection) {
                ForEach(MacSection.Group.allCases, id: \.self) { group in
                    let sections = hidden.visible.filter { $0.group == group }
                    if !sections.isEmpty {
                        Section(group.rawValue) {
                            ForEach(sections) { section in
                                NavigationLink(value: section) {
                                    Label(section.title, systemImage: section.systemImage)
                                }
                            }
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            detail(for: currentSection)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    if let snapshot = store.snapshot {
                        Pasteboard.copy(MacReport.text(snapshot: snapshot, network: store.network))
                    }
                } label: {
                    Label("Copy Report", systemImage: "doc.on.doc")
                }
                .help("Copy a plain-text report of every value and its source (⇧⌘C)")
                .disabled(store.snapshot == nil)

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
        .onChange(of: hiddenSectionsRaw) { _ in
            // A section hidden in Settings while selected falls back to the overview.
            if let selection = navigation.selection, hidden.contains(selection) { navigation.selection = .overview }
        }
    }

    private var currentSection: MacSection {
        guard let selection = navigation.selection, !hidden.contains(selection) else { return .overview }
        return selection
    }

    @ViewBuilder
    private func detail(for section: MacSection) -> some View {
        if let snapshot = store.snapshot {
            Group {
                switch section {
                case .overview: OverviewView(snapshot: snapshot, network: store.network, catalogError: store.catalogError,
                                             navigation: navigation)
                case .processor: ProcessorView(snapshot: snapshot)
                case .graphics: GraphicsView(snapshot: snapshot)
                case .memory: MemoryView(snapshot: snapshot, store: store)
                case .storage: StorageView(snapshot: snapshot)
                case .displays: DisplaysView(snapshot: snapshot)
                case .power: PowerView(snapshot: snapshot)
                case .network: NetworkView(network: store.network, collectedAt: snapshot.collectedAt)
                case .system: SystemView(snapshot: snapshot, catalogVersion: store.catalogVersion)
                case .catalog: ModelRecordView(snapshot: snapshot, catalogError: store.catalogError)
                }
            }
            .navigationTitle(section.title)
            .navigationSubtitle(snapshot.specification.marketingName.value ?? "This Mac")
        } else {
            VStack(spacing: 12) {
                ProgressView()
                    .accessibilityLabel("Loading")
                Text("Reading this Mac…")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(section.title)
        }
    }
}
