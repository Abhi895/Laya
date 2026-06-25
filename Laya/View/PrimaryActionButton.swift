//
//  PrimaryActionButton.swift
//  Laya
//
//  Created by Abhi Reddy on 18/06/2026.
//

import SwiftUI

/// The app's primary call-to-action — the grounded, full-width capsule used for
/// the journey-entry actions: "Begin" on the first-visit reveal and "Continue"
/// on return visits. Centralised here so the two can never drift apart in font,
/// padding, fill, or shadow; callers supply only the title and action and set
/// the surrounding width via their own horizontal padding.
struct PrimaryActionButton: View {
    let title: String
    /// Fill colour for the capsule. Defaults to `.textPrimary` (espresso brown).
    /// Pass `.copper` for the dark locked screen's Follow CTA.
    var background: Color = .textPrimary
    /// Optional leading glyph — e.g. the Spotify mark for "Stream" CTAs.
    /// Template-rendered in the same cream as the title so it never needs
    /// its own color decision.
    var icon: Image? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    icon
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
                Text(title)
                    .font(.layaBody(17, weight: .semibold))
            }
            .foregroundStyle(.cream)
            // Full-width within the caller's column; height stays
            // padding-driven so it scales with Dynamic Type.
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(background))
        }
        // Tactile press: the whole capsule dips and dims, springing back on
        // release, felt as well as seen via PressableButtonStyle's haptic.
        .buttonStyle(PressableButtonStyle())
    }
}

// Shrinks and dims the label while pressed, springing back on release, with a
// light haptic on press-down. Shared with SecondaryActionButton and
// CircleButton so every button in the app feels identical to the touch.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6),
                       value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { Haptics.tap() }
            }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 24) {
        PrimaryActionButton(title: "Begin") {}
        PrimaryActionButton(title: "Continue") {}
    }
    .padding(.horizontal, 56)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.cream)
}
#endif
