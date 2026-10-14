import Foundation

public struct PracticeStatItem: Equatable, Sendable {
    public var direction: Direction
    public var weighted: Int
    public var faithfulness: Int
    public var expressiveness: Int
    public var elegance: Int
    public var submittedAt: Date

    public init(
        direction: Direction,
        weighted: Int,
        faithfulness: Int,
        expressiveness: Int,
        elegance: Int,
        submittedAt: Date
    ) {
        self.direction = direction
        self.weighted = weighted
        self.faithfulness = faithfulness
        self.expressiveness = expressiveness
        self.elegance = elegance
        self.submittedAt = submittedAt
    }
}

public struct ScoreSpread: Equatable, Sendable {
    public var average: Int?
    public var best: Int?
    public var lowest: Int?
    public var recentAverage: Int?
    public var faithAverage: Int?
    public var expressAverage: Int?
    public var eleganceAverage: Int?
    public var from90: Int
    public var from80: Int
    public var from70: Int
    public var under70: Int

    public var total: Int { from90 + from80 + from70 + under70 }

    public init(
        average: Int?,
        best: Int?,
        lowest: Int?,
        recentAverage: Int?,
        faithAverage: Int?,
        expressAverage: Int?,
        eleganceAverage: Int?,
        from90: Int,
        from80: Int,
        from70: Int,
        under70: Int
    ) {
        self.average = average
        self.best = best
        self.lowest = lowest
        self.recentAverage = recentAverage
        self.faithAverage = faithAverage
        self.expressAverage = expressAverage
        self.eleganceAverage = eleganceAverage
        self.from90 = from90
        self.from80 = from80
        self.from70 = from70
        self.under70 = under70
    }
}

public enum PracticeStats {
    public static func count(_ items: [PracticeStatItem], direction: Direction) -> Int {
        items.filter { $0.direction == direction }.count
    }

    public static func spread(_ items: [PracticeStatItem], recent: Int = 7) -> ScoreSpread {
        let scores = items.map(\.weighted)
        let newest = items.sorted { $0.submittedAt > $1.submittedAt }.prefix(recent).map(\.weighted)
        return ScoreSpread(
            average: ScoreAverage.mean(scores),
            best: scores.max(),
            lowest: scores.min(),
            recentAverage: ScoreAverage.mean(Array(newest)),
            faithAverage: ScoreAverage.mean(items.map(\.faithfulness)),
            expressAverage: ScoreAverage.mean(items.map(\.expressiveness)),
            eleganceAverage: ScoreAverage.mean(items.map(\.elegance)),
            from90: scores.filter { ScoreBand.from90.matches(score: $0) }.count,
            from80: scores.filter { ScoreBand.from80.matches(score: $0) }.count,
            from70: scores.filter { ScoreBand.from70.matches(score: $0) }.count,
            under70: scores.filter { ScoreBand.under70.matches(score: $0) }.count
        )
    }
}
