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
    // Every video this user has watched — the single source of truth for "how far".
    // Chapter completion and per-chapter progress are derived from this against the
    // catalog (Chapter.videos), so there's nothing to keep in sync.
    var watchedVideoIds: Set<String>
    // Explicit resume pointer — which video to drop the user back into. The watched
    // set is unordered, so this can't be derived from it.
    var lastWatchedVideoId: String?
    // Set when all 3 chapters are done
    var completedAt: Date?
}

extension WeeklyAssignment {
    /// The real-world Monday at 00:00 on/before `date` — the actual weekly
    /// rollover boundary, independent of locale/region week settings (Sunday-
    /// vs-Monday-first calendars). `MockAssignmentService` uses this both to
    /// pick which mock artist is "this week's" and to drive chapter unlocks.
    static func currentWeekStartDate(from date: Date = Date()) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay) // 1=Sun...7=Sat
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay) ?? startOfDay
    }
}
