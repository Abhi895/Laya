//
//  HomeReturnView.swift
//  Laya
//
//  Created by Abhi Reddy on 18/06/2026.
//

import SwiftUI

/// The Home screen as it appears on *return* visits — after the artist has been
/// revealed and the journey begun. Unlike the first-visit hold-to-reveal, the
/// portrait is already sharp and identified; this screen welcomes the user back
/// and shows how far through the three chapters they are, with a Continue CTA
/// back into the journey player.
struct HomeReturnView: View {
    @State private var artist: Artist?
    @State private var chapters: [Chapter] = []
    @State private var watchedVideoIds: Set<String> = []
    @State private var weekStartDate = Date()

    #if DEBUG
    // Shares RootView's latch (same key). Flipping it false here routes the app
    // straight back to the onboarding screen.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasBegunJourney") private var hasBegunJourney = false
    #endif

    private let service: AssignmentServing
    // RootView keeps this view mounted continuously underneath the journey
    // session overlay (rather than tearing it down between visits) so the
    // slide-down dismiss reveals it instantly. That means `.task` only ever
    // fires once, on first mount — long before any chapter is watched. This
    // toggles every time a session opens or closes (RootView's `showSession`),
    // so `.task(id:)` below re-fetches on every return to this screen instead
    // of holding onto whatever progress existed the very first time it loaded.
    private let isSessionActive: Bool
    // Fired when "Continue" is tapped — carries the current chapter and
    // whether it's already partway watched, so RootView can populate the
    // chapter intro screen (fresh vs. resume) before presenting it. Computed
    // here rather than guessed by the caller, since this view is the one
    // holding the real watched-progress data.
    private let onContinue: (Chapter, Bool) -> Void

    @State private var showSharePreview = false

    init(service: AssignmentServing,
         isSessionActive: Bool = false,
         onContinue: @escaping (Chapter, Bool) -> Void = { _, _ in }) {
        self.service = service
        self.isSessionActive = isSessionActive
        self.onContinue = onContinue
        LayaFontRegistration.registerAll()
    }

    #if DEBUG
    init(isSessionActive: Bool = false,
         onContinue: @escaping (Chapter, Bool) -> Void = { _, _ in }) {
        self.service = MockAssignmentService()
        self.isSessionActive = isSessionActive
        self.onContinue = onContinue
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

                    Spacer(minLength: 30)

                    // Sharp portrait throughout — the completed state only
                    // drops the meta line, not focus.
                    ArtistCard(width: geo.size.width * 0.72,
                               artist: artist,
                               blurRadius: 0,
                               showName: true,
                               showMeta: true,
                               includesMeta: !isJourneyComplete)

                    // Tight gap so the progress track reads as belonging to the card.
                    Spacer().frame(height: 35)

                    VStack(alignment: .leading, spacing: 14) {
                        ChapterProgressTrack(chapters: chapters,
                                             watchedVideoIds: watchedVideoIds,
                                             weekStartDate: weekStartDate,
                                             showLabels: !isJourneyComplete)
                        if isJourneyComplete {
                            Text("All chapters completed.")
                                .font(.layaBody(13, weight: .light))
                                .foregroundStyle(.ink.opacity(0.45))
                        }
                    }
                    .padding(.horizontal, 24)

                    // The completed state stacks two CTAs instead of one —
                    // a touch more room here keeps it from reading denser
                    // than the rest of the screen's spacing rhythm.
                    Spacer(minLength: isJourneyComplete ? 40 : 30)

                    if isJourneyComplete {
                        completedActions
                    } else {
                        VStack(spacing: 14) {
                            PrimaryActionButton(
                                title: isCurrentChapterUnlocked ? "Continue" : "Stream \(firstName)'s music",
                                icon: isCurrentChapterUnlocked ? nil : Image("spotify"),
                                action: {
                                    guard isCurrentChapterUnlocked, let chapter = currentChapter else {
                                        // TODO: route to artist.spotifyArtistId once Spotify linking is wired up.
                                        return
                                    }
                                    onContinue(chapter, isCurrentChapterStarted)
                                }
                            )
                            timeLeftLabel
                        }
                        // Same inset as the progress track so the CTA grounds itself
                        // in the same content column as the card and track above it.
                        .padding(.horizontal, 24)
                        .padding(.bottom, 44)
                    }
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                #if DEBUG
                resetButton
                #endif
            }
        }
        .task(id: isSessionActive) { await load() }
        .fullScreenCover(isPresented: $showSharePreview) {
            if let artist {
                ShareArtifactPreviewView(artist: artist, onDismiss: { showSharePreview = false })
            }
        }
    }

    // MARK: - Completed actions

    // Follow (placeholder — no real follow backend yet) + Share Journey
    // (reuses the same artifact preview wired up from ChapterCompleteView's
    // finished screen) + the inset/padding the active-state CTA column uses.
    private var completedActions: some View {
        VStack(spacing: 14) {
            PrimaryActionButton(title: "+ Follow \(firstName)", action: {})
            SecondaryActionButton(title: "Share Journey", icon: Image(systemName: "square.and.arrow.up")) {
                showSharePreview = true
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 44)
    }

    #if DEBUG
    // Flips RootView's shared latch back to false, routing the app to the
    // first-visit pre-reveal HomeView. Top-right, matching HomeView's debug chip.
    // Also wipes watched-video progress — otherwise this only ever looked like
    // a reset; the next "Begin" would land back on whatever chapter/progress
    // the mock store still had from before.
    private var resetButton: some View {
        VStack {
            HStack {
                Spacer()
                // Marks every chapter before the last as watched and unlocks
                // the week, so the next Continue tap drops straight into the
                // last chapter — one debug Skip away from the real finished
                // screen / share artifact.
                Button(action: {
                    MockAssignmentService.skipToFinished()
                    Task { await load() }
                }) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.ink.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.ink.opacity(0.08)))
                }
                .accessibilityLabel("Debug: skip to finished")
                .padding(.trailing, 6)

                Button(action: {
                    hasBegunJourney = false
                    hasCompletedOnboarding = false
                    MockAssignmentService.resetProgress()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.ink.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.ink.opacity(0.08)))
                }
                .accessibilityLabel("Debug: reset")
                .padding(.trailing, 16)
            }
            .padding(.top, 8)
            Spacer()
        }
    }
    #endif

    // MARK: - Header

    // The celebration itself belongs entirely to ChapterCompleteView's
    // finished screen — a one-time payoff. This is the persistent home base
    // the user returns to all week, so it never re-announces "congrats";
    // it just calmly reflects status, same as the in-progress greeting does.
    private var header: some View {
        VStack(spacing: 6) {
            Text("Welcome, Abhi.")
                .font(.layaDisplay(38))
                .foregroundStyle(.ink)

            Text(isJourneyComplete ? "You're all caught up this week." : "Pick up where you left off.")
                .font(.layaBody(15, weight: .light))
                .foregroundStyle(.ink.opacity(0.55))

            if isJourneyComplete {
                Text(nextJourneyLabel)
                    .font(.layaBody(13, weight: .light))
                    .foregroundStyle(.ink.opacity(0.4))
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Continue

    // The weekly runway — quiet, reinforcing Laya's intentional weekly cadence
    // without competing with the Continue CTA above it. Swaps to a countdown
    // once the user has caught up to a chapter that isn't available yet.
    private var timeLeftLabel: some View {
        Text(isCurrentChapterUnlocked ? "4 days left this week" : lockedCountdownLabel)
            .font(.layaBody(12, weight: .light))
            .foregroundStyle(.ink.opacity(0.4))
    }

    private var lockedCountdownLabel: String {
        guard let chapter = currentChapter else { return "" }
        let days = chapter.daysUntilUnlock(weekStartDate: weekStartDate)
        let numeral = romanNumeral(chapter.index + 1)
        guard days > 0 else { return "Chapter \(numeral) soon" }
        return "Chapter \(numeral) in \(days) day\(days == 1 ? "" : "s")"
    }

    // MARK: - Derived state

    // The chapter the user is on: the first not-yet-completed one (or the last,
    // once every chapter is done). Completion is derived from the watched set.
    // Being "current" here is about identity/display, not access — it says
    // nothing about whether the chapter is actually unlocked yet.
    private var currentChapter: Chapter? {
        chapters.first { !$0.isComplete(watchedVideoIds) } ?? chapters.last
    }

    // Gates the Continue button — without this, a returning user could land
    // on the current chapter before its unlock date and walk straight past
    // the locked wall that ChapterCompleteView is supposed to enforce.
    private var isCurrentChapterUnlocked: Bool {
        currentChapter?.isUnlocked(weekStartDate: weekStartDate) ?? true
    }

    // A "current" chapter is by definition not complete, so this splits
    // cleanly into two cases: never opened (0%) → fresh intro, partway
    // through (>0%) → resume intro at the next unwatched clip.
    private var isCurrentChapterStarted: Bool {
        (currentChapter?.fractionWatched(watchedVideoIds) ?? 0) > 0
    }

    private var firstName: String {
        artist?.name.split(separator: " ").first.map(String.init) ?? "the artist"
    }

    // Every chapter watched — the week's whole journey, not just the current
    // one. Shared with ChapterCompleteView via Journey/[Chapter].isComplete
    // rather than each view inferring "done" its own way.
    private var isJourneyComplete: Bool {
        chapters.isComplete(watchedVideoIds)
    }

    // Weeks run on a fixed 7-day cadence from weekStartDate, so the next
    // journey's start is simply one week on from this one.
    private var nextJourneyLabel: String {
        let calendar = Calendar.current
        let nextStart = calendar.date(byAdding: .day, value: 7, to: weekStartDate) ?? weekStartDate
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: nextStart)
        ).day ?? 0
        guard days > 0 else { return "Next journey soon." }
        return "Next journey in \(days) day\(days == 1 ? "" : "s")."
    }

    // MARK: - Loading

    private func load() async {
        do {
            let package = try await service.fetchCurrentAssignment(for: "user-mock")
            artist = package.artist
            chapters = package.journey.chapters.sorted { $0.index < $1.index }
            weekStartDate = package.assignment.weekStartDate
            watchedVideoIds = package.assignment.progress.watchedVideoIds
        } catch {
            // No-op — UI-only screen.
        }
    }
}

// MARK: - Chapter progress track

// Three equal segments — a pill per chapter over its "I — Background" label.
// Completed chapters read ink-solid; unlocked ones show a copper fill
// proportional to how far through its videos the user is (0% included, so
// it still reads as "you are here"); locked ones are a flat muted outline.
private struct ChapterProgressTrack: View {
    let chapters: [Chapter]
    let watchedVideoIds: Set<String>
    let weekStartDate: Date
    // Drops chapter titles (the caller shows one shared "All chapters
    // completed." caption below the track instead) once the whole journey's
    // done — but each pill still shows its bare roman numeral; see label(for:).
    var showLabels: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(chapters) { chapter in
                VStack(alignment: .leading, spacing: 9) {
                    pill(for: chapter)
                        .frame(height: 12)

                    label(for: chapter)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // Just two states, not a four-way done/current/locked/upcoming split: done
    // is solid ink (standard "finished" treatment); anything else is either
    // locked (a flat, muted hairline outline — no fill, no accent color, the
    // same regardless of whether it's the next chapter or a further one) or
    // unlocked (a grey track with a copper fill proportional to watched
    // progress, 0% reading as "you are here" same as before).
    @ViewBuilder
    private func pill(for chapter: Chapter) -> some View {
        if chapter.isComplete(watchedVideoIds) {
            Capsule().fill(Color.ink)
        } else if chapter.isUnlocked(weekStartDate: weekStartDate) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.muted.opacity(0.3))
                    Capsule()
                        .fill(Color.copper)
                        .frame(width: geo.size.width * chapter.fractionWatched(watchedVideoIds))
                }
            }
        } else {
            Capsule().strokeBorder(Color.muted.opacity(0.5), lineWidth: 1)
        }
    }

    // Antic Didone — the editorial display face, whose roman numerals carry the
    // journey's chapter markers. minimumScale guards the longest title
    // ("I • Background") from truncating in its column. Locked chapters swap
    // the title for a clock glyph at a fixed, low opacity — there's nothing
    // useful to read yet, so naming the chapter just invites someone to wonder
    // why they can't tap into it; a clock reads as "time, not access" more
    // than a lock would. Once the whole journey's done, titles drop (the
    // caption below the track already says "all completed") but the roman
    // numeral itself stays — every other surface in the app identifies
    // chapters by numeral, so this is the one place that shouldn't go bare.
    @ViewBuilder
    private func label(for chapter: Chapter) -> some View {
        if !showLabels {
            Text(romanNumeral(chapter.index + 1))
                .font(.layaDisplay(12))
                .foregroundStyle(.ink.opacity(0.5))
        } else if chapter.isUnlocked(weekStartDate: weekStartDate) {
            Text("\(romanNumeral(chapter.index + 1)) • \(chapter.title)")
                .font(.layaDisplay(12))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(.ink.opacity(labelOpacity(for: chapter)))
        } else {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.ink.opacity(0.35))
        }
    }

    // A gentle, two-step hierarchy — done settles in at full weight, anything
    // still unwatched (whether it's the current chapter or not) reads the same.
    private func labelOpacity(for chapter: Chapter) -> Double {
        chapter.isComplete(watchedVideoIds) ? 0.7 : 0.55
    }
}

#if DEBUG
// Preview-only service that watches all of chapter I and half of chapter II, so
// the track shows the mock-up state with the new fractional fill: I done, II
// (Music) current and partway through, III upcoming.
private struct ReturnPreviewService: AssignmentServing {
    func fetchCurrentAssignment(for userId: String) async throws -> AssignmentPackage {
        var assignment = WeeklyAssignment.mock
        let watched = Chapter.mockBackground.videos.map(\.id)
            + [Chapter.mockMusic.videos[0].id]
        assignment.progress.watchedVideoIds = Set(watched)
        return AssignmentPackage(assignment: assignment, journey: .mock, artist: .mock)
    }
    func updateProgress(_ progress: JourneyProgress, assignmentId: String) async throws {}
    func completeChapter(index: Int, assignmentId: String) async throws {}
}

#Preview {
    HomeReturnView(service: ReturnPreviewService())
}
#endif
