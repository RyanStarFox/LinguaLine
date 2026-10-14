import Foundation

public enum PracticeLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case chinese = "zh"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case russian = "ru"
    case portuguese = "pt"
    case italian = "it"
    case arabic = "ar"

    public var id: String { rawValue }

    public var usesCharacterCount: Bool { self == .japanese || self == .chinese }

    public var promptName: String {
        switch self {
        case .chinese: "中文"
        case .english: "英语"
        case .japanese: "日语"
        case .korean: "韩语"
        case .french: "法语"
        case .german: "德语"
        case .spanish: "西班牙语"
        case .russian: "俄语"
        case .portuguese: "葡萄牙语"
        case .italian: "意大利语"
        case .arabic: "阿拉伯语"
        }
    }

    public var readingGuide: String {
        switch self {
        case .chinese:
            "汉语拼音，带声调，音节之间用空格，例如 shuǐ"
        case .english:
            "国际音标，放在斜线里，例如 /bʌs/"
        case .japanese:
            "平假名。汉字词写出读音，已经是假名的照写，不要用国际音标"
        case .korean:
            "罗马字"
        case .arabic:
            "带元音符号的读音"
        case .french, .german, .spanish, .portuguese, .italian, .russian:
            "国际音标，放在斜线里"
        }
    }

    public static func fallback(excluding language: PracticeLanguage) -> PracticeLanguage {
        allCases.first { $0 != language } ?? .english
    }

    public static func fromSystem(preferredLanguages: [String]) -> (language: PracticeLanguage, script: ChineseScript) {
        let code = preferredLanguages.first?.lowercased() ?? ""
        let traditional = code.hasPrefix("zh-hant") || code.contains("-hant") || code.hasPrefix("zh-tw") || code.hasPrefix("zh-hk") || code.hasPrefix("zh-mo")
        let script: ChineseScript = traditional ? .hant : .hans
        if code.hasPrefix("zh") { return (.chinese, script) }
        let prefix = code.split(separator: "-").first.map(String.init) ?? code
        let language = PracticeLanguage(rawValue: prefix) ?? .chinese
        return (language, script)
    }
}

public enum Direction: String, CaseIterable, Codable, Sendable, Identifiable {
    case zhToForeign
    case foreignToZh

    public var id: String { rawValue }

    public func source(native: PracticeLanguage, practice: PracticeLanguage) -> PracticeLanguage {
        self == .zhToForeign ? native : practice
    }

    public func target(native: PracticeLanguage, practice: PracticeLanguage) -> PracticeLanguage {
        self == .zhToForeign ? practice : native
    }
}

public enum ExerciseKind: String, Codable, Sendable {
    case daily
    case extra
    case placement
    case ready
}

public enum Band: Int, CaseIterable, Sendable {
    case beginner
    case elementary
    case intermediate
    case upperIntermediate
    case advanced
    case professional

    public var usagePrompt: String {
        switch self {
        case .beginner:
            "还不能日常交流。只会招呼、自我介绍和一个简单请求。"
        case .elementary:
            "只能在点餐、问路、购物这类固定场景说短句，换一个情境就接不上。"
        case .intermediate:
            "日常交流。能讲清一段经历、一个原因，或办成一件常见的事。"
        case .upperIntermediate:
            "能比较流畅地讨论具体话题，说出看法、比较和稍复杂的说明。"
        case .advanced:
            "非常熟练。能展开工作、新闻和抽象话题，接近受过良好教育的使用者。"
        case .professional:
            "母语水平。可以出现文学表达、言外之意和母语者才自然的说法。"
        }
    }

    public var usageDisplayKey: String {
        switch self {
        case .beginner: "band_beginner"
        case .elementary: "band_elementary"
        case .intermediate: "band_intermediate"
        case .upperIntermediate: "band_upper"
        case .advanced: "band_advanced"
        case .professional: "band_professional"
        }
    }
}

public struct LevelProfile: Equatable, Sendable {
    public var band: Band
    public var usagePrompt: String
    public var examPrompt: String
    public var vocabulary: Int
    public var usageDisplayKey: String

    public init(band: Band, usagePrompt: String, examPrompt: String, vocabulary: Int, usageDisplayKey: String) {
        self.band = band
        self.usagePrompt = usagePrompt
        self.examPrompt = examPrompt
        self.vocabulary = vocabulary
        self.usageDisplayKey = usageDisplayKey
    }
}

public enum Difficulty {
    public static let skippedLevel = 50

    public static func band(for level: Int) -> Band {
        switch min(100, max(0, level)) {
        case ..<17: .beginner
        case ..<34: .elementary
        case ..<51: .intermediate
        case ..<68: .upperIntermediate
        case ..<85: .advanced
        default: .professional
        }
    }

    public static func profile(language: PracticeLanguage, level: Int) -> LevelProfile {
        let band = band(for: level)
        let exam = examReference(language: language, band: band)
        return LevelProfile(
            band: band,
            usagePrompt: band.usagePrompt,
            examPrompt: exam.text,
            vocabulary: exam.vocabulary,
            usageDisplayKey: band.usageDisplayKey
        )
    }

    public static func step(weightedScore: Int, editRatio: Double, placement: Bool) -> Int {
        let score = ScoreMath.clamp(weightedScore)
        var base: Int
        switch score {
        case 85...100: base = 2
        case 70..<85: base = 1
        case 55..<70: base = 0
        case 40..<55: base = -1
        default: base = -2
        }
        if score >= 85, editRatio > 0.40 {
            base = 1
        }
        if score <= 39, editRatio < 0.10 {
            base = 0
        }
        if placement {
            base *= 3
        }
        return base
    }

    public static func applying(level: Int, step: Int) -> Int {
        min(100, max(0, level + step))
    }

    private static func examReference(language: PracticeLanguage, band: Band) -> (text: String, vocabulary: Int) {
        let index = band.rawValue
        switch language {
        case .english:
            let rows = [
                ("中考", 1600),
                ("高考", 3500),
                ("大学英语四级", 4500),
                ("大学英语六级", 6000),
                ("英语专业四级", 8000),
                ("英语专业八级", 13000),
            ]
            return row(rows, index)
        case .japanese:
            let rows = [
                ("JLPT N5", 800),
                ("JLPT N4", 1500),
                ("JLPT N3", 3000),
                ("JLPT N2", 6000),
                ("JLPT N1", 10000),
                ("超出 JLPT N1 的报刊与文学", 15000),
            ]
            return row(rows, index)
        case .korean:
            let rows = [
                ("TOPIK I 1 级", 800),
                ("TOPIK I 2 级", 1500),
                ("TOPIK II 3 级", 2500),
                ("TOPIK II 4 级", 4000),
                ("TOPIK II 5 级", 6000),
                ("TOPIK II 6 级", 10000),
            ]
            return row(rows, index)
        case .french:
            return cefr("DELF/DALF", index, french: true)
        case .german:
            return cefr("歌德学院", index, french: false)
        case .spanish:
            return cefr("DELE", index, french: false)
        case .russian:
            let rows = [
                ("ТРКИ 基础级", 500),
                ("ТРКИ 初级", 1000),
                ("ТРКИ 一级", 2000),
                ("ТРКИ 二级", 4000),
                ("ТРКИ 三级", 8000),
                ("ТРКИ 四级", 16000),
            ]
            return row(rows, index)
        case .chinese:
            let rows = [
                ("HSK 1", 150),
                ("HSK 2", 300),
                ("HSK 3", 600),
                ("HSK 4", 1200),
                ("HSK 5", 2500),
                ("HSK 6", 5000),
            ]
            return row(rows, index)
        case .portuguese, .italian, .arabic:
            let rows = [
                ("CEFR A1", 500),
                ("CEFR A2", 1000),
                ("CEFR B1", 2000),
                ("CEFR B2", 4000),
                ("CEFR C1", 8000),
                ("CEFR C2", 16000),
            ]
            return row(rows, index)
        }
    }

    private static func row(_ rows: [(String, Int)], _ index: Int) -> (text: String, vocabulary: Int) {
        let item = rows[min(max(0, index), rows.count - 1)]
        return (item.0, item.1)
    }

    private static func cefr(_ prefix: String, _ index: Int, french: Bool) -> (text: String, vocabulary: Int) {
        let levels = ["A1", "A2", "B1", "B2", "C1", "C2"]
        let vocab = [500, 1000, 2000, 4000, 8000, 16000]
        let level = levels[index]
        let name: String
        if french {
            name = (level == "C1" || level == "C2") ? "DALF \(level)" : "DELF \(level)"
        } else if prefix == "DELE" {
            name = "DELE \(level)"
        } else {
            name = "\(prefix) \(level)"
        }
        return (name, vocab[index])
    }
}
