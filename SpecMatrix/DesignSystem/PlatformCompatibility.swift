//
//  PlatformCompatibility.swift
//  SpecMatrix
//

import SwiftUI

// Every OS-version check in the interface lives in this file. Screens call these wrappers and never
// contain `#available` themselves, so each screen has one implementation on every supported OS.
//
// iOS 26 and later get Liquid Glass from the system components themselves (tab bar, navigation bars,
// toolbars, alerts, menus). These wrappers only add the opt-in behaviours and styles that do not exist
// earlier. On iOS 17–18 they leave the standard appearance of those components untouched.

extension View {
    /// iOS 26+: asks the tab bar to shrink while scrolling down through content, giving the content more
    /// room. Earlier: the standard, always-expanded tab bar. Not observed to shrink on the iOS 26.0
    /// simulator; see docs/PHASE3_HANDOFF.md, F5.
    @ViewBuilder
    func specTabBarMinimizesOnScroll() -> some View {
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    /// iOS 26+: a subtitle under the navigation title. Earlier: no subtitle. Callers only pass
    /// information the screen also shows in its content, so before iOS 26 it is lost only while that
    /// content is hidden in Settings.
    @ViewBuilder
    func specNavigationSubtitle(_ subtitle: String?) -> some View {
        if #available(iOS 26.0, *), let subtitle {
            navigationSubtitle(Text(verbatim: subtitle))
        } else {
            self
        }
    }

    /// The style for a screen's main call to action. iOS 26+: Liquid Glass prominent.
    /// Earlier: bordered prominent. Both are tinted with the accent color.
    @ViewBuilder
    func specProminentButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}
