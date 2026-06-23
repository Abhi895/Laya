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

#if DEBUG
extension WeeklyAssignment {
    static let mock = WeeklyAssignment(
        id: "assignment-mock",
        userId: "user-mock",
        journeyId: "journey-tayo-james",
        // Anchored 3 days back so Music (offset 2) reads as unlocked and Goals
        // (offset 5) reads as locked — lets both completion-screen variants be
        // exercised by playing Background → Music in one run.
        weekStartDate: Calendar.current.date(
            byAdding: .day, value: -3,
            to: Calendar.current.startOfDay(for: Date())
        )!,
        assignedAt: Date(),
        progress: JourneyProgress(
            watchedVideoIds: [],
            lastWatchedVideoId: nil,
            completedAt: nil
        )
    )

    // Debug-only variant — anchored far enough back that every chapter,
    // including the last (offset 5), reads as unlocked. Backs the "Skip to
    // finished" debug shortcut so the real finished-screen / share-artifact
    // flow can be reached without waiting on real unlock dates.
    static let mockAllUnlocked = WeeklyAssignment(
        id: "assignment-mock",
        userId: "user-mock",
        journeyId: "journey-tayo-james",
        weekStartDate: Calendar.current.date(
            byAdding: .day, value: -7,
            to: Calendar.current.startOfDay(for: Date())
        )!,
        assignedAt: Date(),
        progress: JourneyProgress(
            watchedVideoIds: [],
            lastWatchedVideoId: nil,
            completedAt: nil
        )
    )
}
#endif
