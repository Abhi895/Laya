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

    #if DEBUG
    // Shares RootView's latch (same key). Flipping it false here routes the app
    // straight back to the onboarding screen.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasBegunJourney") private var hasBegunJourney = false
    #endif

    private let service: AssignmentServing
    // Fired when "Continue" is tapped — carries the current chapter so
    // RootView can populate the chapter intro screen before presenting it.
    private let onContinue: (Chapter) -> Void

    init(service: AssignmentServing,
         onContinue: @escaping (Chapter) -> Void = { _ in }) {
        self.service = service
        self.onContinue = onContinue
        LayaFontRegistration.registerAll()
    }

    #if DEBUG
    init(onContinue: @escaping (Chapter) -> Void = { _ in }) {
        self.service = MockAssignmentService()
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
                                         watchedVideoIds: watchedVideoIds)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 30)

                    VStack(spacing: 14) {
                        PrimaryActionButton(title: "Continue",
                                           action: {
                            let chapter = chapters.first { $0.index == currentIndex }
                                ?? chapters.first
                                ?? .mockBackground
                            onContinue(chapter)
                        })
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
        .task { await load() }
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
    // without competing with the Continue CTA above it.
    private var timeLeftLabel: some View {
        Text("4 days left this week")
            .font(.layaBody(12, weight: .light))
            .foregroundStyle(.ink.opacity(0.4))
    }

    // MARK: - Derived state

    // The chapter the user is on: the first not-yet-completed one (or the last,
    // once every chapter is done). Completion is derived from the watched set.
    private var currentIndex: Int {
        chapters.first { !$0.isComplete(watchedVideoIds) }?.index
            ?? (chapters.last?.index ?? 0)
    }

    // MARK: - Loading

    private func load() async {
        do {
            let package = try await service.fetchCurrentAssignment(for: "user-mock")
            artist = package.artist
            chapters = package.journey.chapters.sorted { $0.index < $1.index }
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

    // Completed → solid ink. Current → faint copper track with a solid copper fill
    // proportional to the chapter's watched fraction (so even 0% still reads as
    // "you are here"). Upcoming → faint wash.
    @ViewBuilder
    private func pill(for chapter: Chapter) -> some View {
        if chapter.isComplete(watchedVideoIds) {
            Capsule().fill(Color.ink)
        } else if chapter.index == currentIndex {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.muted.opacity(0.3))
                    Capsule()
                        .fill(Color.copper)
                        .frame(width: geo.size.width * chapter.fractionWatched(watchedVideoIds))
                }
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
