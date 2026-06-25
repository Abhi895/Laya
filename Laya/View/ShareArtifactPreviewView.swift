//
//  ShareArtifactPreviewView.swift
//  Laya
//
//  Created by Abhi Reddy on 23/06/2026.
//

import SwiftUI

/// Full-bleed in-app preview of the journey-complete share artifact — shown
/// before the native share sheet so the user sees exactly what they're about
/// to share. Presented via `.fullScreenCover` (not `.sheet`) so it matches
/// the rest of the app's edge-to-edge, no-system-chrome treatment.
struct ShareArtifactPreviewView: View {
    let artist: Artist
    let onDismiss: () -> Void

    @State private var renderedImage: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.ink.ignoresSafeArea()

                VStack(spacing: 28) {
                    closeButton

                    Spacer(minLength: 0)

                    // The live SwiftUI view, not the rendered UIImage — pixel-identical
                    // layout to what ImageRenderer produces, no flash-of-blank while
                    // the render completes. Scaled down (never up) to fit narrower
                    // screens — the card's fixed 360pt width is wider than the
                    // available space on e.g. an iPhone SE once this column's own
                    // padding is subtracted. Only the on-screen preview scales;
                    // the actual share image below is still rendered at full,
                    // untouched native size/quality.
                    JourneyShareArtifactView(artist: artist, animated: true)
                        .scaleEffect(previewScale(for: geo.size.width))
                        .frame(
                            width: JourneyShareArtifactView.cardWidth * previewScale(for: geo.size.width),
                            height: JourneyShareArtifactView.cardHeight * previewScale(for: geo.size.width)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)

                    Spacer(minLength: 0)

                    shareButton
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
        }
        .task {
            let renderer = ImageRenderer(content: JourneyShareArtifactView(artist: artist))
            renderer.scale = 3
            renderedImage = renderer.uiImage
        }
    }

    // 1:1 on any screen wide enough; shrinks just enough to fit narrower ones.
    // screenWidth, not the already-padded column width — the 32pt horizontal
    // padding on each side of the VStack is subtracted here instead.
    private func previewScale(for screenWidth: CGFloat) -> CGFloat {
        let available = screenWidth - 64
        return min(1, available / JourneyShareArtifactView.cardWidth)
    }

    // MARK: - Close

    private var closeButton: some View {
        HStack {
            Spacer()
            Button(action: { Haptics.tap(); onDismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.cream)
                    // 44×44pt minimum tap target (Apple HIG) — the glyph
                    // itself stays small, the tappable area doesn't.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Share

    @ViewBuilder
    private var shareButton: some View {
        if let renderedImage {
            ShareLink(
                item: Image(uiImage: renderedImage),
                preview: SharePreview("Journey complete", image: Image(uiImage: renderedImage))
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Share")
                        .font(.layaBody(17, weight: .semibold))
                }
                .foregroundStyle(.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(Color.copper))
            }
        } else {
            ProgressView()
                .tint(.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
    }
}

#if DEBUG
#Preview {
    ShareArtifactPreviewView(artist: .mock, onDismiss: {})
}
#endif
