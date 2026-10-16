//
//  SpecColors.swift
//  SpecMatrix
//

import SwiftUI

/// Status colours by meaning, so a status looks the same everywhere and can be adjusted in one place.
/// Each is an adaptive UIKit system colour, so light, dark and Increase Contrast variants come from
/// the system. Status is never shown by colour alone: a text row always states it too.
/// The app's accent (system blue) is not a status colour; use `Color.accentColor` for it.
enum SpecColors {
    /// Healthy or available, e.g. charging, connected, a camera feature the model has.
    static let good = Color(uiColor: .systemGreen)
    /// Getting low, the mildest alert, e.g. battery at half or below.
    static let caution = Color(uiColor: .systemYellow)
    /// Low, needs attention soon, e.g. battery at a fifth or below.
    static let warning = Color(uiColor: .systemOrange)
    /// Failed or nearly exhausted, e.g. disconnected, battery at a tenth or below.
    static let critical = Color(uiColor: .systemRed)
    /// Not known, e.g. a battery level the system does not report.
    static let neutral = Color(uiColor: .secondaryLabel)
}
