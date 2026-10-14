import XCTest
@testable import TranslationCore

final class ScoreMathTests: XCTestCase {
    func testWeights() {
        XCTAssertEqual(ScoreMath.weighted(faithfulness: 100, expressiveness: 0, elegance: 0), 40)
        XCTAssertEqual(ScoreMath.weighted(faithfulness: 0, expressiveness: 100, elegance: 0), 40)
        XCTAssertEqual(ScoreMath.weighted(faithfulness: 0, expressiveness: 0, elegance: 100), 20)
        XCTAssertEqual(ScoreMath.weighted(faithfulness: 80, expressiveness: 50, elegance: 10), 54)
    }

    func testClamp() {
        XCTAssertEqual(ScoreMath.weighted(faithfulness: 140, expressiveness: -5, elegance: 10), 42)
    }
}

final class ScoringRubricTests: XCTestCase {
    func testFaithfulnessCoversWordingAndLeavesGrammarToFluency() {
        let review = PromptBuilder.review(
            source: "今天早上我错过了公交。",
            user: "I missed the train this morning.",
            direction: .zhToForeign,
            language: .english,
            script: .hans
        )
        let grade = PromptBuilder.gradeOnly(
            source: "今天早上我错过了公交。",
            user: "Today morning I missed the bus.",
            direction: .zhToForeign,
            language: .english
        )
        for prompt in [review, grade] {
            XCTAssertTrue(prompt.contains("还能换个更好的词，不扣信"))
            XCTAssertTrue(prompt.contains("语法是否成立算达"))
            XCTAssertTrue(prompt.contains("就扣雅，不扣信"))
            XCTAssertTrue(prompt.contains("I was unable to board the bus this morning. 信 93，达 76，雅 68"))
            XCTAssertTrue(prompt.contains("I missed the train this morning. 信 45"))
            XCTAssertTrue(prompt.contains("Today morning I missed the bus. 信 88，达 48"))
        }
        XCTAssertTrue(review.contains("整段只能是英语"))
        XCTAssertTrue(review.contains("不要把原文句子贴进 corrected"))
        let correction = PromptBuilder.correctionOnly(source: "水", user: "水", target: .chinese, retry: true)
        XCTAssertTrue(correction.contains("只能出现中文"))
        XCTAssertTrue(correction.contains("上一次把原文语言写进了批改"))
        XCTAssertFalse(QuestionGate.matches("周末我和朋友去看电影週末は友達と映画を見に行きました。", script: .chinese))
        XCTAssertTrue(QuestionGate.matches("周末我和朋友去看电影了。电影很有趣，所以我还想再看一次。", script: .chinese))
    }
}

final class DifficultyTests: XCTestCase {
    func testBandBoundaries() {
        XCTAssertEqual(Difficulty.band(for: 0), .beginner)
        XCTAssertEqual(Difficulty.band(for: 16), .beginner)
        XCTAssertEqual(Difficulty.band(for: 17), .elementary)
        XCTAssertEqual(Difficulty.band(for: 33), .elementary)
        XCTAssertEqual(Difficulty.band(for: 34), .intermediate)
        XCTAssertEqual(Difficulty.band(for: 50), .intermediate)
        XCTAssertEqual(Difficulty.band(for: 51), .upperIntermediate)
        XCTAssertEqual(Difficulty.band(for: 67), .upperIntermediate)
        XCTAssertEqual(Difficulty.band(for: 68), .advanced)
        XCTAssertEqual(Difficulty.band(for: 84), .advanced)
        XCTAssertEqual(Difficulty.band(for: 85), .professional)
        XCTAssertEqual(Difficulty.band(for: 100), .professional)
    }

    func testEnglishProfileIsStable() {
        let profile = Difficulty.profile(language: .english, level: 50)
        XCTAssertEqual(profile.usagePrompt, "日常交流。能讲清一段经历、一个原因，或办成一件常见的事。")
        XCTAssertEqual(profile.examPrompt, "大学英语四级")
        XCTAssertEqual(profile.vocabulary, 4500)
        XCTAssertEqual(Difficulty.profile(language: .english, level: 50).examPrompt, profile.examPrompt)
        XCTAssertEqual(Difficulty.profile(language: .english, level: 0).vocabulary, 1600)
        XCTAssertEqual(Difficulty.profile(language: .english, level: 90).examPrompt, "英语专业八级")
        XCTAssertEqual(Difficulty.profile(language: .japanese, level: 50).examPrompt, "JLPT N3")
        XCTAssertEqual(Difficulty.profile(language: .japanese, level: 50).vocabulary, 3000)
    }

    func testLengthDoesNotChangeProfileLookup() {
        let low = Difficulty.profile(language: .english, level: 10)
        let high = Difficulty.profile(language: .english, level: 90)
        XCTAssertNotEqual(low.examPrompt, high.examPrompt)
        let medium = LengthPolicy.spec(preset: .medium, language: .english, direction: .zhToForeign)
        XCTAssertEqual(medium.range, 60...100)
        XCTAssertEqual(LengthPolicy.spec(preset: .medium, language: .english, direction: .foreignToZh).range, 30...50)
    }

    func testSteps() {
        XCTAssertEqual(Difficulty.step(weightedScore: 85, editRatio: 0, placement: false), 2)
        XCTAssertEqual(Difficulty.step(weightedScore: 100, editRatio: 0.41, placement: false), 1)
        XCTAssertEqual(Difficulty.step(weightedScore: 84, editRatio: 0.9, placement: false), 1)
        XCTAssertEqual(Difficulty.step(weightedScore: 70, editRatio: 0, placement: false), 1)
        XCTAssertEqual(Difficulty.step(weightedScore: 69, editRatio: 0, placement: false), 0)
        XCTAssertEqual(Difficulty.step(weightedScore: 55, editRatio: 0, placement: false), 0)
        XCTAssertEqual(Difficulty.step(weightedScore: 40, editRatio: 0, placement: false), -1)
        XCTAssertEqual(Difficulty.step(weightedScore: 39, editRatio: 0.5, placement: false), -2)
        XCTAssertEqual(Difficulty.step(weightedScore: 10, editRatio: 0.09, placement: false), 0)
        XCTAssertEqual(Difficulty.step(weightedScore: 90, editRatio: 0, placement: true), 6)
        XCTAssertEqual(Difficulty.step(weightedScore: 10, editRatio: 0.05, placement: true), 0)
        XCTAssertEqual(Difficulty.applying(level: 99, step: 2), 100)
        XCTAssertEqual(Difficulty.applying(level: 1, step: -2), 0)
    }
}

final class LengthPolicyTests: XCTestCase {
    func testPresets() {
        let short = LengthPolicy.spec(preset: .short, language: .english, direction: .foreignToZh)
        XCTAssertEqual(short.range, 10...20)
        XCTAssertEqual(short.sentenceRange, 1...2)
        XCTAssertEqual(short.unit, .words)

        let japanese = LengthPolicy.spec(preset: .medium, language: .japanese, direction: .foreignToZh)
        XCTAssertEqual(japanese.unit, .characters)
        XCTAssertEqual(japanese.range, 60...100)

        let longChinese = LengthPolicy.spec(preset: .long, language: .french, direction: .zhToForeign)
        XCTAssertEqual(longChinese.range, 150...250)
        XCTAssertEqual(longChinese.sentenceRange, 4...8)
        let nativeEnglish = LengthPolicy.spec(preset: .medium, language: .japanese, direction: .zhToForeign, native: .english)
        XCTAssertEqual(nativeEnglish.unit, .words)
        XCTAssertEqual(PracticeLanguage.fromSystem(preferredLanguages: ["ja-JP"]).language, .japanese)
        XCTAssertEqual(PracticeLanguage.fromSystem(preferredLanguages: ["zh-Hant-TW"]).script, .hant)
        XCTAssertEqual(PracticeLanguage.fromSystem(preferredLanguages: ["zh-Hans-CN"]).language, .chinese)
    }
}

final class SyncMergeTests: XCTestCase {
    func testNewerRecordAndNewerDeletionWin() {
        let older = SyncRecord(kind: "exercise", id: "a", updatedAt: Date(timeIntervalSince1970: 10), body: Data("old".utf8))
        let newer = SyncRecord(kind: "exercise", id: "a", updatedAt: Date(timeIntervalSince1970: 20), body: Data("new".utf8))
        let merged = SyncMerge.merge(local: [older], remote: [newer])
        XCTAssertEqual(merged.first?.body, Data("new".utf8))
        let deleted = SyncRecord(kind: "exercise", id: "a", updatedAt: Date(timeIntervalSince1970: 30), deletedAt: Date(timeIntervalSince1970: 30))
        let afterDelete = SyncMerge.merge(local: [newer], remote: [deleted])
        XCTAssertNotNil(afterDelete.first?.deletedAt)
        let revived = SyncRecord(kind: "exercise", id: "a", updatedAt: Date(timeIntervalSince1970: 40), body: Data("back".utf8))
        let afterRevive = SyncMerge.merge(local: [deleted], remote: [revived])
        XCTAssertNil(afterRevive.first?.deletedAt)
        XCTAssertEqual(afterRevive.first?.body, Data("back".utf8))
    }
}

final class QuestionGateTests: XCTestCase {
    func testAcceptsMediumChinese() {
        let text = String(repeating: "字", count: 70) + "。这是第二句。"
        let spec = LengthPolicy.spec(preset: .medium, language: .english, direction: .zhToForeign)
        XCTAssertNil(QuestionGate.check(text: text, spec: spec, recentTexts: []))
        XCTAssertEqual(QuestionGate.sentenceCount(text), 2)
    }

    func testRejectsShortLength() {
        let spec = LengthPolicy.spec(preset: .medium, language: .english, direction: .zhToForeign)
        let failure = QuestionGate.check(text: "太短。", spec: spec, recentTexts: [])
        guard case .length = failure else {
            return XCTFail("expected length failure")
        }
    }

    func testRejectsDuplicate() {
        let text = String(repeating: "字", count: 70) + "。这是第二句。"
        let spec = LengthPolicy.spec(preset: .medium, language: .english, direction: .zhToForeign)
        let failure = QuestionGate.check(text: text, spec: spec, recentTexts: [text])
        XCTAssertEqual(failure, .duplicate)
    }

    func testWordCount() {
        XCTAssertEqual(QuestionGate.wordCount("one two  three"), 3)
        XCTAssertEqual(QuestionGate.characterCount("你好，世界。"), 4)
    }

    func testRejectsJapaneseSourceForChinesePrompt() {
        let text = "先週の土曜日、友達と一緒に街へ買い物に行きました。新しい服を探していたので、何軒かの店を回ってやっと気に入るものを見つけられました。"
        let spec = LengthPolicy.spec(preset: .medium, language: .japanese, direction: .zhToForeign)
        let failure = QuestionGate.check(text: text, spec: spec, recentTexts: [], script: .chinese)
        XCTAssertEqual(failure, .wrongLanguage)
        XCTAssertTrue(QuestionGate.matches(text, script: .japanese))
    }
}

final class StreakTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 1 + offset))!
    }

    func testRequiresBothDirections() {
        let update = StreakEngine.register(state: StreakSnapshot(), on: day(0), bothDirectionsDone: false, calendar: calendar)
        XCTAssertEqual(update.snapshot.current, 0)
        XCTAssertFalse(update.shouldCelebrate)
    }

    func testIncrementsAcrossDaysAndResetsAfterGap() {
        let first = StreakEngine.register(state: StreakSnapshot(), on: day(0), bothDirectionsDone: true, calendar: calendar)
        XCTAssertEqual(first.snapshot.current, 1)
        let sameDay = StreakEngine.register(state: first.snapshot, on: day(0), bothDirectionsDone: true, calendar: calendar)
        XCTAssertEqual(sameDay.snapshot.current, 1)
        let next = StreakEngine.register(state: sameDay.snapshot, on: day(1), bothDirectionsDone: true, calendar: calendar)
        XCTAssertEqual(next.snapshot.current, 2)
        let gap = StreakEngine.register(state: next.snapshot, on: day(3), bothDirectionsDone: true, calendar: calendar)
        XCTAssertEqual(gap.snapshot.current, 1)
    }

    func testCelebratesEveryTwentyFiveOnce() {
        var state = StreakSnapshot(current: 24, lastCompletedDay: day(0), lastCelebratedMultiple: 0)
        let hit = StreakEngine.register(state: state, on: day(1), bothDirectionsDone: true, calendar: calendar)
        XCTAssertEqual(hit.snapshot.current, 25)
        XCTAssertTrue(hit.shouldCelebrate)
        let again = StreakEngine.register(state: hit.snapshot, on: day(1), bothDirectionsDone: true, calendar: calendar)
        XCTAssertFalse(again.shouldCelebrate)
        state = StreakSnapshot(current: 49, lastCompletedDay: day(10), lastCelebratedMultiple: 25)
        let fifty = StreakEngine.register(state: state, on: day(11), bothDirectionsDone: true, calendar: calendar)
        XCTAssertEqual(fifty.snapshot.current, 50)
        XCTAssertTrue(fifty.shouldCelebrate)
    }

    func testTenDayRunGrantsOneShieldAndRepairDoesNotAddADay() {
        let nine = StreakSnapshot(current: 9, lastCompletedDay: day(0))
        let ten = StreakEngine.register(state: nine, on: day(1), bothDirectionsDone: true, calendar: calendar)
        XCTAssertEqual(ten.snapshot.current, 10)
        XCTAssertEqual(ten.snapshot.shields, 1)
        XCTAssertEqual(ten.snapshot.shieldsGrantedForRun, 1)

        let repaired = StreakEngine.repair(state: ten.snapshot, on: day(3), calendar: calendar)
        XCTAssertEqual(repaired?.current, 10)
        XCTAssertEqual(repaired?.shields, 0)
        XCTAssertEqual(repaired?.lastCompletedDay, day(2))
        XCTAssertEqual(repaired?.shieldedDayKeys, [DayKey.string(from: day(2), calendar: calendar)])

        let eleven = StreakEngine.register(state: repaired!, on: day(3), bothDirectionsDone: true, calendar: calendar)
        XCTAssertEqual(eleven.snapshot.current, 11)
        XCTAssertEqual(eleven.snapshot.shields, 0)
    }

    func testTwoShieldsCoverTwoMissedDaysAndThreeCannotBeRepaired() {
        let state = StreakSnapshot(current: 12, lastCompletedDay: day(0), shields: 2, shieldsGrantedForRun: 1)
        let repaired = StreakEngine.repair(state: state, on: day(3), calendar: calendar)
        XCTAssertEqual(repaired?.current, 12)
        XCTAssertEqual(repaired?.shields, 0)
        XCTAssertEqual(repaired?.shieldedDayKeys.count, 2)
        let next = StreakEngine.register(state: repaired!, on: day(3), bothDirectionsDone: true, calendar: calendar)
        XCTAssertEqual(next.snapshot.current, 13)

        XCTAssertNil(StreakEngine.repair(state: state, on: day(4), calendar: calendar))
    }

    func testShieldsCapAtTwoAndResetKeepsHeldShields() {
        let nineteen = StreakSnapshot(current: 19, lastCompletedDay: day(0), shields: 1, shieldsGrantedForRun: 1)
        let twenty = StreakEngine.register(state: nineteen, on: day(1), bothDirectionsDone: true, calendar: calendar)
        XCTAssertEqual(twenty.snapshot.current, 20)
        XCTAssertEqual(twenty.snapshot.shields, 2)
        XCTAssertEqual(twenty.snapshot.shieldsGrantedForRun, 2)

        let twentyNine = StreakSnapshot(current: 29, lastCompletedDay: day(10), shields: 2, shieldsGrantedForRun: 2)
        let thirty = StreakEngine.register(state: twentyNine, on: day(11), bothDirectionsDone: true, calendar: calendar)
        XCTAssertEqual(thirty.snapshot.shields, 2)
        XCTAssertEqual(thirty.snapshot.shieldsGrantedForRun, 3)

        let broken = StreakEngine.register(state: twenty.snapshot, on: day(4), bothDirectionsDone: true, calendar: calendar)
        XCTAssertEqual(broken.snapshot.current, 1)
        XCTAssertEqual(broken.snapshot.shields, 2)
        XCTAssertEqual(broken.snapshot.shieldsGrantedForRun, 0)
    }

    func testExistingLongStreakReconcilesUpToTwoShields() {
        let reconciled = StreakEngine.reconcileShields(StreakSnapshot(current: 25))
        XCTAssertEqual(reconciled.shields, 2)
        XCTAssertEqual(reconciled.shieldsGrantedForRun, 2)
        XCTAssertEqual(ScoreAverage.mean([80, 90]), 85)
        XCTAssertEqual(ScoreAverage.mean([80, 81]), 81)
        XCTAssertNil(ScoreAverage.mean([]))
    }

    func testMonthGridAndRecentThreeWeeks() {
        var calendar = self.calendar
        calendar.firstWeekday = 2
        let cells = CalendarLayout.monthCells(containing: day(0), calendar: calendar)
        XCTAssertEqual(cells.count, 35)
        XCTAssertNil(cells[2])
        XCTAssertEqual(calendar.component(.day, from: cells[3]!), 1)
        let weeks = CalendarLayout.recentWeeks(ending: day(14), count: 3, calendar: calendar)
        XCTAssertEqual(weeks.count, 3)
        XCTAssertEqual(calendar.component(.month, from: weeks[2]), 1)
        XCTAssertEqual(calendar.component(.day, from: weeks[2]), 12)
        XCTAssertEqual(weeks[1], calendar.date(byAdding: .day, value: -7, to: weeks[2]))
        XCTAssertEqual(weeks[0], calendar.date(byAdding: .day, value: -14, to: weeks[2]))
    }
}

final class ScoreListTests: XCTestCase {
    private func day(_ offset: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: 2026, month: 3, day: 1 + offset))!
    }

    func testBandsAndScoreOrder() {
        XCTAssertTrue(ScoreBand.all.matches(score: nil))
        XCTAssertFalse(ScoreBand.from90.matches(score: nil))
        XCTAssertTrue(ScoreBand.from90.matches(score: 90))
        XCTAssertFalse(ScoreBand.from90.matches(score: 89))
        XCTAssertTrue(ScoreBand.from80.matches(score: 80))
        XCTAssertFalse(ScoreBand.from80.matches(score: 90))
        XCTAssertTrue(ScoreBand.from70.matches(score: 79))
        XCTAssertTrue(ScoreBand.under70.matches(score: 69))

        struct Row {
            var date: Date
            var score: Int?
            var pinned: Bool
        }
        let rows = [
            Row(date: day(0), score: 90, pinned: false),
            Row(date: day(1), score: nil, pinned: false),
            Row(date: day(2), score: 70, pinned: true),
            Row(date: day(3), score: 80, pinned: false),
        ]
        let high = ScoreList.ordered(rows, sort: .high, date: \.date, score: \.score, pinned: \.pinned)
        XCTAssertEqual(high.map(\.score), [Optional(70), Optional(90), Optional(80), nil])
        let low = ScoreList.ordered(rows, sort: .low, date: \.date, score: \.score, pinned: \.pinned)
        XCTAssertEqual(low.map(\.score), [Optional(70), Optional(80), Optional(90), nil])
    }
}

final class TextDiffTests: XCTestCase {
    func testIdenticalRatioIsZero() {
        XCTAssertEqual(TextDiff.editRatio(user: "I missed the bus", corrected: "I missed the bus"), 0)
    }

    func testShowsDeletionAndInsertion() {
        let ops = TextDiff.diff(user: "I missed the bus", corrected: "I missed the train")
        XCTAssertTrue(ops.contains(.delete("bus")))
        XCTAssertTrue(ops.contains(.insert("train")))
        XCTAssertGreaterThan(TextDiff.editRatio(user: "I missed the bus", corrected: "I missed the train"), 0)
    }

    func testKeepsPunctuationAsItsOwnToken() {
        let chinese = TextDiff.tokens("上周，我和家人一起去了京都。")
        XCTAssertTrue(chinese.contains("，"))
        XCTAssertTrue(chinese.contains("。"))
        let english = TextDiff.tokens("I missed the bus.")
        XCTAssertEqual(english.last, ".")
        XCTAssertFalse(english.contains(" ."))
    }
}

final class JapaneseChineseIndexTests: XCTestCase {
    func testReadsReadingGlossAndChineseReverse() {
        let json = """
        {
          "水": "（みず）⓪【名】水，凉水",
          "10つ": "(とお1) 十个",
          "先生": "（せんせい）③【名】老师；医生"
        }
        """
        let records = JapaneseChineseIndex.records(in: Data(json.utf8))
        let water = records.first { $0.head == "水" }
        XCTAssertEqual(water?.reading, "みず")
        XCTAssertEqual(water?.gloss, "水，凉水")
        XCTAssertEqual(records.first { $0.head == "みず" }?.gloss, "水，凉水")
        XCTAssertEqual(records.first { $0.head == "老师" }?.gloss, "先生（せんせい）")
        XCTAssertEqual(records.first { $0.head == "十个" }?.gloss, "10つ（とお）")
        XCTAssertEqual(records.first { $0.head == "とお" }?.gloss, "十个")
    }
}

final class CedictIndexTests: XCTestCase {
    func testIndexesBothDirectionsAndTraditional() {
        let text = """
        # comment
        公交 公交 [gong1 jiao1] /public transport/bus/
        愛 爱 [ai4] /to love/affection/
        ⺮ ⺮ [zhu2] /(bambou, radical)/
        """
        let records = CedictIndex.records(in: text)
        let bus = records.first { $0.head == "公交" }
        XCTAssertEqual(bus?.reading, "gong1 jiao1")
        XCTAssertTrue(bus?.gloss.contains("bus") == true)
        let reverse = records.first { $0.head == "bus" }
        XCTAssertTrue(reverse?.gloss.contains("公交") == true)
        XCTAssertTrue(records.contains { $0.head == "爱" })
        XCTAssertTrue(records.contains { $0.head == "愛" })
        XCTAssertTrue(records.contains { $0.head == "love" })
        XCTAssertTrue(records.contains { $0.head == "bambou" })
        XCTAssertEqual(CedictIndex.lookupKeys(for: "公交车", sourceIsChinese: true).first, "公交车")
        let sentence = CedictIndex.lookupKeys(for: "今天我坐公交车去学校", sourceIsChinese: true)
        XCTAssertTrue(sentence.contains("公交车"))
        XCTAssertEqual(sentence.first, "今天我坐公交车去")
        let japanese = CedictIndex.lookupKeys(for: "水を飲みます", sourceIsChinese: false)
        XCTAssertEqual(japanese.first, "水を飲みます")
        XCTAssertTrue(japanese.contains("水"))
        XCTAssertTrue(japanese.contains("飲み"))
        let english = CedictIndex.lookupKeys(for: "the bus", sourceIsChinese: false)
        XCTAssertEqual(english.first, "the bus")
        XCTAssertTrue(english.contains("bus"))
    }
}

final class VocabularyPromptTests: XCTestCase {
    func testAsksForPronunciationOfThePracticeLanguage() {
        let intoJapanese = PromptBuilder.vocabulary(term: "公交车", source: .chinese, target: .japanese)
        XCTAssertTrue(intoJapanese.contains("平假名"))
        XCTAssertTrue(intoJapanese.contains("译文"))
        let intoChinese = PromptBuilder.vocabulary(term: "水", source: .japanese, target: .chinese)
        XCTAssertTrue(intoChinese.contains("汉语拼音"))
        XCTAssertTrue(intoChinese.contains("中文"))
        XCTAssertFalse(intoChinese.contains("平假名"))
        XCTAssertTrue(ChinesePinyin.marks(of: "水").localizedCaseInsensitiveContains("shuǐ"))
    }
}

final class DailyAndHistoryTests: XCTestCase {
    func testDailyQuestionStaysPut() {
        let existing = [DailyItem(key: "2026-10-11|en|zhToForeign", text: "原题")]
        let resolved = DailyCatalog.resolve(existing: existing, key: "2026-10-11|en|zhToForeign") {
            DailyItem(key: "2026-10-11|en|zhToForeign", text: "新题")
        }
        XCTAssertEqual(resolved.text, "原题")
        let key = DayKey.dailyKey(day: Date(timeIntervalSince1970: 0), language: .english, direction: .zhToForeign, calendar: {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            return calendar
        }())
        XCTAssertTrue(key.contains("en"))
        XCTAssertTrue(key.contains(Direction.zhToForeign.rawValue))
        XCTAssertFalse(key.hasSuffix("|0"))
    }

    func testDailyKeyKeepsTheOriginalSlot() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 0)
        let legacy = DayKey.dailyKey(day: day, language: .english, direction: .zhToForeign, calendar: calendar)
        XCTAssertEqual(DayKey.dailyKey(day: day, language: .english, direction: .zhToForeign, index: 0, calendar: calendar), legacy)
        let extra = DayKey.dailyKey(day: day, language: .english, direction: .zhToForeign, index: 1, calendar: calendar)
        XCTAssertEqual(extra, legacy + "|1")
        XCTAssertEqual(DayKey.dailyIndex(in: legacy), 0)
        XCTAssertEqual(DayKey.dailyIndex(in: extra), 1)
        XCTAssertTrue(DayKey.matches(legacy, day: day, language: .english, direction: .zhToForeign, calendar: calendar))
        XCTAssertTrue(DayKey.matches(extra, day: day, language: .english, direction: .zhToForeign, calendar: calendar))
        XCTAssertFalse(DayKey.matches(extra, day: day, language: .english, direction: .foreignToZh, calendar: calendar))
    }

    func testDailyQuotaRejectsAnEmptyPair() {
        XCTAssertNil(DailyQuota.accepted(nativeToPractice: 0, practiceToNative: 0))
        XCTAssertNil(DailyQuota.accepted(nativeToPractice: -3, practiceToNative: 0))
        let zeroAndOne = DailyQuota.accepted(nativeToPractice: 0, practiceToNative: 1)
        XCTAssertEqual(zeroAndOne?.nativeToPractice, 0)
        XCTAssertEqual(zeroAndOne?.practiceToNative, 1)
        XCTAssertEqual(DailyQuota.accepted(nativeToPractice: 99, practiceToNative: 0)?.nativeToPractice, 10)
        XCTAssertTrue(DailyQuota.requirementsMet(submitted: 0, target: 0))
        XCTAssertFalse(DailyQuota.requirementsMet(submitted: 0, target: 1))
        XCTAssertTrue(DailyQuota.requirementsMet(submitted: 2, target: 2))
        XCTAssertTrue(DailyQuota.requirementsMet(submittedIndices: [], target: 0))
        XCTAssertFalse(DailyQuota.requirementsMet(submittedIndices: [1], target: 1))
        XCTAssertTrue(DailyQuota.requirementsMet(
            nativeToPractice: [0],
            practiceToNative: [],
            nativeToPracticeTarget: 1,
            practiceToNativeTarget: 0
        ))
        XCTAssertFalse(DailyQuota.requirementsMet(
            nativeToPractice: [0],
            practiceToNative: [],
            nativeToPracticeTarget: 2,
            practiceToNativeTarget: 0
        ))
    }

    func testFavoriteSnapshotSurvivesAttemptDeletion() {
        let attemptID = UUID()
        let favorite = FavoriteStamp(id: UUID(), sourceText: "保留下来的题目", sourceAttemptID: attemptID)
        let attempt = AttemptStamp(id: attemptID, createdAt: Date(timeIntervalSince1970: 10))
        let doomed = HistoryDeletion.ids(in: [attempt], before: Date(timeIntervalSince1970: 20))
        let remaining = HistoryDeletion.removing([attempt], ids: doomed)
        let favorites = FavoriteIndependence.afterAttemptDeletion([favorite])
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertEqual(favorites, [favorite])
    }

    func testFolderCycle() {
        let child = UUID()
        let parent = UUID()
        let parents = [child: parent, parent: nil as UUID?]
        XCTAssertFalse(FolderTree.canPlace(parent, under: child, parentOf: { parents[$0] ?? nil }))
        XCTAssertTrue(FolderTree.canPlace(child, under: nil, parentOf: { parents[$0] ?? nil }))
    }
}

final class LLMSupportTests: XCTestCase {
    func testJSONFence() throws {
        let payload = try LLMJSON.decode("```json\n{\"topic\":\"雨天\",\"text\":\"今天下雨。\"}\n```")
        XCTAssertEqual(payload.topic, "雨天")
        XCTAssertEqual(payload.text, "今天下雨。")
    }

    func testReviewMergesWhenEndpointsMatch() {
        let settings = LLMSettings(defaultEndpoint: EndpointConfig(kind: .openAI, baseURL: "https://example.com/v1", model: "m"))
        XCTAssertTrue(LLMRouting.mergesReview(settings: settings))
        var split = settings
        split.translationEndpoint = EndpointConfig(kind: .openAI, baseURL: "http://127.0.0.1:11434/v1", model: "translate")
        XCTAssertFalse(LLMRouting.mergesReview(settings: split))
        XCTAssertEqual(LLMRouting.identity(for: .grade, settings: split).model, "m")
        XCTAssertEqual(LLMRouting.identity(for: .correct, settings: split).model, "translate")
        XCTAssertEqual(LLMRouting.identity(for: .exemplar, settings: split).keyAccount, "llm.translation")
        XCTAssertEqual(LLMRouting.identity(for: .vocabulary, settings: split).model, "translate")
        XCTAssertEqual(LLMRouting.identity(for: .generate, settings: split).model, "m")
    }

    func testLegacyOverrideBecomesTranslationEndpoint() throws {
        let json = """
        {"defaultEndpoint":{"kind":"openAI","baseURL":"https://example.com/v1","model":"general"},"overrides":{"correct":{"kind":"openAI","baseURL":"http://127.0.0.1:11434/v1","model":"translate"}}}
        """.data(using: .utf8)!
        let settings = try JSONDecoder().decode(LLMSettings.self, from: json)
        XCTAssertEqual(settings.defaultEndpoint.model, "general")
        XCTAssertEqual(settings.translationEndpoint.model, "translate")
        XCTAssertNil(settings.overrides["correct"])
        XCTAssertEqual(LLMRouting.identity(for: .correct, settings: settings).keyAccount, "llm.translation")
    }

    func testProbeUsesChatCompletionsAndAcceptsAReply() async throws {
        ProbeStub.status = 200
        ProbeStub.body = Data(#"{"choices":[{"message":{"content":"ok"}}]}"#.utf8)
        ProbeStub.request = nil
        let client = LLMClient(session: ProbeStub.session, loadKey: { _ in nil })
        let reply = try await client.probe(
            kind: .openAI,
            baseURL: "http://127.0.0.1:11434/v1",
            model: "qwen",
            key: "secret"
        )
        XCTAssertEqual(reply, "ok")
        XCTAssertEqual(ProbeStub.request?.url?.absoluteString, "http://127.0.0.1:11434/v1/chat/completions")
        XCTAssertEqual(ProbeStub.request?.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        let payload = try JSONSerialization.jsonObject(with: ProbeStub.capturedBody) as? [String: Any]
        XCTAssertEqual(payload?["enable_thinking"] as? Bool, false)
        XCTAssertEqual(payload?["reasoning_effort"] as? String, "none")
    }

    func testUnknownThinkingFlagIsRetriedPlain() async throws {
        ProbeStub.script = [
            (400, Data(#"{"error":"unknown parameter enable_thinking"}"#.utf8)),
            (200, Data(#"{"choices":[{"message":{"content":"ok"}}]}"#.utf8)),
        ]
        let client = LLMClient(session: ProbeStub.session, loadKey: { _ in nil })
        let reply = try await client.probe(
            kind: .openAI,
            baseURL: "http://127.0.0.1:11434/v1",
            model: "qwen",
            key: "secret"
        )
        XCTAssertEqual(reply, "ok")
        let payload = try JSONSerialization.jsonObject(with: ProbeStub.capturedBody) as? [String: Any]
        XCTAssertNil(payload?["enable_thinking"])
        XCTAssertNil(payload?["reasoning_effort"])
        ProbeStub.script = []
    }

    func testProbeReportsHTTPFailure() async {
        ProbeStub.status = 401
        ProbeStub.body = Data("unauthorized".utf8)
        let client = LLMClient(session: ProbeStub.session, loadKey: { _ in nil })
        do {
            _ = try await client.probe(kind: .anthropic, baseURL: "https://api.anthropic.com", model: "claude", key: "k")
            XCTFail("expected HTTP error")
        } catch let error as LLMClientError {
            guard case let .http(code, _) = error else {
                return XCTFail("unexpected \(error)")
            }
            XCTAssertEqual(code, 401)
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertEqual(ProbeStub.request?.url?.path, "/v1/messages")
        XCTAssertEqual(ProbeStub.request?.value(forHTTPHeaderField: "x-api-key"), "k")
    }
}

private final class ProbeStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var request: URLRequest?
    nonisolated(unsafe) static var capturedBody = Data()
    nonisolated(unsafe) static var script: [(Int, Data)] = []

    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProbeStub.self]
        return URLSession(configuration: configuration)
    }()

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.request = request
        Self.capturedBody = Self.readBody(request)
        let status: Int
        let body: Data
        if Self.script.isEmpty {
            status = Self.status
            body = Self.body
        } else {
            let next = Self.script.removeFirst()
            status = next.0
            body = next.1
        }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "http://127.0.0.1")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func readBody(_ request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: 1024)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    override func stopLoading() {}
}

final class ReviewScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func at(day offset: Int, hour: Int = 0) -> Date {
        let day = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1 + offset))!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    private func uuid(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))!
    }

    private func source(
        _ suffix: Int,
        direction: Direction = .zhToForeign,
        language: String = "en",
        kind: ExerciseKind = .daily,
        submitted: Bool = true,
        dayOffset: Int,
        hour: Int = 15,
        score: Int
    ) -> ReviewSource {
        ReviewSource(
            id: uuid(suffix),
            direction: direction,
            languageCode: language,
            kind: kind,
            submitted: submitted,
            submittedAt: at(day: dayOffset, hour: hour),
            weightedScore: score
        )
    }

    private func due(
        _ sources: [ReviewSource],
        marks: [ReviewMark] = [],
        direction: Direction = .zhToForeign,
        language: String = "en",
        dayOffset: Int,
        hour: Int = 12,
        policy: ReviewPolicy = .standard
    ) -> [ReviewDueItem] {
        ReviewSchedule.dueItems(
            sources: sources,
            marks: marks,
            direction: direction,
            languageCode: language,
            today: at(day: dayOffset, hour: hour),
            calendar: calendar,
            policy: policy
        )
    }

    func testHighScoreLeavesTheQueue() {
        let mastered = source(1, dayOffset: 0, score: 96)
        let staying = source(2, dayOffset: 0, score: 95)
        XCTAssertEqual(due([mastered, staying], dayOffset: 1).map(\.exerciseID), [staying.id])
        let stricter = ReviewPolicy(retireScore: 90, growScore: 80, growFactor: 2, holdScore: 30, shrinkFactor: 2)
        XCTAssertTrue(due([staying], dayOffset: 1, policy: stricter).isEmpty)
    }

    func testNotDueOnSubmissionDay() {
        let item = source(1, dayOffset: 0, hour: 23, score: 70)
        XCTAssertTrue(due([item], dayOffset: 0, hour: 23).isEmpty)
        XCTAssertEqual(
            ReviewSchedule.firstDueDay(submittedAt: item.submittedAt, calendar: calendar),
            at(day: 1)
        )
        XCTAssertFalse(ReviewSchedule.admits(kind: .ready, submitted: true))
        XCTAssertFalse(ReviewSchedule.admits(kind: .daily, submitted: false))
        XCTAssertTrue(due([source(2, kind: .ready, dayOffset: 0, score: 90)], dayOffset: 1).isEmpty)
        XCTAssertTrue(due([source(3, submitted: false, dayOffset: 0, score: 90)], dayOffset: 1).isEmpty)
    }

    func testDueTheNextDay() {
        let daily = source(1, dayOffset: 0, hour: 23, score: 64)
        let extra = source(2, kind: .extra, dayOffset: 0, hour: 8, score: 71)
        let placement = source(3, kind: .placement, dayOffset: 0, score: 55)
        let otherLanguage = source(4, language: "ja", dayOffset: 0, score: 99)
        let items = due([daily, extra, placement, otherLanguage], dayOffset: 1, hour: 0)
        XCTAssertEqual(items.map(\.exerciseID), [placement.id, daily.id, extra.id])
        XCTAssertEqual(items.map(\.lastScore), [55, 64, 71])
        XCTAssertEqual(items.map(\.dueDay), [at(day: 1), at(day: 1), at(day: 1)])
    }

    func testSortOrder() {
        let mostOverdue = source(1, dayOffset: 0, score: 94)
        let olderSameScore = source(2, dayOffset: 1, score: 10)
        let lowerScore = source(3, dayOffset: 2, score: 50)
        let higherScore = source(4, dayOffset: 2, score: 90)
        let laterDue = source(5, dayOffset: 3, score: 50)
        let mark = ReviewMark(
            id: uuid(9),
            exerciseID: olderSameScore.id,
            direction: .zhToForeign,
            languageCode: "en",
            reviewedAt: at(day: 2, hour: 10),
            weightedScore: 50,
            intervalDays: 1,
            dueDay: at(day: 3)
        )
        let items = due(
            [laterDue, higherScore, lowerScore, olderSameScore, mostOverdue],
            marks: [mark],
            dayOffset: 4
        )
        XCTAssertEqual(items.map(\.exerciseID), [mostOverdue.id, olderSameScore.id, lowerScore.id, higherScore.id, laterDue.id])
        XCTAssertEqual(items.first { $0.exerciseID == olderSameScore.id }?.lastScore, 50)
        XCTAssertEqual(items.first { $0.exerciseID == mostOverdue.id }?.lastScore, 94)
    }

    func testIntervalDoublesHoldsAndResets() {
        XCTAssertEqual(ReviewSchedule.previousInterval(marks: [], exerciseID: uuid(1), direction: .zhToForeign, languageCode: "en"), 1)
        XCTAssertEqual(ReviewSchedule.interval(after: 80, previousDays: 1), 2)
        XCTAssertEqual(ReviewSchedule.interval(after: 100, previousDays: 4), 8)
        XCTAssertEqual(ReviewSchedule.interval(after: 79, previousDays: 4), 4)
        XCTAssertEqual(ReviewSchedule.interval(after: 60, previousDays: 4), 4)
        XCTAssertEqual(ReviewSchedule.interval(after: 30, previousDays: 4), 4)
        XCTAssertEqual(ReviewSchedule.interval(after: 70, previousDays: 0), 1)
        XCTAssertEqual(ReviewSchedule.interval(after: 29, previousDays: 8), 4)
        XCTAssertEqual(ReviewSchedule.interval(after: 0, previousDays: 16), 8)
        let custom = ReviewPolicy(retireScore: 90, growScore: 70, growFactor: 3, holdScore: 40, shrinkFactor: 4)
        XCTAssertEqual(ReviewSchedule.interval(after: 70, previousDays: 2, policy: custom), 6)
        XCTAssertEqual(ReviewSchedule.interval(after: 40, previousDays: 8, policy: custom), 8)
        XCTAssertEqual(ReviewSchedule.interval(after: 39, previousDays: 8, policy: custom), 2)
        XCTAssertTrue(ReviewSchedule.retires(score: 96))
        XCTAssertFalse(ReviewSchedule.retires(score: 95))
        let due = ReviewSchedule.dueDay(on: at(day: 5, hour: 22), intervalDays: 3, calendar: calendar)
        XCTAssertEqual(due, at(day: 8))
    }

    func testExtraBandUsesItsOwnChange() {
        let policy = ReviewPolicy(bands: [
            ReviewBand(minScore: 90, change: .retire),
            ReviewBand(minScore: 80, change: .multiply(2)),
            ReviewBand(minScore: 50, change: .multiply(3)),
            ReviewBand(minScore: 30, change: .keep),
            ReviewBand(minScore: 0, change: .divide(2)),
        ]).clamped()
        XCTAssertEqual(ReviewSchedule.interval(after: 100, previousDays: 2, policy: policy), 4)
        XCTAssertEqual(ReviewSchedule.interval(after: 80, previousDays: 2, policy: policy), 4)
        XCTAssertEqual(ReviewSchedule.interval(after: 50, previousDays: 2, policy: policy), 6)
        XCTAssertEqual(ReviewSchedule.interval(after: 49, previousDays: 4, policy: policy), 4)
        XCTAssertEqual(ReviewSchedule.interval(after: 29, previousDays: 4, policy: policy), 2)
        XCTAssertTrue(ReviewSchedule.retires(score: 90, policy: policy))
        XCTAssertFalse(ReviewSchedule.retires(score: 89, policy: policy))
        let inserted = ReviewPolicy.standard.insertingBand()
        XCTAssertEqual(inserted.orderedBands.filter { $0.change == .keep }.map(\.minScore), [55, 30])
        let floor = ReviewPolicy.standard.orderedBands.first { $0.minScore == 0 }
        XCTAssertEqual(ReviewPolicy.standard.removingBand(id: floor?.id ?? UUID()).orderedBands.count, 4)
    }

    func testIntervalCapsAtSixty() {
        XCTAssertEqual(ReviewSchedule.interval(after: 80, previousDays: 30), 60)
        XCTAssertEqual(ReviewSchedule.interval(after: 85, previousDays: 31), 60)
        XCTAssertEqual(ReviewSchedule.interval(after: 90, previousDays: 40), 60)
        XCTAssertEqual(ReviewSchedule.interval(after: 100, previousDays: 60), 60)
        XCTAssertEqual(ReviewSchedule.interval(after: 79, previousDays: 60), 60)
    }

    func testDirectionsNeverShareDueState() {
        let native = source(1, direction: .zhToForeign, dayOffset: 0, score: 40)
        let practice = source(2, direction: .foreignToZh, dayOffset: 0, score: 80)
        let sources = [native, practice]
        let bothNative = due(sources, direction: .zhToForeign, dayOffset: 1)
        let bothPractice = due(sources, direction: .foreignToZh, dayOffset: 1)
        XCTAssertEqual(bothNative.map(\.exerciseID), [native.id])
        XCTAssertEqual(bothPractice.map(\.exerciseID), [practice.id])
        XCTAssertEqual(bothPractice.first?.lastScore, 80)
        XCTAssertEqual(bothPractice.first?.dueDay, at(day: 1))

        let reviewed = ReviewMark(
            id: uuid(8),
            exerciseID: native.id,
            direction: .zhToForeign,
            languageCode: "en",
            reviewedAt: at(day: 1, hour: 9),
            weightedScore: 90,
            intervalDays: 2,
            dueDay: ReviewSchedule.dueDay(on: at(day: 1, hour: 9), intervalDays: 2, calendar: calendar)
        )
        XCTAssertTrue(due(sources, marks: [reviewed], direction: .zhToForeign, dayOffset: 1).isEmpty)
        let practiceAfter = due(sources, marks: [reviewed], direction: .foreignToZh, dayOffset: 1)
        XCTAssertEqual(practiceAfter.map(\.exerciseID), [practice.id])
        XCTAssertEqual(practiceAfter.first?.lastScore, 80)
        XCTAssertEqual(practiceAfter.first?.dueDay, at(day: 1))

        let nativeLater = due(sources, marks: [reviewed], direction: .zhToForeign, dayOffset: 3)
        XCTAssertEqual(nativeLater.map(\.exerciseID), [native.id])
        XCTAssertEqual(nativeLater.first?.lastScore, 90)
        let practiceLater = due(sources, marks: [reviewed], direction: .foreignToZh, dayOffset: 3)
        XCTAssertEqual(practiceLater.first?.lastScore, 80)
        XCTAssertEqual(practiceLater.first?.dueDay, at(day: 1))

        let leaked = ReviewMark(
            id: uuid(7),
            exerciseID: native.id,
            direction: .foreignToZh,
            languageCode: "en",
            reviewedAt: at(day: 1),
            weightedScore: 10,
            intervalDays: 8,
            dueDay: at(day: 9)
        )
        XCTAssertEqual(
            ReviewSchedule.previousInterval(marks: [leaked], exerciseID: native.id, direction: .zhToForeign, languageCode: "en"),
            1
        )
    }

    func testLatestReviewScoreReplacesOriginal() {
        let item = source(1, dayOffset: 0, score: 42)
        let before = due([item], dayOffset: 2)
        XCTAssertEqual(before.first?.lastScore, 42)
        XCTAssertEqual(before.first?.dueDay, at(day: 1))
        let mark = ReviewMark(
            id: uuid(4),
            exerciseID: item.id,
            direction: .zhToForeign,
            languageCode: "en",
            reviewedAt: at(day: 2, hour: 11),
            weightedScore: 88,
            intervalDays: 2,
            dueDay: at(day: 4)
        )
        XCTAssertTrue(due([item], marks: [mark], dayOffset: 2).isEmpty)
        let later = due([item], marks: [mark], dayOffset: 4)
        XCTAssertEqual(later.first?.lastScore, 88)
        XCTAssertEqual(later.first?.dueDay, at(day: 4))
    }
}

final class PracticeStatsTests: XCTestCase {
    func testCountsAndSpread() {
        let items = [
            PracticeStatItem(direction: .zhToForeign, weighted: 92, faithfulness: 90, expressiveness: 88, elegance: 80, submittedAt: Date(timeIntervalSince1970: 40)),
            PracticeStatItem(direction: .zhToForeign, weighted: 70, faithfulness: 70, expressiveness: 70, elegance: 70, submittedAt: Date(timeIntervalSince1970: 30)),
            PracticeStatItem(direction: .foreignToZh, weighted: 50, faithfulness: 40, expressiveness: 60, elegance: 50, submittedAt: Date(timeIntervalSince1970: 10))
        ]
        XCTAssertEqual(PracticeStats.count(items, direction: .zhToForeign), 2)
        XCTAssertEqual(PracticeStats.count(items, direction: .foreignToZh), 1)
        let spread = PracticeStats.spread(items, recent: 2)
        XCTAssertEqual(spread.average, 71)
        XCTAssertEqual(spread.best, 92)
        XCTAssertEqual(spread.lowest, 50)
        XCTAssertEqual(spread.recentAverage, 81)
        XCTAssertEqual(spread.from90, 1)
        XCTAssertEqual(spread.from70, 1)
        XCTAssertEqual(spread.under70, 1)
        XCTAssertEqual(spread.total, 3)
    }
}

@MainActor
final class TokenUsageTests: XCTestCase {
    func testReadsOpenAIAndAnthropicUsage() {
        let openAI = Data(#"{"choices":[{"message":{"content":"ok"}}],"usage":{"prompt_tokens":12,"completion_tokens":4}}"#.utf8)
        let open = TokenUsageReading.tokens(kind: .openAI, body: openAI)
        XCTAssertEqual(open, TokenTally(input: 12, output: 4))
        let missing = Data(#"{"choices":[{"message":{"content":"ok"}}]}"#.utf8)
        XCTAssertEqual(TokenUsageReading.tokens(kind: .openAI, body: missing), TokenTally())
        let anthropic = Data(#"{"content":[{"text":"ok"}],"usage":{"input_tokens":8,"output_tokens":3}}"#.utf8)
        XCTAssertEqual(TokenUsageReading.tokens(kind: .anthropic, body: anthropic), TokenTally(input: 8, output: 3))
    }

    func testLedgerAddsByAccount() {
        let defaults = UserDefaults(suiteName: "token-ledger-test")!
        defaults.removePersistentDomain(forName: "token-ledger-test")
        let ledger = TokenLedger(defaults: defaults, key: "llm.tokens.v1")
        ledger.add(account: "llm.default", input: 10, output: 2)
        ledger.add(account: "llm.default", input: 1, output: 1)
        ledger.add(account: "llm.translation", input: 5, output: 7)
        XCTAssertEqual(ledger.tally(for: "llm.default"), TokenTally(input: 11, output: 3))
        XCTAssertEqual(ledger.tally(for: "llm.translation"), TokenTally(input: 5, output: 7))
        let reloaded = TokenLedger(defaults: defaults, key: "llm.tokens.v1")
        XCTAssertEqual(reloaded.tally(for: "llm.default"), TokenTally(input: 11, output: 3))
    }

    func testLedgerReadsTotalsSavedBeforeDaysExisted() {
        let defaults = UserDefaults(suiteName: "token-ledger-legacy")!
        defaults.removePersistentDomain(forName: "token-ledger-legacy")
        let old = try! JSONEncoder().encode(["llm.default": TokenTally(input: 9, output: 1)])
        defaults.set(old, forKey: "llm.tokens.v1")
        let ledger = TokenLedger(defaults: defaults, key: "llm.tokens.v1")
        XCTAssertEqual(ledger.tally(for: "llm.default"), TokenTally(input: 9, output: 1))
        XCTAssertTrue(ledger.days.isEmpty)
        XCTAssertTrue(ledger.hasUndated)
    }

    func testLedgerKeepsADayAndRollsItIntoTheMonth() {
        let defaults = UserDefaults(suiteName: "token-ledger-days")!
        defaults.removePersistentDomain(forName: "token-ledger-days")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let october = calendar.date(from: DateComponents(year: 2026, month: 10, day: 13))!
        let september = calendar.date(from: DateComponents(year: 2026, month: 9, day: 2))!
        let ledger = TokenLedger(defaults: defaults, key: "llm.tokens.v1")
        ledger.add(account: "llm.default", input: 10, output: 2, on: october, calendar: calendar)
        ledger.add(account: "llm.default", input: 1, output: 1, on: october, calendar: calendar)
        ledger.add(account: "llm.translation", input: 4, output: 1, on: september, calendar: calendar)
        XCTAssertEqual(ledger.days.count, 2)
        let months = ledger.buckets(span: .month, ending: october, calendar: calendar, count: 2)
        XCTAssertEqual(months.map(\.total), [5, 14])
        XCTAssertEqual(
            ledger.tally(for: "llm.default", span: .day, ending: october, calendar: calendar, count: 1),
            TokenTally(input: 11, output: 3)
        )
        let reloaded = TokenLedger(defaults: defaults, key: "llm.tokens.v1")
        XCTAssertEqual(reloaded.days.count, 2)
        XCTAssertFalse(reloaded.hasUndated)
    }

    func testLedgerSplitsDaysByModelAndKeepsOldRows() {
        let defaults = UserDefaults(suiteName: "token-ledger-models")!
        defaults.removePersistentDomain(forName: "token-ledger-models")
        let old = Data(#"{"totals":{"llm.default":{"input":3,"output":1}},"days":[{"day":"2026-10-01","account":"llm.default","input":3,"output":1}]}"#.utf8)
        defaults.set(old, forKey: "llm.tokens.v1")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 13))!
        let ledger = TokenLedger(defaults: defaults, key: "llm.tokens.v1")
        XCTAssertEqual(ledger.days.first?.model, "")
        ledger.add(account: "llm.default", input: 4, output: 2, model: "qwen", on: day, calendar: calendar)
        ledger.add(account: "llm.translation", input: 1, output: 1, model: "gpt-4o", on: day, calendar: calendar)
        ledger.add(account: "llm.default", input: 1, output: 0, model: "qwen", on: day, calendar: calendar)
        XCTAssertEqual(ledger.modelNames, ["gpt-4o", "qwen"])
        XCTAssertEqual(ledger.tally(model: "qwen", span: .day, ending: day, calendar: calendar, count: 1), TokenTally(input: 5, output: 2))
        let segments = ledger.segments(span: .day, ending: day, calendar: calendar, count: 1)
        XCTAssertEqual(segments.map(\.model).sorted(), ["gpt-4o", "qwen"])
        let reloaded = TokenLedger(defaults: defaults, key: "llm.tokens.v1")
        XCTAssertEqual(reloaded.modelNames, ["gpt-4o", "qwen"])
        XCTAssertEqual(reloaded.days.first { $0.model.isEmpty }?.input, 3)
    }

    func testTokenPriceUsesPerMillionRates() {
        let price = ModelTokenPrice(model: "qwen", currencyCode: "CNY", inputPerMillion: "2", outputPerMillion: "8")
        XCTAssertEqual(TokenMoney.cost(input: 1_500_000, output: 250_000, price: price), Decimal(5))
        XCTAssertEqual(
            TokenMoney.cost(input: 1_000_000, output: 0, price: ModelTokenPrice(model: "qwen", inputPerMillion: "1.5")),
            Decimal(string: "1.5", locale: Locale(identifier: "en_US_POSIX"))
        )
        XCTAssertNil(TokenMoney.cost(input: 10, output: 10, price: ModelTokenPrice(model: "qwen")))
        XCTAssertEqual(TokenMoney.amount("2,5"), Decimal(string: "2.5"))
    }

    func testTokenUnitScalesAndTrims() {
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(TokenUnit.one.text(1_077, locale: locale), "1,077")
        XCTAssertEqual(TokenUnit.thousand.text(1_077, locale: locale), "1.077")
        XCTAssertEqual(TokenUnit.thousand.text(1_000, locale: locale), "1")
        XCTAssertEqual(TokenUnit.million.text(2_500_000, locale: locale), "2.5")
        XCTAssertEqual(TokenUnit.million.text(1_077, locale: locale), "0.001077")
        XCTAssertEqual(TokenUnit.billion.text(1_077, locale: locale), "0.000001077")
        XCTAssertEqual(TokenUnit.thousand.scale(1_077), 1.077, accuracy: 0.000_000_1)
        XCTAssertEqual(TokenUnit.compactText(994, locale: locale), "994")
        XCTAssertEqual(TokenUnit.compactText(1_000, locale: locale), "1K")
        XCTAssertEqual(TokenUnit.compactText(1_077, locale: locale), "1.08K")
        XCTAssertEqual(TokenUnit.compactText(9_698, locale: locale), "9.7K")
        XCTAssertEqual(TokenUnit.compactText(14_994, locale: locale), "15K")
        XCTAssertEqual(TokenUnit.compactText(2_500_000, locale: locale), "2.5M")
        XCTAssertEqual(TokenUnit.compactText(1_500_000_000, locale: locale), "1.5B")
        XCTAssertEqual(TokenUnit.fitting(14_994), .thousand)
        let labeled = TokenSeries.withModels(
            [
                TokenDayRecord(day: "2026-10-14", account: "llm.default", input: 10, output: 2),
                TokenDayRecord(day: "2026-10-14", account: "llm.translation", input: 4, output: 1),
            ],
            accountModels: ["llm.default": "qwen", "llm.translation": "gpt-4o"]
        )
        XCTAssertEqual(Set(labeled.map(\.model)), ["gpt-4o", "qwen"])
    }
}

final class EditHunkTests: XCTestCase {
    func testPiecesShareAHunkUntilUnchangedWords() {
        let pieces = TextDiff.pieces(user: "I missed the bus today", corrected: "I caught the train today")
        let changed = pieces.filter { $0.hunk != nil }
        XCTAssertEqual(changed.map(\.hunk), [0, 0, 1, 1])
        XCTAssertEqual(changed.map(\.token), ["missed", "caught", "bus", "train"])
    }

    func testGroupsAdjacentChangesAndKeepsSeparatedOnesApart() {
        let replaced = TextDiff.hunks(user: "I missed the bus", corrected: "I missed the train")
        XCTAssertEqual(replaced, [EditHunk(before: "bus", after: "train")])
        let two = TextDiff.hunks(user: "I missed the bus today", corrected: "I caught the train today")
        XCTAssertEqual(two, [
            EditHunk(before: "missed", after: "caught"),
            EditHunk(before: "bus", after: "train"),
        ])
    }

    func testZipsReasonsInHunkOrder() {
        let hunks = [EditHunk(before: "bus", after: "train"), EditHunk(before: "", after: "the")]
        let notes = EditNotes.zip(hunks: hunks, reasons: [" 词义错了 "])
        XCTAssertEqual(notes[0].reason, "词义错了")
        XCTAssertEqual(notes[1].reason, "")
        XCTAssertEqual(EditNotes.decode(EditNotes.encode(notes)), notes)
    }

    func testTokenTapExtendsThenStartsOver() {
        var marks = TokenSelection()
        XCTAssertEqual(marks.tap(1), 1...1)
        XCTAssertEqual(marks.tap(3), 1...3)
        XCTAssertEqual(marks.tap(0), 0...0)
        XCTAssertNil(marks.tap(0))
    }
}

final class PhraseScheduleTests: XCTestCase {
    func testCorrectGrowsAndWrongShrinksWithoutLeavingTheQueue() {
        let policy = ReviewPolicy.standard
        XCTAssertEqual(PhraseSchedule.interval(remembered: true, previousDays: 1, policy: policy), 2)
        XCTAssertEqual(PhraseSchedule.interval(remembered: true, previousDays: 2, policy: policy), 4)
        XCTAssertEqual(PhraseSchedule.interval(remembered: false, previousDays: 4, policy: policy), 2)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let created = calendar.date(from: DateComponents(year: 2026, month: 10, day: 13))!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 14))!
        let phrase = PhraseSource(id: UUID(), direction: .zhToForeign, languageCode: "ja", createdAt: created)
        let due = PhraseSchedule.dueItems(
            phrases: [phrase],
            marks: [],
            direction: .zhToForeign,
            languageCode: "ja",
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(due.map(\.phraseID), [phrase.id])
        let remembered = PhraseReviewMark(
            id: UUID(),
            phraseID: phrase.id,
            reviewedAt: today,
            remembered: true,
            intervalDays: 2,
            dueDay: calendar.date(from: DateComponents(year: 2026, month: 10, day: 16))!
        )
        let later = PhraseSchedule.dueItems(
            phrases: [phrase],
            marks: [remembered],
            direction: .zhToForeign,
            languageCode: "ja",
            today: today,
            calendar: calendar
        )
        XCTAssertTrue(later.isEmpty)
    }
}
