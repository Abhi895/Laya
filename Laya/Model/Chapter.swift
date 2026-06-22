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

    /// Whole days from `date` until this chapter unlocks — for "in N days" copy.
    func daysUntilUnlock(weekStartDate: Date, from date: Date = Date()) -> Int {
        let days = Calendar.current.dateComponents([.day], from: date, to: unlockDate(weekStartDate: weekStartDate)).day ?? 0
        return max(0, days)
    }
}
