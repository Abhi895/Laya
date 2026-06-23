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
    // When > 0, the connecting dashes glow (matching the home screen's
    // hold-to-reveal ring), at this intensity (0...1). Applied to each dash
    // individually rather than as one full-width background — glowing the
    // whole row at once bleeds light straight through the gaps either side
    // of the numerals, erasing the spacing between them.
    var glowIntensity: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<totalChapters, id: \.self) { i in
                Text(romanNumeral(i + 1))
                    .font(.layaDisplay(13))
                    .tracking(1)
                    .foregroundStyle(Color.copper.opacity(i < filledCount ? 1.0 : 0.32))

                if i < totalChapters - 1 {
                    dash(filled: i < filledCount - 1)
                }
            }
        }
    }

    @ViewBuilder
    private func dash(filled: Bool) -> some View {
        let line = Rectangle()
            .fill(Color.copper.opacity(filled ? 0.7 : 0.25))
            .frame(height: 1)
        if glowIntensity > 0 {
            line
                .shadow(color: .copper.opacity(0.85 * glowIntensity), radius: 10)
                .shadow(color: .copper.opacity(0.65 * glowIntensity), radius: 5)
                .shadow(color: .copper.opacity(0.5 * glowIntensity), radius: 1.5)
        } else {
            line
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
