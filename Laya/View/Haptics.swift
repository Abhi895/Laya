//
//  Haptics.swift
//  Laya
//
//  Created by Abhi Reddy on 25/06/2026.
//

import UIKit

/// Centralised haptic triggers so every tactile moment in the app uses one of
/// a small, intentional set of feelings instead of ad-hoc generator calls
/// scattered across every button.
enum Haptics {
    /// Routine button tap — every CTA and icon button in the app.
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// A meaningful completion — the hold-to-reveal finishing, a journey
    /// finishing. Heavier than a routine tap so it reads as a release.
    static func success() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// One tick in a ramping sequence — e.g. a hold gesture's tension
    /// building toward completion. `intensity` (0...1) controls how strong
    /// this particular tick reads; callers ramp it up over the gesture.
    static func tick(intensity: Double) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: intensity)
    }
}
