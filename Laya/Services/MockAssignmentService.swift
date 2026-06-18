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
struct MockAssignmentService: AssignmentServing {
    func fetchCurrentAssignment(for userId: String) async throws -> AssignmentPackage {
        AssignmentPackage(
            assignment: .mock,
            journey: .mock,
            artist: .mock
        )
    }
    
    func updateProgress(_ progress: JourneyProgress, assignmentId: String) async throws {
        // No-op in mock — state lives in the view model
    }
    
    func completeChapter(index: Int, assignmentId: String) async throws {
        // No-op in mock
    }
}
#endif
