//
//  Haptics.swift
//  Laya
//
//  Created by Abhi Reddy on 25/06/2026.
//

import SwiftUI
import UIKit
import CoreHaptics

/// A persistent, app-wide `CHHapticEngine` — ported from a proven-working
/// pattern in another project (Resonance's `HapticManager`) after both a
/// hand-managed `UIImpactFeedbackGenerator` and SwiftUI's `.sensoryFeedback`
/// failed silently on a real device.
///
/// The likely root cause of that silence: a `CHHapticEngine`/player created
/// fresh per call and left to go out of scope immediately after `start()` can
/// get torn down by ARC before the pattern actually reaches the Taptic Engine
/// — `.impactOccurred()`/`.sensoryFeedback` almost certainly hit the same
/// problem internally, just with no error surfaced since they fail silently
/// by design. Keeping one engine alive for the whole app session (instead of
/// transient instances), with a muted continuous player looping the entire
/// time to keep it permanently "hot," sidesteps that race entirely.
final class Haptics {
    static let shared = Haptics()

    private var engine: CHHapticEngine?
    private var keepAlivePlayer: CHHapticAdvancedPatternPlayer?

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            setupKeepAlive()

            // The system can stop/reset the engine at any time (backgrounding,
            // audio interruptions, etc.) — without restarting here, every
            // subsequent play call would silently do nothing.
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
                self?.setupKeepAlive()
            }
            engine?.stoppedHandler = { [weak self] _ in
                try? self?.engine?.start()
                self?.setupKeepAlive()
            }
        } catch {
            print("Haptics: engine init failed: \(error)")
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.engine?.start(completionHandler: { [weak self] error in
                if let error { print("Haptics: restart on foreground failed: \(error)") }
                else { self?.setupKeepAlive() }
            })
        }
    }

    // A near-silent continuous event, looped forever, keeps the engine
    // actively running rather than idling — every discrete tap then lands on
    // an engine that's already warm instead of racing its startup.
    private func setupKeepAlive() {
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ],
            relativeTime: 0,
            duration: 3600
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            keepAlivePlayer = try engine?.makeAdvancedPlayer(with: pattern)
            keepAlivePlayer?.loopEnabled = true
            let mute = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: 0.0, relativeTime: 0)
            try keepAlivePlayer?.sendParameters([mute], atTime: 0)
            try keepAlivePlayer?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Haptics: keep-alive setup failed: \(error)")
        }
    }

    private func play(intensity: Float, sharpness: Float) {
        guard let engine else { return }
        let params = [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ]
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: params, relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Haptics: play failed: \(error)")
        }
    }

    /// Routine button tap — every CTA and icon button in the app.
    static func tap() {
        shared.play(intensity: 0.7, sharpness: 0.5)
    }

    /// A meaningful completion — the hold-to-reveal finishing, a journey
    /// finishing. Heavier and duller than a routine tap so it reads as a release.
    static func success() {
        shared.play(intensity: 1.0, sharpness: 0.3)
    }

    /// One tick in a ramping sequence — e.g. a hold gesture's tension
    /// building toward completion. `intensity` (0...1) controls how strong
    /// this particular tick reads; callers ramp it up over the gesture.
    static func tick(intensity: Double) {
        shared.play(intensity: Float(intensity), sharpness: 0.5)
    }
}

/// A `.plain`-equivalent button style — no visual press effect — for buttons
/// that already have their own custom look (close icons, text links) and
/// just need a reliable tap haptic added without changing how they look.
struct HapticOnlyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { Haptics.tap() }
            }
    }
}
