import Foundation

public enum ChineseScript: String, CaseIterable, Codable, Sendable, Identifiable {
    case hans
    case hant

    public var id: String { rawValue }

    public var promptLine: String {
        self == .hans ? "中文使用简体。" : "中文使用繁体。"
    }
}

public struct GenerationRequest: Sendable {
    public var language: PracticeLanguage
    public var direction: Direction
    public var level: Int
    public var preset: LengthPreset
    public var script: ChineseScript
    public var native: PracticeLanguage
    public var recentTopics: [String]
    public var errorTags: [String]
    public var retryNote: String?

    public init(
        language: PracticeLanguage,
        direction: Direction,
        level: Int,
        preset: LengthPreset,
        script: ChineseScript,
        native: PracticeLanguage = .chinese,
        recentTopics: [String],
        errorTags: [String],
        retryNote: String? = nil
    ) {
        self.language = language
        self.direction = direction
        self.level = level
        self.preset = preset
        self.script = script
        self.native = native
        self.recentTopics = recentTopics
        self.errorTags = errorTags
        self.retryNote = retryNote
    }
}

public enum PromptBuilder {
    public static func generation(_ request: GenerationRequest) -> String {
        let profile = Difficulty.profile(language: request.language, level: request.level)
        let spec = LengthPolicy.spec(preset: request.preset, language: request.language, direction: request.direction, native: request.native)
        let unitName = spec.unit == .characters ? "字（不计标点和空白）" : "词"
        let lengthLine = "篇幅必须是 \(spec.range.lowerBound) 到 \(spec.range.upperBound) \(unitName)，句子 \(spec.sentenceRange.lowerBound) 到 \(spec.sentenceRange.upperBound) 句。"
        let ability = "译文难度：\(profile.usagePrompt)这是学习者翻译之后要达到的难度，不是原文该使用的语言。"
        let exam = "译文的词汇和语法大约不超过\(profile.examPrompt)（约 \(profile.vocabulary) 词）。通过该考试并不足以代表前面的使用能力。请按使用能力控制译文难度，不要写成试卷、阅读理解或改错题。"
        let source = request.direction.source(native: request.native, practice: request.language)
        let target = request.direction.target(native: request.native, practice: request.language)
        let task = "出一道\(source.promptName)原文，供学习者译成\(target.promptName)。text 必须是\(source.promptName)，不要写成\(target.promptName)。"
        var lines = [task, ability, exam]
        if source == .chinese || target == .chinese {
            lines.append(request.script.promptLine)
        }
        lines.append(lengthLine)
        if !request.recentTopics.isEmpty {
            lines.append("不要使用这些近期主题：\(request.recentTopics.suffix(8).joined(separator: "、"))。")
        }
        let tags = Array(request.errorTags.prefix(2))
        if !tags.isEmpty {
            lines.append("尽量避开学习者反复出错的点：\(tags.joined(separator: "、"))。")
        }
        if let retryNote = request.retryNote, !retryNote.isEmpty {
            lines.append(retryNote)
        }
        lines.append("正文里不要出现考试名称、能力说明或字数。再次确认：text 只能是\(source.promptName)。只返回 JSON：{\"topic\":\"...\",\"text\":\"...\"}")
        return lines.joined(separator: "\n")
    }

    public static func review(source: String, user: String, direction: Direction, language: PracticeLanguage, script: ChineseScript, native: PracticeLanguage = .chinese) -> String {
        let target = direction.target(native: native, practice: language)
        let scriptLine = native == .chinese || language == .chinese ? script.promptLine : ""
        return """
        你在批改翻译。原文是练习题，学习者要译成\(target.promptName)。\(scriptLine)
        \(scoringRubric)
        corrected 是在学习者译文上做最小修改后的完整译文，整段只能是\(target.promptName)。能留的是学习者已经写对的词，不是原文里的词。漏掉的意思用\(target.promptName)补上，不要把原文句子贴进 corrected。逗号、句号、问号等标点也要留下。
        exemplar 是另一篇完整的好译文，语言同样只能是\(target.promptName)，并给出它的三项分。
        errorTags 最多 4 个短标签，用词问题写「用词」，语法问题写「语法」，例如「漏译」「用词」「时态」。
        原文：\(source)
        学习者译文：\(user)
        只返回 JSON：{"faithfulness":0,"expressiveness":0,"elegance":0,"corrected":"","exemplar":"","exemplarFaithfulness":0,"exemplarExpressiveness":0,"exemplarElegance":0,"errorTags":[]}
        """
    }

    public static func gradeOnly(source: String, user: String, direction: Direction, language: PracticeLanguage, native: PracticeLanguage = .chinese) -> String {
        let target = direction.target(native: native, practice: language)
        return """
        给下面这段译成\(target.promptName)的译文打分。信、达、雅各为 0 到 100 的整数。
        \(scoringRubric)
        errorTags 最多 4 个短标签，用词问题写「用词」，语法问题写「语法」。
        原文：\(source)
        译文：\(user)
        只返回 JSON：{"faithfulness":0,"expressiveness":0,"elegance":0,"errorTags":[]}
        """
    }

    public static func correctionOnly(source: String, user: String, target: PracticeLanguage, retry: Bool = false) -> String {
        let retryLine = retry ? "上一次把原文语言写进了批改。请整段重写。" : ""
        return """
        在学习者译文上做最小修改，得到一篇完整的\(target.promptName)译文。corrected 里只能出现\(target.promptName)，不要夹进原文的句子。能留的是学习者已经写对的词，漏译用\(target.promptName)补上，标点也保留。
        \(retryLine)
        原文：\(source)
        学习者译文：\(user)
        只返回 JSON：{"corrected":""}
        """
    }

    public static func exemplarOnly(source: String, direction: Direction, language: PracticeLanguage, native: PracticeLanguage = .chinese) -> String {
        let target = direction.target(native: native, practice: language)
        return """
        给原文写一篇译成\(target.promptName)的范例，并按下面的信、达、雅打 0 到 100 的分。
        \(scoringRubric)
        原文：\(source)
        只返回 JSON：{"exemplar":"","exemplarFaithfulness":0,"exemplarExpressiveness":0,"exemplarElegance":0}
        """
    }

    public static func editReasons(source: String, user: String, corrected: String, hunks: [EditHunk], native: PracticeLanguage) -> String {
        let lines = hunks.enumerated().map { index, hunk in
            "\(index + 1). 删「\(hunk.before)」增「\(hunk.after)」"
        }.joined(separator: "\n")
        return """
        下面是已经算好的译文增删。请用\(native.promptName)给每一处写一句短原因，说明为什么要这样改。不要改译文，不要再打分。
        reasons 的数量和顺序必须与编号一致。某一处没有删或没有增时，对应的引号是空的。
        原文：\(source)
        学习者译文：\(user)
        改后译文：\(corrected)
        改动：
        \(lines)
        只返回 JSON：{"reasons":["..."]}
        """
    }

    private static let scoringRubric = """
    信只评译文有没有忠实于原文，不评好不好听。按三项合起来打一个 0 到 100 的整数：
    信息：人物、时间、数量、否定、因果有没有漏掉、添上或改掉。
    用词：关键词、程度（很/有点）、情态（必须/可以）有没有译成另一个意思。词义错了才扣信。意思站得住、只是还能换个更好的词，不扣信。
    关系：谁修饰谁、指代、前后逻辑有没有接错。
    语法错但意思没变，不扣信。语法错把意思改了（把「已经错过」译成习惯动作），信和达一起扣。
    信 40：主要信息遗漏，或关键词译反。信 70：大意在，但有几处词义或关系不准。信 90：信息、词义和关系都对。
    达只评译文像不像目标语言。语法是否成立算达：时态、一致、语序、助词、冠词。用词让句子别扭、不像母语者会说的，也扣达。达 40：读不成句。达 70：能懂但别扭。达 90：语法正确且自然。
    雅评语域、语气，以及词选得贴不贴切。两个词意思都对时，更准确、更贴场合的那个算雅：当前说法可以，换一个词会更好，就扣雅，不扣信。雅 40：语气或用词明显不贴。雅 70：过得去，但有更贴的说法。雅 90：用词和语气都贴切。
    参照原文「今天早上我错过了公交。」：
    I missed the train this morning. 信 45，达 92，雅 80。公交被译成火车，词义错了。
    Today morning I missed the bus. 信 88，达 48，雅 55。信息还在，但不像英语。
    I was unable to board the bus this morning. 信 93，达 76，雅 68。意思对，句子也成立，但 missed 更贴切。
    I missed the bus this morning. 信 96，达 93，雅 90。
    """

    public static func vocabulary(term: String, source: PracticeLanguage, target: PracticeLanguage) -> String {
        """
        把这个\(source.promptName)词语译成\(target.promptName)。gloss 写译文，ipa 写这条译文的读音：\(target.readingGuide)。
        词语：\(term)
        只返回 JSON：{"gloss":"","ipa":""}
        """
    }
}
