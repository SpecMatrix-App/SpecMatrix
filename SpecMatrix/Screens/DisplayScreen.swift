//
//  DisplayScreen.swift
//  SpecMatrix
//

import SwiftUI

/// The Display tab: screen geometry, catalog display figures and live brightness.
struct DisplayScreen: View {
    let isVisible: Bool
    let screenInfo: ScreenInfo

    var body: some View {
        SpecScreen(
            title: "Display Information",
            hiddenNotice: isVisible ? nil : HiddenNotice(title: "Display Information Hidden")
        ) {
            ScreenInfoView(screenInfo: screenInfo)
        }
    }
}

struct ScreenInfoView: View {
    let screenInfo: ScreenInfo
    @StateObject private var brightnessMonitor = BrightnessMonitor()

    var body: some View {
        SpecSection(title: "Display Information", systemImage: "display") {
            SpecRow(label: "Resolution", value: screenInfo.resolution)
            SpecRow(label: "Scale Factor", value: String(format: "%.1fx", screenInfo.scale))
            SpecRow(label: "Native Scale", value: String(format: "%.1fx", screenInfo.nativeScale))
            SpecRow(label: "Pixel Density", value: screenInfo.ppi)
            SpecRow(label: "Physical Size", value: screenInfo.physicalSize)
            SpecRow(label: "Refresh Rate", value: "\(Int(screenInfo.refreshRate))Hz")

            let brightness = min(max(brightnessMonitor.brightness, 0), 1)
            VStack(alignment: .leading, spacing: 8) {
                SpecRow(label: "Brightness", value: "\(Int(brightness * 100))%")
                ProgressView(value: brightness)
                    .accessibilityHidden(true)
            }
        }
    }
}
