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
// Backs the mock with an in-memory store keyed by assignment id, so progress
// written by one view (e.g. JourneySessionView watching a video) is visible
// to the next fetch from any other view (e.g. HomeReturnView) — without this,
// every fetchCurrentAssignment() would reset to WeeklyAssignment.mock's empty
// progress, and chapter progress could never survive leaving a session.
@MainActor
private final class MockProgressStore {
    static let shared = MockProgressStore()
    private var progress: [String: JourneyProgress] = [:]
    private init() {}

    func progress(for assignmentId: String, fallback: JourneyProgress) -> JourneyProgress {
        progress[assignmentId] ?? fallback
    }

    func set(_ progress: JourneyProgress, for assignmentId: String) {
        self.progress[assignmentId] = progress
    }
}

struct MockAssignmentService: AssignmentServing {
    func fetchCurrentAssignment(for userId: String) async throws -> AssignmentPackage {
        var assignment = WeeklyAssignment.mock
        assignment.progress = await MockProgressStore.shared.progress(for: assignment.id, fallback: assignment.progress)
        return AssignmentPackage(
            assignment: assignment,
            journey: .mock,
            artist: .mock
        )
    }

    func updateProgress(_ progress: JourneyProgress, assignmentId: String) async throws {
        await MockProgressStore.shared.set(progress, for: assignmentId)
    }

    func completeChapter(index: Int, assignmentId: String) async throws {
        // No-op in mock
    }
}
#endif
