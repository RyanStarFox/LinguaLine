import SwiftUI
import SwiftData
import TranslationCore

struct ReviewView: View {
    @Environment(AppModel.self) private var model
    var exercise: Exercise
    var foldsAnswers = false
    @Query(sort: \ReviewAttempt.createdAt, order: .forward) private var attempts: [ReviewAttempt]
    @Query private var phrases: [PhrasePair]
    @State private var saved = false
    @State private var pickingPhrase = false
    @State private var promptDraft = ""
    @State private var answerDraft = ""
    @State private var promptSelection = ""
    @State private var answerSelection = ""

    var body: some View {
        PageScroll { span in
            if span == .paired {
                HStack(alignment: .top, spacing: 16) {
                    correctionColumn
                    exemplarColumn
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    correctionColumn
                    exemplarColumn
                }
            }
        }
        .navigationTitle("review_total")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if pickingPhrase {
                phraseBar
            } else {
                #if os(iOS)
                GlossBar()
                #endif
            }
        }
        .onChange(of: promptSelection) { _, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { promptDraft = trimmed }
        }
        .onChange(of: answerSelection) { _, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { answerDraft = trimmed }
        }
    }

    private var correctionColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            sourcePassage
            if foldsAnswers {
                if pickingPhrase {
                    correctedCard
                }
                answerLog
            } else {
                scoreBlock(
                    title: "review_total",
                    total: exercise.weightedScore,
                    faith: exercise.faithfulness,
                    express: exercise.expressiveness,
                    elegance: exercise.elegance
                )
                .glassCard()
                if !exercise.errorTags.isEmpty {
                    FlowTags(tags: exercise.errorTags)
                }
                correctedCard
            }
            HStack(spacing: 8) {
                Button(pickingPhrase ? "phrase_done" : "phrase_pick") {
                    pickingPhrase.toggle()
                    if pickingPhrase {
                        model.clearGloss()
                    }
                }
                .glassButton(prominent: false)
                .disabled(model.isWorking)
                Button("review_regrade") {
                    Task { await model.regrade(exercise: exercise) }
                }
                .glassButton(prominent: false)
                .disabled(model.isWorking)
            }
            savedPhrases
            if model.isWorking {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(model.workCaption ?? String(localized: "ai_grading"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let message = model.statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var exemplarColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("review_exemplar")
                    .font(.headline)
                LookupPassage(exercise: exercise, text: exercise.exemplarText)
                scoreBlock(
                    title: "review_exemplar_score",
                    total: exercise.exemplarWeightedScore,
                    faith: exercise.exemplarFaithfulness,
                    express: exercise.exemplarExpressiveness,
                    elegance: exercise.exemplarElegance
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
            if !foldsAnswers, !exerciseAttempts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("tab_review")
                        .font(.headline)
                    ForEach(exerciseAttempts) { attempt in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(attempt.createdAt, format: .dateTime.year().month().day())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(attempt.userText)
                            Text("\(attempt.weightedScore)")
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                            HStack {
                                scoreChip("review_faith", attempt.faithfulness)
                                scoreChip("review_express", attempt.expressiveness)
                                scoreChip("review_elegance", attempt.elegance)
                            }
                            if !attempt.correctedText.isEmpty {
                                Text("review_corrected")
                                    .font(.subheadline)
                                Text(attempt.correctedText)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            }
            Button(saved ? "review_saved" : "review_favorite") {
                model.favorite(exercise)
                saved = true
            }
            .glassButton(prominent: true)
            .disabled(saved)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var correctedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("review_corrected")
                .font(.headline)
            if pickingPhrase {
                Text("phrase_answer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PassageText(text: exercise.correctedText, selection: $answerSelection, minimumHeight: 44)
            } else {
                DiffText(user: exercise.userText, corrected: exercise.correctedText, notes: exercise.storedEditNotes())
            }
            editStatus(id: exercise.id, notes: exercise.storedEditNotes())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var loggedAnswers: [LoggedAnswer] {
        var items = [
            LoggedAnswer(
                id: exercise.id,
                date: exercise.createdAt,
                first: true,
                userText: exercise.userText,
                correctedText: exercise.correctedText,
                score: exercise.weightedScore,
                faith: exercise.faithfulness,
                express: exercise.expressiveness,
                elegance: exercise.elegance,
                notes: exercise.storedEditNotes(),
                explainID: exercise.id
            )
        ]
        items += exerciseAttempts.map { attempt in
            LoggedAnswer(
                id: attempt.id,
                date: attempt.createdAt,
                first: false,
                userText: attempt.userText,
                correctedText: attempt.correctedText,
                score: attempt.weightedScore,
                faith: attempt.faithfulness,
                express: attempt.expressiveness,
                elegance: attempt.elegance,
                notes: attempt.storedEditNotes(),
                explainID: attempt.id
            )
        }
        return items.sorted { $0.date > $1.date }
    }

    @ViewBuilder
    private var answerLog: some View {
        let answers = loggedAnswers
        if let latest = answers.first {
            answerCard(latest)
            if answers.count > 1 {
                DisclosureGroup {
                    ForEach(Array(answers.dropFirst())) { answer in
                        answerCard(answer)
                    }
                } label: {
                    Text("history_earlier")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private func answerCard(_ answer: LoggedAnswer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(answer.first ? "history_answer_first" : "history_answer_review")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                Text(answer.date, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text("\(answer.score)")
                    .font(.title2.weight(.semibold).monospacedDigit())
            }
            Text(answer.userText)
            HStack {
                scoreChip("review_faith", answer.faith)
                scoreChip("review_express", answer.express)
                scoreChip("review_elegance", answer.elegance)
            }
            if !answer.correctedText.isEmpty {
                DiffText(user: answer.userText, corrected: answer.correctedText, notes: answer.notes)
                editStatus(id: answer.explainID, notes: answer.notes)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    @ViewBuilder
    private var sourcePassage: some View {
        if pickingPhrase {
            VStack(alignment: .leading, spacing: 6) {
                Text("phrase_prompt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PassageText(text: exercise.sourceText, selection: $promptSelection, minimumHeight: 44)
            }
            .promptSurface()
        } else {
            LookupPassage(exercise: exercise, text: exercise.sourceText)
                .promptSurface()
        }
    }

    private var phraseBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("phrase_pick_hint")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("phrase_prompt", text: $promptDraft, axis: .vertical)
                .textFieldStyle(.plain)
            TextField("phrase_answer", text: $answerDraft, axis: .vertical)
                .textFieldStyle(.plain)
            Button("phrase_save") {
                model.savePhrase(exercise: exercise, prompt: promptDraft, answer: answerDraft)
                promptDraft = ""
                answerDraft = ""
                promptSelection = ""
                answerSelection = ""
            }
            .glassButton(prominent: true)
            .disabled(promptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || answerDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var savedPhrases: some View {
        let saved = phrases.filter { $0.exerciseID == exercise.id }.sorted { $0.createdAt > $1.createdAt }
        if !saved.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("phrase_saved")
                    .font(.headline)
                ForEach(saved) { phrase in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(phrase.promptText)
                            Text(phrase.answerText)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Button("common_delete", systemImage: "trash") {
                            model.deletePhrase(phrase)
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }

    @ViewBuilder
    private func editStatus(id: UUID, notes: [EditHunk]) -> some View {
        if model.explainingID == id {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("ai_explaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if model.explainFailedID == id, let message = model.explainMessage, notes.isEmpty {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    private var exerciseAttempts: [ReviewAttempt] {
        attempts.filter { $0.exerciseID == exercise.id }
    }

    private func scoreBlock(title: LocalizedStringKey, total: Int, faith: Int, express: Int, elegance: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text("\(total)")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
            Text("review_weights")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                scoreChip("review_faith", faith)
                scoreChip("review_express", express)
                scoreChip("review_elegance", elegance)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scoreChip(_ title: LocalizedStringKey, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LoggedAnswer: Identifiable {
    var id: UUID
    var date: Date
    var first: Bool
    var userText: String
    var correctedText: String
    var score: Int
    var faith: Int
    var express: Int
    var elegance: Int
    var notes: [EditHunk]
    var explainID: UUID
}

private struct FlowTags: View {
    var tags: [String]

    var body: some View {
        HStack {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
        }
    }
}

