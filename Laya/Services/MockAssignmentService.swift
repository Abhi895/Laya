//
//  MockAssignmentService.swift
//  Laya
//
//  Created by Abhi Reddy on 17/06/2026.
//

import Foundation

// Mock service — returns a hardcoded Reuben Aziz assignment
// Used in SwiftUI previews and UI tests (via launch argument)
// Never referenced in release builds outside of #if DEBUG

#if DEBUG
// One rotation slot: a self-contained (artist, journey) bundle the service can
// serve for a given week. Add more entries here to extend the rotation later —
// nothing else needs to change. This whole rotation is scaffolding: the real
// backend will eventually set each user's weekly assignment (and its videos/
// dates) directly, replacing this entirely.
private struct MockWeekContent {
    let artist: Artist
    let journey: Journey
}

private let mockRotation: [MockWeekContent] = [
    MockWeekContent(artist: .mock, journey: .mock),
    MockWeekContent(artist: .mockBubba, journey: .mockBubba)
]

// The Monday on/before a fixed reference date — just needs to be *some* real
// Monday in the past; which one doesn't matter, only used for stable indexing.
private let mockRotationEpoch = WeeklyAssignment.currentWeekStartDate(
    from: DateComponents(calendar: .current, year: 2026, month: 1, day: 1).date!
)

private func mockRotationIndex(for weekStart: Date) -> Int {
    let days = Calendar(identifier: .gregorian)
        .dateComponents([.day], from: mockRotationEpoch, to: weekStart).day ?? 0
    let weeks = days / 7
    return ((weeks % mockRotation.count) + mockRotation.count) % mockRotation.count
}

// Backs the mock with an in-memory store keyed by assignment id, so progress
// written by one view (e.g. JourneySessionView watching a video) is visible
// to the next fetch from any other view (e.g. HomeReturnView) — without this,
// every fetchCurrentAssignment() would reset to empty progress, and chapter
// progress could never survive leaving a session.
@MainActor
private final class MockProgressStore {
    static let shared = MockProgressStore()
    private var progress: [String: JourneyProgress] = [:]
    // Debug-only: when true, fetchCurrentAssignment serves an anchor far
    // enough back that every chapter (including the last) reads as unlocked
    // — see skipToFinished().
    var forceAllUnlocked = false
    // Debug-only: overrides the natural weekly rotation index so a specific
    // mock artist's week can be previewed immediately — see cycleForcedArtist().
    var forcedRotationIndex: Int?
    private init() {}

    func progress(for assignmentId: String, fallback: JourneyProgress) -> JourneyProgress {
        progress[assignmentId] ?? fallback
    }

    func set(_ progress: JourneyProgress, for assignmentId: String) {
        self.progress[assignmentId] = progress
    }

    func reset() {
        progress.removeAll()
        forceAllUnlocked = false
        forcedRotationIndex = nil
    }
}

struct MockAssignmentService: AssignmentServing {
    func fetchCurrentAssignment(for userId: String) async throws -> AssignmentPackage {
        let weekStart = WeeklyAssignment.currentWeekStartDate()
        let index = await MockProgressStore.shared.forcedRotationIndex ?? mockRotationIndex(for: weekStart)
        let content = mockRotation[index]

        let forceAllUnlocked = await MockProgressStore.shared.forceAllUnlocked
        let effectiveWeekStart = forceAllUnlocked
            ? Calendar.current.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
            : weekStart

        let assignmentId = "assignment-mock-\(content.artist.id)"
        var assignment = WeeklyAssignment(
            id: assignmentId,
            userId: userId,
            journeyId: content.journey.id,
            weekStartDate: effectiveWeekStart,
            assignedAt: Date(),
            progress: JourneyProgress(
                watchedVideoIds: [],
                lastWatchedVideoId: nil,
                completedAt: nil
            )
        )
        assignment.progress = await MockProgressStore.shared.progress(for: assignmentId, fallback: assignment.progress)
        return AssignmentPackage(
            assignment: assignment,
            journey: content.journey,
            artist: content.artist
        )
    }

    func updateProgress(_ progress: JourneyProgress, assignmentId: String) async throws {
        await MockProgressStore.shared.set(progress, for: assignmentId)
    }

    func completeChapter(index: Int, assignmentId: String) async throws {
        // No-op in mock
    }

    // Wipes all watched-video progress. Used by the DEBUG reset chips so
    // resetting actually clears the slate, rather than just routing back to
    // onboarding while the last session's progress quietly survives underneath.
    @MainActor
    static func resetProgress() {
        MockProgressStore.shared.reset()
    }

    // Marks every chapter before the last (for whichever artist's week is
    // currently active) as watched and unlocks the whole week, so tapping
    // Continue drops the user straight into the last chapter — one debug
    // Skip away from the real finished screen / share artifact, without
    // faking the completion event itself.
    @MainActor
    static func skipToFinished() {
        MockProgressStore.shared.forceAllUnlocked = true
        let weekStart = WeeklyAssignment.currentWeekStartDate()
        let index = MockProgressStore.shared.forcedRotationIndex ?? mockRotationIndex(for: weekStart)
        let content = mockRotation[index]
        let chapters = content.journey.chapters
        let watched = Set(chapters.dropLast().flatMap { $0.videos.map(\.id) })
        MockProgressStore.shared.set(
            JourneyProgress(
                watchedVideoIds: watched,
                lastWatchedVideoId: chapters.dropLast().last?.videos.last?.id,
                completedAt: nil
            ),
            for: "assignment-mock-\(content.artist.id)"
        )
    }

    // Advances the forced rotation override to the next mock artist, so the
    // upcoming week's content can be previewed immediately rather than
    // waiting for a real Monday (or changing the simulator's clock).
    @MainActor
    static func cycleForcedArtist() {
        let weekStart = WeeklyAssignment.currentWeekStartDate()
        let current = MockProgressStore.shared.forcedRotationIndex ?? mockRotationIndex(for: weekStart)
        MockProgressStore.shared.forcedRotationIndex = (current + 1) % mockRotation.count
    }
}
#endif
