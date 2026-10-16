//
//  SpecComponents.swift
//  SpecMatrix
//

import SwiftUI

// Shared building blocks for every SpecMatrix screen. Screens are inset-grouped lists inside a
// navigation stack, so the system supplies the bars, their materials (Liquid Glass on iOS 26+),
// row backgrounds, separators and Dynamic Type metrics. Content rows themselves are never glass.

/// A tab's root screen: a large-title navigation stack around an inset-grouped list.
/// When `hiddenNotice` is set, the list is empty and the notice explains why.
struct SpecScreen<Content: View>: View {
    let title: String
    var subtitle: String?
    var hiddenNotice: HiddenNotice?
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            List {
                if hiddenNotice == nil {
                    content
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if let hiddenNotice {
                    hiddenNotice
                }
            }
            .navigationTitle(title)
            .specNavigationSubtitle(subtitle)
        }
    }
}

/// The state shown when the user has hidden a screen's information in Settings.
struct HiddenNotice: View {
    let title: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "eye.slash")
        } description: {
            Text("Enable in Settings")
        }
    }
}

/// A titled group of rows: the card used for each kind of information.
struct SpecSection<Content: View>: View {
    let title: String
    let systemImage: String
    /// Colours the header symbol for states that also have a text row (never colour alone).
    var symbolColor: Color?
    var footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        Section {
            content
        } header: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(symbolColor ?? .accentColor)
                    .accessibilityHidden(true)
            }
        } footer: {
            if let footer {
                Text(footer)
            }
        }
        .headerProminence(.increased)
    }
}

/// A label and its value. Values stay on the trailing edge at standard text sizes and move below
/// the label at accessibility sizes, so long values are never truncated. VoiceOver reads the row
/// as one element, and the value can be selected and copied.
struct SpecRow: View {
    let label: String
    let value: String
    /// A trailing symbol after the value, e.g. for a row that is also a button.
    var accessorySystemImage: String?
    /// Off for rows inside buttons, where a long press should not start a text selection.
    var isSelectable = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 16))
        layout {
            Text(label)
                .foregroundStyle(.secondary)
            if !stacked {
                Spacer(minLength: 0)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                let valueText = Text(value)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .multilineTextAlignment(stacked ? .leading : .trailing)
                if isSelectable {
                    valueText.textSelection(.enabled)
                } else {
                    valueText
                }
                if let accessorySystemImage {
                    Image(systemName: accessorySystemImage)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
