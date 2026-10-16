//
//  CameraScreen.swift
//  SpecMatrix
//

import SwiftUI

/// The Camera tab: back and front camera details from the bundled catalog.
struct CameraScreen: View {
    let isVisible: Bool
    let device: CatalogDeviceInfo

    var body: some View {
        SpecScreen(
            title: "Camera System",
            hiddenNotice: isVisible ? nil : HiddenNotice(title: "Camera Information Hidden")
        ) {
            CameraInfoView(camera: device.backCamera, systemImage: "camera.fill.badge.ellipsis")
            CameraInfoView(camera: device.frontCamera, systemImage: "camera.fill")
        }
    }
}

struct CameraInfoView: View {
    let camera: CatalogDeviceInfo.CameraSummary
    let systemImage: String

    var body: some View {
        SpecSection(title: camera.title, systemImage: systemImage) {
            SpecRow(label: "Resolution", value: camera.resolution)
            SpecRow(label: "Aperture", value: camera.aperture)
            ForEach(camera.features, id: \.self) { feature in
                Label {
                    Text(feature)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .accessibilityLabel("Feature: \(feature)")
            }
        }
    }
}
