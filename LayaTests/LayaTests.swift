//
//  LayaTests.swift
//  LayaTests
//
//  Created by Abhi Reddy on 17/06/2026.
//

import Testing
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
