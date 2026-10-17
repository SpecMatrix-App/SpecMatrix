#if os(macOS)
import AppKit
import CoreGraphics
import SpecMatrixShared

/// Reads the connected displays through `NSScreen` and CoreGraphics display APIs.
@MainActor
public enum MacDisplayReader {
    public static func read() -> [MacDisplayReading] {
        NSScreen.screens.compactMap(reading)
    }

    private static func reading(_ screen: NSScreen) -> MacDisplayReading? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        let displayID = CGDirectDisplayID(number.uint32Value)

        let name: SpecValue<String> = screen.localizedName.isEmpty
            ? .unknown("The display did not report a name.")
            : .measured(screen.localizedName, source("NSScreen.localizedName"))

        let resolution: SpecValue<PixelDimensions>
        if let mode = CGDisplayCopyDisplayMode(displayID),
           let pixels = PixelDimensions(width: mode.pixelWidth, height: mode.pixelHeight) {
            resolution = .measured(pixels, source("CGDisplayMode.pixelWidth/pixelHeight"))
        } else {
            resolution = .unknown("The display did not report its current mode.")
        }

        let points: SpecValue<PixelDimensions> = PixelDimensions(width: Int(screen.frame.width.rounded()),
                                                                 height: Int(screen.frame.height.rounded()))
            .map { .measured($0, source("NSScreen.frame")) } ?? .unknown("The display reported an empty frame.")

        let scale: SpecValue<Double> = screen.backingScaleFactor > 0
            ? .measured(Double(screen.backingScaleFactor), source("NSScreen.backingScaleFactor"))
            : .unknown("The display reported an invalid scale.")

        let refresh: SpecValue<RefreshRate> = RefreshRate(hertz: screen.maximumFramesPerSecond)
            .map { .measured($0, source("NSScreen.maximumFramesPerSecond")) }
            ?? .unknown("The display did not report a refresh rate.")

        // CGDisplayScreenSize returns millimetres from the display's EDID, or zero when unknown.
        let millimetres = CGDisplayScreenSize(displayID)
        let diagonal: SpecValue<DisplayDiagonal>
        if millimetres.width > 0, millimetres.height > 0,
           let inches = DisplayDiagonal(inches: (millimetres.width * millimetres.width + millimetres.height * millimetres.height)
                                                .squareRoot() / 25.4) {
            diagonal = .measured(inches, source("CGDisplayScreenSize"))
        } else {
            diagonal = .unknown("The display did not report its physical size.")
        }

        let headroom = Double(screen.maximumPotentialExtendedDynamicRangeColorComponentValue)
        let edr: SpecValue<Double> = headroom >= 1
            ? .measured(headroom, source("NSScreen.maximumPotentialExtendedDynamicRangeColorComponentValue"))
            : .unknown("The display reported an invalid dynamic-range headroom.")

        return MacDisplayReading(
            id: displayID,
            name: name,
            isBuiltIn: .measured(CGDisplayIsBuiltin(displayID) != 0, source("CGDisplayIsBuiltin")),
            resolution: resolution,
            pointSize: points,
            scale: scale,
            maximumRefreshRate: refresh,
            diagonal: diagonal,
            extendedDynamicRangeHeadroom: edr
        )
    }
}
#endif
