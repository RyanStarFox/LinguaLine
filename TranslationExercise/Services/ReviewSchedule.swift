import Foundation

public struct ReviewSource: Equatable, Sendable {
    public var id: UUID
    public var direction: Direction
    public var languageCode: String
    public var kind: ExerciseKind
    public var submitted: Bool
    public var submittedAt: Date
    public var weightedScore: Int

    public init(
        id: UUID,
        direction: Direction,
        languageCode: String,
        kind: ExerciseKind,
        submitted: Bool,
        submittedAt: Date,
        weightedScore: Int
    ) {
        self.id = id
        self.direction = direction
        self.languageCode = languageCode
        self.kind = kind
        self.submitted = submitted
        self.submittedAt = submittedAt
        self.weightedScore = weightedScore
    }
}

public struct ReviewMark: Equatable, Sendable {
    public var id: UUID
    public var exerciseID: UUID
    public var direction: Direction
    public var languageCode: String
    public var reviewedAt: Date
    public var weightedScore: Int
    public var intervalDays: Int
    public var dueDay: Date

    public init(
        id: UUID,
        exerciseID: UUID,
        direction: Direction,
        languageCode: String,
        reviewedAt: Date,
        weightedScore: Int,
        intervalDays: Int,
        dueDay: Date
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.direction = direction
        self.languageCode = languageCode
        self.reviewedAt = reviewedAt
        self.weightedScore = weightedScore
        self.intervalDays = intervalDays
        self.dueDay = dueDay
    }
}

public struct ReviewDueItem: Equatable, Sendable, Identifiable {
    public var exerciseID: UUID
    public var direction: Direction
    public var dueDay: Date
    public var lastScore: Int
    public var submittedAt: Date

    public var id: UUID { exerciseID }

    public init(exerciseID: UUID, direction: Direction, dueDay: Date, lastScore: Int, submittedAt: Date) {
        self.exerciseID = exerciseID
        self.direction = direction
        self.dueDay = dueDay
        self.lastScore = lastScore
        self.submittedAt = submittedAt
    }
}

public enum ReviewChange: Equatable, Sendable, Codable {
    case retire
    case multiply(Int)
    case keep
    case divide(Int)
}

public struct ReviewBand: Equatable, Sendable, Codable, Identifiable {
    public var id: UUID
    public var minScore: Int
    public var change: ReviewChange

    public init(id: UUID = UUID(), minScore: Int, change: ReviewChange) {
        self.id = id
        self.minScore = minScore
        self.change = change
    }
}

public struct ReviewPolicy: Equatable, Sendable, Codable {
    public var bands: [ReviewBand]

    public static let standard = ReviewPolicy(retireScore: 96, growScore: 80, growFactor: 2, holdScore: 30, shrinkFactor: 2)
    public static let scoreRange = 0...100
    public static let factorRange = 2...8
    public static let maxBands = 8

    public init(bands: [ReviewBand]) {
        self.bands = bands
    }

    public init(retireScore: Int, growScore: Int, growFactor: Int, holdScore: Int, shrinkFactor: Int) {
        let shrink = min(max(shrinkFactor, Self.factorRange.lowerBound), Self.factorRange.upperBound)
        let grow = min(max(growFactor, Self.factorRange.lowerBound), Self.factorRange.upperBound)
        let hold = min(max(holdScore, Self.scoreRange.lowerBound), Self.scoreRange.upperBound)
        let grown = min(max(growScore, hold), Self.scoreRange.upperBound)
        let retire = min(max(retireScore, grown), Self.scoreRange.upperBound)
        var bands = [
            ReviewBand(minScore: retire, change: .retire),
            ReviewBand(minScore: grown, change: .multiply(grow)),
        ]
        if hold < grown {
            bands.append(ReviewBand(minScore: hold, change: .keep))
        }
        bands.append(ReviewBand(minScore: 0, change: .divide(shrink)))
        self.init(bands: bands)
        self = clamped()
    }

    public var orderedBands: [ReviewBand] {
        bands.sorted { lhs, rhs in
            if lhs.minScore != rhs.minScore { return lhs.minScore > rhs.minScore }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    public var retireScore: Int {
        orderedBands.first { $0.change == .retire }?.minScore ?? 101
    }

    public var growScore: Int {
        orderedBands.first { if case .multiply = $0.change { return true }; return false }?.minScore
            ?? orderedBands.first { $0.change == .keep }?.minScore
            ?? 0
    }

    public var growFactor: Int {
        for band in orderedBands {
            if case let .multiply(factor) = band.change { return factor }
        }
        return Self.factorRange.lowerBound
    }

    public var holdScore: Int {
        orderedBands.first { $0.change == .keep }?.minScore ?? 0
    }

    public var shrinkFactor: Int {
        if case let .divide(factor) = orderedBands.last?.change { return factor }
        return Self.factorRange.lowerBound
    }

    public func clamped() -> ReviewPolicy {
        let next = bands.map { band -> ReviewBand in
            var band = band
            band.minScore = min(max(band.minScore, Self.scoreRange.lowerBound), Self.scoreRange.upperBound)
            switch band.change {
            case let .multiply(factor):
                band.change = .multiply(min(max(factor, Self.factorRange.lowerBound), Self.factorRange.upperBound))
            case let .divide(factor):
                band.change = .divide(min(max(factor, Self.factorRange.lowerBound), Self.factorRange.upperBound))
            case .retire, .keep:
                break
            }
            return band
        }
        let retire = next.filter { $0.change == .retire }.max { $0.minScore < $1.minScore }
        var others = next.filter { $0.change != .retire }.sorted { $0.minScore > $1.minScore }
        var kept: [ReviewBand] = []
        var used: Set<Int> = []
        for band in others where !used.contains(band.minScore) {
            used.insert(band.minScore)
            kept.append(band)
        }
        if !kept.contains(where: { $0.minScore == 0 }) {
            kept.append(ReviewBand(minScore: 0, change: .divide(Self.factorRange.lowerBound)))
        }
        if let retire {
            kept.append(retire)
        }
        return ReviewPolicy(bands: kept)
    }

    public func band(covering score: Int) -> ReviewBand? {
        orderedBands.first { $0.change != .retire && score >= $0.minScore }
    }

    public func scoreBounds(for id: UUID) -> ClosedRange<Int> {
        let sorted = orderedBands
        guard let index = sorted.firstIndex(where: { $0.id == id }) else { return Self.scoreRange }
        if sorted[index].minScore == 0 { return 0...0 }
        let current = sorted[index].minScore
        let ceiling = index > 0 ? sorted[index - 1].minScore - 1 : Self.scoreRange.upperBound
        let floor = index + 1 < sorted.count ? sorted[index + 1].minScore + 1 : 1
        return min(floor, current)...max(ceiling, current)
    }

    public var canInsertBand: Bool {
        orderedBands.count < Self.maxBands && insertionScore() != nil
    }

    public func insertingBand() -> ReviewPolicy {
        guard let score = insertionScore() else { return clamped() }
        var next = bands
        next.append(ReviewBand(minScore: score, change: .keep))
        return ReviewPolicy(bands: next).clamped()
    }

    public func removingBand(id: UUID) -> ReviewPolicy {
        guard orderedBands.count > 2, let band = bands.first(where: { $0.id == id }), band.minScore != 0 else {
            return clamped()
        }
        return ReviewPolicy(bands: bands.filter { $0.id != id }).clamped()
    }

    public func updatingScore(id: UUID, score: Int) -> ReviewPolicy {
        var next = bands
        guard let index = next.firstIndex(where: { $0.id == id }), next[index].minScore != 0 else { return clamped() }
        next[index].minScore = score
        return ReviewPolicy(bands: next).clamped()
    }

    public func updatingChange(id: UUID, change: ReviewChange) -> ReviewPolicy {
        var next = bands
        guard let index = next.firstIndex(where: { $0.id == id }) else { return clamped() }
        next[index].change = change
        return ReviewPolicy(bands: next).clamped()
    }

    private func insertionScore() -> Int? {
        let scores = orderedBands.map(\.minScore)
        var bounds = scores
        if bounds.first != Self.scoreRange.upperBound {
            bounds.insert(Self.scoreRange.upperBound, at: 0)
        }
        var best: (gap: Int, score: Int)?
        for index in 0..<(bounds.count - 1) {
            let gap = bounds[index] - bounds[index + 1]
            guard gap > 1 else { continue }
            let score = bounds[index + 1] + gap / 2
            if best == nil || gap > best!.gap {
                best = (gap, score)
            }
        }
        return best?.score
    }
}

public enum ReviewSchedule {
    public static let maxIntervalDays = 60

    public static func admits(kind: ExerciseKind, submitted: Bool) -> Bool {
        guard submitted else { return false }
        switch kind {
        case .daily, .extra, .placement:
            return true
        case .ready:
            return false
        }
    }

    public static func firstDueDay(submittedAt: Date, calendar: Calendar) -> Date {
        adding(days: 1, to: submittedAt, calendar: calendar)
    }

    public static func interval(after score: Int, previousDays: Int, policy: ReviewPolicy = .standard) -> Int {
        let previous = max(1, previousDays)
        let policy = policy.clamped()
        guard let band = policy.band(covering: score) else {
            return min(maxIntervalDays, previous)
        }
        switch band.change {
        case .retire, .keep:
            return min(maxIntervalDays, previous)
        case let .multiply(factor):
            let multiplied = previous.multipliedReportingOverflow(by: factor)
            let value = multiplied.overflow ? maxIntervalDays : multiplied.partialValue
            return min(maxIntervalDays, max(1, value))
        case let .divide(factor):
            return max(1, previous / max(1, factor))
        }
    }

    public static func retires(score: Int, policy: ReviewPolicy = .standard) -> Bool {
        score >= policy.clamped().retireScore
    }

    public static func dueDay(on reviewDay: Date, intervalDays: Int, calendar: Calendar) -> Date {
        adding(days: max(1, intervalDays), to: reviewDay, calendar: calendar)
    }

    public static func previousInterval(
        marks: [ReviewMark],
        exerciseID: UUID,
        direction: Direction,
        languageCode: String
    ) -> Int {
        let related = marks.filter {
            $0.exerciseID == exerciseID && $0.direction == direction && $0.languageCode == languageCode
        }
        guard let latest = latestMark(in: related) else { return 1 }
        return max(1, latest.intervalDays)
    }

    public static func dueItems(
        sources: [ReviewSource],
        marks: [ReviewMark],
        direction: Direction,
        languageCode: String,
        today: Date,
        calendar: Calendar,
        policy: ReviewPolicy = .standard
    ) -> [ReviewDueItem] {
        let policy = policy.clamped()
        let todayStart = calendar.startOfDay(for: today)
        let items = sources.compactMap { source -> ReviewDueItem? in
            guard source.direction == direction, source.languageCode == languageCode else { return nil }
            guard admits(kind: source.kind, submitted: source.submitted) else { return nil }
            let related = marks.filter {
                $0.exerciseID == source.id && $0.direction == direction && $0.languageCode == languageCode
            }
            let due: Date
            let score: Int
            if let latest = latestMark(in: related) {
                due = calendar.startOfDay(for: latest.dueDay)
                score = latest.weightedScore
            } else {
                due = firstDueDay(submittedAt: source.submittedAt, calendar: calendar)
                score = source.weightedScore
            }
            guard due <= todayStart, score < policy.retireScore else { return nil }
            return ReviewDueItem(
                exerciseID: source.id,
                direction: source.direction,
                dueDay: due,
                lastScore: score,
                submittedAt: source.submittedAt
            )
        }
        return items.sorted { lhs, rhs in
            if lhs.dueDay != rhs.dueDay { return lhs.dueDay < rhs.dueDay }
            if lhs.lastScore != rhs.lastScore { return lhs.lastScore < rhs.lastScore }
            if lhs.submittedAt != rhs.submittedAt { return lhs.submittedAt < rhs.submittedAt }
            return lhs.exerciseID.uuidString < rhs.exerciseID.uuidString
        }
    }

    private static func latestMark(in marks: [ReviewMark]) -> ReviewMark? {
        marks.max { lhs, rhs in
            if lhs.reviewedAt != rhs.reviewedAt { return lhs.reviewedAt < rhs.reviewedAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private static func adding(days: Int, to date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: days, to: start) ?? start
    }
}

public struct PhraseSource: Equatable, Sendable {
    public var id: UUID
    public var direction: Direction
    public var languageCode: String
    public var createdAt: Date

    public init(id: UUID, direction: Direction, languageCode: String, createdAt: Date) {
        self.id = id
        self.direction = direction
        self.languageCode = languageCode
        self.createdAt = createdAt
    }
}

public struct PhraseReviewMark: Equatable, Sendable {
    public var id: UUID
    public var phraseID: UUID
    public var reviewedAt: Date
    public var remembered: Bool
    public var intervalDays: Int
    public var dueDay: Date

    public init(id: UUID, phraseID: UUID, reviewedAt: Date, remembered: Bool, intervalDays: Int, dueDay: Date) {
        self.id = id
        self.phraseID = phraseID
        self.reviewedAt = reviewedAt
        self.remembered = remembered
        self.intervalDays = intervalDays
        self.dueDay = dueDay
    }
}

public struct PhraseDueItem: Equatable, Sendable, Identifiable {
    public var phraseID: UUID
    public var direction: Direction
    public var dueDay: Date

    public var id: UUID { phraseID }

    public init(phraseID: UUID, direction: Direction, dueDay: Date) {
        self.phraseID = phraseID
        self.direction = direction
        self.dueDay = dueDay
    }
}

public enum PhraseSchedule {
    public static func interval(remembered: Bool, previousDays: Int, policy: ReviewPolicy = .standard) -> Int {
        let score = remembered ? policy.clamped().growScore : 0
        return ReviewSchedule.interval(after: score, previousDays: previousDays, policy: policy)
    }

    public static func dueItems(
        phrases: [PhraseSource],
        marks: [PhraseReviewMark],
        direction: Direction,
        languageCode: String,
        today: Date,
        calendar: Calendar
    ) -> [PhraseDueItem] {
        let todayStart = calendar.startOfDay(for: today)
        let items = phrases.compactMap { phrase -> PhraseDueItem? in
            guard phrase.direction == direction, phrase.languageCode == languageCode else { return nil }
            let related = marks.filter { $0.phraseID == phrase.id }
            let due: Date
            if let latest = related.max(by: { lhs, rhs in
                if lhs.reviewedAt != rhs.reviewedAt { return lhs.reviewedAt < rhs.reviewedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }) {
                due = calendar.startOfDay(for: latest.dueDay)
            } else {
                due = ReviewSchedule.firstDueDay(submittedAt: phrase.createdAt, calendar: calendar)
            }
            guard due <= todayStart else { return nil }
            return PhraseDueItem(phraseID: phrase.id, direction: phrase.direction, dueDay: due)
        }
        return items.sorted { lhs, rhs in
            if lhs.dueDay != rhs.dueDay { return lhs.dueDay < rhs.dueDay }
            return lhs.phraseID.uuidString < rhs.phraseID.uuidString
        }
    }
}
