//
//  SettingsView.swift
//  SpecMatrixMac
//

import SwiftUI

/// The Settings window (SpecMatrix ▸ Settings…, ⌘,).
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            SectionSettingsView()
                .tabItem { Label("Sidebar", systemImage: "sidebar.left") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(SettingsKey.appearance) private var appearance = AppearancePreference.system.rawValue
    @AppStorage(SettingsKey.showSourceBadges) private var showSourceBadges = true

    var body: some View {
        Form {
            Picker("Appearance:", selection: $appearance) {
                ForEach(AppearancePreference.allCases) { preference in
                    Text(preference.title).tag(preference.rawValue)
                }
            }
            .pickerStyle(.radioGroup)
            Toggle("Show source badges next to values", isOn: $showSourceBadges)
            Text("Badges mark each value as Detected (read from macOS) or Catalog (Apple's published specification). The source is always available in the value's tooltip.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .onChange(of: appearance) { AppearancePreference.apply($0) }
    }
}

private struct SectionSettingsView: View {
    @AppStorage(SettingsKey.hiddenSections) private var hiddenSectionsRaw = ""

    var body: some View {
        Form {
            Text("Show in the sidebar:")
            ForEach(MacSection.allCases.filter(\.canBeHidden)) { section in
                Toggle(isOn: binding(for: section)) {
                    Label(section.title, systemImage: section.systemImage)
                }
            }
            Button("Show All") { hiddenSectionsRaw = "" }
                .disabled(hiddenSectionsRaw.isEmpty)
        }
        .padding(20)
    }

    private func binding(for section: MacSection) -> Binding<Bool> {
        Binding {
            !HiddenSections(rawValue: hiddenSectionsRaw).contains(section)
        } set: { visible in
            var hidden = HiddenSections(rawValue: hiddenSectionsRaw)
            hidden.set(section, hidden: !visible)
            hiddenSectionsRaw = hidden.rawValue
        }
    }
}

private struct AboutSettingsView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SpecMatrix for Mac")
                .font(.title2.weight(.semibold))
            Text("Version \(AppInfo.version) (\(AppInfo.build))")
                .foregroundColor(.secondary)
                .textSelection(.enabled)
            Text("Shows this Mac's hardware as macOS reports it, alongside Apple's published specifications for the model. Every value is labelled with its source; values SpecMatrix cannot determine are shown as unknown, never estimated.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Privacy: SpecMatrix makes no network connections, collects no analytics and never reads the serial number. Settings are stored only on this Mac.")
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.secondary)
            HStack {
                Button("Website") { openURL(SpecMatrixLinks.website) }
                Button("Source Code") { openURL(SpecMatrixLinks.repository) }
                Button("Report an Issue") { openURL(SpecMatrixLinks.issues) }
            }
            .specControlButtonStyle()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
