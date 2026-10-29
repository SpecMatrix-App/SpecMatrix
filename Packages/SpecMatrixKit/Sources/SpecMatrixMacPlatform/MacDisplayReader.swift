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

        let mode = CGDisplayCopyDisplayMode(displayID)
        let resolution: SpecValue<PixelDimensions>
        if let mode, let pixels = PixelDimensions(width: mode.pixelWidth, height: mode.pixelHeight) {
            resolution = .measured(pixels, source("CGDisplayMode.pixelWidth/pixelHeight"))
        } else {
            resolution = .unknown("The display did not report its current mode.")
        }
        // CGDisplayMode.refreshRate is 0 for variable-refresh displays (e.g. ProMotion), which have no fixed rate.
        let currentRefresh: SpecValue<Double>
        if let rate = mode?.refreshRate, rate > 0 {
            currentRefresh = .measured(rate, source("CGDisplayMode.refreshRate"))
        } else if mode != nil {
            currentRefresh = .unknown("The current mode has no fixed refresh rate (variable refresh or not reported).")
        } else {
            currentRefresh = .unknown("The display did not report its current mode.")
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

        let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        let modes = (CGDisplayCopyAllDisplayModes(displayID, options) as? [CGDisplayMode]) ?? []
        let largest: SpecValue<PixelDimensions> = modes
            .max { $0.pixelWidth * $0.pixelHeight < $1.pixelWidth * $1.pixelHeight }
            .flatMap { PixelDimensions(width: $0.pixelWidth, height: $0.pixelHeight) }
            .map { .measured($0, source("CGDisplayCopyAllDisplayModes")) }
            ?? .unknown("The display did not report its available modes.")

        let rotation = CGDisplayRotation(displayID)
        let colorSpace: SpecValue<String> = screen.colorSpace?.localizedName.flatMap { $0.isEmpty ? nil : $0 }
            .map { .measured($0, source("NSScreen.colorSpace.localizedName")) }
            ?? .unknown("The display did not report a named color space.")

        return MacDisplayReading(
            id: displayID,
            name: name,
            isBuiltIn: .measured(CGDisplayIsBuiltin(displayID) != 0, source("CGDisplayIsBuiltin")),
            resolution: resolution,
            pointSize: points,
            scale: scale,
            maximumRefreshRate: refresh,
            diagonal: diagonal,
            extendedDynamicRangeHeadroom: edr,
            isMain: .measured(CGDisplayIsMain(displayID) != 0, source("CGDisplayIsMain")),
            isMirrored: .measured(CGDisplayIsInMirrorSet(displayID) != 0, source("CGDisplayIsInMirrorSet")),
            rotation: rotation.isFinite ? .measured(Int(rotation.rounded()), source("CGDisplayRotation"))
                                        : .unknown("The display reported an invalid rotation."),
            currentRefreshRate: currentRefresh,
            colorSpace: colorSpace,
            largestModeResolution: largest
        )
    }
}
#endif
