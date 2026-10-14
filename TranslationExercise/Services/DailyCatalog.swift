import Foundation

public enum DayKey {
    public static func string(from date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func dailyKey(
        day: Date,
        language: PracticeLanguage,
        direction: Direction,
        index: Int = 0,
        native: PracticeLanguage? = nil,
        calendar: Calendar = .current
    ) -> String {
        var key = "\(string(from: day, calendar: calendar))|\(language.rawValue)|\(direction.rawValue)"
        if index > 0 {
            key += "|\(index)"
        }
        if let native {
            key += "|\(native.rawValue)"
        }
        return key
    }

    public static func matches(
        _ key: String,
        day: Date,
        language: PracticeLanguage,
        direction: Direction,
        native: PracticeLanguage? = nil,
        calendar: Calendar = .current
    ) -> Bool {
        guard !key.isEmpty else { return false }
        let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3 else { return false }
        guard parts[0] == string(from: day, calendar: calendar) else { return false }
        guard parts[1] == language.rawValue, parts[2] == direction.rawValue else { return false }
        return nativeCode(in: key) == native?.rawValue
    }

    public static func dailyIndex(in key: String) -> Int {
        let parts = key.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count >= 4, let index = Int(parts[3]), index > 0 else { return 0 }
        return index
    }

    public static func nativeCode(in key: String) -> String? {
        let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 4 else { return nil }
        if Int(parts[3]) != nil {
            guard parts.count >= 5 else { return nil }
            return parts[4]
        }
        return parts[3]
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
