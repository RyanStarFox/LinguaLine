import Foundation

public enum DayKey {
    public static func string(from date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func dailyKey(day: Date, language: PracticeLanguage, direction: Direction, index: Int = 0, calendar: Calendar = .current) -> String {
        let base = "\(string(from: day, calendar: calendar))|\(language.rawValue)|\(direction.rawValue)"
        guard index > 0 else { return base }
        return "\(base)|\(index)"
    }

    public static func matches(_ key: String, day: Date, language: PracticeLanguage, direction: Direction, calendar: Calendar = .current) -> Bool {
        guard !key.isEmpty else { return false }
        let base = dailyKey(day: day, language: language, direction: direction, calendar: calendar)
        return key == base || key.hasPrefix(base + "|")
    }

    public static func dailyIndex(in key: String) -> Int {
        let parts = key.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count >= 4, let index = Int(parts[3]), index > 0 else { return 0 }
        return index
    }
}

public enum DailyQuota {
    public static let minimumTotal = 1
    public static let maximumPerDirection = 10

    public static func clamp(_ value: Int) -> Int {
        min(maximumPerDirection, max(0, value))
    }

    public static func accepted(nativeToPractice: Int, practiceToNative: Int) -> (nativeToPractice: Int, practiceToNative: Int)? {
        let native = clamp(nativeToPractice)
        let practice = clamp(practiceToNative)
        guard native + practice >= minimumTotal else { return nil }
        return (native, practice)
    }

    public static func requirementsMet(submitted: Int, target: Int) -> Bool {
        submitted >= target
    }

    public static func requirementsMet(submittedIndices: Set<Int>, target: Int) -> Bool {
        guard target > 0 else { return true }
        return (0..<target).allSatisfy { submittedIndices.contains($0) }
    }

    public static func requirementsMet(
        nativeToPractice: Set<Int>,
        practiceToNative: Set<Int>,
        nativeToPracticeTarget: Int,
        practiceToNativeTarget: Int
    ) -> Bool {
        requirementsMet(submittedIndices: nativeToPractice, target: nativeToPracticeTarget)
            && requirementsMet(submittedIndices: practiceToNative, target: practiceToNativeTarget)
    }
}

public struct DailyItem: Equatable, Sendable {
    public var key: String
    public var text: String

    public init(key: String, text: String) {
        self.key = key
        self.text = text
    }
}

public enum DailyCatalog {
    public static func resolve(existing: [DailyItem], key: String, make: () -> DailyItem) -> DailyItem {
        if let found = existing.first(where: { $0.key == key }) {
            return found
        }
        return make()
    }
}
