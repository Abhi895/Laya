//
//  HomeView.swift
//  Laya
//
//  Created by Abhi Reddy on 18/06/2026.
//

import SwiftUI

/// Visibility milestones of the post-reveal waterfall, in order: the name and
/// meta land on the card, then the bio, the Begin button, and finally the quiet
/// time-remaining line. Bundling them gives the screen a single source of truth
/// for "how far through the reveal are we" — `reset()`/`skip()` assign a preset
/// instead of flipping a half-dozen booleans by hand (and forgetting one).
///
/// Each milestone stays an independent flag (rather than a single ordered stage)
/// because the waterfall fades each element in with its own delayed animation —
/// and `withAnimation(.delay:)` commits state instantly, so a lone advancing
/// value couldn't gate five elements at five different wall-clock times.
struct RevealStages: Equatable {
    var name = false
    var meta = false
    var bio = false
    var button = false
    var timeLeft = false

    /// Pre-reveal: nothing has arrived yet.
    static let concealed = RevealStages()
    /// Fully revealed end-state (used by the debug skip).
    static let revealed = RevealStages(name: true, meta: true, bio: true,
                                       button: true, timeLeft: true)
}

struct HomeView: View {
    // The artist is hidden on this screen — we only use the (blurred) image.
    @State private var artist: Artist?
    // First chapter of the journey — passed to the chapter intro on Begin.
    @State private var firstChapter: Chapter = .mockBackground
    // Lifted out of the card so the surrounding text can recede during the hold.
    @State private var holdProgress: CGFloat = 0
    // Latched true once the hold completes and the artist is revealed.
    @State private var isRevealed = false
    // Bumped by the debug reset button to recreate the card with fresh state.
    @State private var resetToken = 0
    // The whole post-reveal waterfall — one source of truth, owned here so the
    // card and the footer stay in step and reset/skip can't drift apart.
    @State private var stages = RevealStages.concealed
    // Debug: makes the recreated card appear already revealed.
    @State private var skipRevealed = false

    private let service: AssignmentServing
    // Fired when "Begin" is tapped — carries the first chapter so RootView
    // can populate the chapter intro screen before presenting it.
    private let onBegin: (Chapter) -> Void
    private let onReset: () -> Void

    init(service: AssignmentServing,
         onBegin: @escaping (Chapter) -> Void = { _ in },
         onReset: @escaping () -> Void = {}) {
        self.service = service
        self.onBegin = onBegin
        self.onReset = onReset
        LayaFontRegistration.registerAll()
    }

    #if DEBUG
    init(onBegin: @escaping (Chapter) -> Void = { _ in },
         onReset: @escaping () -> Void = {}) {
        self.service = MockAssignmentService()
        self.onBegin = onBegin
        self.onReset = onReset
        LayaFontRegistration.registerAll()
    }
    #endif

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.top, 34)
                        // Recedes as the user commits to the hold, then snaps back
                        // into full focus the instant the artist is revealed.
                        .opacity(isRevealed ? 1 : 1 - 0.55 * Double(holdProgress))

                    Spacer(minLength: 50)

                    RevealCard(width: geo.size.width * 0.72,
                               artist: artist,
                               startRevealed: skipRevealed,
                               showName: stages.name,
                               showMeta: stages.meta,
                               holdProgress: $holdProgress,
                               isRevealed: $isRevealed)
                        .id(resetToken)

                    Spacer(minLength: 20)

                    // Heavier bottom gap → card sits a touch above true centre,
                    // optically balancing the two-line tagline below.
//                    Spacer(minLength: 0)
//                        .frame(maxHeight: 36)

                    ZStack {
                        // Pre-reveal tagline — fades away as the card takes focus.
                        footer
                            .opacity(isRevealed ? 0 : 1 - 0.60 * Double(holdProgress))
                            // Nudged up a notch off its centred resting spot.
                            .offset(y: -20)

                        // Post-reveal bio + Begin — fades in last in the waterfall.
                        postRevealFooter
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 54)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                #if DEBUG
                resetButton
                #endif
            }
        }
        .task { await load() }
        .onChange(of: isRevealed) { _, revealed in
            guard revealed else { return }
            runRevealWaterfall()
        }
    }

    // MARK: - Reveal choreography

    // The full post-reveal waterfall in one place: the name and meta fade onto
    // the card, then the bio, the Begin button, and finally the quiet
    // time-remaining line. A long initial beat lets the user simply sit with the
    // artist's face; the wide gap before the button gives time to read the bio.
    private func runRevealWaterfall() {
        withAnimation(.easeOut(duration: 0.9).delay(1.1)) { stages.name = true }
        withAnimation(.easeOut(duration: 0.9).delay(2.05)) { stages.meta = true }
        withAnimation(.easeOut(duration: 1.0).delay(3.3)) { stages.bio = true }
        withAnimation(.easeOut(duration: 1.0).delay(5.5)) { stages.button = true }
        withAnimation(.easeOut(duration: 1.2).delay(7.2)) { stages.timeLeft = true }
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

    // MARK: - Post-reveal footer

    // Bio then the Begin button — the final two stages of the reveal waterfall.
    private var postRevealFooter: some View {
        VStack(spacing: 0) {
            Text(artist?.bio ?? "")
                .font(.layaDisplay(18))
                .foregroundStyle(.ink.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                // Extra inset so the bio reads as a narrow centred column rather
                // than wrapping the full width.
                .padding(.horizontal, 20)
                .opacity(stages.bio ? 1 : 0)
                .offset(y: stages.bio ? 0 : 14)

            // Fixed gap (a plain Spacer won't expand in a content-sized VStack)
            // sets the bio → button distance.
            Spacer().frame(height: 42)

            // Same grounded full-width CTA as the return screen's "Continue", and
            // the same 24pt inset so both align to the card's column.
            PrimaryActionButton(title: "Begin", action: { onBegin(firstChapter) })
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .opacity(stages.button ? 1 : 0)
                .offset(y: stages.button ? 0 : 14)

            // Quiet time-remaining — sits below Begin so the info that left the
            // card on reveal still has a home, without competing with the CTA.
            Text("4 days left this week")
                .font(.layaBody(12, weight: .light))
                .foregroundStyle(.ink.opacity(0.4))
                .padding(.top, 5)
                .opacity(stages.timeLeft ? 1 : 0)
        }
    }

    #if DEBUG
    // MARK: - Debug reset

    // Testing-only: reset the screen, or skip straight to the revealed state.
    private var resetButton: some View {
        VStack {
            HStack {
                Spacer()
                debugIcon("forward.end.fill", label: "Debug: skip", action: skip)
                debugIcon("arrow.counterclockwise", label: "Debug: reset", action: reset)
                    .padding(.trailing, 16)
            }
            .padding(.top, 8)
            Spacer()
        }
    }

    private func debugIcon(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.ink.opacity(0.6))
                .frame(width: 44, height: 44)
                .background(Circle().fill(.ink.opacity(0.08)))
        }
        .accessibilityLabel(label)
    }

    private func reset() {
        // Recreating the card (via id) clears its private @State; the parent
        // bindings are reset here. No animation — snap straight back.
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            holdProgress = 0
            isRevealed = false
            stages = .concealed
            skipRevealed = false
            resetToken += 1
        }
    }

    private func skip() {
        // Jump straight to the fully-revealed end-state, no animation. The card
        // is recreated with startRevealed = true so its name/meta show instantly.
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            holdProgress = 1
            isRevealed = true
            stages = .revealed
            skipRevealed = true
            resetToken += 1
        }
    }
    #endif

    // MARK: - Loading

    private func load() async {
        do {
            let package = try await service.fetchCurrentAssignment(for: "user-mock")
            artist = package.artist
            if let chapter = package.journey.chapters.first {
                firstChapter = chapter
            }
        } catch {
            // No-op — UI-only screen.
        }
    }
}

// MARK: - Reveal card

private struct RevealCard: View {

    let width: CGFloat
    // The revealed artist — its identity fades onto the card after the hold.
    let artist: Artist?
    // Debug: when true the card appears already in its revealed end-state.
    var startRevealed: Bool = false
    // Identity visibility, owned by the parent's reveal waterfall and forwarded
    // to the ArtistCard so the whole sequence stays in one place.
    var showName: Bool = false
    var showMeta: Bool = false
    // 0...1 fill of the ring as the user holds. Owned by the parent so the
    // surrounding text can recede in step with the hold.
    @Binding var holdProgress: CGFloat
    // Latched true once the hold completes — owned by the parent so it can drive
    // the surrounding reveal sequence.
    @Binding var isRevealed: Bool

    // Drives the breathing pulse on the "Hold to reveal." prompt while idle.
    @State private var pulse = false
    // Drives the slow, breathing blur on the obscured portrait.
    @State private var blur: CGFloat = 16
    // True for the duration of an active press.
    @State private var isHolding = false
    // Drives the ramping haptic tick during a hold — cancelled on release so
    // it can't keep firing into a hold that's already unwinding.
    @State private var hapticTask: Task<Void, Never>?
    // Bumped on every hold start and every release. The hold's completion
    // captures the token it started with and only fires if it still matches —
    // so a released hold can't trigger the reveal via SwiftUI's completion
    // takeover (the unwind animation otherwise inherits the pending completion).
    @State private var holdToken = 0
    // When the current hold began — lets us recover the real fill fraction on
    // release (the model holdProgress is pinned at 1 for the whole hold).
    @State private var holdStart = Date()
    // Card scale — squeezes on hold, springs on reveal.
    @State private var cardScale: CGFloat = 1.0

    // Matches the shared card so the ring and hit-test trace the same corner.
    private let cornerRadius = ArtistCard.cornerRadius
    // The ring is centred this far outside the card edge. The stroke starts
    // thin (a slight gap shows) and thickens to 2×this, so its inner edge grows
    // inward and meets the card edge exactly at completion — seamless, no gap.
    private let ringInset: CGFloat = 3
    // How long a full hold takes to fill the ring. Slow enough to feel the
    // tension build as the portrait clears.
    private let holdDuration: Double = 3.2
    // Stretches the release unwind at every fill level so the ring returns a
    // little more slowly than it filled.
    private let unwindDurationScale: Double = 1.35

    // The prompt grows and brightens as the hold fills; breathes gently when idle.
    private var promptOpacity: Double {
        if isRevealed { return 0 }
        guard isHolding || holdProgress > 0 else { return pulse ? 1.0 : 0.45 }
        return 0.5 + 0.5 * Double(holdProgress)
    }
    private var promptScale: CGFloat {
        guard isHolding || holdProgress > 0 else { return pulse ? 1.0 : 0.94 }
        // Ease-in (back-loaded) growth: most of the scaling happens near the end
        // so the prompt visibly reaches full size right as the ring closes,
        // rather than appearing maxed while the ring is still filling.
        let eased = holdProgress * holdProgress
        return 0.94 + 0.22 * eased
    }

    var body: some View {
        // Shared portrait card; the home screen adds its own interactive chrome.
        ArtistCard(width: width,
                   artist: artist,
                   // Idle breathing blur, clearing toward sharp as the hold fills.
                   blurRadius: blur * (0.95 - holdProgress),
                   showName: showName,
                   showMeta: showMeta,
                   // Keep the meta line reserved so the name doesn't jump up when
                   // city • genre fades in mid-waterfall.
                   includesMeta: true)
            // Week marker + hold prompt — home-only, layered over the portrait.
            .overlay { cardChrome }
            // Progress ring — sits just outside the card edge and fills as you
            // hold. Vanishes instantly on reveal (no fade) so it doesn't linger
            // over the artist as the rest of the sequence plays.
            .overlay(progressRing.opacity(isRevealed ? 0 : 1).animation(nil, value: isRevealed))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .gesture(holdGesture)
            .scaleEffect(cardScale)
            .onAppear {
                // The revealed end-state (debug skip) needs no idle animation;
                // holdProgress is 1 so the portrait is already sharp. Otherwise
                // arm the idle pulse and breathing blur.
                guard !startRevealed else { return }
                startIdlePulse()
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    blur = 22
                }
            }
    }

    // MARK: - Card chrome

    // The week marker and the hold prompt — overlaid on the shared portrait card
    // and present only during the home reveal interaction.
    private var cardChrome: some View {
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
                // Snap out instantly the moment the ring fills — no fade.
                .animation(nil, value: isRevealed)
                .scaleEffect(promptScale)
                .padding(.bottom, 22)
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
                guard !isHolding, !isRevealed else { return }

                isHolding = true
                holdToken += 1
                holdStart = Date()
                let token = holdToken
                // Ramping haptic tick — speeds up and strengthens as the ring
                // fills, so the tension building visually is felt too. Checks
                // both the token and isRevealed each loop so a release or a
                // fresh hold cleanly stops the previous one.
                hapticTask?.cancel()
                hapticTask = Task {
                    while !Task.isCancelled, token == holdToken, !isRevealed {
                        let progress = min(1, Date().timeIntervalSince(holdStart) / holdDuration)
                        Haptics.tick(intensity: 0.3 + 0.7 * progress)
                        if progress >= 1 { break }
                        let interval = 0.22 - 0.16 * progress
                        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    }
                }
                // Squeeze the card down to register the press.
                withAnimation(.easeOut(duration: 0.2)) { cardScale = 0.97 }
                withAnimation(.easeInOut(duration: holdDuration)) {
                    holdProgress = 1
                } completion: {
                    // Ignore if this hold was released (or superseded) — the
                    // token will have moved on.
                    guard token == holdToken else { return }
                    completeReveal()
                }
            }
            .onEnded { _ in
                guard !isRevealed else { return }
                isHolding = false
                hapticTask?.cancel()
                // Invalidate the in-flight hold so its completion can't fire.
                holdToken += 1
                // Release before completion → ring unwinds back to empty.
                // The model holdProgress is pinned at 1, so derive how far the
                // ring actually filled from elapsed time, and scale the unwind to
                // that: a short tap snaps back quickly, a long hold traces all the
                // way home. Without this, every release crawled for a fixed 1.3s.
                let fill = min(1, Date().timeIntervalSince(holdStart) / holdDuration)
                // Scalar stretch so the return reads a touch more leisurely at
                // every fill level (tune to taste).
                let unwind = max(0.18, fill * 0.9) * unwindDurationScale
                withAnimation(.easeInOut(duration: unwind)) {
                    holdProgress = 0
                }
                // Release the squeeze and re-arm the idle breathing.
                withAnimation(.easeOut(duration: 0.25)) { cardScale = 1.0 }
                startIdlePulse()
            }
    }

    // MARK: - Reveal

    // Fires only when the ring fills while the user is still holding. Releases
    // the built tension: the card springs and the parent's reveal sequence
    // (driven by isRevealed) takes over the rest of the choreography.
    private func completeReveal() {
        guard isHolding, !isRevealed else { return }
        isHolding = false
        Haptics.success()

        // Drives the ring/prompt clear and the parent's header/footer transition
        // plus the waterfall (the parent observes isRevealed).
        withAnimation(.easeInOut(duration: 0.45)) {
            isRevealed = true
        }

        // Spring pop: 0.97 → 1.03 → 1.0 to release the tension of the hold.
        withAnimation(.spring(response: 0.26, dampingFraction: 0.5)) {
            cardScale = 1.03
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) {
                cardScale = 1.0
            }
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
    HomeView()
}

