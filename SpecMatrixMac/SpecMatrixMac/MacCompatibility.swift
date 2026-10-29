//
//  MacCompatibility.swift
//  SpecMatrixMac
//
//  Every OS-version check in the Mac app lives here. The app supports macOS 13; newer APIs are used
//  behind `#available` with a native fallback, and must exist in the CI SDK (macOS 26, Xcode 26).
//

import SwiftUI

extension View {
    /// Background for dashboard cards. Cards are content, so they use a plain grouped fill on every
    /// version; Liquid Glass is reserved for controls and navigation, as Apple's design guidance describes.
    func specCardBackground() -> some View {
        background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor))
        )
    }

    /// Buttons placed in content (e.g. "Copy Report"): Liquid Glass on macOS 26+, bordered before.
    @ViewBuilder
    func specControlButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// Small status capsules in the overview header: a glass capsule on macOS 26+, a quiet fill before.
    @ViewBuilder
    func specCapsuleBackground() -> some View {
        if #available(macOS 26.0, *) {
            padding(.horizontal, 10)
                .padding(.vertical, 4)
                .glassEffect(.regular, in: Capsule())
        } else {
            padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.5)))
        }
    }
}

/// A centred empty, unavailable or error state. Uses `ContentUnavailableView` on macOS 14+ and an
/// equivalent stack on macOS 13.
struct SpecStatusView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        if #available(macOS 14.0, *) {
            ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
        } else {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .regular))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}
