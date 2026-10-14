import Foundation

public struct StreakSnapshot: Equatable, Sendable {
    public var current: Int
    public var lastCompletedDay: Date?
    public var lastCelebratedMultiple: Int
    public var shields: Int
    public var shieldsGrantedForRun: Int
    public var shieldedDayKeys: [String]

    public init(
        current: Int = 0,
        lastCompletedDay: Date? = nil,
        lastCelebratedMultiple: Int = 0,
        shields: Int = 0,
        shieldsGrantedForRun: Int = 0,
        shieldedDayKeys: [String] = []
    ) {
        self.current = current
        self.lastCompletedDay = lastCompletedDay
        self.lastCelebratedMultiple = lastCelebratedMultiple
        self.shields = shields
        self.shieldsGrantedForRun = shieldsGrantedForRun
        self.shieldedDayKeys = shieldedDayKeys
    }
}

public struct StreakUpdate: Equatable, Sendable {
    public var snapshot: StreakSnapshot
    public var shouldCelebrate: Bool

    public init(snapshot: StreakSnapshot, shouldCelebrate: Bool) {
        self.snapshot = snapshot
        self.shouldCelebrate = shouldCelebrate
    }
}

public enum StreakEngine {
    public static let shieldCap = 2

    public static func register(
        state: StreakSnapshot,
        on day: Date,
        bothDirectionsDone: Bool,
        calendar: Calendar
    ) -> StreakUpdate {
        var state = reconcileShields(state)
        guard bothDirectionsDone else {
            return StreakUpdate(snapshot: state, shouldCelebrate: false)
        }
        let today = calendar.startOfDay(for: day)
        if let last = state.lastCompletedDay, calendar.isDate(last, inSameDayAs: today) {
            return StreakUpdate(snapshot: state, shouldCelebrate: false)
        }

        var next = state
        if let last = state.lastCompletedDay {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            if calendar.isDate(last, inSameDayAs: yesterday) {
                next.current += 1
            } else {
                next.current = 1
                next.shieldsGrantedForRun = 0
            }
        } else {
            next.current = 1
            next.shieldsGrantedForRun = 0
        }
        next.lastCompletedDay = today
        next = reconcileShields(next)

        var celebrate = false
        if next.current > 0, next.current.isMultiple(of: 25), next.lastCelebratedMultiple != next.current {
            celebrate = true
            next.lastCelebratedMultiple = next.current
        }
        return StreakUpdate(snapshot: next, shouldCelebrate: celebrate)
    }

    public static func missedDays(since last: Date?, on day: Date, calendar: Calendar) -> [Date] {
        guard let last else { return [] }
        let today = calendar.startOfDay(for: day)
        let lastDay = calendar.startOfDay(for: last)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return [] }
        if lastDay >= yesterday { return [] }
        var missed: [Date] = []
        var cursor = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? yesterday
        while cursor <= yesterday {
            missed.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return missed
    }

    public static func repair(state: StreakSnapshot, on day: Date, calendar: Calendar) -> StreakSnapshot? {
        let missed = missedDays(since: state.lastCompletedDay, on: day, calendar: calendar)
        guard !missed.isEmpty, missed.count <= state.shields, missed.count <= shieldCap else { return nil }
        var next = state
        next.shields -= missed.count
        let today = calendar.startOfDay(for: day)
        next.lastCompletedDay = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let keys = missed.map { DayKey.string(from: $0, calendar: calendar) }
        for key in keys where !next.shieldedDayKeys.contains(key) {
            next.shieldedDayKeys.append(key)
        }
        return next
    }

    public static func reconcileShields(_ state: StreakSnapshot) -> StreakSnapshot {
        var next = state
        let earned = max(0, next.current / 10)
        if earned > next.shieldsGrantedForRun {
            let gain = earned - next.shieldsGrantedForRun
            next.shields = min(shieldCap, next.shields + gain)
            next.shieldsGrantedForRun = earned
        }
        return next
    }
}

public struct DayStat: Equatable, Sendable {
    public var streakDirections: Int
    public var scores: [Int]
    public var shielded: Bool

    public var average: Int? {
        ScoreAverage.mean(scores)
    }

    public init(streakDirections: Int = 0, scores: [Int] = [], shielded: Bool = false) {
        self.streakDirections = streakDirections
        self.scores = scores
        self.shielded = shielded
    }
}

public enum ScoreAverage {
    public static func mean(_ scores: [Int]) -> Int? {
        guard !scores.isEmpty else { return nil }
        let total = scores.reduce(0, +)
        return Int((Double(total) / Double(scores.count)).rounded())
    }
}

public enum CalendarLayout {
    public static func monthCells(containing date: Date, calendar: Calendar) -> [Date?] {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        guard let dayRange = calendar.range(of: .day, in: .month, for: start) else { return [] }
        let weekday = calendar.component(.weekday, from: start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in dayRange {
            var parts = calendar.dateComponents([.year, .month], from: start)
            parts.day = day
            cells.append(calendar.date(from: parts))
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    public static func recentWeeks(ending date: Date, count: Int, calendar: Calendar) -> [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        return (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -7 * offset, to: start)
        }
    }
}
