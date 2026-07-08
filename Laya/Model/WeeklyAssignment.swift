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
    // No longer drives resume placement (see Chapter.firstUnwatchedIndex, which
    // scans watchedVideoIds directly instead) — kept only as a persisted record
    // of the most recently reached-or-finished clip.
    var lastWatchedVideoId: String?
    // How far the user has gotten: one past the last chapter whose completion
    // event fired (natural end or the phantom-page swipe-past shortcut alike).
    // Monotonic — never regresses. Deliberately independent of watchedVideoIds,
    // which stays honest per-clip; deriving "current chapter" from that instead
    // of this is what let skip-swiped progress silently revert.
    var furthestChapterIndex: Int

    init(watchedVideoIds: Set<String>, lastWatchedVideoId: String?, furthestChapterIndex: Int = 0) {
        self.watchedVideoIds = watchedVideoIds
        self.lastWatchedVideoId = lastWatchedVideoId
        self.furthestChapterIndex = furthestChapterIndex
    }

    // Tolerates already-persisted UserDefaults data written before this field
    // existed — decodes to 0 rather than throwing, which (via LocalProgressStore's
    // `try? decode([String: JourneyProgress])`) would otherwise silently wipe
    // every stored assignment's progress, not just this one's.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        watchedVideoIds = try container.decode(Set<String>.self, forKey: .watchedVideoIds)
        lastWatchedVideoId = try container.decodeIfPresent(String.self, forKey: .lastWatchedVideoId)
        furthestChapterIndex = try container.decodeIfPresent(Int.self, forKey: .furthestChapterIndex) ?? 0
    }
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
