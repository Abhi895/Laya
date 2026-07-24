import Foundation

// Chapter within a Journey (I/II/III)
struct Chapter: Codable, Identifiable {
    // Unique identifier for the chapter
    let id: String
    // 0/1/2 → I/II/III
    let index: Int
    // Title (Background / Music / Goals)
    let title: String
    // Subtitle (e.g., "Where Reuben began", "The sound that defines him")
    let subtitle: String
    // Unlock offset in days from the shared weekStartDate
    let unlockOffsetDays: Int
    // Ordered list of videos
    let videos: [JourneyVideo]
}

extension Chapter {
    /// A valid-but-empty stand-in for "nothing loaded yet" — used as the
    /// only safe default `@State` value outside of DEBUG, where the real
    /// mock chapters (`Chapter.mockBackground` etc.) don't exist. Always
    /// overwritten by the real fetched chapter before it could ever be
    /// shown to a user.
    static let placeholder = Chapter(
        id: "chapter-placeholder", index: 0, title: "", subtitle: "",
        unlockOffsetDays: 0, videos: []
    )

    /// 0…1 — how far through this chapter's videos the given watched set reaches.
    /// Drives the progress bar's fractional fill.
    func fractionWatched(_ watched: Set<String>) -> Double {
        guard !videos.isEmpty else { return 0 }
        let seen = videos.filter { watched.contains($0.id) }.count
        return Double(seen) / Double(videos.count)
    }

    /// True once every video in the chapter has been watched.
    func isComplete(_ watched: Set<String>) -> Bool {
        !videos.isEmpty && videos.allSatisfy { watched.contains($0.id) }
    }

    /// The index of the first video not yet in `watched`, or the last index
    /// if every video has already been watched. Used for resume — finds
    /// genuine gaps instead of trusting a "last touched" pointer, which
    /// paging forward without watching can stomp.
    func firstUnwatchedIndex(_ watched: Set<String>) -> Int {
        videos.firstIndex(where: { !watched.contains($0.id) }) ?? max(0, videos.count - 1)
    }

    /// The wall-clock moment this chapter becomes available, given the shared
    /// weekly anchor.
    func unlockDate(weekStartDate: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: unlockOffsetDays, to: weekStartDate) ?? weekStartDate
    }

    /// Whether this chapter has reached its unlock date yet.
    func isUnlocked(weekStartDate: Date, on date: Date = Date()) -> Bool {
        date >= unlockDate(weekStartDate: weekStartDate)
    }

    /// Weekday this chapter unlocks on, e.g. "Wednesday" — for "Drops Wednesday" copy.
    func unlockDayName(weekStartDate: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE"
        return fmt.string(from: unlockDate(weekStartDate: weekStartDate))
    }

    /// Whole calendar days from `date` until this chapter unlocks — for "in N
    /// days" copy. Normalizes both sides to the start of their calendar day
    /// first (matching HomeReturnView.nextJourneyLabel's convention), so the
    /// count reflects calendar-day intuition rather than a raw time-of-day
    /// diff — otherwise this could flip a day early depending on what time of
    /// day the chapter's anchor happens to fall on.
    func daysUntilUnlock(weekStartDate: Date, from date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: unlockDate(weekStartDate: weekStartDate))
        ).day ?? 0
        return max(0, days)
    }
}
