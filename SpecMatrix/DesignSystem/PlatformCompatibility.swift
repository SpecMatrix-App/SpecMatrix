//
//  PlatformCompatibility.swift
//  SpecMatrix
//

import SwiftUI

// Every OS-version check in the interface lives in this file. Screens call these wrappers and never
// contain `#available` themselves, so each screen has one implementation on every supported OS.
//
// iOS 26 and later get Liquid Glass from the system components themselves (tab bar, navigation bars,
// toolbars, alerts, menus). These wrappers only add the opt-in behaviours that do not exist earlier.
// On iOS 17–18 they leave the standard appearance of those components untouched.

extension View {
    /// iOS 26+: the tab bar shrinks while scrolling down through content, giving the content more room.
    /// Earlier: the standard, always-expanded tab bar.
    @ViewBuilder
    func specTabBarMinimizesOnScroll() -> some View {
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    /// iOS 26+: a subtitle under the navigation title. Earlier: no subtitle. Callers only pass
    /// information that is also shown elsewhere on the screen, so nothing is lost before iOS 26.
    @ViewBuilder
    func specNavigationSubtitle(_ subtitle: String?) -> some View {
        if #available(iOS 26.0, *), let subtitle {
            navigationSubtitle(Text(verbatim: subtitle))
        } else {
            self
        }
    }
}
