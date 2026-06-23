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

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<totalChapters, id: \.self) { i in
                Text(romanNumeral(i + 1))
                    .font(.layaBody(13, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(Color.copper.opacity(i < filledCount ? 1.0 : 0.32))

                if i < totalChapters - 1 {
                    Rectangle()
                        .fill(Color.copper.opacity(i < filledCount - 1 ? 0.7 : 0.25))
                        .frame(width: 28, height: 1)
                }
            }
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
