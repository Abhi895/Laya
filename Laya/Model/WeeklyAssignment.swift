import Foundation

// Which journey a user has this week — per-user; also carries progress
struct WeeklyAssignment: Codable, Identifiable {
    // Unique identifier for this assignment
    let id: String
    // The user's identifier
    let userId: String
    // The assigned journey's identifier
    let journeyId: String
    // The shared week anchor — identical for every user assigned that week
    let weekStartDate: Date
    // Analytics / "joined mid-week" detection — does not drive unlocks
    let assignedAt: Date
    // Nested progress value (not its own document)
    var progress: JourneyProgress

}

struct JourneyProgress: Codable {
    // Which chapter indices have been completed
    var completedChapterIndices: [Int]
    // The last watched video id, if any
    var lastWatchedVideoId: String?
    // Set when all 3 chapters are done
    var completedAt: Date?
}

#if DEBUG
extension WeeklyAssignment {
    static let mock = WeeklyAssignment(
        id: "assignment-mock",
        userId: "user-mock",
        journeyId: "journey-tayo-james",
        weekStartDate: Calendar.current.startOfDay(for: Date()),
        assignedAt: Date(),
        progress: JourneyProgress(
            completedChapterIndices: [],
            lastWatchedVideoId: nil,
            completedAt: nil
        )
    )
}
#endif
