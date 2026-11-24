import Foundation

public struct FocusSession: Codable, Equatable, Sendable {
    public var start: Date
    public var end: Date
    public var modeID: UUID?

    public init(start: Date, end: Date, modeID: UUID? = nil) {
        self.start = start
        self.end = end
        self.modeID = modeID
    }

    public var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

/// Completed blocks, used for daily totals and the day streak.
public struct FocusHistory: Codable, Equatable, Sendable {
    public static let retentionDays = 365

    public var sessions: [FocusSession]

    public init(sessions: [FocusSession] = []) {
        self.sessions = sessions
    }

    /// Adds a session and drops sessions that ended more than `retentionDays` before it.
    public func appending(_ session: FocusSession) -> FocusHistory {
        let cutoff = session.end.addingTimeInterval(-Double(Self.retentionDays) * 86_400)
        return FocusHistory(sessions: (sessions + [session]).filter { $0.end >= cutoff })
    }

    /// Focused seconds within the calendar day of `day`. Sessions crossing midnight are split.
    public func totalFocus(on day: Date, calendar: Calendar = .current) -> TimeInterval {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }
        return sessions.reduce(0) { total, session in
            let overlap = min(session.end, dayEnd).timeIntervalSince(max(session.start, dayStart))
            return total + max(0, overlap)
        }
    }

    /// Days of the last `weeks` weeks (columns, oldest first), 7 per week, aligned to `calendar.firstWeekday`.
    /// Days after `now`'s day are nil.
    public func weeklyGrid(weeks: Int, endingAt now: Date,
                           calendar: Calendar = .current) -> [[(date: Date, focus: TimeInterval)?]] {
        let today = calendar.startOfDay(for: now)
        guard weeks > 0,
              let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let first = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeek) else { return [] }
        // shortcut: scans every session per cell; bucket sessions in one pass if history grows to thousands.
        return (0..<weeks).map { week in
            (0..<7).map { weekday in
                guard let day = calendar.date(byAdding: .day, value: week * 7 + weekday, to: first),
                      day <= today else { return nil }
                return (day, totalFocus(on: day, calendar: calendar))
            }
        }
    }

    /// Consecutive days with focus, ending today. If today has none yet, counting starts from yesterday.
    public func streak(endingAt now: Date, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: now)
        if totalFocus(on: day, calendar: calendar) == 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while totalFocus(on: day, calendar: calendar) > 0 {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
