import Foundation
import SwiftData
import TranslationCore

@MainActor
@Observable
final class AppModel {
    let container: ModelContainer
    let keychain = KeychainStore()
    private let client: LLMClient

    var settings: AppSettings {
        didSet { settings.save() }
    }

    var statusMessage: String?
    var workCaption: String?
    var explainingID: UUID?
    var explainFailedID: UUID?
    var explainMessage: String?
    private var workingCount = 0
    var isWorking: Bool { workingCount > 0 }
    var celebrate = false
    var glossTerm = ""
    var glossText = ""
    var glossIPA = ""
    var glossLoading = false
    var syncing = false
    var syncStatus: String?
    var lastSyncAt: Date?
    var placementExerciseID: UUID?
    var placementIndex = 0
    var placementSession: Direction = .zhToForeign

    let dictionaries = DictionaryLibrary()
    let tokenLedger: TokenLedger
    private var glossCache: [String: (term: String, gloss: String, reading: String)] = [:]
    private var replenishTask: Task<Void, Never>?
    private var replenishAgain = false
    private var placementLoading = false
    private var placementLoadDirection: Direction?
    private let stockDepth = 5

    init(container: ModelContainer, client: LLMClient? = nil) {
        self.container = container
        self.settings = AppSettings.load()
        let keychain = KeychainStore()
        let ledger = TokenLedger()
        self.tokenLedger = ledger
        self.client = client ?? LLMClient(
            loadKey: { account in keychain.load(account: account) },
            recordUsage: { account, model, input, output in
                Task { @MainActor in
                    ledger.add(account: account, input: input, output: output, model: model)
                }
            }
        )
        migrateTranslationKey()
        bindExercisesToNative()
        ensureSkills()
        ensureStreak()
        dictionaries.refresh()
    }

    private func migrateTranslationKey() {
        guard settings.llm.translationEndpoint.isComplete, !hasKey(account: "llm.translation") else { return }
        for task in LLMTask.allCases where task.usesTranslationModel {
            let account = "llm.\(task.rawValue)"
            guard let secret = keychain.load(account: account), !secret.isEmpty else { continue }
            try? saveKey(secret, account: "llm.translation")
            return
        }
    }

    var context: ModelContext { container.mainContext }

    var webdavPassword: String {
        keychain.load(account: "sync.webdav") ?? ""
    }

    func setWebdavPassword(_ value: String) {
        try? keychain.save(account: "sync.webdav", secret: value)
    }

    func bumpPracticeSettings() {
        settings.settingsRevision = Date()
    }

    func setReviewPolicy(_ mutate: (inout ReviewPolicy) -> Void) {
        var policy = settings.reviewPolicy
        mutate(&policy)
        settings.reviewPolicy = policy
        bumpPracticeSettings()
    }

    func ensureSkills() {
        let language = settings.activeLanguage
        for direction in Direction.allCases {
            _ = skill(language: language, direction: direction)
        }
        save()
    }

    func selectPracticeLanguage(_ language: PracticeLanguage) {
        if language == settings.nativeLanguage {
            let replacement = settings.activeLanguage == language
                ? PracticeLanguage.fallback(excluding: language)
                : settings.activeLanguage
            settings.nativeLanguageCode = replacement.rawValue
        }
        settings.activeLanguageCode = language.rawValue
        if !settings.enabledLanguageCodes.contains(language.rawValue) {
            settings.enabledLanguageCodes.append(language.rawValue)
        }
        bumpPracticeSettings()
        ensureSkills()
    }

    func selectNativeLanguage(_ language: PracticeLanguage) {
        if language == settings.activeLanguage {
            settings.activeLanguageCode = PracticeLanguage.fallback(excluding: language).rawValue
        }
        settings.nativeLanguageCode = language.rawValue
        bumpPracticeSettings()
        ensureSkills()
    }

    func setLength(_ preset: LengthPreset) {
        settings.length = preset
        bumpPracticeSettings()
    }

    func setDailyTarget(_ count: Int, for direction: Direction) {
        let proposedNative = direction == .zhToForeign ? count : settings.dailyTargetZhToForeign
        let proposedPractice = direction == .foreignToZh ? count : settings.dailyTargetForeignToZh
        guard let pair = DailyQuota.accepted(nativeToPractice: proposedNative, practiceToNative: proposedPractice) else { return }
        guard pair.nativeToPractice != settings.dailyTargetZhToForeign || pair.practiceToNative != settings.dailyTargetForeignToZh else { return }
        settings.dailyTargetZhToForeign = pair.nativeToPractice
        settings.dailyTargetForeignToZh = pair.practiceToNative
        bumpPracticeSettings()
        releaseUnstartedDailies()
    }

    func setScript(_ script: ChineseScript) {
        settings.script = script
        bumpPracticeSettings()
    }

    func ensureStreak() {
        if streakRecord() == nil {
            context.insert(StreakRecord())
            save()
            return
        }
        guard let record = streakRecord() else { return }
        let reconciled = StreakEngine.reconcileShields(record.snapshot)
        if reconciled != record.snapshot {
            record.apply(reconciled)
            save()
        }
    }

    func streakCanRepair(on day: Date = Date()) -> Bool {
        guard let record = streakRecord() else { return false }
        return StreakEngine.repair(state: record.snapshot, on: day, calendar: .current) != nil
    }

    func repairStreak(on day: Date = Date()) {
        guard let record = streakRecord(),
              let repaired = StreakEngine.repair(state: record.snapshot, on: day, calendar: .current) else { return }
        record.apply(repaired)
        registerStreakIfNeeded(language: settings.activeLanguage)
        save()
        Task { await syncNow() }
    }

    func declineStreakRepair() {
        registerStreakIfNeeded(language: settings.activeLanguage, forceReset: true)
        save()
        Task { await syncNow() }
    }

    func ensureDailyPair() async {
        releaseUnstartedDailies()
        guard apiReady(for: .generate) else {
            statusMessage = LLMClientError.missingConfiguration.errorDescription
            return
        }
        let language = settings.activeLanguage
        for direction in Direction.allCases {
            let target = settings.dailyTarget(for: direction)
            guard target > 0 else { continue }
            for index in 0..<target {
                if let existing = dailyExercise(language: language, direction: direction, index: index) {
                    let untouched = !existing.submitted && existing.userDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let script = SourceScript.expected(direction: direction, language: language, native: settings.nativeLanguage)
                    if untouched && !QuestionGate.matches(existing.sourceText, script: script) {
                        noteDeletion(kind: "exercise", recordID: existing.id.uuidString)
                        context.delete(existing)
                        save()
                    } else {
                        continue
                    }
                }
                do {
                    if claimReady(language: language, direction: direction, kind: .daily, dailyIndex: index) == nil {
                        try await generate(language: language, direction: direction, kind: .daily, dailyIndex: index)
                    }
                } catch {
                    statusMessage = error.localizedDescription
                }
            }
        }
        scheduleReplenish()
    }

    func generateExtra(direction: Direction) async -> Exercise? {
        if let ready = claimReady(language: settings.activeLanguage, direction: direction, kind: .extra) {
            return ready
        }
        do {
            return try await generate(language: settings.activeLanguage, direction: direction, kind: .extra)
        } catch {
            statusMessage = error.localizedDescription
            return nil
        }
    }

    func startPlacement(direction: Direction) async {
        let record = skill(language: settings.activeLanguage, direction: direction)
        guard !record.placementDone else { return }
        if record.placementStep == 0 {
            let done = allExercises().filter { item in
                item.kind == .placement
                    && item.submitted
                    && item.languageCode == settings.activeLanguage.rawValue
                    && item.direction == direction
            }.count
            if done >= 5 {
                record.placementDone = true
                save()
                return
            }
            if done > 0 {
                record.placementStep = done
                save()
            }
        }
        placementSession = direction
        if let existing = unsubmittedPlacement(direction: direction) {
            placementExerciseID = existing.id
            placementIndex = record.placementStep
            statusMessage = nil
            return
        }
        placementIndex = record.placementStep
        statusMessage = nil
        beginWorking()
        defer { endWorking() }
        await loadPlacement(index: record.placementStep)
    }

    func retryPlacement() async {
        statusMessage = nil
        let direction = placementSession
        if let id = placementExerciseID,
           allExercises().contains(where: { $0.id == id && $0.submitted && $0.direction == direction }) {
            beginWorking()
            defer { endWorking() }
            await loadPlacement(index: placementIndex + 1)
            return
        }
        await startPlacement(direction: direction)
    }

    func skipPlacement(direction: Direction) {
        let record = skill(language: settings.activeLanguage, direction: direction)
        record.placementDone = true
        record.updatedAt = Date()
        if placementSession == direction {
            placementExerciseID = nil
        }
        save()
    }

    @discardableResult
    func generate(language: PracticeLanguage, direction: Direction, kind: ExerciseKind, quiet: Bool = false, dailyIndex: Int = 0) async throws -> Exercise {
        if kind == .daily, let existing = dailyExercise(language: language, direction: direction, index: dailyIndex) {
            return existing
        }
        if !quiet { beginWorking() }
        defer { if !quiet { endWorking() } }
        let current = skill(language: language, direction: direction)
        var note: String?
        let task: LLMTask = kind == .placement ? .placement : .generate
        for _ in 0..<3 {
            let prompt = PromptBuilder.generation(
                GenerationRequest(
                    language: language,
                    direction: direction,
                    level: current.level,
                    preset: settings.length,
                    script: settings.script,
                    native: settings.nativeLanguage,
                    recentTopics: recentTopics(language: language),
                    errorTags: topErrorTags(language: language, direction: direction),
                    retryNote: note
                )
            )
            let payload = try await client.completeJSON(task: task, settings: settings.llm, prompt: prompt, temperature: 0.8)
            if quiet, Task.isCancelled { throw CancellationError() }
            let text = payload.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let topic = payload.topic?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else {
                note = "没有返回题目正文。请重写。"
                continue
            }
            let spec = LengthPolicy.spec(preset: settings.length, language: language, direction: direction, native: settings.nativeLanguage)
            let script = SourceScript.expected(direction: direction, language: language, native: settings.nativeLanguage)
            if let failure = QuestionGate.check(text: text, spec: spec, recentTexts: current.recentSources, script: script) {
                note = QuestionGate.feedback(for: failure)
                continue
            }
            if kind == .daily, let existing = dailyExercise(language: language, direction: direction, index: dailyIndex) {
                if !quiet { statusMessage = nil }
                return existing
            }
            let dailyKey = kind == .daily
                ? DayKey.dailyKey(day: Date(), language: language, direction: direction, index: dailyIndex, native: settings.nativeLanguage)
                : nil
            let exercise = Exercise(
                dailyKey: dailyKey,
                languageCode: language.rawValue,
                direction: direction,
                kind: kind,
                topic: topic,
                sourceText: text
            )
            exercise.nativeLanguageCode = settings.nativeLanguage.rawValue
            context.insert(exercise)
            if kind == .ready {
                exercise.stockLevel = current.level
                exercise.stockPresetRaw = settings.length.rawValue
                exercise.stockScriptRaw = settings.script.rawValue
            }
            var sources = current.recentSources
            sources.append(text)
            if sources.count > 30 { sources.removeFirst(sources.count - 30) }
            current.recentSources = sources
            current.updatedAt = Date()
            save()
            if !quiet { statusMessage = nil }
            if kind != .ready {
                await syncNow()
            }
            return exercise
        }
        throw LLMClientError.invalidJSON
    }

    private func claimReady(language: PracticeLanguage, direction: Direction, kind: ExerciseKind, dailyIndex: Int = 0) -> Exercise? {
        if kind == .daily, let existing = dailyExercise(language: language, direction: direction, index: dailyIndex) {
            return existing
        }
        guard let exercise = freshStock(language: language, direction: direction).first else { return nil }
        exercise.kindRaw = kind.rawValue
        if kind == .daily {
            exercise.dailyKey = DayKey.dailyKey(day: Date(), language: language, direction: direction, index: dailyIndex, native: settings.nativeLanguage)
            exercise.nativeLanguageCode = settings.nativeLanguage.rawValue
        }
        save()
        scheduleReplenish()
        return exercise
    }

    private func freshStock(language: PracticeLanguage, direction: Direction) -> [Exercise] {
        let level = skill(language: language, direction: direction).level
        return allExercises().filter { item in
            item.kind == .ready
                && item.id != placementExerciseID
                && item.languageCode == language.rawValue
                && item.direction == direction
                && item.stockLevel == level
                && item.stockPresetRaw == settings.length.rawValue
                && item.stockScriptRaw == settings.script.rawValue
                && item.nativeLanguageCode == settings.nativeLanguage.rawValue
        }
    }

    private func stockNeedsFill() -> Bool {
        Direction.allCases.contains { direction in
            freshStock(language: settings.activeLanguage, direction: direction).count < stockDepth
        }
    }

    private func scheduleReplenish() {
        guard workingCount == 0, apiReady(for: .generate) else { return }
        if let replenishTask, !replenishTask.isCancelled {
            replenishAgain = true
            return
        }
        replenishAgain = false
        replenishTask = Task {
            await replenishStock()
            guard !Task.isCancelled else { return }
            replenishTask = nil
            if replenishAgain {
                replenishAgain = false
                scheduleReplenish()
            }
        }
    }

    private func replenishStock() async {
        guard workingCount == 0, apiReady(for: .generate) else { return }
        discardStaleStock()
        let language = settings.activeLanguage
        for direction in Direction.allCases {
            while freshStock(language: language, direction: direction).count < stockDepth {
                if Task.isCancelled || workingCount > 0 { return }
                do {
                    try await generate(language: language, direction: direction, kind: .ready, quiet: true)
                } catch {
                    return
                }
            }
        }
    }

    private func discardStaleStock() {
        var changed = false
        for item in allExercises() where item.kind == .ready && item.id != placementExerciseID {
            let language = PracticeLanguage(rawValue: item.languageCode) ?? settings.activeLanguage
            let level = skill(language: language, direction: item.direction).level
            let fresh = item.stockLevel == level
                && item.stockPresetRaw == settings.length.rawValue
                && item.stockScriptRaw == settings.script.rawValue
                && item.nativeLanguageCode == settings.nativeLanguage.rawValue
            if !fresh {
                context.delete(item)
                changed = true
            }
        }
        if changed { save() }
    }

    func submit(exercise: Exercise, answer: String) async {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        exercise.userDraft = trimmed
        statusMessage = nil
        explainFailedID = nil
        explainMessage = nil
        workCaption = String(localized: "ai_grading")
        beginWorking()
        var released = false
        defer {
            if !released {
                endWorking()
                workCaption = nil
            }
        }
        do {
            let language = PracticeLanguage(rawValue: exercise.languageCode) ?? .english
            let review = try await requestReview(source: exercise.sourceText, user: trimmed, direction: exercise.direction, language: language)
            exercise.userText = trimmed
            exercise.correctedText = review.corrected
            exercise.exemplarText = review.exemplar
            exercise.faithfulness = review.faithfulness
            exercise.expressiveness = review.expressiveness
            exercise.elegance = review.elegance
            exercise.weightedScore = review.weighted
            exercise.exemplarFaithfulness = review.exemplarFaithfulness
            exercise.exemplarExpressiveness = review.exemplarExpressiveness
            exercise.exemplarElegance = review.exemplarElegance
            exercise.exemplarWeightedScore = review.exemplarWeighted
            exercise.errorTags = review.tags
            exercise.storeEditNotes([])
            exercise.submitted = true
            let ratio = TextDiff.editRatio(user: trimmed, corrected: review.corrected)
            let current = skill(language: language, direction: exercise.direction)
            let delta = Difficulty.step(weightedScore: review.weighted, editRatio: ratio, placement: exercise.kind == .placement)
            current.level = Difficulty.applying(level: current.level, step: delta)
            exercise.updatedAt = Date()
            current.updatedAt = Date()
            if exercise.kind == .daily {
                registerStreakIfNeeded(language: language)
            }
            if exercise.kind == .placement {
                advancePlacement(direction: exercise.direction)
            }
            save()
            let exerciseID = exercise.id
            let source = exercise.sourceText
            let corrected = review.corrected
            endWorking()
            workCaption = nil
            released = true
            statusMessage = nil
            scheduleReasons(target: .exercise(exerciseID), source: source, user: trimmed, corrected: corrected)
            await syncNow()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func regrade(exercise: Exercise) async {
        let trimmed = exercise.userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard exercise.submitted, exercise.kind != .ready, !trimmed.isEmpty else { return }
        let exerciseID = exercise.id
        let source = exercise.sourceText
        let direction = exercise.direction
        let language = PracticeLanguage(rawValue: exercise.languageCode) ?? .english
        statusMessage = nil
        explainFailedID = nil
        explainMessage = nil
        workCaption = String(localized: "ai_grading")
        beginWorking()
        var released = false
        defer {
            if !released {
                endWorking()
                workCaption = nil
            }
        }
        do {
            let review = try await requestReview(source: source, user: trimmed, direction: direction, language: language)
            guard let current = allExercises().first(where: { $0.id == exerciseID }), current.submitted else { return }
            current.correctedText = review.corrected
            current.exemplarText = review.exemplar
            current.faithfulness = review.faithfulness
            current.expressiveness = review.expressiveness
            current.elegance = review.elegance
            current.weightedScore = review.weighted
            current.exemplarFaithfulness = review.exemplarFaithfulness
            current.exemplarExpressiveness = review.exemplarExpressiveness
            current.exemplarElegance = review.exemplarElegance
            current.exemplarWeightedScore = review.exemplarWeighted
            current.errorTags = review.tags
            current.storeEditNotes([])
            current.updatedAt = Date()
            save()
            endWorking()
            workCaption = nil
            released = true
            statusMessage = nil
            scheduleReasons(target: .exercise(exerciseID), source: source, user: trimmed, corrected: review.corrected)
            await syncNow()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @discardableResult
    func submitReview(exercise: Exercise, answer: String) async -> UUID? {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, exercise.submitted, exercise.kind != .ready else { return nil }
        let exerciseID = exercise.id
        let source = exercise.sourceText
        let direction = exercise.direction
        let languageCode = exercise.languageCode
        let language = PracticeLanguage(rawValue: languageCode) ?? .english
        statusMessage = nil
        explainFailedID = nil
        explainMessage = nil
        workCaption = String(localized: "ai_grading")
        beginWorking()
        var released = false
        defer {
            if !released {
                endWorking()
                workCaption = nil
            }
        }
        do {
            let review = try await requestReview(source: source, user: trimmed, direction: direction, language: language)
            guard let current = allExercises().first(where: { $0.id == exerciseID }),
                  current.submitted,
                  current.kind != .ready else { return nil }
            let marks = allReviewAttempts().filter { $0.exerciseID == exerciseID }.map { attempt in
                ReviewMark(
                    id: attempt.id,
                    exerciseID: attempt.exerciseID,
                    direction: attempt.direction,
                    languageCode: attempt.languageCode,
                    reviewedAt: attempt.createdAt,
                    weightedScore: attempt.weightedScore,
                    intervalDays: attempt.intervalDays,
                    dueDay: attempt.dueDay
                )
            }
            let previous = ReviewSchedule.previousInterval(
                marks: marks,
                exerciseID: exerciseID,
                direction: direction,
                languageCode: languageCode
            )
            let interval = ReviewSchedule.interval(after: review.weighted, previousDays: previous, policy: settings.reviewPolicy)
            let due = ReviewSchedule.dueDay(on: Date(), intervalDays: interval, calendar: .current)
            let now = Date()
            let attempt = ReviewAttempt(
                exerciseID: exerciseID,
                createdAt: now,
                userText: trimmed,
                correctedText: review.corrected,
                faithfulness: review.faithfulness,
                expressiveness: review.expressiveness,
                elegance: review.elegance,
                weightedScore: review.weighted,
                direction: direction,
                languageCode: languageCode,
                intervalDays: interval,
                dueDay: due
            )
            context.insert(attempt)
            save()
            endWorking()
            workCaption = nil
            released = true
            statusMessage = nil
            scheduleReasons(target: .attempt(attempt.id), source: source, user: trimmed, corrected: review.corrected)
            await syncNow()
            return attempt.id
        } catch {
            statusMessage = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func applyDictionaryGloss(term: String, exercise: Exercise) -> Bool {
        let cleaned = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            clearGloss()
            return true
        }
        let sides = glossSides(exercise: exercise)
        let cacheKey = glossCacheKey(source: sides.source, target: sides.target, term: cleaned)
        if let cached = glossCache[cacheKey] {
            showGloss(cached)
            return true
        }
        guard settings.preferDictionary, let dictionaryLanguage = sides.dictionaryLanguage else { return false }
        if let hit = dictionaries.lookup(term: cleaned, language: dictionaryLanguage, sourceIsChinese: sides.source == .chinese) {
            let reading = sides.target == .chinese ? ChinesePinyin.marks(of: hit.gloss) : ""
            let gloss = (term: hit.key, gloss: hit.gloss, reading: reading)
            glossCache[cacheKey] = gloss
            showGloss(gloss)
            return true
        }
        return false
    }

    func lookup(term: String, exercise: Exercise) async {
        let cleaned = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            clearGloss()
            return
        }
        if applyDictionaryGloss(term: cleaned, exercise: exercise) {
            return
        }
        guard cleaned.count <= 48 else {
            glossLoading = false
            return
        }
        let sides = glossSides(exercise: exercise)
        let cacheKey = glossCacheKey(source: sides.source, target: sides.target, term: cleaned)
        glossTerm = cleaned
        glossText = ""
        glossIPA = ""
        glossLoading = true
        defer { glossLoading = false }
        do {
            let prompt = PromptBuilder.vocabulary(term: cleaned, source: sides.source, target: sides.target)
            let payload = try await client.completeJSON(task: .vocabulary, settings: settings.llm, prompt: prompt, temperature: 0.2)
            let gloss = payload.gloss ?? ""
            let ipa = payload.ipa ?? ""
            let shown = (term: cleaned, gloss: gloss, reading: ipa)
            glossCache[cacheKey] = shown
            guard !Task.isCancelled else { return }
            showGloss(shown)
        } catch {
            glossTerm = cleaned
            glossText = error.localizedDescription
            glossIPA = ""
        }
    }

    func clearGloss() {
        glossTerm = ""
        glossText = ""
        glossIPA = ""
        glossLoading = false
    }

    private func showGloss(_ gloss: (term: String, gloss: String, reading: String)) {
        glossTerm = gloss.term
        glossText = gloss.gloss
        glossIPA = gloss.reading
        glossLoading = false
    }

    private func glossSides(exercise: Exercise) -> (source: PracticeLanguage, target: PracticeLanguage, dictionaryLanguage: PracticeLanguage?) {
        let practice = PracticeLanguage(rawValue: exercise.languageCode) ?? settings.activeLanguage
        let source = exercise.direction.source(native: settings.nativeLanguage, practice: practice)
        let target = exercise.direction.target(native: settings.nativeLanguage, practice: practice)
        let dictionaryLanguage: PracticeLanguage?
        if source == .chinese, target != .chinese {
            dictionaryLanguage = target
        } else if target == .chinese, source != .chinese {
            dictionaryLanguage = source
        } else {
            dictionaryLanguage = nil
        }
        return (source, target, dictionaryLanguage)
    }

    private func glossCacheKey(source: PracticeLanguage, target: PracticeLanguage, term: String) -> String {
        "\(source.rawValue)|\(target.rawValue)|\(settings.preferDictionary)|py|\(term)"
    }

    func setPreferDictionary(_ enabled: Bool) {
        settings.preferDictionary = enabled
        bumpPracticeSettings()
        glossCache.removeAll()
        clearGloss()
    }

    func downloadDictionary(_ id: String) async {
        await dictionaries.download(id)
        glossCache.removeAll()
    }

    func deleteDictionary(_ id: String) {
        dictionaries.delete(id)
        glossCache.removeAll()
    }

    func favorite(_ exercise: Exercise) {
        guard exercise.submitted else { return }
        let item = FavoriteItem(folderID: settings.favoriteFolderID, exercise: exercise)
        context.insert(item)
        save()
    }

    func savePhrase(exercise: Exercise, prompt: String, answer: String) {
        let promptText = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let answerText = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard exercise.submitted, !promptText.isEmpty, !answerText.isEmpty else { return }
        let pair = PhrasePair(
            exerciseID: exercise.id,
            languageCode: exercise.languageCode,
            direction: exercise.direction,
            promptText: promptText,
            answerText: answerText
        )
        context.insert(pair)
        save()
        Task { await syncNow() }
    }

    func deletePhrase(_ phrase: PhrasePair) {
        noteDeletion(kind: "phrase", recordID: phrase.id.uuidString)
        tombstonePhraseReviews(of: phrase.id)
        context.delete(phrase)
        save()
        Task { await syncNow() }
    }

    func gradePhrase(_ phrase: PhrasePair, remembered: Bool) {
        let marks = allPhraseReviews().filter { $0.phraseID == phrase.id }.map { review in
            PhraseReviewMark(
                id: review.id,
                phraseID: review.phraseID,
                reviewedAt: review.createdAt,
                remembered: review.remembered,
                intervalDays: review.intervalDays,
                dueDay: review.dueDay
            )
        }
        let previous = marks.max { lhs, rhs in
            if lhs.reviewedAt != rhs.reviewedAt { return lhs.reviewedAt < rhs.reviewedAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }?.intervalDays ?? 1
        let interval = PhraseSchedule.interval(remembered: remembered, previousDays: previous, policy: settings.reviewPolicy)
        let due = ReviewSchedule.dueDay(on: Date(), intervalDays: interval, calendar: .current)
        let review = PhraseReview(
            phraseID: phrase.id,
            remembered: remembered,
            intervalDays: interval,
            dueDay: due
        )
        context.insert(review)
        phrase.updatedAt = Date()
        save()
        Task { await syncNow() }
    }

    private enum ReasonTarget {
        case exercise(UUID)
        case attempt(UUID)

        var id: UUID {
            switch self {
            case let .exercise(id), let .attempt(id):
                id
            }
        }
    }

    private func scheduleReasons(target: ReasonTarget, source: String, user: String, corrected: String) {
        let hunks = TextDiff.hunks(user: user, corrected: corrected)
        guard !hunks.isEmpty else { return }
        explainingID = target.id
        explainFailedID = nil
        explainMessage = nil
        Task {
            await self.fetchReasons(target: target, source: source, user: user, corrected: corrected, hunks: hunks)
        }
    }

    private func fetchReasons(target: ReasonTarget, source: String, user: String, corrected: String, hunks: [EditHunk]) async {
        defer {
            if explainingID == target.id { explainingID = nil }
        }
        do {
            let prompt = PromptBuilder.editReasons(
                source: source,
                user: user,
                corrected: corrected,
                hunks: hunks,
                native: settings.nativeLanguage
            )
            let payload = try await client.completeJSON(task: .grade, settings: settings.llm, prompt: prompt, temperature: 0.2)
            let notes = EditNotes.zip(hunks: hunks, reasons: payload.reasons ?? [])
            guard explainingID == target.id else { return }
            switch target {
            case let .exercise(id):
                guard let exercise = allExercises().first(where: { $0.id == id }), exercise.correctedText == corrected else { return }
                exercise.storeEditNotes(notes)
                exercise.updatedAt = Date()
            case let .attempt(id):
                guard let attempt = allReviewAttempts().first(where: { $0.id == id }), attempt.correctedText == corrected else { return }
                attempt.storeEditNotes(notes)
                attempt.updatedAt = Date()
            }
            save()
            await syncNow()
        } catch {
            explainFailedID = target.id
            explainMessage = error.localizedDescription
        }
    }

    func deleteExercise(_ exercise: Exercise) {
        if exercise.kind != .ready {
            noteDeletion(kind: "exercise", recordID: exercise.id.uuidString)
            tombstoneReviews(of: exercise.id)
            tombstonePhrases(of: exercise.id)
        }
        context.delete(exercise)
        save()
        if exercise.kind != .ready {
            Task { await syncNow() }
        }
    }

    func deleteExercises(before cutoff: Date) {
        let stamps = allExercises().map { AttemptStamp(id: $0.id, createdAt: $0.createdAt) }
        let doomed = HistoryDeletion.ids(in: stamps, before: cutoff)
        for exercise in allExercises() where exercise.kind != .ready && doomed.contains(exercise.id) {
            noteDeletion(kind: "exercise", recordID: exercise.id.uuidString)
            tombstoneReviews(of: exercise.id)
            tombstonePhrases(of: exercise.id)
            context.delete(exercise)
        }
        save()
        Task { await syncNow() }
    }

    func createFolder(name: String, parentID: UUID?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let siblings = allFolders().filter { $0.parentID == parentID }
        let folder = FavoriteFolder(name: trimmed, parentID: parentID, sortIndex: siblings.count)
        context.insert(folder)
        save()
    }

    func deleteFolders(_ ids: Set<UUID>) {
        var all = Set<UUID>()
        for id in ids {
            all.formUnion(FolderTree.descendantIDs(of: id, childrenOf: children(of:)))
        }
        for item in allItems() where item.folderID.map(all.contains) == true {
            noteDeletion(kind: "favorite", recordID: item.id.uuidString)
            context.delete(item)
        }
        for folder in allFolders() where all.contains(folder.id) {
            noteDeletion(kind: "folder", recordID: folder.id.uuidString)
            context.delete(folder)
        }
        if let current = settings.favoriteFolderID, all.contains(current) {
            settings.favoriteFolderID = nil
        }
        save()
        Task { await syncNow() }
    }

    func deleteItems(_ ids: Set<UUID>) {
        for item in allItems() where ids.contains(item.id) {
            noteDeletion(kind: "favorite", recordID: item.id.uuidString)
            context.delete(item)
        }
        save()
        Task { await syncNow() }
    }

    func togglePin(folder: FavoriteFolder) {
        folder.pinned.toggle()
        save()
    }

    func togglePin(item: FavoriteItem) {
        item.pinned.toggle()
        save()
    }

    func needsPlacement(language: PracticeLanguage, direction: Direction) -> Bool {
        !skill(language: language, direction: direction).placementDone
    }

    func apiReady(for task: LLMTask) -> Bool {
        let identity = LLMRouting.identity(for: task, settings: settings.llm)
        guard settings.llm.config(for: task).isComplete else { return false }
        guard let key = keychain.load(account: identity.keyAccount), !key.isEmpty else { return false }
        return true
    }

    func saveKey(_ secret: String, account: String) throws {
        try keychain.save(account: account, secret: secret)
    }

    func clearKey(account: String) {
        keychain.delete(account: account)
    }

    func hasKey(account: String) -> Bool {
        guard let key = keychain.load(account: account) else { return false }
        return !key.isEmpty
    }

    func testEndpoint(_ config: EndpointConfig, account: String, typedKey: String) async throws {
        let typed = typedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = typed.isEmpty ? (keychain.load(account: account) ?? "") : typed
        try await client.probe(kind: config.kind, baseURL: config.baseURL, model: config.model, key: key)
    }

    private func requestReview(source: String, user: String, direction: Direction, language: PracticeLanguage) async throws -> ReviewBundle {
        if LLMRouting.mergesReview(settings: settings.llm) {
            let prompt = PromptBuilder.review(source: source, user: user, direction: direction, language: language, script: settings.script, native: settings.nativeLanguage)
            let payload = try await client.completeJSON(task: .grade, settings: settings.llm, prompt: prompt, temperature: 0.2)
            var bundle = ReviewBundle(payload: payload, fallbackUser: user)
            bundle.corrected = try await correctedInTargetLanguage(
                bundle.corrected,
                source: source,
                user: user,
                direction: direction,
                language: language
            )
            return bundle
        }
        async let gradeCall = client.completeJSON(
            task: .grade,
            settings: settings.llm,
            prompt: PromptBuilder.gradeOnly(source: source, user: user, direction: direction, language: language, native: settings.nativeLanguage),
            temperature: 0.2
        )
        async let correctCall = client.completeJSON(
            task: .correct,
            settings: settings.llm,
            prompt: PromptBuilder.correctionOnly(
                source: source,
                user: user,
                target: direction.target(native: settings.nativeLanguage, practice: language)
            ),
            temperature: 0.2
        )
        async let exemplarCall = client.completeJSON(
            task: .exemplar,
            settings: settings.llm,
            prompt: PromptBuilder.exemplarOnly(source: source, direction: direction, language: language, native: settings.nativeLanguage),
            temperature: 0.4
        )
        let grade = try await gradeCall
        let corrected = try await correctCall
        let exemplar = try await exemplarCall
        var bundle = ReviewBundle(grade: grade, corrected: corrected, exemplar: exemplar, fallbackUser: user)
        bundle.corrected = try await correctedInTargetLanguage(
            bundle.corrected,
            source: source,
            user: user,
            direction: direction,
            language: language
        )
        return bundle
    }

    private func correctedInTargetLanguage(
        _ corrected: String,
        source: String,
        user: String,
        direction: Direction,
        language: PracticeLanguage
    ) async throws -> String {
        let target = direction.target(native: settings.nativeLanguage, practice: language)
        let script = SourceScript.script(of: target)
        if QuestionGate.matches(corrected, script: script) {
            return corrected
        }
        let payload = try await client.completeJSON(
            task: .correct,
            settings: settings.llm,
            prompt: PromptBuilder.correctionOnly(source: source, user: user, target: target, retry: true),
            temperature: 0.2
        )
        if let text = payload.corrected, QuestionGate.matches(text, script: script) {
            return text
        }
        return user
    }

    private func advancePlacement(direction: Direction) {
        let record = skill(language: settings.activeLanguage, direction: direction)
        if record.placementStep >= 4 {
            finishPlacement(direction: direction)
            return
        }
        record.placementStep += 1
        record.updatedAt = Date()
        save()
        guard placementSession == direction else { return }
        beginWorking()
        Task {
            defer { endWorking() }
            await loadPlacement(index: record.placementStep)
        }
    }

    private func unsubmittedPlacement(direction: Direction, excluding excluded: UUID? = nil) -> Exercise? {
        allExercises().first { item in
            item.kind == .placement
                && !item.submitted
                && item.id != excluded
                && item.languageCode == settings.activeLanguage.rawValue
                && item.direction == direction
        }
    }

    private func loadPlacement(index: Int) async {
        let direction = placementSession
        guard index <= 4 else {
            finishPlacement(direction: direction)
            return
        }
        if let existing = unsubmittedPlacement(direction: direction) {
            if placementSession == direction {
                placementIndex = index
                placementExerciseID = existing.id
                statusMessage = nil
            }
            return
        }
        if placementLoading, placementLoadDirection == direction { return }
        placementLoading = true
        placementLoadDirection = direction
        defer {
            if placementLoadDirection == direction {
                placementLoading = false
                placementLoadDirection = nil
            }
        }
        let language = settings.activeLanguage
        if let ready = claimReady(language: language, direction: direction, kind: .placement) {
            let blocked = placementSession != direction
                || unsubmittedPlacement(direction: direction, excluding: ready.id) != nil
            if blocked {
                parkInStock(ready, language: language, direction: direction)
                return
            }
            placementIndex = index
            placementExerciseID = ready.id
            statusMessage = nil
            return
        }
        do {
            let exercise = try await generate(
                language: language,
                direction: direction,
                kind: .placement
            )
            let blocked = placementSession != direction
                || unsubmittedPlacement(direction: direction, excluding: exercise.id) != nil
            if blocked {
                parkInStock(exercise, language: language, direction: direction)
                return
            }
            placementIndex = index
            placementExerciseID = exercise.id
            statusMessage = nil
            scheduleReplenish()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func releaseUnstartedDailies() {
        let language = settings.activeLanguage
        let native = settings.nativeLanguage
        var changed = false
        for exercise in allExercises() where exercise.kind == .daily && !exercise.submitted {
            guard exercise.languageCode == language.rawValue else { continue }
            guard let key = exercise.dailyKey else { continue }
            let direction = exercise.direction
            guard DayKey.matches(key, day: Date(), language: language, direction: direction, native: native) else { continue }
            guard DayKey.dailyIndex(in: key) >= settings.dailyTarget(for: direction) else { continue }
            exercise.kindRaw = ExerciseKind.ready.rawValue
            exercise.dailyKey = nil
            if exercise.nativeLanguageCode.isEmpty {
                exercise.nativeLanguageCode = native.rawValue
            }
            exercise.stockLevel = skill(language: language, direction: direction).level
            exercise.stockPresetRaw = settings.length.rawValue
            exercise.stockScriptRaw = settings.script.rawValue
            exercise.updatedAt = Date()
            changed = true
        }
        if changed {
            save()
            scheduleReplenish()
        }
    }

    private func parkInStock(_ exercise: Exercise, language: PracticeLanguage, direction: Direction) {
        exercise.kindRaw = ExerciseKind.ready.rawValue
        exercise.dailyKey = nil
        exercise.stockLevel = skill(language: language, direction: direction).level
        exercise.stockPresetRaw = settings.length.rawValue
        exercise.stockScriptRaw = settings.script.rawValue
        save()
        scheduleReplenish()
    }

    private func finishPlacement(direction: Direction) {
        let record = skill(language: settings.activeLanguage, direction: direction)
        record.placementDone = true
        record.updatedAt = Date()
        if placementSession == direction {
            placementExerciseID = nil
        }
        save()
    }

    private func registerStreakIfNeeded(language: PracticeLanguage, forceReset: Bool = false) {
        let day = DayKey.string(from: Date())
        let submitted = allExercises().filter { exercise in
            exercise.kind == .daily && exercise.submitted && exercise.languageCode == language.rawValue && (exercise.dailyKey?.hasPrefix(day) ?? false)
        }
        let met = DailyQuota.requirementsMet(
            nativeToPractice: submittedDailyIndices(in: submitted, direction: .zhToForeign),
            practiceToNative: submittedDailyIndices(in: submitted, direction: .foreignToZh),
            nativeToPracticeTarget: settings.dailyTarget(for: .zhToForeign),
            practiceToNativeTarget: settings.dailyTarget(for: .foreignToZh)
        )
        let record = streakRecord() ?? {
            let created = StreakRecord()
            context.insert(created)
            return created
        }()
        let missed = StreakEngine.missedDays(since: record.lastCompletedDay, on: Date(), calendar: .current)
        if met && !forceReset && !missed.isEmpty && missed.count <= record.shields && missed.count <= StreakEngine.shieldCap {
            return
        }
        let update = StreakEngine.register(state: record.snapshot, on: Date(), bothDirectionsDone: met, calendar: .current)
        record.apply(update.snapshot)
        if update.shouldCelebrate {
            celebrate = true
        }
    }

    func skill(language: PracticeLanguage, direction: Direction) -> DirectionSkill {
        if let existing = allSkills().first(where: { $0.languageCode == language.rawValue && $0.direction == direction }) {
            return existing
        }
        let created = DirectionSkill(languageCode: language.rawValue, direction: direction)
        context.insert(created)
        return created
    }

    func streakRecord() -> StreakRecord? {
        (try? context.fetch(FetchDescriptor<StreakRecord>()))?.first
    }

    private func dailyExercise(language: PracticeLanguage, direction: Direction, index: Int = 0) -> Exercise? {
        let key = DayKey.dailyKey(day: Date(), language: language, direction: direction, index: index, native: settings.nativeLanguage)
        return allExercises().first { $0.dailyKey == key }
    }

    func bindExercisesToNative() {
        let native = settings.nativeLanguage.rawValue
        var changed = false
        for exercise in allExercises() {
            if let key = exercise.dailyKey, !key.isEmpty {
                if let coded = DayKey.nativeCode(in: key) {
                    if exercise.nativeLanguageCode != coded {
                        exercise.nativeLanguageCode = coded
                        changed = true
                    }
                } else {
                    let index = DayKey.dailyIndex(in: key)
                    let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                    guard parts.count >= 3 else { continue }
                    var rebuilt = "\(parts[0])|\(parts[1])|\(parts[2])"
                    if index > 0 {
                        rebuilt += "|\(index)"
                    }
                    rebuilt += "|\(native)"
                    exercise.dailyKey = rebuilt
                    exercise.nativeLanguageCode = native
                    exercise.updatedAt = Date()
                    changed = true
                }
            } else if exercise.nativeLanguageCode.isEmpty {
                exercise.nativeLanguageCode = native
                changed = true
            }
        }
        if changed { save() }
    }

    private func submittedDailyIndices(in exercises: [Exercise], direction: Direction) -> Set<Int> {
        Set(exercises.filter { $0.direction == direction }.compactMap { exercise in
            exercise.dailyKey.map(DayKey.dailyIndex(in:))
        })
    }

    private func recentTopics(language: PracticeLanguage) -> [String] {
        allExercises()
            .filter { $0.languageCode == language.rawValue && !$0.topic.isEmpty }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(8)
            .map(\.topic)
    }

    private func topErrorTags(language: PracticeLanguage, direction: Direction) -> [String] {
        let tags = allExercises()
            .filter { $0.languageCode == language.rawValue && $0.direction == direction && $0.submitted }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(20)
            .flatMap(\.errorTags)
        var counts: [String: Int] = [:]
        for tag in tags { counts[tag, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.prefix(2).map(\.key)
    }

    func allExercises() -> [Exercise] {
        (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
    }

    func allReviewAttempts() -> [ReviewAttempt] {
        (try? context.fetch(FetchDescriptor<ReviewAttempt>())) ?? []
    }

    func allPhrases() -> [PhrasePair] {
        (try? context.fetch(FetchDescriptor<PhrasePair>())) ?? []
    }

    func allPhraseReviews() -> [PhraseReview] {
        (try? context.fetch(FetchDescriptor<PhraseReview>())) ?? []
    }

    func allSkills() -> [DirectionSkill] {
        (try? context.fetch(FetchDescriptor<DirectionSkill>())) ?? []
    }

    func allFolders() -> [FavoriteFolder] {
        (try? context.fetch(FetchDescriptor<FavoriteFolder>())) ?? []
    }

    func allItems() -> [FavoriteItem] {
        (try? context.fetch(FetchDescriptor<FavoriteItem>())) ?? []
    }

    private func children(of id: UUID) -> [UUID] {
        allFolders().filter { $0.parentID == id }.map(\.id)
    }

    func save() {
        try? context.save()
    }

    private func beginWorking() {
        workingCount += 1
        replenishTask?.cancel()
    }

    private func endWorking() {
        workingCount = max(0, workingCount - 1)
        if workingCount == 0 { scheduleReplenish() }
    }
}

private struct ReviewBundle {
    var faithfulness: Int
    var expressiveness: Int
    var elegance: Int
    var weighted: Int
    var corrected: String
    var exemplar: String
    var exemplarFaithfulness: Int
    var exemplarExpressiveness: Int
    var exemplarElegance: Int
    var exemplarWeighted: Int
    var tags: [String]

    init(payload: LLMJSON.Payload, fallbackUser: String) {
        faithfulness = ScoreMath.clamp(payload.faithfulness ?? 0)
        expressiveness = ScoreMath.clamp(payload.expressiveness ?? 0)
        elegance = ScoreMath.clamp(payload.elegance ?? 0)
        weighted = ScoreMath.weighted(faithfulness: faithfulness, expressiveness: expressiveness, elegance: elegance)
        corrected = payload.corrected?.isEmpty == false ? payload.corrected! : fallbackUser
        exemplar = payload.exemplar ?? ""
        exemplarFaithfulness = ScoreMath.clamp(payload.exemplarFaithfulness ?? 0)
        exemplarExpressiveness = ScoreMath.clamp(payload.exemplarExpressiveness ?? 0)
        exemplarElegance = ScoreMath.clamp(payload.exemplarElegance ?? 0)
        exemplarWeighted = ScoreMath.weighted(
            faithfulness: exemplarFaithfulness,
            expressiveness: exemplarExpressiveness,
            elegance: exemplarElegance
        )
        tags = Array((payload.errorTags ?? []).prefix(4))
    }

    init(grade: LLMJSON.Payload, corrected: LLMJSON.Payload, exemplar: LLMJSON.Payload, fallbackUser: String) {
        var merged = grade
        merged.corrected = corrected.corrected
        merged.exemplar = exemplar.exemplar
        merged.exemplarFaithfulness = exemplar.exemplarFaithfulness
        merged.exemplarExpressiveness = exemplar.exemplarExpressiveness
        merged.exemplarElegance = exemplar.exemplarElegance
        self.init(payload: merged, fallbackUser: fallbackUser)
    }
}
