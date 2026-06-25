//
//  ArtistCard.swift
//  Laya
//
//  Created by Abhi Reddy on 18/06/2026.
//

import SwiftUI

/// Presentational artist portrait card — the shared visual used on both the
/// home reveal screen and the completion screen. It renders the (optionally
/// blurred) portrait, the legibility gradients, and the lower-left identity
/// block. It carries no interaction: callers layer the ring / prompt / gesture
/// on top via `.overlay`.
struct ArtistCard: View {
    let width: CGFloat
    let artist: Artist?
    /// Portrait blur. 0 = sharp. The home screen drives this toward 0 as the
    /// hold fills; the completion screen holds it soft.
    var blurRadius: CGFloat = 0
    /// Portrait colour. 0 = fully grayscale, 1 = full colour. The home
    /// screen's pre-reveal card starts at 0 and drives this toward 1 in step
    /// with the hold — the artist coming into colour alongside coming into
    /// focus, both landing together as "discovered." Every other caller
    /// already knows the artist, so they default to full colour.
    var saturation: Double = 1
    /// Identity visibility — animated in during the home reveal, constant
    /// wherever the artist is already known.
    var showName: Bool = true
    var showMeta: Bool = false
    /// Whether the meta (city • genre) line participates in layout at all. The
    /// home card keeps it reserved (so the name doesn't jump when meta fades
    /// in); the completion card drops it entirely so the name sits at the base.
    var includesMeta: Bool = false

    /// Shared so callers (e.g. the home ring overlay) trace the same corner.
    static let cornerRadius: CGFloat = 23

    private var height: CGFloat { width * 1.34 }

    var body: some View {
        ZStack {
            // Obscured artist photo — constrained to the card size so the image
            // can't dictate the ZStack's layout and push the labels past the edges.
            Image(artist?.imageName ?? "artistCard")
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
                .blur(radius: blurRadius)
                .saturation(saturation)

            // Vignette — darkens the edges and draws the eye to the centre.
            RadialGradient(
                colors: [.clear, Color.ink.opacity(0.6)],
                center: .center,
                startRadius: width * 0.22,
                endRadius: width * 0.78
            )

            // Top + bottom darkening for label legibility.
            LinearGradient(
                colors: [.black.opacity(0.30), .clear, .clear, .black.opacity(0.32)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(width: width, height: height)
        .overlay(alignment: .bottomLeading) { identity }
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        // Defined edge — a thin rim so the card reads against the cream background.
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .stroke(Color.cream.opacity(0.38), lineWidth: 3)
        )
    }

    // MARK: - Identity

    // Lower-left identity block. Name first, then an optional city • genre line.
    // Each rises slightly as it fades in (driven by the show flags), so the home
    // reveal can stagger them; static callers just pass the flags as constants.
    private var identity: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(artist?.name ?? "")
                .font(.layaDisplay(32))
                .foregroundStyle(.cream)
                .opacity(showName ? 1 : 0)
                .offset(y: showName ? 0 : 18)

            if includesMeta {
                Text("\(artist?.city ?? "") • \(artist?.genre ?? "")")
                    .font(.layaBody(14, weight: .medium))
                    .foregroundStyle(.copper)
                    .opacity(showMeta ? 1 : 0)
                    .offset(y: showMeta ? 0 : 14)
            }
        }
        // Soft shadow keeps the text legible over lighter areas of the portrait.
        .shadow(color: .ink.opacity(0.5), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 25)
        .padding(.bottom, 25)
    }
}

#if DEBUG
#Preview("Home variant — sharp, name + meta") {
    ArtistCard(width: 300, artist: .mock, blurRadius: 0,
               showName: true, showMeta: true, includesMeta: true)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cream)
}

#Preview("Completion variant — soft, name only") {
    ArtistCard(width: 300, artist: .mock, blurRadius: 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cream)
}
#endif
