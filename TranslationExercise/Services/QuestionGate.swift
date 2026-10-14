import Foundation

public enum SourceScript: Equatable, Sendable {
    case chinese
    case japanese
    case korean
    case cyrillic
    case arabic
    case latin

    public static func expected(direction: Direction, language: PracticeLanguage, native: PracticeLanguage = .chinese) -> SourceScript {
        script(of: direction.source(native: native, practice: language))
    }

    public static func script(of language: PracticeLanguage) -> SourceScript {
        switch language {
        case .chinese: .chinese
        case .japanese: .japanese
        case .korean: .korean
        case .russian: .cyrillic
        case .arabic: .arabic
        case .english, .french, .german, .spanish, .portuguese, .italian: .latin
        }
    }
}

public enum GateFailure: Equatable, Sendable {
    case length(actual: Int, allowed: ClosedRange<Int>, unit: LengthUnit)
    case sentences(actual: Int, allowed: ClosedRange<Int>)
    case duplicate
    case wrongLanguage
}

public enum QuestionGate {
    public static func check(text: String, spec: LengthSpec, recentTexts: [String], script: SourceScript? = nil) -> GateFailure? {
        if let script, !matches(text, script: script) {
            return .wrongLanguage
        }
        let count = spec.unit == .characters ? characterCount(text) : wordCount(text)
        if !spec.range.contains(count) {
            return .length(actual: count, allowed: spec.range, unit: spec.unit)
        }
        let sentences = sentenceCount(text)
        if !spec.sentenceRange.contains(sentences) {
            return .sentences(actual: sentences, allowed: spec.sentenceRange)
        }
        for recent in recentTexts.suffix(30) where trigramOverlap(text, recent) > 0.6 {
            return .duplicate
        }
        return nil
    }

    public static func characterCount(_ text: String) -> Int {
        text.reduce(into: 0) { count, character in
            if character.isLetter || character.isNumber {
                count += 1
            }
        }
    }

    public static func wordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    public static func sentenceCount(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        let endings = CharacterSet(charactersIn: "。！？!?…")
        var count = 0
        var pending = false
        for scalar in trimmed.unicodeScalars {
            if endings.contains(scalar) {
                if pending {
                    count += 1
                    pending = false
                }
            } else if !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                pending = true
            }
        }
        if pending { count += 1 }
        return count
    }

    public static func trigramOverlap(_ lhs: String, _ rhs: String) -> Double {
        let left = trigrams(lhs)
        let right = trigrams(rhs)
        if left.isEmpty || right.isEmpty { return 0 }
        let shared = left.intersection(right).count
        return Double(shared) / Double(min(left.count, right.count))
    }

    public static func feedback(for failure: GateFailure) -> String {
        switch failure {
        case let .length(actual, allowed, unit):
            let unitName = unit == .characters ? "字" : "词"
            return "现在是 \(actual) \(unitName)，要求 \(allowed.lowerBound)–\(allowed.upperBound) \(unitName)。请重写。"
        case let .sentences(actual, allowed):
            return "现在是 \(actual) 句，要求 \(allowed.lowerBound)–\(allowed.upperBound) 句。请重写。"
        case .duplicate:
            return "这和最近的题目太像。请换一个主题重写。"
        case .wrongLanguage:
            return "正文语言不对。请按要求的语言重写。"
        }
    }

    public static func matches(_ text: String, script: SourceScript) -> Bool {
        var han = 0
        var kana = 0
        var hangul = 0
        var cyrillic = 0
        var arabic = 0
        var latin = 0
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF:
                han += 1
            case 0x3040...0x30FF:
                kana += 1
            case 0xAC00...0xD7AF:
                hangul += 1
            case 0x0400...0x04FF:
                cyrillic += 1
            case 0x0600...0x06FF:
                arabic += 1
            default:
                if scalar.value < 128, Character(scalar).isLetter {
                    latin += 1
                }
            }
        }
        let letters = han + kana + hangul + cyrillic + arabic + latin
        guard letters > 0 else { return false }
        switch script {
        case .chinese:
            return kana + hangul == 0 && han * 2 >= letters
        case .japanese:
            return kana >= 4 && kana * 5 >= letters
        case .korean:
            return hangul * 2 >= letters
        case .cyrillic:
            return cyrillic * 2 >= letters
        case .arabic:
            return arabic * 2 >= letters
        case .latin:
            return latin * 2 >= letters && han + kana + hangul < latin
        }
    }

    private static func trigrams(_ text: String) -> Set<String> {
        let chars = Array(text.lowercased().filter { $0.isLetter || $0.isNumber })
        if chars.count < 3 {
            return chars.isEmpty ? [] : [String(chars)]
        }
        var result = Set<String>()
        for index in 0...(chars.count - 3) {
            result.insert(String(chars[index...index + 2]))
        }
        return result
    }
}
