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

                    // Sharp, fully-identified portrait — the same shared card as
                    // the reveal screen, so it reads as the very same artist.
                    ArtistCard(width: geo.size.width * 0.72,
                               artist: artist,
                               blurRadius: 0,
                               showName: true,
                               showMeta: true,
                               includesMeta: true)

                    // Tight gap so the progress track reads as belonging to the card.
                    Spacer().frame(height: 35)

                    ChapterProgressTrack(chapters: chapters,
                                         currentIndex: currentIndex,
                                         watchedVideoIds: watchedVideoIds,
                                         weekStartDate: weekStartDate)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 30)

                    VStack(spacing: 14) {
                        PrimaryActionButton(title: isCurrentChapterUnlocked ? "Continue" : "Locked",
                                           action: {
                            guard isCurrentChapterUnlocked, let chapter = currentChapter else { return }
                            onContinue(chapter, isCurrentChapterStarted)
                        })
                        .opacity(isCurrentChapterUnlocked ? 1 : 0.45)
                        .allowsHitTesting(isCurrentChapterUnlocked)
                        timeLeftLabel
                    }
                    // Same inset as the progress track so the CTA grounds itself
                    // in the same content column as the card and track above it.
                    .padding(.horizontal, 24)
                    .padding(.bottom, 44)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                #if DEBUG
                resetButton
                #endif
            }
        }
        .task(id: isSessionActive) { await load() }
    }

    #if DEBUG
    // Flips RootView's shared latch back to false, routing the app to the
    // first-visit pre-reveal HomeView. Top-right, matching HomeView's debug chip.
    private var resetButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    hasBegunJourney = false
                    hasCompletedOnboarding = false
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.ink.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.ink.opacity(0.08)))
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 8)
            Spacer()
        }
    }
    #endif

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("Welcome, Abhi!")
                .font(.layaDisplay(38))
                .foregroundStyle(.ink)

            Text("Pick up where you left off.")
                .font(.layaBody(15, weight: .light))
                .foregroundStyle(.ink.opacity(0.55))
        }
    }

    // MARK: - Continue

    // The weekly runway — quiet, reinforcing Laya's intentional weekly cadence
    // without competing with the Continue CTA above it. Swaps to the unlock
    // day once the user has caught up to a chapter that isn't available yet.
    private var timeLeftLabel: some View {
        Text(isCurrentChapterUnlocked
             ? "4 days left this week"
             : "Drops \(currentChapter?.unlockDayName(weekStartDate: weekStartDate) ?? "soon")")
            .font(.layaBody(12, weight: .light))
            .foregroundStyle(.ink.opacity(0.4))
    }

    // MARK: - Derived state

    // The chapter the user is on: the first not-yet-completed one (or the last,
    // once every chapter is done). Completion is derived from the watched set.
    // Being "current" here is about identity/display, not access — it says
    // nothing about whether the chapter is actually unlocked yet.
    private var currentChapter: Chapter? {
        chapters.first { !$0.isComplete(watchedVideoIds) } ?? chapters.last
    }

    private var currentIndex: Int {
        currentChapter?.index ?? 0
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
// Completed chapters read ink-solid; the current one shows a copper fill
// proportional to how far through its videos the user is; upcoming ones a faint
// wash, mirroring the journey player's sense of progress.
private struct ChapterProgressTrack: View {
    let chapters: [Chapter]
    let currentIndex: Int
    let watchedVideoIds: Set<String>
    let weekStartDate: Date

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(chapters) { chapter in
                VStack(alignment: .leading, spacing: 9) {
                    pill(for: chapter)
                        .frame(height: 12)

                    // Antic Didone — the editorial display face, whose roman
                    // numerals carry the journey's chapter markers. minimumScale
                    // guards the longest title ("I • Background") from truncating
                    // in its column. The active chapter is signalled by size (see
                    // scaleEffect); opacity sets a gentle done/active/upcoming
                    // hierarchy.
                    Text("\(romanNumeral(chapter.index + 1)) • \(chapter.title)")
                        .font(.layaDisplay(12))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(.ink.opacity(labelOpacity(for: chapter)))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // Completed → solid ink. Current & unlocked → faint copper track with a solid
    // copper fill proportional to the chapter's watched fraction (so even 0% still
    // reads as "you are here"). Current & locked → a hairline copper outline rather
    // than a fill, so it can't be mistaken for "ready to resume" — same idea as the
    // hairline progress dots on the locked ChapterCompleteView screen. Upcoming →
    // faint wash.
    @ViewBuilder
    private func pill(for chapter: Chapter) -> some View {
        if chapter.isComplete(watchedVideoIds) {
            Capsule().fill(Color.ink)
        } else if chapter.index == currentIndex {
            if chapter.isUnlocked(weekStartDate: weekStartDate) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.muted.opacity(0.3))
                        Capsule()
                            .fill(Color.copper)
                            .frame(width: geo.size.width * chapter.fractionWatched(watchedVideoIds))
                    }
                }
            } else {
                Capsule().strokeBorder(Color.copper.opacity(0.45), lineWidth: 1)
            }
        } else {
            Capsule().fill(Color.muted.opacity(0.3))
        }
    }

    // A gentle static hierarchy — emphasis on the active chapter comes from its
    // scale, not opacity, so these just separate done / active / upcoming.
    private func labelOpacity(for chapter: Chapter) -> Double {
        if chapter.isComplete(watchedVideoIds) { return 0.7 }   // done — settled
        if chapter.index == currentIndex { return 0.8 }         // active
        return 0.5                                              // upcoming — faint
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
