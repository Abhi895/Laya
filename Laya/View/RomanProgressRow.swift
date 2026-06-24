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

    // Both the numerals and dashes glow via this one shadow stack, so the
    // whole row reads as a single uniform glow rather than two different
    // effects that happen to be the same color. Capsule's rounded caps and
    // Text's organic glyph shapes both take a direct .shadow() cleanly (no
    // boxy-silhouette risk — that only showed up with Rectangle's hard
    // corners) so neither needs the old blurred-duplicate-behind trick.
    @ViewBuilder
    private func glow<Content: View>(_ content: Content, baseOpacity: Double) -> some View {
        if glowIntensity > 0 {
            content
                .shadow(color: .copper.opacity(min(1, baseOpacity * glowIntensity)), radius: 4)
                .shadow(color: .copper.opacity(min(1, baseOpacity * 0.7 * glowIntensity)), radius: 2)
                .shadow(color: .copper.opacity(min(1, baseOpacity * 0.5 * glowIntensity)), radius: 1)
        } else {
            content
        }
    }

    private func numeral(_ index: Int) -> some View {
        let filled = index < filledCount
        let text = Text(romanNumeral(index + 1))
            .font(.layaDisplay(13))
            .tracking(1)
            .foregroundStyle(Color.copper.opacity(filled ? 1.0 : 0.32))
        return glow(text, baseOpacity: filled ? 1.0 : 0.5)
    }

    private func dash(filled: Bool) -> some View {
        let line = Capsule()
            .fill(Color.copper.opacity(filled ? 0.7 : 0.25))
            .frame(height: 1)
        return glow(line, baseOpacity: filled ? 1.0 : 0.5)
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
