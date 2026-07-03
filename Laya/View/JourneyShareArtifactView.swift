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
    // Live preview only — the share image itself must render one fixed,
    // calm frame, never a mid-pulse one, so this defaults to false and is
    // only switched on by the on-screen instance in ShareArtifactPreviewView.
    
    var animated: Bool = false

    static let cardWidth: CGFloat = 360
    static let cardHeight: CGFloat = 552
    private static let cornerRadius: CGFloat = 23
    private static let photoHeight: CGFloat = 360
    private static let gradientHeight: CGFloat = 730

    // Drives the numeral row's "breathing" glow — toggled by a repeating
    // animation, only ever armed when `animated` is true.
    @State private var breathe = false

    var body: some View {
        ZStack(alignment: .top) {
            photo
            topScrim
            topRow
                .padding(.horizontal, 22)
                .padding(.top, 22)
            bottomPanel
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight, alignment: .top)
        .background(Color.ink)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    // Top-down darkening so the logo and "Journey Complete" eyebrow stay
    // legible regardless of how light the photo happens to be at that spot.
    private var topScrim: some View {
        LinearGradient(
            colors: [Color.ink.opacity(0.9), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: Self.cardWidth, height: 180, alignment: .top)
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
            // Scaled to fill a taller-than-needed rect first, then clipped down
            // to the real photo height anchored to the top — so any cropping
            // comes off the bottom (legs/torso), never the top (the head).
            Image(artist.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: Self.cardWidth, height: Self.photoHeight * 1.45)
                .frame(width: Self.cardWidth, height: Self.photoHeight, alignment: .top)
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
            VStack(alignment: .center, spacing: -5) {
                Image("logoDark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                Text("Laya")
                    .font(.layaDisplay(15))
                    .foregroundStyle(.cream)
            }

            Spacer()

            VStack(alignment: .center, spacing: 6) {
                Text("Journey\nComplete")
                    .font(.layaBody(10, weight: .medium))
                    .tracking(2.2)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
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
                .font(.layaDisplay(53))
                .foregroundStyle(.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 4)

            Rectangle()
                .frame(width: 20, height: 2)
                .foregroundStyle(.copper)
                .padding(.vertical, 14)

            Text("\u{201C}\(artist.displayQuote)\u{201D}")
                .font(.layaDisplay(17))
                .tracking(1)
                .foregroundStyle(.cream.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 22)

            // `breathe` (armed only when `animated`) pulses the dashes' glow
            // so the card reads as quietly alive; the shared image itself
            // always renders the resting (non-pulsed) intensity.
            RomanProgressRow(totalChapters: totalChapters, filledCount: totalChapters,
                              glow: breathe ? .breathing : .resting)
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
