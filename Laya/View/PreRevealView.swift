//
//  PreRevealView.swift
//  Laya
//
//  Created by Abhi Reddy on 18/06/2026.
//

import SwiftUI

struct PreRevealView: View {
    // The artist is hidden on this screen — we only use the (blurred) image.
    @State private var artist: Artist?
    // Lifted out of the card so the surrounding text can recede during the hold.
    @State private var holdProgress: CGFloat = 0

    private let service: AssignmentServing

    init(service: AssignmentServing) {
        self.service = service
        LayaFontRegistration.registerAll()
    }

    #if DEBUG
    init() {
        self.service = MockAssignmentService()
        LayaFontRegistration.registerAll()
    }
    #endif

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.top, 44)
                        // Recedes as the user commits to the hold. Dark ink text
                        // needs a deeper fade than the footer to read as dimming.
                        .opacity(1 - 0.50 * Double(holdProgress))

                    Spacer(minLength: 24)

                    RevealCard(width: geo.size.width * 0.72, holdProgress: $holdProgress)

                    Spacer(minLength: 20)

                    // Heavier bottom gap → card sits a touch above true centre,
                    // optically balancing the two-line tagline below.
                    Spacer(minLength: 0)
                        .frame(maxHeight: 36)

                    footer
                        .padding(.bottom, 54)
                        // The ambient copy fades furthest — the card takes the focus.
                        .opacity(1 - 0.60 * Double(holdProgress))
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await load() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("This week's")
                .font(.layaBody(15, weight: .light))
                .foregroundStyle(.ink.opacity(0.55))

            Text("Artist Journey")
                .font(.layaDisplay(40))
                .foregroundStyle(.ink)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 30) {
            Text("Your next favourite artist\nis waiting to be discovered.")
                .font(.layaDisplay(20))
                .foregroundStyle(.ink.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            DiamondDivider()
        }
    }

    // MARK: - Loading

    private func load() async {
        do {
            let package = try await service.fetchCurrentAssignment(for: "user-mock")
            artist = package.artist
        } catch {
            // No-op — UI-only screen.
        }
    }
}

// MARK: - Reveal card

private struct RevealCard: View {
    
    //TODO: add haptics
    let width: CGFloat
    // 0...1 fill of the ring as the user holds. Owned by the parent so the
    // surrounding text can recede in step with the hold.
    @Binding var holdProgress: CGFloat

    // Drives the breathing pulse on the "Hold to reveal." prompt while idle.
    @State private var pulse = false
    // Drives the slow, breathing blur on the obscured portrait.
    @State private var blur: CGFloat = 16
    // True for the duration of an active press.
    @State private var isHolding = false

    private let cornerRadius: CGFloat = 23
    // The ring is centred this far outside the card edge. The stroke starts
    // thin (a slight gap shows) and thickens to 2×this, so its inner edge grows
    // inward and meets the card edge exactly at completion — seamless, no gap.
    private let ringInset: CGFloat = 3
    // How long a full hold takes to fill the ring. Slow enough to feel the
    // tension build as the portrait clears.
    private let holdDuration: Double = 3.2

    // Portrait card — sized off the image's natural aspect ratio.
    private var height: CGFloat { width * 1.34 }

    // The prompt grows and brightens as the hold fills; breathes gently when idle.
    private var promptOpacity: Double {
        guard isHolding || holdProgress > 0 else { return pulse ? 1.0 : 0.45 }
        return 0.5 + 0.5 * Double(holdProgress)
    }
    private var promptScale: CGFloat {
        guard isHolding || holdProgress > 0 else { return pulse ? 1.0 : 0.94 }
        return 0.94 + 0.22 * holdProgress
    }

    var body: some View {
        ZStack {
            // Obscured artist photo — fills the card, aspect ratio preserved.
            Image("artistCard")
                .resizable()
                .scaledToFill()
                // Idle breathing blur, clearing toward sharp as the hold fills.
                .blur(radius: blur * (1 - holdProgress))

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

            VStack {
                // Week marker — sits at the top of the card.
                Text("WEEK 24 • 4 DAYS LEFT")
                    .font(.layaBody(11, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(.cream.opacity(0.85))
                    // Fades away as the portrait is revealed.
                    .opacity(1 - Double(holdProgress))
                    .padding(.top, 20)

                Spacer()

                Text("Hold to reveal.")
                    .font(.layaBody(15, weight: .regular))
                    .foregroundStyle(.cream)
                    // Soft shadow keeps the prompt legible as the portrait clears.
                    .shadow(color: .ink.opacity(0.55), radius: 6, x: 0, y: 1)
                    .opacity(promptOpacity)
                    .scaleEffect(promptScale)
                    .padding(.bottom, 22)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Defined edge — a thin rim so the card reads against the cream background.
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.cream.opacity(0.38), lineWidth: 2)
        )
        // Progress ring — sits just outside the card edge and fills as you hold.
        .overlay(progressRing)
        // Two layers: a soft ambient cast plus a tighter contact shadow so the
        // card reads as clearly lifted off the cream on a real screen.
        .shadow(color: Color.ink.opacity(0.45), radius: 30, x: 0, y: 24)
        .shadow(color: Color.ink.opacity(0.30), radius: 9, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .gesture(holdGesture)
        .onAppear {
            startIdlePulse()
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                blur = 22
            }
        }
    }

    // Restarts the breathing pulse on the prompt. The repeating animation gets
    // cancelled once a hold drives the same opacity/scale, so it must be
    // re-armed when the user lets go.
    private func startIdlePulse() {
        pulse = false
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    // MARK: - Hold-to-reveal ring

    private var progressRing: some View {
        // Traced from top-centre so the fill begins at the top of the card.
        TopCentreRoundedRect(cornerRadius: cornerRadius + ringInset)
            .trim(from: 0, to: holdProgress)
            // The traced line is solid copper from the first instant of the hold
            // (an empty trim draws nothing at rest, so no fade is needed). The
            // stroke thickens from a slight offset to flush against the card:
            // inner edge = ringInset − lineWidth/2, reaching 0 when lineWidth = 2×ringInset.
            .stroke(Color.copper, style: StrokeStyle(lineWidth: 2 + 2 * ringInset * holdProgress, lineCap: .round))
            .padding(-ringInset)
            // Glow blooms brighter and wider the longer the user holds.
            .shadow(color: .copper.opacity(0.85 * Double(holdProgress)), radius: 19 * holdProgress)
            .shadow(color: .copper.opacity(0.72 * Double(holdProgress)), radius: 9 * holdProgress)
            .shadow(color: .copper.opacity(0.6 * Double(holdProgress)), radius: 4 * holdProgress)
    }

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isHolding else { return }
                isHolding = true
                withAnimation(.easeInOut(duration: holdDuration)) {
                    holdProgress = 1
                }
            }
            .onEnded { _ in
                isHolding = false
                // Release before completion → ring unwinds back to empty.
                // Duration scales with how far it filled so the line is always
                // visibly traced back to its top-centre start.
                let unwind = max(0.5, Double(holdProgress) * 1.3)
                withAnimation(.easeInOut(duration: unwind)) {
                    holdProgress = 0
                }
                // Re-arm the idle breathing the prompt falls back to.
                startIdlePulse()
            }
    }
}

// MARK: - Ring path

// A rounded-rectangle perimeter traced clockwise starting at top-centre, so a
// trim fills from the top of the card rather than the right edge.
private struct TopCentreRoundedRect: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r,
                 startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return p
    }
}

// MARK: - Decorative divider

// A small diamond flanked by two thin lines.
private struct DiamondDivider: View {
    var body: some View {
        HStack(spacing: 14) {
            line
            Diamond()
                .fill(Color.copper)
                .frame(width: 9, height: 9)
            line
        }
        .frame(maxWidth: 190)
    }

    private var line: some View {
        Rectangle()
            .fill(Color.copper.opacity(0.55))
            .frame(height: 1.5)
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    PreRevealView()
}
