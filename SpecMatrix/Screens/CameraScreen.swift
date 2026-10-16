//
//  CameraScreen.swift
//  SpecMatrix
//

import SwiftUI

/// The Camera tab: back and front camera details.
struct CameraScreen: View {
    let isVisible: Bool
    let cameraInfo: CameraInfo

    var body: some View {
        SpecScreen(
            title: "Camera System",
            hiddenNotice: isVisible ? nil : HiddenNotice(title: "Camera Information Hidden")
        ) {
            CameraInfoView(camera: cameraInfo.backCamera)
            CameraInfoView(camera: cameraInfo.frontCamera)
        }
    }
}

struct CameraInfoView: View {
    let camera: CameraInfo.Camera

    var body: some View {
        SpecSection(
            title: "\(camera.position) Camera",
            systemImage: camera.position == "Front" ? "camera.fill" : "camera.fill.badge.ellipsis"
        ) {
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
