//
//  RomanProgressRow.swift
//  Laya
//
//  Created by Abhi Reddy on 23/06/2026.
//

import SwiftUI

/// Shared roman-numeral helper — I/II/III for chapters 1-3, numeric fallback beyond.
func romanNumeral(_ value: Int) -> String {
    switch value {
    case 1: return "I"
    case 2: return "II"
    case 3: return "III"
    default: return "\(value)"
    }
}

/// "I —— II —— III" chapter-progress row — roman numerals separated by thin
/// copper dashes. Completed numerals (and the dashes between them) read at
/// full copper opacity; anything beyond `filledCount` is dimmed. Used by the
/// journey-finished screen and the share artifact, where every numeral is
/// always filled.
struct RomanProgressRow: View {
    let totalChapters: Int
    let filledCount: Int
    // The dashes glow (matching the home screen's hold-to-reveal ring) when
    // shown live in the share-artifact preview — `.resting`/`.breathing` are
    // its only two real intensities, so the caller picks one of those rather
    // than guessing a raw number. `.none` (the default) is what every other
    // context — e.g. a cream completion screen — actually wants.
    enum Glow { case none, resting, breathing }
    var glow: Glow = .none

    private var glowIntensity: Double {
        switch glow {
        case .none: 0
        case .resting: 0.6
        case .breathing: 1.0
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<totalChapters, id: \.self) { i in
                numeral(i)

                if i < totalChapters - 1 {
                    dash(filled: i < filledCount - 1)
                }
            }
        }
    }

    // Text glyphs are already organic shapes (not rectangular), so a direct
    // .shadow() reads as a clean glow with no boxy-silhouette risk — unlike
    // the dash, which needed the blurred-capsule-behind trick. Glowing the
    // numerals too (not just the dashes) keeps the whole row reading as one
    // cohesive warm strip, matching how the hold-to-reveal ring glows along
    // its entire path rather than select segments.
    @ViewBuilder
    private func numeral(_ index: Int) -> some View {
        let filled = index < filledCount
        let text = Text(romanNumeral(index + 1))
            .font(.layaDisplay(13))
            .tracking(1)
            .foregroundStyle(Color.copper.opacity(filled ? 1.0 : 0.32))
        if glowIntensity > 0 {
            text
                .shadow(color: .copper.opacity(0.8 * glowIntensity), radius: 5)
                .shadow(color: .copper.opacity(0.55 * glowIntensity), radius: 2.5)
        } else {
            text
        }
    }

    // A single blurred Capsule behind the crisp line, rather than several
    // stacked .shadow() layers on a Rectangle — shadows on a hard-cornered
    // shape leave a visible rectangular silhouette at the glow's edge;
    // rounded caps plus one soft blur read as a true glow instead.
    @ViewBuilder
    private func dash(filled: Bool) -> some View {
        let opacity = filled ? 0.7 : 0.25
        ZStack {
            if glowIntensity > 0 {
                Capsule()
                    .fill(Color.copper.opacity(opacity * glowIntensity))
                    .frame(height: 5)
                    .blur(radius: 3.5)
            }
            Capsule()
                .fill(Color.copper.opacity(opacity))
                .frame(height: 1)
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color.ink.ignoresSafeArea()
        RomanProgressRow(totalChapters: 3, filledCount: 3)
    }
}
#endif
