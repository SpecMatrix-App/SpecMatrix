//
//  NetworkScreen.swift
//  SpecMatrix
//

import SwiftUI

/// The Network tab: connection status from the network path monitor.
struct NetworkScreen: View {
    let isVisible: Bool
    @StateObject private var networkMonitor = NetworkMonitor()

    var body: some View {
        SpecScreen(
            title: "Network",
            hiddenNotice: isVisible ? nil : HiddenNotice(title: "Network Information Hidden")
        ) {
            NetworkInfoView(networkInfo: networkMonitor.networkInfo)
        }
    }
}

struct NetworkInfoView: View {
    let networkInfo: NetworkInfo

    var body: some View {
        SpecSection(
            title: "Network Status",
            systemImage: networkInfo.statusIcon,
            symbolColor: networkInfo.statusColor
        ) {
            SpecRow(label: "Status", value: networkInfo.statusDescription)
            SpecRow(label: "Type", value: networkInfo.type)
        }
    }
}
