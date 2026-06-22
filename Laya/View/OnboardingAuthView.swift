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
                Image("logo")
                    .resizable()
                    .scaledToFit()
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

private struct OnboardingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

#if DEBUG
#Preview {
    OnboardingAuthView()
}
#endif
