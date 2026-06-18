//
//  AssignmentServing.swift
//  Laya
//
//  Created by Abhi Reddy on 17/06/2026.
//

import Foundation

protocol AssignmentServing {
    // Fetch the current week's assignment for a given user,
    // including the nested journey and artist
    func fetchCurrentAssignment(for userId: String) async throws -> AssignmentPackage
    
    // Write progress updates to the assignment
    func updateProgress(_ progress: JourneyProgress, assignmentId: String) async throws
    
    // Mark a chapter as complete
    func completeChapter(index: Int, assignmentId: String) async throws
}

// Bundles everything Home needs in a single fetch
struct AssignmentPackage {
    let assignment: WeeklyAssignment
    let journey: Journey
    let artist: Artist
}
