//
//  LayaTests.swift
//  LayaTests
//
//  Created by Abhi Reddy on 17/06/2026.
//

import Testing
import Foundation
@testable import Laya

struct LayaTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

}

// The reveal waterfall's state lives in one bundled value with two presets.
// These guard the presets so reset/skip can never silently drift out of sync
// as new milestones are added (the bug class the refactor was meant to remove).
struct RevealStagesTests {

    @Test func concealedHidesEverything() {
        let s = RevealStages.concealed
        #expect(s.name == false)
        #expect(s.meta == false)
        #expect(s.bio == false)
        #expect(s.button == false)
        #expect(s.timeLeft == false)
        #expect(s == RevealStages())
    }

    @Test func revealedShowsEverything() {
        let s = RevealStages.revealed
        #expect(s.name)
        #expect(s.meta)
        #expect(s.bio)
        #expect(s.button)
        #expect(s.timeLeft)
    }

    @Test func presetsAreOpposites() {
        // Every milestone the concealed preset hides, the revealed preset shows —
        // so no stage can be added to one preset and forgotten in the other.
        #expect(RevealStages.concealed != RevealStages.revealed)
    }
}

// Fixes bug #8: "current chapter" must be driven purely by how far the user
// has reached, never by re-deriving from per-clip watched state — otherwise
// a partially-skipped earlier chapter can pull "current" backward.
struct ChapterFurthestReachedTests {

    @Test func indexZeroReturnsFirstChapter() {
        let result = Journey.mock.chapters.chapter(furthestReached: 0)
        #expect(result?.id == Chapter.mockBackground.id)
    }

    @Test func indexOneReturnsSecondChapter() {
        let result = Journey.mock.chapters.chapter(furthestReached: 1)
        #expect(result?.id == Chapter.mockMusic.id)
    }

    @Test func outOfRangeIndexClampsToLastChapter() {
        let result = Journey.mock.chapters.chapter(furthestReached: 99)
        #expect(result?.id == Chapter.mockGoals.id)
    }

    @Test func emptyChaptersReturnsNil() {
        let result = [Chapter]().chapter(furthestReached: 0)
        #expect(result == nil)
    }
}

// Fixes bug #9: resume must find the first genuinely unwatched clip, not
// trust a "last touched" pointer that reached-but-never-finished clips
// could stomp.
struct ChapterFirstUnwatchedIndexTests {

    @Test func emptyWatchedSetResumesAtFirstClip() {
        #expect(Chapter.mockMusic.firstUnwatchedIndex([]) == 0)
    }

    @Test func allWatchedResumesAtLastClip() {
        let watched = Set(Chapter.mockMusic.videos.map(\.id))
        #expect(Chapter.mockMusic.firstUnwatchedIndex(watched) == Chapter.mockMusic.videos.count - 1)
    }

    @Test func laterClipWatchedDoesNotPermanentlySkipEarlierGap() {
        // Bug #9 repro: only a later clip is in the watched set (e.g. via a
        // phantom-page skip) — the genuinely unwatched earlier clip must
        // still be found, not silently skipped forever.
        let watched: Set<String> = [Chapter.mockMusic.videos[1].id]
        #expect(Chapter.mockMusic.firstUnwatchedIndex(watched) == 0)
    }

    @Test func partiallyWatchedResumesRightAfterTheGap() {
        let watched: Set<String> = [Chapter.mockMusic.videos[0].id]
        #expect(Chapter.mockMusic.firstUnwatchedIndex(watched) == 1)
    }
}

// Fixes the case where an earlier chapter has a genuine, never-healed watch
// gap (e.g. via "Skip for demo," or simply abandoning a clip mid-play then
// paging past the rest) while every chapter has nonetheless been *reached*.
// Without this fallback, furthestChapterIndex alone would strand Home on a
// later chapter forever with no way back to the gap — meaning the journey
// could never honestly reach isJourneyComplete.
struct ChapterCurrentChapterTests {

    @Test func belowEndIgnoresEarlierGapsAndUsesFurthestReached() {
        // Not yet reached the end (furthestChapterIndex 1 < 3 chapters) —
        // must NOT reroute back to Background's gap; that would reopen bug #8
        // (forward progress silently reverting to an earlier chapter).
        let result = Journey.mock.chapters.currentChapter(furthestReached: 1, watched: [])
        #expect(result?.id == Chapter.mockMusic.id)
    }

    @Test func atEndWithNoGapsReturnsLastChapter() {
        let allWatched = Set(Journey.mock.chapters.flatMap { $0.videos.map(\.id) })
        let result = Journey.mock.chapters.currentChapter(furthestReached: 3, watched: allWatched)
        #expect(result?.id == Chapter.mockGoals.id)
    }

    @Test func atEndWithAnEarlierGapRoutesBackToTheGap() {
        // Music and Goals genuinely complete; Background was skipped and
        // never healed. Once every chapter has been reached, Home must offer
        // a way back to the one that's still genuinely incomplete.
        let watched = Set(Chapter.mockMusic.videos.map(\.id) + Chapter.mockGoals.videos.map(\.id))
        let result = Journey.mock.chapters.currentChapter(furthestReached: 3, watched: watched)
        #expect(result?.id == Chapter.mockBackground.id)
    }
}

struct JourneyProgressDecodingTests {

    @Test func decodesOldPersistedJSONMissingFurthestChapterIndex() throws {
        // Simulates already-persisted UserDefaults data written before this
        // field existed — must decode gracefully, not throw (which would
        // otherwise wipe all stored progress via LocalProgressStore's `try?`).
        let json = """
        {"watchedVideoIds":["video-music-1"],"lastWatchedVideoId":"video-music-1"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(JourneyProgress.self, from: json)
        #expect(decoded.furthestChapterIndex == 0)
        #expect(decoded.watchedVideoIds == ["video-music-1"])
    }

    @Test func roundTripsFurthestChapterIndex() throws {
        let original = JourneyProgress(watchedVideoIds: ["video-music-1"],
                                       lastWatchedVideoId: "video-music-1",
                                       furthestChapterIndex: 2)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JourneyProgress.self, from: data)
        #expect(decoded.furthestChapterIndex == 2)
    }
}

// Fixes two honesty bugs in ChapterCompleteView's screen-shape decision: #1 the
// locked screen's progress tally counted a chapter as done the moment it was
// reached (including via a phantom-page skip), regardless of whether it was
// genuinely watched; #2 the last chapter always resolved to .finished regardless
// of isJourneyComplete, offering a full celebration + Share Journey CTA for a
// journey the user never actually watched.
struct ChapterCompleteViewVariantTests {

    @Test func unlockedIgnoresChapterWatchedStatusWhenTrue() {
        let result = ChapterCompleteView.Variant.resolve(
            hasNextChapter: true, isNextUnlocked: true,
            chapterFullyWatched: true, journeyFullyWatched: false)
        #expect(result == .unlocked)
    }

    @Test func unlockedIgnoresChapterWatchedStatusWhenFalse() {
        let result = ChapterCompleteView.Variant.resolve(
            hasNextChapter: true, isNextUnlocked: true,
            chapterFullyWatched: false, journeyFullyWatched: false)
        #expect(result == .unlocked)
    }

    @Test func lockedHonestReflectsChapterGenuinelyWatched() {
        let result = ChapterCompleteView.Variant.resolve(
            hasNextChapter: true, isNextUnlocked: false,
            chapterFullyWatched: true, journeyFullyWatched: false)
        #expect(result == .locked(chapterFullyWatched: true))
    }

    @Test func lockedDishonestFlagsPhantomSkip() {
        // Regression test for bug #1.
        let result = ChapterCompleteView.Variant.resolve(
            hasNextChapter: true, isNextUnlocked: false,
            chapterFullyWatched: false, journeyFullyWatched: false)
        #expect(result == .locked(chapterFullyWatched: false))
    }

    @Test func finishedHonestWhenJourneyGenuinelyComplete() {
        let result = ChapterCompleteView.Variant.resolve(
            hasNextChapter: false, isNextUnlocked: false,
            chapterFullyWatched: true, journeyFullyWatched: true)
        #expect(result == .finished(journeyFullyWatched: true))
    }

    @Test func finishedDishonestOnLastChapterWithoutWatching() {
        // Regression test for bug #2: nextChapter is nil (last chapter) but the
        // journey wasn't genuinely watched — must not silently upgrade to an
        // honest "finished" celebration.
        let result = ChapterCompleteView.Variant.resolve(
            hasNextChapter: false, isNextUnlocked: false,
            chapterFullyWatched: false, journeyFullyWatched: false)
        #expect(result == .finished(journeyFullyWatched: false))
    }

    @Test func journeyFullyWatchedForcesFinishedEvenWithNextChapter() {
        let result = ChapterCompleteView.Variant.resolve(
            hasNextChapter: true, isNextUnlocked: true,
            chapterFullyWatched: true, journeyFullyWatched: true)
        #expect(result == .finished(journeyFullyWatched: true))
    }
}
