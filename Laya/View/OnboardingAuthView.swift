//
//  OnboardingAuthView.swift
//  Laya
//
//  Created by Codex on 21/06/2026.
//

import SwiftUI

/// First-run authentication screen.
///
/// Matches the launch mockup: quiet cream canvas, centred Laya mark, Spotify as
/// the primary route, guest as the secondary route, and a small legal footer.
struct OnboardingAuthView: View {
    var onSpotify: () -> Void = {}
    var onGuest: () -> Void = {}

    init(onSpotify: @escaping () -> Void = {},
         onGuest: @escaping () -> Void = {}) {
        self.onSpotify = onSpotify
        self.onGuest = onGuest
        LayaFontRegistration.registerAll()
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    brand
                        .frame(height: geo.size.height * 0.50, alignment: .center)

                    Spacer(minLength: 0)

                    actions
                        .padding(.horizontal, 48)

                    terms
                        .padding(.horizontal, 28)
                        .padding(.top, 36)
                        .padding(.bottom, max(8, geo.safeAreaInsets.bottom + 6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var brand: some View {
        VStack(spacing: 14) {
            
            VStack(spacing: -24) {
                GrowingLogoMark()
                    .frame(width: 90, height: 90)

                Text("Laya")
                    .font(.layaDisplay(56))
                    .foregroundStyle(.ink)
                    .padding(.top, -4)
            }

            Text("One artist. One journey. Every week.")
                .font(.layaBody(17, weight: .regular))
                .foregroundStyle(.ink.opacity(0.58))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }

    private var actions: some View {
        VStack(spacing: 22) {
            Button(action: onSpotify) {
                HStack(spacing: 14) {
                    Image("spotify")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.cream)
                        .frame(width: 30, height: 30)

                    Text("Continue with Spotify")
                        .font(.layaBody(17, weight: .regular))
                        .foregroundStyle(.cream)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Capsule().fill(Color.textPrimary))
                .shadow(color: .ink.opacity(0.34), radius: 12, x: 0, y: 8)
            }
            .buttonStyle(OnboardingPressStyle())

            divider

            Button(action: onGuest) {
                Text("Continue as guest")
                    .font(.layaBody(17, weight: .regular))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        Capsule()
                            .stroke(Color.textPrimary, lineWidth: 1.3)
                    )
                    .shadow(color: .ink.opacity(0.16), radius: 9, x: 0, y: 5)
            }
            .buttonStyle(OnboardingPressStyle())
        }
    }

    private var divider: some View {
        HStack(spacing: 22) {
            Rectangle()
                .fill(Color.ink.opacity(0.48))
                .frame(height: 1)

            Text("or")
                .font(.layaBody(14, weight: .light))
                .foregroundStyle(.ink.opacity(0.5))

            Rectangle()
                .fill(Color.ink.opacity(0.48))
                .frame(height: 1)
        }
    }

    private var terms: some View {
        Text("By continuing, you agree to our Terms of Service and Privacy Policy.")
            .font(.layaBody(10, weight: .light))
            .foregroundStyle(.ink.opacity(0.42))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Animated logo mark

/// Reproduces the two leaf shapes from the brand mark (Logo.svg, 386×367
/// viewBox) as live vector paths instead of the static raster asset, so each
/// petal can grow from their shared joint into its exact final shape on
/// first appearance — the bedroom-discovery ritual starting the moment the
/// app opens, not just once a journey is revealed.
struct GrowingLogoMark: View {
    @State private var stemGrown = false
    @State private var leafGrown = false

    // Where the two petals actually meet in the source artwork (the ink
    // petal's base ≈ (148.2, 250.7), the copper petal's tip ≈ (147.5, 250.2)
    // — nearly the same point), expressed as a fraction of the 386×367
    // viewBox so scaleEffect can anchor growth there regardless of frame size.
    private static let joint = UnitPoint(x: 147.85 / 386, y: 250.44 / 367)

    var body: some View {
        ZStack {
            LogoStemShape()
                .fill(Color.ink)
                .scaleEffect(stemGrown ? 1 : 0.02, anchor: Self.joint)
            LogoLeafShape()
                .fill(Color.copper)
                .scaleEffect(leafGrown ? 1 : 0.02, anchor: Self.joint)
        }
        .aspectRatio(386.0 / 367.0, contentMode: .fit)
        .onAppear {
            // Slow, deliberate growth — like a flower's petals actually
            // unfurling, not a quick pop-in. Stem grows first and is
            // mostly settled before the leaf starts, so the two read as a
            // sequence rather than a simultaneous scale-up. Low damping
            // means each one overshoots noticeably past full size before
            // settling, giving a pronounced little spring/bounce at the end.
            withAnimation(.spring(response: 1.4, dampingFraction: 0.66).delay(0.2)) {
                stemGrown = true
            }
            withAnimation(.spring(response: 1.3, dampingFraction: 0.66).delay(0.5)) {
                leafGrown = true
            }
        }
    }
}

/// The tall ink petal — exact path from Logo.svg.
private struct LogoStemShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 164.81, y: 200.474))
        path.addCurve(to: CGPoint(x: 148.224, y: 250.706),
                      control1: CGPoint(x: 167.142, y: 260.42),
                      control2: CGPoint(x: 152, y: 252))
        path.addCurve(to: CGPoint(x: 111.918, y: 153.645),
                      control1: CGPoint(x: 135.379, y: 241.691),
                      control2: CGPoint(x: 121.936, y: 215.507))
        path.addCurve(to: CGPoint(x: 124.706, y: 45.6981),
                      control1: CGPoint(x: 102.592, y: 96.0544),
                      control2: CGPoint(x: 117.422, y: 48.8309))
        path.addCurve(to: CGPoint(x: 164.81, y: 200.474),
                      control1: CGPoint(x: 135.904, y: 47.8831),
                      control2: CGPoint(x: 162.649, y: 144.895))
        path.closeSubpath()
        return path.applying(Self.scaleTransform(for: rect))
    }

    fileprivate static func scaleTransform(for rect: CGRect) -> CGAffineTransform {
        let scale = min(rect.width / 386, rect.height / 367)
        return CGAffineTransform(scaleX: scale, y: scale)
    }
}

/// The wide copper petal — exact path from Logo.svg.
private struct LogoLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 257.755, y: 241.811))
        path.addCurve(to: CGPoint(x: 147.471, y: 250.182),
                      control1: CGPoint(x: 200.776, y: 252.739),
                      control2: CGPoint(x: 156.579, y: 256.331))
        path.addCurve(to: CGPoint(x: 246.448, y: 198.104),
                      control1: CGPoint(x: 155.363, y: 240.172),
                      control2: CGPoint(x: 190.47, y: 218.009))
        path.addCurve(to: CGPoint(x: 345.387, y: 197.12),
                      control1: CGPoint(x: 300.397, y: 178.92),
                      control2: CGPoint(x: 342.753, y: 179.262))
        path.addCurve(to: CGPoint(x: 257.755, y: 241.811),
                      control1: CGPoint(x: 348.678, y: 219.43),
                      control2: CGPoint(x: 314.734, y: 230.882))
        path.closeSubpath()
        return path.applying(LogoStemShape.scaleTransform(for: rect))
    }
}

#if DEBUG
#Preview("Growing logo") {
    GrowingLogoMark()
        .frame(width: 160, height: 160)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cream)
}
#endif

private struct OnboardingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7),
                       value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { Haptics.tap() }
            }
    }
}

#if DEBUG
#Preview {
    OnboardingAuthView()
}
#endif
