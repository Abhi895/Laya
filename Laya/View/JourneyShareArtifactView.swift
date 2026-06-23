//
//  JourneyShareArtifactView.swift
//  Laya
//
//  Created by Abhi Reddy on 23/06/2026.
//

import SwiftUI

/// The shareable "journey complete" card — a static, fixed-size artifact
/// rendered both live (in the in-app preview) and headlessly via
/// `ImageRenderer` for the share sheet. No animation/state: it always
/// renders fully landed, since it's never shown mid-cascade.
struct JourneyShareArtifactView: View {
    let artist: Artist
    var totalChapters: Int = 3

    static let cardWidth: CGFloat = 360
    static let cardHeight: CGFloat = 552
    private static let cornerRadius: CGFloat = 23
    private static let photoHeight: CGFloat = 360
    private static let gradientHeight: CGFloat = 760

    var body: some View {
        ZStack(alignment: .top) {
            photo
            topRow
                .padding(.horizontal, 20)
                .padding(.top, 18)
            bottomPanel
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight, alignment: .top)
        .background(Color.ink)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }

    // MARK: - Photo + seamless fade

    // Same proven pattern as ChapterCompleteView's locked screen: photo +
    // a taller gradient, flattened with .compositingGroup() before any
    // opacity/clip further up the tree, so the gradient's solid-ink tail
    // can't be weakened and let the photo's clipped edge bleed through.
    // Warm copper-tinted stops instead of grayscale/ink-only, so the fade
    // itself reads warm rather than gray.
    private var photo: some View {
        ZStack(alignment: .top) {
            Image("artistCard")
                .resizable()
                .scaledToFill()
                .frame(width: Self.cardWidth, height: Self.photoHeight)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 140 / 1000),
                    .init(color: Color.copper.opacity(0.22), location: 300 / 1000),
                    .init(color: Color.ink.opacity(0.45), location: 380 / 1000),
                    .init(color: Color.ink.opacity(0.78), location: 430 / 1000),
                    .init(color: Color.ink.opacity(0.93), location: 470 / 1000),
                    .init(color: Color.ink, location: 500 / 1000),
                    .init(color: Color.ink, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: Self.cardWidth, height: Self.gradientHeight)
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight, alignment: .top)
        .clipped()
        .compositingGroup()
    }

    // MARK: - Top row

    private var topRow: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Image("logo")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.cream)
                Text("Laya")
                    .font(.layaDisplay(15))
                    .foregroundStyle(.cream)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("Journey\nComplete")
                    .font(.layaBody(10, weight: .medium))
                    .tracking(2.2)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.cream)
                CopperDivider(width: 46)
            }
        }
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(artist.city.uppercased()) • \(artist.genre.uppercased())")
                .font(.layaBody(11, weight: .medium))
                .tracking(2.4)
                .foregroundStyle(.copper)

            Text(artist.name)
                .font(.layaDisplay(48))
                .foregroundStyle(.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 4)

            CopperDivider(width: 70)
                .padding(.vertical, 14)

            Text("\u{201C}\(artist.quote)\u{201D}")
                .font(.layaBody(15, weight: .light))
                .italic()
                .foregroundStyle(.cream.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 22)

            RomanProgressRow(totalChapters: totalChapters, filledCount: totalChapters)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}

#if DEBUG
#Preview {
    JourneyShareArtifactView(artist: .mock)
        .padding(40)
        .background(Color.cream)
}
#endif
