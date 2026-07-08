//
//  ChapterCompleteView.swift
//  Laya
//
//  Created by Abhi Reddy on 19/06/2026.
//

import SwiftUI

/// The cream "you finished a chapter" card, shown after the last clip of a
/// chapter plays out. It mirrors `ChapterIntroView`'s editorial cascade so the
/// chapter opens and closes with the same ritual, and takes one of three shapes:
///
/// - **Unlocked next chapter** → "UP NEXT" pinned to top, the next chapter's
///   `ChapterInfoBlock` centered on screen, and a Continue CTA at the bottom.
/// - **Locked next chapter** → "That's Chapter I.", a soft artist portrait, and a
///   come-back-in-N-days note with a Follow CTA.
/// - **Journey finished** (no next chapter) → a celebration close: headline,
///   sharp `ArtistCard`, filled progress row, Follow + Share Journey CTAs.
struct ChapterCompleteView: View {
    let completedChapter: Chapter
    /// The next chapter in the journey, or nil if this was the last.
    let nextChapter: Chapter?
    /// Whether `nextChapter` is already available to watch.
    let isNextUnlocked: Bool
    /// Whole days until `nextChapter` unlocks (only meaningful when locked).
    let daysUntilUnlock: Int
    /// The Monday that started this week's journey — used to compute the
    /// exact unlock timestamp and next-week date for notification scheduling.
    let weekStartDate: Date
    let artist: Artist?
    /// Total chapters in the journey — used for the progress dot row on the locked screen.
    var totalChapters: Int = 3
    /// Whether every chapter has actually been watched — the real source of
    /// truth for "the journey is done", computed once by the caller (see
    /// Journey/[Chapter].isComplete) rather than inferred here from `nextChapter`.
    var isJourneyComplete: Bool = false
    /// Whether every clip in `completedChapter` was actually watched — vs. merely
    /// reached via a phantom-page skip. Feeds `Variant.resolve` and the locked
    /// screen's progress tally (`chaptersGenuinelyDone`).
    let completedChapterFullyWatched: Bool

    /// Advance to the next chapter's intro (unlocked path only).
    var onContinue: () -> Void
    /// Leave the journey, back to Home.
    var onBackHome: () -> Void
    /// Demo only: jump straight to the journey-complete screen.
    var onSkipForDemo: (() -> Void)? = nil

    // Cascade beats — matched to ChapterIntroView's feel.
    // Unlocked:  5-beat — head → numeral → title → subtitle → actions.
    // Locked:    4-beat — head → mid (title block) → portrait → actions.
    // Finished:  4-beat — head → mid (card + progress) → actions → back home.
    @State private var showHead = false
    @State private var showNumeral = false   // unlocked only
    @State private var showTitle = false     // unlocked only
    @State private var showSubtitle = false  // unlocked only
    @State private var showMid = false       // locked / finished only
    @State private var showActions = false
    @State private var showBackHomeLink = false  // unlocked / locked / finished — trails the CTA above it
    @State private var showSharePreview = false

    private let cascadeStart = 0.8
    private let beatGap = 0.3
    private let beatFade = 0.55
    private let backHomeLinkGap = 0.15

    // Locked screen's cascade reads a beat slower/more spaced out than
    // unlocked/finished — there's more to take in (photo, title, dots, CTA).
    private let lockedCascadeStart = 1.1
    private let lockedBeatGap = 0.45
    private let lockedBeatFade = 0.7

    var body: some View {
        ZStack {
            // Locked screen is a full-bleed dark editorial; everything else is cream.
            (isLocked ? Color.ink : Color.cream).ignoresSafeArea()
            layoutContent
        }
        // Flattens the entire visual content — including the ignoresSafeArea color —
        // into one compositing layer so the parent's .transition(.opacity) fades the
        // full screen uniformly. Without this, the ignoresSafeArea extensions render
        // outside the view's nominal frame and can appear cream at the bottom during
        // the locked (ink) → chapter-intro (cream) crossfade.
        .compositingGroup()
        .task { await runCascade() }
        .fullScreenCover(isPresented: $showSharePreview) {
            if let artist {
                ShareArtifactPreviewView(artist: artist, onDismiss: { showSharePreview = false })
            }
        }
    }

    // MARK: - Layout

    @ViewBuilder
    private var layoutContent: some View {
        if isUnlocked {
            // "UP NEXT" pinned to top; ChapterInfoBlock centered; actions at bottom.
            VStack(spacing: 0) {
                Text("Up next")
                    .font(.layaBody(13, weight: .regular))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundStyle(.copper)
                    .padding(.top, 22)
                    .opacity(showHead ? 1 : 0)
                    .offset(y: showHead ? 0 : 12)

                Spacer(minLength: 0)

                ChapterInfoBlock(
                    numeralText: nextChapter.map { romanNumeral($0.index + 1) } ?? "",
                    title: nextChapter?.title ?? "",
                    subtitle: nextChapter?.subtitle ?? "",
                    showNumeral: showNumeral,
                    showTitle: showTitle,
                    showSubtitle: showSubtitle
                )

                Spacer(minLength: 0)

                actions
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 44)
        } else if isLocked {
            // Dark editorial layout: a height-capped photo fading into the ink
            // base beneath it, so the text panel always reads against solid
            // ink rather than against whatever the photo happens to show at
            // that height. Full colour, not grayscale — by the time this
            // screen shows, the artist has already been seen in colour in
            // the chapter just watched, so dimming it back to gray would be
            // undoing something already true rather than withholding it. A
            // copper-tinted stop ahead of the ink ramp (the same trick the
            // finished screen's share card uses) keeps any photo's palette
            // from clashing with this screen's copper/ink accent regardless
            // of its actual colours, without erasing the colour itself.
            GeometryReader { geo in
            ZStack(alignment: .top) {
                // ── Background: photo + seamless fade, framed and clipped to the
                // screen's exact bounds. The gradient is deliberately taller than any
                // real device so its solid-ink tail comfortably outlasts the fade with
                // no visible seam — but left unclipped, that oversized frame would
                // inflate this ZStack past geo.size and shove the content panel below
                // off the bottom of the screen. Capping the pair to geo.size keeps the
                // overflow from ever reaching layout; only what's actually on-screen draws.
                ZStack(alignment: .top) {
                    // Frame is fixed and explicit (not inferred from the image), so the
                    // source photo's own dimensions/aspect ratio can never affect this
                    // view's layout — only what's visible inside this exact box changes.
                    Image(artist?.imageName ?? "artistCard")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: 520)
                        .clipped()

                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: 110 / 1000),
                            .init(color: Color.copper.opacity(0.22), location: 280 / 1000),
                            .init(color: Color.ink.opacity(0.42), location: 360 / 1000),
                            .init(color: Color.ink.opacity(0.68), location: 425 / 1000),
                            .init(color: Color.ink.opacity(0.88), location: 470 / 1000),
                            .init(color: Color.ink, location: 500 / 1000),
                            .init(color: Color.ink, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: geo.size.width, height: 1000)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                .clipped()
                // Flatten photo + mask into one layer before fading. Without this,
                // SwiftUI fades each layer independently, weakening the gradient's
                // solid-ink tail mid-fade and letting the photo's clipped edge
                // bleed through as a visible seam against the ink background.
                .compositingGroup()
                .opacity(showHead ? 1 : 0)
                .animation(.easeOut(duration: lockedBeatFade).delay(lockedCascadeStart), value: showHead)

                // ── Content panel pinned to bottom ──
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    // "CHAPTER II · UNLOCKS WEDNESDAY"
                    Text(lockedNextEyebrow)
                        .font(.layaBody(11, weight: .regular))
                        .tracking(2.8)
                        .textCase(.uppercase)
                        .foregroundStyle(.copper)
                        .opacity(showMid ? 1 : 0)
                        .offset(y: showMid ? 0 : 12)

                    Spacer().frame(height: 10)

                    // Next chapter title — large editorial display
                    Text(nextChapter?.title ?? "")
                        .font(.layaDisplay(62))
                        .foregroundStyle(.cream)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .opacity(showMid ? 1 : 0)
                        .offset(y: showMid ? 0 : 12)

                    Spacer().frame(height: 6)

                    // Next chapter subtitle
                    Text(nextChapter?.subtitle ?? "")
                        .font(.layaBody(15, weight: .light))
                        .foregroundStyle(.cream.opacity(0.46))
                        .opacity(showMid ? 1 : 0)
                        .offset(y: showMid ? 0 : 12)

                    Spacer().frame(height: 34)

                    // Progress dots + label — hairline rings rather than flat filled
                    // blobs, so the indicator reads as a quiet editorial detail instead
                    // of a generic onboarding-style progress bar.
                    HStack(spacing: 10) {
                        ForEach(0..<totalChapters, id: \.self) { i in
                            Circle()
                                .strokeBorder(Color.cream.opacity(i < chaptersGenuinelyDone ? 0.85 : 0.28), lineWidth: 1)
                                .background(
                                    Circle()
                                        .fill(i < chaptersGenuinelyDone ? Color.cream.opacity(0.85) : Color.clear)
                                )
                                .frame(width: 5, height: 5)
                        }
                        Text("\(chaptersGenuinelyDone) of \(totalChapters) chapters done")
                            .font(.layaBody(10, weight: .regular))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundStyle(.cream.opacity(0.45))
                    }
                    .opacity(showActions ? 1 : 0)
                    .offset(y: showActions ? 0 : 12)

                    Spacer().frame(height: 58)

                    // Copper, not the default espresso fill: this screen's
                    // background is ink, and espresso-on-ink is too close in
                    // value to read clearly. Copper is already this screen's
                    // accent (the "Drops Thursday" eyebrow), so it reads as
                    // the dark screen's natural accent.
                    NotifyMeButton(
                        style: .primary(background: .copper),
                        label: "Notify me when it drops",
                        date: nextChapter?.unlockDate(weekStartDate: weekStartDate) ?? Date(),
                        notificationTitle: "Laya",
                        notificationBody: "\(firstName)'s next chapter just dropped."
                    )
                    .opacity(showActions ? 1 : 0)
                    .offset(y: showActions ? 0 : 12)

                    Spacer().frame(height: 20)

                    // Back home text link — lands last, after the CTA above it.
                    Button(action: onBackHome) {
                        Text("Back home")
                            .font(.layaBody(14, weight: .regular))
                            .foregroundStyle(.cream.opacity(0.3))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(HapticOnlyButtonStyle())
                    .opacity(showBackHomeLink ? 1 : 0)

                    if let skip = onSkipForDemo {
                        Button(action: skip) {
                            Text("Skip for demo")
                                .font(.layaBody(11, weight: .regular))
                                .foregroundStyle(.cream.opacity(0.18))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(HapticOnlyButtonStyle())
                        .padding(.top, 6)
                        .opacity(showBackHomeLink ? 1 : 0)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 34 + geo.safeAreaInsets.bottom)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .ignoresSafeArea()
            }
        } else {
            // Finished: celebration close — headline, sharp ArtistCard,
            // Follow + Share Journey CTAs, quiet back-home link.
            // Top-anchored: head + card sit at a fixed distance from the top
            // regardless of whether NotifyMeButton is visible below.
            VStack(spacing: 0) {
                head
                Spacer().frame(height: 58)
                finishedMiddle
                Spacer(minLength: 0)
                finishedActions
            }
            .padding(.horizontal, 32)
            .padding(.top, 52)
            .padding(.bottom, 44)
        }
    }

    // MARK: - Head (locked / finished only)

    @ViewBuilder
    private var head: some View {
        VStack(spacing: 0) {
            Text(eyebrow)
                .font(.layaBody(13, weight: .regular))
                .tracking(3)
                .textCase(.uppercase)
                .foregroundStyle(.copper)
                .padding(.bottom, 14)

            Text(headline)
                .font(.layaDisplay(headlineSize))
                .multilineTextAlignment(.center)
                .foregroundStyle(.ink)
        }
        .opacity(showHead ? 1 : 0)
        .offset(y: showHead ? 0 : 12)
    }

    // MARK: - Middle (finished only)

    @ViewBuilder
    private var finishedMiddle: some View {
        VStack(spacing: 22) {
            ArtistCard(width: 250, artist: artist, blurRadius: 0,
                       showName: true, showMeta: true, includesMeta: true)
        }
        .opacity(showMid ? 1 : 0)
        .offset(y: showMid ? 0 : 12)
    }

    // MARK: - Actions

    // Only ever reached for .unlocked (from layoutContent's "UP NEXT" branch) —
    // .locked and .finished build their own dedicated bottom panels.
    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 18) {
            PrimaryActionButton(title: "Continue", action: onContinue)
                .opacity(showActions ? 1 : 0)
                .offset(y: showActions ? 0 : 12)
            backHomeButton
                .opacity(showBackHomeLink ? 1 : 0)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Actions (finished only)

    @ViewBuilder
    private var finishedActions: some View {
        VStack(spacing: 18) {
            NotifyMeButton(
                style: .primary(background: .textPrimary),
                label: "Notify me about next week",
                date: Calendar.current.date(byAdding: .day, value: 7, to: weekStartDate) ?? weekStartDate,
                notificationTitle: "Laya",
                notificationBody: "Your next journey is ready."
            )
                .opacity(showActions ? 1 : 0)
                .offset(y: showActions ? 0 : 12)

            if artist != nil && isJourneyComplete {
                SecondaryActionButton(
                    title: "Share Journey",
                    icon: Image(systemName: "square.and.arrow.up"),
                    action: { showSharePreview = true }
                )
                .opacity(showActions ? 1 : 0)
                .offset(y: showActions ? 0 : 12)
            }

            backHomeButton
                .opacity(showBackHomeLink ? 1 : 0)
        }
        .padding(.horizontal, 24)
    }

    private var backHomeButton: some View {
        Button(action: onBackHome) {
            Text("Back home")
                .font(.layaBody(14, weight: .regular))
                .foregroundStyle(.ink.opacity(0.45))
        }
        .buttonStyle(HapticOnlyButtonStyle())
    }

    // MARK: - Choreography

    private func runCascade() async {
        if isLocked {
            withAnimation(.easeOut(duration: lockedBeatFade).delay(lockedCascadeStart)) {
                showHead = true
            }
            // Beat 2: eyebrow + title + subtitle panel
            withAnimation(.easeOut(duration: lockedBeatFade).delay(lockedCascadeStart + lockedBeatGap)) {
                showMid = true
            }
            // Beat 3: progress dots + Notify CTA + Back home link — all land
            // together so there's no window where Notify is tappable but the
            // only exit home isn't visible yet.
            withAnimation(.easeOut(duration: lockedBeatFade).delay(lockedCascadeStart + 2 * lockedBeatGap)) {
                showActions = true
                showBackHomeLink = true
            }
            return
        }

        withAnimation(.easeOut(duration: beatFade).delay(cascadeStart)) {
            showHead = true
        }
        if isUnlocked {
            // Mirror ChapterIntroView's waterfall: numeral → title → divider+subtitle.
            withAnimation(.easeOut(duration: beatFade).delay(cascadeStart + beatGap)) {
                showNumeral = true
            }
            withAnimation(.easeOut(duration: beatFade).delay(cascadeStart + 2 * beatGap)) {
                showTitle = true
            }
            withAnimation(.easeOut(duration: beatFade).delay(cascadeStart + 3 * beatGap)) {
                showSubtitle = true
            }
            withAnimation(.easeOut(duration: beatFade).delay(cascadeStart + 4 * beatGap)) {
                showActions = true
            }
            // Back home link only starts once Continue's own fade has fully
            // landed — the last thing to arrive, not overlapping with it.
            withAnimation(.easeOut(duration: beatFade).delay(cascadeStart + 4 * beatGap + beatFade + backHomeLinkGap)) {
                showBackHomeLink = true
            }
        } else {
            withAnimation(.easeOut(duration: beatFade).delay(cascadeStart + beatGap)) {
                showMid = true
            }
            withAnimation(.easeOut(duration: beatFade).delay(cascadeStart + 2 * beatGap)) {
                showActions = true
                showBackHomeLink = true
            }
        }
    }

    // MARK: - Variant + copy

    enum Variant: Equatable {
        case unlocked
        case locked(chapterFullyWatched: Bool)
        case finished(journeyFullyWatched: Bool)

        /// journeyFullyWatched dominates hasNextChapter — a genuinely-done journey
        /// is never shown a stale "up next" screen, mirroring the original guard's
        /// dead-end-avoidance intent, just now conditioned on the honest flag
        /// instead of firing unconditionally whenever nextChapter is nil.
        static func resolve(hasNextChapter: Bool, isNextUnlocked: Bool,
                             chapterFullyWatched: Bool, journeyFullyWatched: Bool) -> Variant {
            guard !journeyFullyWatched, hasNextChapter else {
                return .finished(journeyFullyWatched: journeyFullyWatched)
            }
            return isNextUnlocked ? .unlocked : .locked(chapterFullyWatched: chapterFullyWatched)
        }
    }

    private var variant: Variant {
        .resolve(hasNextChapter: nextChapter != nil, isNextUnlocked: isNextUnlocked,
                  chapterFullyWatched: completedChapterFullyWatched, journeyFullyWatched: isJourneyComplete)
    }

    private var isUnlocked: Bool { variant == .unlocked }

    private var isLocked: Bool {
        if case .locked = variant { return true }
        return false
    }

    private var eyebrow: String {
        switch variant {
        case .unlocked: return "Up next"
        case .locked(let watched):
            let numeral = romanNumeral(completedChapter.index + 1)
            return watched ? "Chapter \(numeral) complete" : "Chapter \(numeral)"
        case .finished(let watched): return watched ? "Journey complete" : "End of the week"
        }
    }

    private var headline: String {
        switch variant {
        case .unlocked: return ""
        case .locked: return "Complete."
        case .finished(let watched): return watched ? "That's \(artist?.name ?? "the artist")." : ""
        }
    }

    private var headlineSize: CGFloat { 44 }

    /// The just-completed chapter only counts toward the locked screen's tally if
    /// it was genuinely watched — reaching it via a phantom-page skip doesn't earn
    /// it. Earlier chapters keep the existing "reached" semantics; this fix is
    /// scoped to the chapter just completed, matching the narrow
    /// completedChapterFullyWatched signal.
    private var chaptersGenuinelyDone: Int {
        completedChapterFullyWatched ? completedChapter.index + 1 : completedChapter.index
    }

    /// "CHAPTER II • DROPS WEDNESDAY" — eyebrow on the dark locked screen.
    private var lockedNextEyebrow: String {
        guard let next = nextChapter else { return "" }
        return "Chapter \(romanNumeral(next.index + 1)) • Drops \(unlockDayName)"
    }

    private var unlockDayName: String {
        nextChapter?.unlockDayName(weekStartDate: weekStartDate) ?? "soon"
    }

    private var firstName: String {
        artist?.name.split(separator: " ").first.map(String.init) ?? "the artist"
    }

}

#if DEBUG
#Preview("Unlocked next") {
    ChapterCompleteView(
        completedChapter: .mockBackground,
        nextChapter: .mockMusic,
        isNextUnlocked: true,
        daysUntilUnlock: 0,
        weekStartDate: WeeklyAssignment.currentWeekStartDate(),
        artist: .mock,
        completedChapterFullyWatched: true,
        onContinue: {},
        onBackHome: {}
    )
}

#Preview("Locked next") {
    ChapterCompleteView(
        completedChapter: .mockBackground,
        nextChapter: .mockMusic,
        isNextUnlocked: false,
        daysUntilUnlock: 2,
        weekStartDate: WeeklyAssignment.currentWeekStartDate(),
        artist: .mock,
        completedChapterFullyWatched: true,
        onContinue: {},
        onBackHome: {}
    )
}

#Preview("Locked next (chapter skipped)") {
    ChapterCompleteView(
        completedChapter: .mockBackground,
        nextChapter: .mockMusic,
        isNextUnlocked: false,
        daysUntilUnlock: 2,
        weekStartDate: WeeklyAssignment.currentWeekStartDate(),
        artist: .mock,
        completedChapterFullyWatched: false,
        onContinue: {},
        onBackHome: {}
    )
}

#Preview("Journey finished") {
    ChapterCompleteView(
        completedChapter: .mockGoals,
        nextChapter: nil,
        isNextUnlocked: false,
        daysUntilUnlock: 0,
        weekStartDate: WeeklyAssignment.currentWeekStartDate(),
        artist: .mock,
        isJourneyComplete: true,
        completedChapterFullyWatched: true,
        onContinue: {},
        onBackHome: {}
    )
}

#Preview("Journey finished (skipped, not honest)") {
    ChapterCompleteView(
        completedChapter: .mockGoals,
        nextChapter: nil,
        isNextUnlocked: false,
        daysUntilUnlock: 0,
        weekStartDate: WeeklyAssignment.currentWeekStartDate(),
        artist: .mock,
        isJourneyComplete: false,
        completedChapterFullyWatched: false,
        onContinue: {},
        onBackHome: {}
    )
}
#endif
