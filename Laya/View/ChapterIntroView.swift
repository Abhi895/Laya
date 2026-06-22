//
//  ChapterIntroView.swift
//  Laya
//
//  Created by Abhi Reddy on 19/06/2026.
//

import SwiftUI

/// Full-screen chapter title card — the ritual "opening" between the home
/// screen and the video player.
///
/// - First entry ("Begin"): shows the chapter's own subtitle tagline.
/// - Return entry ("Continue"): shows "Pick up where you left off."
///
/// The screen crossfades in (driven by RootView), then its three lines —
/// numeral, title, and the coupled divider + subtitle — cascade in quickly.
/// The instant the last line settles it holds half a second, then crossfades
/// the whole view into the player. Tap anywhere to skip straight to the player.
struct ChapterIntroView: View {
    let chapter: Chapter
    let isResume: Bool
    // Called once the intro has finished its cascade (or the user taps to skip),
    // so the owning JourneySessionView can crossfade on to the player.
    let onAdvance: () -> Void

    @AppStorage("hasBegunJourney") private var hasBegunJourney = false

    // Cascade beats — each fades its line in on a short stagger.
    @State private var showNumeral = false
    @State private var showTitle = false
    @State private var showSubtitle = false

    // MARK: - Cascade timing

    // Let the whole-view crossfade settle before the text begins arriving.
    private let cascadeStart = 0.8
    // Gap between each cascade beat — quick, like the home reveal waterfall.
    private let beatGap = 0.3
    // How long each line takes to fade in.
    private let beatFade = 0.55
    // Beat the last line holds, fully settled, before advancing to the player —
    // long enough to read the subtitle and register the chapter you're entering.
    private let holdAfter = 1.5
    // How long to wait before latching `hasBegunJourney`. Must be ≥ RootView's
    // entry-crossfade duration (1.1s) so the intro is fully opaque before the
    // HomeView → HomeReturnView swap happens behind it — otherwise the return
    // state flashes through the still-translucent intro on first "Begin".
    private let latchDelay = 1.2

    // Wall-clock moment the final line finishes its fade-in.
    private var lastBeatFinish: Double { cascadeStart + 2 * beatGap + beatFade }

    private var subtitle: String {
        isResume ? "Pick up where you left off." : chapter.subtitle
    }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()

                // Roman numeral + title + ornamental divider + subtitle.
                ChapterInfoBlock(
                    numeralText: romanNumeral(chapter.index + 1),
                    title: chapter.title,
                    subtitle: subtitle,
                    showNumeral: showNumeral,
                    showTitle: showTitle,
                    showSubtitle: showSubtitle
                )

            VStack {
                Spacer()
                Text("Tap to skip.")
                    .font(.layaBody(13, weight: .light))
                    .foregroundStyle(.ink.opacity(0.28))
                    .padding(.bottom, 52)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .task { await runIntro() }
    }

    // MARK: - Choreography

    private func runIntro() async {
        // Quick cascade: numeral → title → (divider + subtitle). Runs while the
        // whole view crossfades in over the home screen.
        withAnimation(.easeOut(duration: beatFade).delay(cascadeStart)) {
            showNumeral = true
        }
        withAnimation(.easeOut(duration: beatFade).delay(cascadeStart + beatGap)) {
            showTitle = true
        }
        withAnimation(.easeOut(duration: beatFade).delay(cascadeStart + 2 * beatGap)) {
            showSubtitle = true
        }

        // Wait until the entry crossfade has fully covered the home screen, then
        // latch the journey-begun flag — so the HomeView → HomeReturnView swap
        // behind the (now opaque) intro is invisible. Latching earlier shows the
        // return state through the still-translucent intro on first "Begin".
        try? await Task.sleep(for: .seconds(latchDelay))
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) { hasBegunJourney = true }

        // Hold once the last line settles, then advance to the player.
        let remaining = (lastBeatFinish + holdAfter) - latchDelay
        try? await Task.sleep(for: .seconds(max(0, remaining)))
        advance()
    }

    // MARK: - Helpers

    // Fire the advance callback exactly once — the cascade and a tap-to-skip can
    // both reach here, so guard against a double hand-off.
    @State private var advanced = false
    private func advance() {
        guard !advanced else { return }
        advanced = true
        onAdvance()
    }

    private func romanNumeral(_ value: Int) -> String {
        switch value {
        case 1: return "I"
        case 2: return "II"
        case 3: return "III"
        default: return "\(value)"
        }
    }
}

#if DEBUG
#Preview("Begin — Chapter I") {
    ChapterIntroView(chapter: .mockBackground, isResume: false, onAdvance: {})
}

#Preview("Continue — Chapter II") {
    ChapterIntroView(chapter: .mockMusic, isResume: true, onAdvance: {})
}
#endif
