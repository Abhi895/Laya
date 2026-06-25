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
///
/// Generators are reused and kept "primed" rather than allocated fresh per
/// call: a fresh `UIImpactFeedbackGenerator` that's never `prepare()`d has to
/// wake the Taptic Engine from cold before it can fire, which on real
/// hardware reads as the haptic simply not happening (especially for quick,
/// one-shot taps) — invisible in the Simulator since it has no Taptic Engine
/// to fail to wake, which is why this only showed up on a real device.
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)

    /// Call once at launch so the very first tap isn't the one paying the
    /// Taptic Engine's cold-start cost.
    static func warmUp() {
        light.prepare()
        medium.prepare()
    }

    /// Routine button tap — every CTA and icon button in the app.
    static func tap() {
        light.impactOccurred()
        light.prepare()
    }

    /// A meaningful completion — the hold-to-reveal finishing, a journey
    /// finishing. Heavier than a routine tap so it reads as a release.
    static func success() {
        medium.impactOccurred()
        medium.prepare()
    }

    /// One tick in a ramping sequence — e.g. a hold gesture's tension
    /// building toward completion. `intensity` (0...1) controls how strong
    /// this particular tick reads; callers ramp it up over the gesture.
    static func tick(intensity: Double) {
        medium.impactOccurred(intensity: intensity)
        medium.prepare()
    }
}
