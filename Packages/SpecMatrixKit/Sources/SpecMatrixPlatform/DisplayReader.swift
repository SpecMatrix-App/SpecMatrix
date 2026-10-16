import Foundation
import SpecMatrixCore
#if os(iOS)
import UIKit
#endif

#if os(iOS)
enum DisplayReader {
    /// Reads the screen currently showing the app. Uses the scene's screen, not the deprecated `UIScreen.main`.
    @MainActor
    static func read(screen: UIScreen?, environment: RuntimeEnvironment) -> DisplayReading {
        guard let screen else {
            return DisplayReading(allMissing: .unknown("No screen is currently showing the app."))
        }
        func source(_ property: String) -> MeasurementSource {
            MeasurementSource(api: "UIScreen.\(property)", environment: environment)
        }
        // nativeBounds is always in portrait orientation, in physical pixels.
        let size = screen.nativeBounds.size
        let resolution: SpecValue<PixelDimensions> = PixelDimensions(width: Int(size.width), height: Int(size.height))
            .map { .measured($0, source("nativeBounds")) } ?? .unknown("The screen reported invalid native bounds.")
        let scale: SpecValue<Double> = screen.nativeScale > 0
            ? .measured(Double(screen.nativeScale), source("nativeScale"))
            : .unknown("The screen reported an invalid scale.")
        let frameRate: SpecValue<RefreshRate> = RefreshRate(hertz: screen.maximumFramesPerSecond)
            .map { .measured($0, source("maximumFramesPerSecond")) } ?? .unknown("The screen reported an invalid frame rate.")
        let brightness: SpecValue<UnitFraction> = UnitFraction(Double(screen.brightness))
            .map { .measured($0, source("brightness")) } ?? .unknown("The screen reported an out-of-range brightness.")
        return DisplayReading(nativeResolution: resolution, nativeScale: scale,
                              maximumFramesPerSecond: frameRate, brightness: brightness)
    }
}
#endif
