//
//  Haptics.swift
//  Laya
//
//  Created by Abhi Reddy on 25/06/2026.
//

import SwiftUI
import UIKit

/// Most buttons in the app get their haptic via SwiftUI's own `.sensoryFeedback`
/// modifier directly (in `PressableButtonStyle`/`OnboardingPressStyle`, or via
/// `HapticOnlyButtonStyle` below) — it manages the Taptic Engine's prepare/fire
/// timing internally, which a hand-managed `UIImpactFeedbackGenerator` only
/// gets right if `prepare()` lands within ~1-2s of the actual fire. The one
/// thing `.sensoryFeedback` doesn't fit naturally is a continuously-ramping
/// haptic mid-gesture (the hold-to-reveal tick), so that one case still uses a
/// manual generator below, with `prepare()` called immediately before each
/// `impactOccurred()` (not after, which is the bug this file used to have).
enum Haptics {
    private static let ramp = UIImpactFeedbackGenerator(style: .medium)

    /// One tick in a ramping sequence — e.g. a hold gesture's tension
    /// building toward completion. `intensity` (0...1) controls how strong
    /// this particular tick reads; callers ramp it up over the gesture.
    static func tick(intensity: Double) {
        ramp.prepare()
        ramp.impactOccurred(intensity: intensity)
    }
}

/// A `.plain`-equivalent button style — no visual press effect — for buttons
/// that already have their own custom look (close icons, text links) and
/// just need a reliable tap haptic added without changing how they look.
struct HapticOnlyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { old, new in
                new
            }
    }
}
