import Foundation

public enum ScoreSort: String, CaseIterable, Identifiable, Sendable {
    case newest
    case oldest
    case high
    case low

    public var id: String { rawValue }
}

public enum ScoreBand: String, CaseIterable, Identifiable, Sendable {
    case all
    case from90
    case from80
    case from70
    case under70

    public var id: String { rawValue }

    public func matches(score: Int?) -> Bool {
        guard let score else { return self == .all }
        switch self {
        case .all: return true
        case .from90: return score >= 90
        case .from80: return (80..<90).contains(score)
        case .from70: return (70..<80).contains(score)
        case .under70: return score < 70
        }
    }
}

public enum ScoreList {
    public static func ordered<T>(
        _ rows: [T],
        sort: ScoreSort,
        date: (T) -> Date,
        score: (T) -> Int?,
        pinned: (T) -> Bool = { _ in false }
    ) -> [T] {
        rows.sorted { lhs, rhs in
            let leftPinned = pinned(lhs)
            let rightPinned = pinned(rhs)
            if leftPinned != rightPinned { return leftPinned && !rightPinned }
            switch sort {
            case .newest:
                return date(lhs) > date(rhs)
            case .oldest:
                return date(lhs) < date(rhs)
            case .high, .low:
                switch (score(lhs), score(rhs)) {
                case let (left?, right?) where left != right:
                    return sort == .high ? left > right : left < right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                default:
                    return date(lhs) > date(rhs)
                }
            }
        }
    }
}
