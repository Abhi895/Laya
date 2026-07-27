//
//  Calendar+WholeDays.swift
//  Laya
//
//  Created by Abhi Reddy on 26/07/2026.
//

import Foundation

extension Calendar {
    /// Whole calendar days between two dates, normalizing both to the start of
    /// their day first — so the count reflects calendar-day intuition ("in N
    /// days") rather than a raw time-of-day diff that could flip a day early
    /// depending on what time of day each date falls on. Unclamped: each caller
    /// keeps its own clamp/guard policy (e.g. `daysUntilUnlock` clamps to `max(0,
    /// …)`; `nextJourneyLabel` uses its own `guard days > 0`).
    func wholeDays(from: Date, to: Date) -> Int {
        dateComponents([.day], from: startOfDay(for: from), to: startOfDay(for: to)).day ?? 0
    }
}
