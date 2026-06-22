//
//  JourneySessionView.swift
//  Laya
//
//  Created by Abhi Reddy on 19/06/2026.
//

import SwiftUI

/// The whole "inside the journey" experience, presented by `RootView` as a
/// single crossfading overlay over Home. It's a three-phase machine:
///
///     .intro   → ChapterIntroView   (cream cascade)
///     .player  → JourneyPlayerView  (dark video feed)
///     .complete→ ChapterCompleteView (cream cascade)
///
/// Phases crossfade into each other with one shared slow opacity animation — the
/// same feel the chapter intro→player morph had when it lived inline. Leaving the
/// journey (the player's ✕ button, or "Back home") calls `onFinished`, which lets
/// RootView slide the overlay down and fade it back to the home screen beneath.
/// Continuing to an unlocked next chapter resets the machine to `.intro` for that chapter.
struct JourneySessionView: View {
    let initialChapter: Chapter
    let isResume: Bool
    /// Tear down the whole session and return to Home.
    /// Receives the chapter the user should land on next and whether it's a resume,
    /// so ContentView can seed the correct intro screen for the next "Continue" tap.
    let onFinished: (Chapter, Bool) -> Void

    private let service: AssignmentServing

    @State private var phase: Phase = .intro
    @State private var currentChapter: Chapter
    @State private var introIsResume: Bool

    // Loaded once — needed for next-chapter routing and lock computation.
    @State private var chapters: [Chapter] = []
    @State private var artist: Artist?
    @State private var weekStartDate = Date()
    @State private var assignmentId = ""
    @State private var watchedVideoIds: Set<String> = []
    @State private var lastWatchedVideoId: String?

    // Frozen snapshot of the data passed to ChapterCompleteView, captured at the
    // moment we enter .complete. This prevents goToNextChapter() updating
    // currentChapter from re-rendering the still-fading-out complete view with
    // the wrong chapter's data (e.g. briefly showing the locked variant).
    @State private var completeSnapshot: CompleteSnapshot?

    enum Phase { case intro, player, complete }

    private struct CompleteSnapshot {
        let completedChapter: Chapter
        let nextChapter: Chapter?
        let isNextUnlocked: Bool
        let daysUntilUnlock: Int
        let totalChapters: Int
    }

    init(initialChapter: Chapter,
         isResume: Bool,
         service: AssignmentServing,
         onFinished: @escaping (Chapter, Bool) -> Void) {
        self.initialChapter = initialChapter
        self.isResume = isResume
        self.service = service
        self.onFinished = onFinished
        _currentChapter = State(initialValue: initialChapter)
        _introIsResume = State(initialValue: isResume)
    }

    #if DEBUG
    init(initialChapter: Chapter,
         isResume: Bool,
         onFinished: @escaping (Chapter, Bool) -> Void) {
        self.init(initialChapter: initialChapter,
                  isResume: isResume,
                  service: MockAssignmentService(),
                  onFinished: onFinished)
    }
    #endif

    var body: some View {
        ZStack {
            // Phase transitions use opacity, so there are moments where the
            // outgoing player and incoming completion view are both translucent.
            // Keep the session itself opaque so those crossfades never reveal
            // the home screen sitting underneath ContentView's overlay.
            Color.cream.ignoresSafeArea()

            if phase == .intro {
                ChapterIntroView(chapter: currentChapter,
                                 isResume: introIsResume,
                                 onAdvance: enterPlayer)
                    .transition(.opacity)
            }

            if phase == .player {
                JourneyPlayerView(
                    chapter: currentChapter,
                    artist: artist,
                    startIndex: resumeStartIndex,
                    onDismiss: dismiss,
                    onChapterComplete: exitPlayer,
                    onVideoReached: markResumePoint,
                    onVideoCompleted: markWatched
                )
                // Explicit identity: forces a fresh view instance (and fresh @State,
                // including videoDetached=false and a new JourneyFeedManager) whenever
                // the chapter changes. Without this, SwiftUI may reuse the outgoing
                // player view while it's still fading out, carrying over stale state.
                .id(currentChapter.id)
                .transition(.opacity)
                .zIndex(1)
            }

            if phase == .complete, let snap = completeSnapshot {
                ChapterCompleteView(
                    completedChapter: snap.completedChapter,
                    nextChapter: snap.nextChapter,
                    isNextUnlocked: snap.isNextUnlocked,
                    daysUntilUnlock: snap.daysUntilUnlock,
                    artist: artist,
                    totalChapters: snap.totalChapters,
                    onContinue: goToNextChapter,
                    onBackHome: dismiss
                )
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .task { await load() }
    }

    // MARK: - Routing

    // Duration of the cream→dark crossfade into the player. The `.transition(.opacity)`
    // on the player phase fades the whole view in — chrome and the AVPlayerLayer alike,
    // since the layer's opacity cascades through Core Animation — so the video rides
    // the same crossfade rather than popping in over the still-fading intro.
    private let enterDuration = 1.2

    // Intro → player: slow easeInOut so the dark feed envelops the cream card,
    // giving the sensation of stepping into something immersive.
    private func enterPlayer() {
        withAnimation(.easeInOut(duration: enterDuration)) { phase = .player }
    }

    // Player → complete: snappier — the chapter is done and the payoff arrives.
    // Snapshot the complete view's data first so a subsequent goToNextChapter()
    // updating currentChapter can't re-render the still-fading-out screen.
    private func exitPlayer() {
        completeSnapshot = CompleteSnapshot(
            completedChapter: currentChapter,
            nextChapter: nextChapter,
            isNextUnlocked: isNextUnlocked,
            daysUntilUnlock: daysUntilNextUnlock,
            totalChapters: chapters.count
        )
        withAnimation(.easeInOut(duration: 0.9)) { phase = .complete }
    }

    private func goToNextChapter() {
        guard let next = completeSnapshot?.nextChapter else { onFinished(currentChapter, false); return }
        currentChapter = next
        introIsResume = false
        // The unlocked completion screen already showed the next chapter's numeral/
        // title/subtitle — it acts as the intro. Same entering feel as intro→player.
        withAnimation(.easeInOut(duration: enterDuration)) { phase = .player }
    }

    /// Computes the right (chapter, isResume) for the home screen and fires onFinished.
    /// - From the player: resume this chapter where they left off.
    /// - From the complete screen (next unlocked): start the next chapter's intro fresh.
    /// - From the complete screen (locked / no next): chapter is done, nothing to resume.
    private func dismiss() {
        switch phase {
        case .player:
            onFinished(currentChapter, true)
        case .complete:
            if let snap = completeSnapshot, snap.isNextUnlocked, let next = snap.nextChapter {
                onFinished(next, false)
            } else {
                onFinished(currentChapter, false)
            }
        case .intro:
            onFinished(currentChapter, false)
        }
    }

    // MARK: - Progress

    // A clip became current — only the resume pointer moves. Reaching a clip
    // isn't watching it; this just makes sure leaving mid-clip drops the user
    // back on the same one rather than the one before it.
    private func markResumePoint(_ video: JourneyVideo) {
        lastWatchedVideoId = video.id
        persistProgress()
    }

    // A clip played to its actual end — this is what counts toward chapter
    // completion and the progress bars.
    private func markWatched(_ video: JourneyVideo) {
        watchedVideoIds.insert(video.id)
        lastWatchedVideoId = video.id
        persistProgress()
    }

    private func persistProgress() {
        let progress = JourneyProgress(watchedVideoIds: watchedVideoIds,
                                       lastWatchedVideoId: lastWatchedVideoId,
                                       completedAt: nil)
        let id = assignmentId
        Task { try? await service.updateProgress(progress, assignmentId: id) }
    }

    // MARK: - Derived state

    // Where to drop the player in: on resume, the clip after the resume pointer
    // within this chapter; otherwise the first clip.
    private var resumeStartIndex: Int {
        guard introIsResume,
              let pointer = lastWatchedVideoId,
              let watchedIdx = currentChapter.videos.firstIndex(where: { $0.id == pointer })
        else { return 0 }
        // Resume on the next unwatched clip, clamped to the last clip.
        return min(watchedIdx + 1, currentChapter.videos.count - 1)
    }

    private var nextChapter: Chapter? {
        chapters.first { $0.index == currentChapter.index + 1 }
    }

    private var isNextUnlocked: Bool {
        guard let next = nextChapter else { return false }
        return next.isUnlocked(weekStartDate: weekStartDate)
    }

    private var daysUntilNextUnlock: Int {
        guard let next = nextChapter else { return 0 }
        return next.daysUntilUnlock(weekStartDate: weekStartDate)
    }

    // MARK: - Loading

    private func load() async {
        do {
            let package = try await service.fetchCurrentAssignment(for: "user-mock")
            artist = package.artist
            chapters = package.journey.chapters.sorted { $0.index < $1.index }
            weekStartDate = package.assignment.weekStartDate
            assignmentId = package.assignment.id
            watchedVideoIds = package.assignment.progress.watchedVideoIds
            lastWatchedVideoId = package.assignment.progress.lastWatchedVideoId
            // Prefer the catalog copy of the chapter (same id) so we always have
            // the full video list, even if the caller passed a lightweight one.
            if let canonical = chapters.first(where: { $0.id == currentChapter.id }) {
                currentChapter = canonical
            }
        } catch {
            // No-op — falls back to the chapter the caller handed us.
        }
    }
}

#if DEBUG
#Preview("Session — Begin") {
    JourneySessionView(initialChapter: .mockBackground,
                       isResume: false,
                       service: MockAssignmentService(),
                       onFinished: { _, _ in })
}
#endif
