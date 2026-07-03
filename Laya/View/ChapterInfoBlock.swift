//
//  ChapterInfoBlock.swift
//  Laya
//
//  Created by Abhi Reddy on 21/06/2026.
//

import SwiftUI

/// The copper-diamond ornamental rule used to separate chapter identity lines.
struct CopperDivider: View {
    var width: CGFloat = 140

    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color.copper).frame(height: 0.5)
            Image(systemName: "diamond.fill")
                .font(.system(size: 5))
                .foregroundStyle(Color.copper)
            Rectangle().fill(Color.copper).frame(height: 0.5)
        }
        .frame(width: width)
    }
}

/// The editorial chapter-identity block: large roman numeral, title, the
/// copper-diamond divider, and a modifiable subtext line.
///
/// Animation is driven by the parent via three separate visibility flags —
/// one per cascade beat. Default to `true` (fully visible) when no animation
/// is needed.
struct ChapterInfoBlock: View {
    let numeralText: String
    let title: String
    let subtitle: String

    var showNumeral: Bool = true
    var showTitle: Bool = true
    var showSubtitle: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            Text(numeralText)
                .font(.layaDisplay(88))
                .foregroundStyle(.ink)
                .opacity(showNumeral ? 1 : 0)
                .offset(y: showNumeral ? 0 : 12)

            Text(title)
                .font(.layaDisplay(46))
                .foregroundStyle(.ink)
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 12)

            Group {
                CopperDivider()
                    .padding(.vertical, 18)

                Text(subtitle)
                    .font(.layaBody(17, weight: .light))
                    .foregroundStyle(.ink.opacity(0.45))
            }
            .opacity(showSubtitle ? 1 : 0)
            .offset(y: showSubtitle ? 0 : 12)
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color.cream.ignoresSafeArea()
        ChapterInfoBlock(
            numeralText: "II",
            title: "The Music",
            subtitle: "Where Tayo found his sound."
        )
    }
}
#endif
