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
/// - **Journey finished** (no next chapter) → a quiet "Journey complete." close.
struct ChapterCompleteView: View {
    let completedChapter: Chapter
    /// The next chapter in the journey, or nil if this was the last.
    let nextChapter: Chapter?
    /// Whether `nextChapter` is already available to watch.
    let isNextUnlocked: Bool
    /// Whole days until `nextChapter` unlocks (only meaningful when locked).
    let daysUntilUnlock: Int
    let artist: Artist?
    /// Total chapters in the journey — used for the progress dot row on the locked screen.
    var totalChapters: Int = 3

    /// Advance to the next chapter's intro (unlocked path only).
    var onContinue: () -> Void
    /// Leave the journey, back to Home.
    var onBackHome: () -> Void

    // Cascade beats — matched to ChapterIntroView's feel.
    // Unlocked:  5-beat — head → numeral → title → subtitle → actions.
    // Locked:    4-beat — head → mid (title block) → portrait → actions.
    // Finished:  3-beat — head → mid → actions.
    @State private var showHead = false
    @State private var showNumeral = false   // unlocked only
    @State private var showTitle = false     // unlocked only
    @State private var showSubtitle = false  // unlocked only
    @State private var showMid = false       // locked / finished only
    @State private var showActions = false

    private let cascadeStart = 0.8
    private let beatGap = 0.3
    private let beatFade = 0.55

    var body: some View {
        ZStack {
            // Locked screen is a full-bleed dark editorial; everything else is cream.
            (variant == .locked ? Color.ink : Color.cream).ignoresSafeArea()
            layoutContent
        }
        .task { await runCascade() }
    }

    // MARK: - Layout

    @ViewBuilder
    private var layoutContent: some View {
        if variant == .unlocked {
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
        } else if variant == .locked {
            // Dark editorial layout: a height-capped grayscale photo fading into the
            // ink base beneath it, so the text panel always reads against solid ink
            // rather than against whatever the photo happens to show at that height.
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
                    Image("artistCard2")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: 520)
                        .clipped()
                        .grayscale(1.0)
                        .brightness(0.02)

                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: 110 / 1000),
                            .init(color: Color.ink.opacity(0.18), location: 280 / 1000),
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
                .opacity(showHead ? 1 : 0)
                .animation(.easeOut(duration: beatFade).delay(cascadeStart), value: showHead)

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

                    Spacer().frame(height: 10)

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
                                .strokeBorder(Color.cream.opacity(i <= completedChapter.index ? 0.85 : 0.28), lineWidth: 1)
                                .background(
                                    Circle()
                                        .fill(i <= completedChapter.index ? Color.cream.opacity(0.85) : Color.clear)
                                )
                                .frame(width: 5, height: 5)
                        }
                        Text("\(completedChapter.index + 1) of \(totalChapters) chapters done")
                            .font(.layaBody(10, weight: .regular))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundStyle(.cream.opacity(0.45))
                    }
                    .opacity(showActions ? 1 : 0)
                    .offset(y: showActions ? 0 : 12)

                    Spacer().frame(height: 58)

                    // Copper Follow CTA
                    PrimaryActionButton(
                        title: "+ Follow \(firstName)",
                        background: .copper,
                        action: onBackHome
                    )
                    .opacity(showActions ? 1 : 0)
                    .offset(y: showActions ? 0 : 12)

                    Spacer().frame(height: 20)

                    // Back home text link
                    Button(action: onBackHome) {
                        Text("Back Home")
                            .font(.layaBody(14, weight: .regular))
                            .foregroundStyle(.cream.opacity(0.3))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    .opacity(showActions ? 1 : 0)
                    .offset(y: showActions ? 0 : 12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 34 + geo.safeAreaInsets.bottom)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .ignoresSafeArea()
            }
        } else {
            // Finished: quiet closing message — eyebrow + "That's a wrap." + avatar.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                head
                middle
                Spacer(minLength: 0)
                actions
            }
            .padding(.horizontal, 32)
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

    // MARK: - Middle (locked / finished only)

    // Used by the finished variant only — locked has its own ZStack layout.
    @ViewBuilder
    private var middle: some View {
        VStack(spacing: 22) {
            softAvatar
            Text("You've seen all of \(firstName)'s story this week.")
                .font(.layaBody(16, weight: .light))
                .multilineTextAlignment(.center)
                .foregroundStyle(.ink.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(showMid ? 1 : 0)
        .offset(y: showMid ? 0 : 12)
    }

    // A soft, circular portrait — the gentle "stay with this artist" cue on the
    // locked / finished screens.
    private var softAvatar: some View {
        Image("artistPfp")
            .resizable()
            .scaledToFill()
            .frame(width: 150, height: 150)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.copper.opacity(0.4), lineWidth: 1))
            .shadow(color: .ink.opacity(0.25), radius: 10, y: 6)
            .padding(.vertical)
    }

    // MARK: - Actions

    // Only ever reached for .unlocked (from layoutContent's "UP NEXT" branch) and
    // .finished (the closing-message branch) — .locked builds its own bottom panel
    // directly in layoutContent and never calls this.
    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 18) {
            if variant == .unlocked {
                PrimaryActionButton(title: "Continue", action: onContinue)
                backHomeButton
            } else {
                PrimaryActionButton(title: "Back home", action: onBackHome)
            }
        }
        .padding(.horizontal, 24)
        .opacity(showActions ? 1 : 0)
        .offset(y: showActions ? 0 : 12)
    }

    private var backHomeButton: some View {
        Button(action: onBackHome) {
            Text("Back home")
                .font(.layaBody(14, weight: .regular))
                .foregroundStyle(.ink.opacity(0.45))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Choreography

    private func runCascade() async {
        withAnimation(.easeOut(duration: beatFade).delay(cascadeStart)) {
            showHead = true
        }
        if variant == .unlocked {
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
        } else if variant == .locked {
            // Beat 2: eyebrow + title + subtitle panel
            withAnimation(.easeOut(duration: beatFade).delay(cascadeStart + beatGap)) {
                showMid = true
            }
            // Beat 3: progress dots + Follow CTA + back link
            withAnimation(.easeOut(duration: beatFade).delay(cascadeStart + 2 * beatGap)) {
                showActions = true
            }
        } else {
            withAnimation(.easeOut(duration: beatFade).delay(cascadeStart + beatGap)) {
                showMid = true
            }
            withAnimation(.easeOut(duration: beatFade).delay(cascadeStart + 2 * beatGap)) {
                showActions = true
            }
        }
    }

    // MARK: - Variant + copy

    private enum Variant { case unlocked, locked, finished }

    private var variant: Variant {
        guard nextChapter != nil else { return .finished }
        return isNextUnlocked ? .unlocked : .locked
    }

    private var eyebrow: String {
        switch variant {
        case .unlocked: return "Up next"
        case .locked:   return "Chapter \(romanNumeral(completedChapter.index + 1)) complete"
        case .finished: return "Journey complete"
        }
    }

    private var headline: String {
        switch variant {
        case .unlocked: return ""
        case .locked:   return "Complete."
        case .finished: return "That's a wrap."
        }
    }

    private var headlineSize: CGFloat { 44 }

    /// "CHAPTER II • DROPS WEDNESDAY" — eyebrow on the dark locked screen.
    private var lockedNextEyebrow: String {
        guard let next = nextChapter else { return "" }
        return "Chapter \(romanNumeral(next.index + 1)) • Drops \(unlockDayName)"
    }

    /// Day name derived from `daysUntilUnlock`, e.g. "Wednesday".
    private var unlockDayName: String {
        guard daysUntilUnlock > 0 else { return "soon" }
        let target = Calendar.current.date(
            byAdding: .day, value: daysUntilUnlock, to: Date()
        ) ?? Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE"
        return fmt.string(from: target)
    }

    private var firstName: String {
        artist?.name.split(separator: " ").first.map(String.init) ?? "the artist"
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
#Preview("Unlocked next") {
    ChapterCompleteView(
        completedChapter: .mockBackground,
        nextChapter: .mockMusic,
        isNextUnlocked: true,
        daysUntilUnlock: 0,
        artist: .mock,
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
        artist: .mock,
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
        artist: .mock,
        onContinue: {},
        onBackHome: {}
    )
}
#endif
