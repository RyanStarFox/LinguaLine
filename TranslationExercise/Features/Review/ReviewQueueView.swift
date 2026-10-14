import SwiftUI
import SwiftData
import TranslationCore

struct ReviewQueueView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query private var exercises: [Exercise]
    @Query private var attempts: [ReviewAttempt]
    @Query private var phrases: [PhrasePair]
    @Query private var phraseReviews: [PhraseReview]
    @State private var screen: ReviewScreen?
    @State private var listKind: ReviewListKind = .sentences

    private enum ReviewScreen: Hashable {
        case practice(UUID)
        case graded(UUID)
        case phrase(UUID)
    }

    private enum ReviewListKind: String, CaseIterable, Identifiable {
        case sentences
        case phrases

        var id: String { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .sentences: "phrase_sentences"
            case .phrases: "phrase_phrases"
            }
        }
    }

    var body: some View {
        NavigationStack {
            queueList
                .navigationDestination(item: $screen) { screen in
                    screenView(screen)
                }
        }
    }

    private var usesColumns: Bool {
        #if os(macOS)
        true
        #else
        sizeClass != .compact
        #endif
    }

    private var queueList: some View {
        let panels = Group {
            if usesColumns {
                HStack(spacing: 0) {
                    queueColumn(.zhToForeign)
                    Divider()
                    queueColumn(.foreignToZh)
                }
            } else {
                VStack(spacing: 0) {
                    queueColumn(.zhToForeign)
                    Divider()
                    queueColumn(.foreignToZh)
                }
            }
        }
        return panels
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("tab_review")
            .toolbar {
                if screen == nil {
                    Picker("tab_review", selection: $listKind) {
                        ForEach(ReviewListKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .refreshable { await model.syncNow() }
    }

    @ViewBuilder
    private func queueColumn(_ direction: Direction) -> some View {
        if listKind == .phrases {
            phraseColumn(direction)
        } else {
            sentenceColumn(direction)
        }
    }

    private func sentenceColumn(_ direction: Direction) -> some View {
        let items = dueItems(direction)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(model.settings.directionText(direction))
                    .font(.headline)
                Spacer(minLength: 8)
                Text("\(items.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()
            if items.isEmpty {
                Text("review_queue_empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { item in
                            Button {
                                screen = .practice(item.exerciseID)
                            } label: {
                                queueRow(item)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func phraseColumn(_ direction: Direction) -> some View {
        let items = duePhrases(direction)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(model.settings.directionText(direction))
                    .font(.headline)
                Spacer(minLength: 8)
                Text("\(items.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()
            if items.isEmpty {
                Text("phrase_empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { item in
                            Button {
                                screen = .phrase(item.phraseID)
                            } label: {
                                Text(phrases.first { $0.id == item.phraseID }?.promptText ?? "")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func queueRow(_ item: ReviewDueItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercises.first { $0.id == item.exerciseID }?.sourceText ?? "")
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            HStack {
                Text(item.dueDay, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text("\(item.lastScore)")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func screenView(_ screen: ReviewScreen) -> some View {
        switch screen {
        case .practice(let id):
            if let exercise = exercises.first(where: { $0.id == id }) {
                PracticeView(exercise: exercise) { attemptID in
                    self.screen = .graded(attemptID)
                }
            } else {
                ContentUnavailableView("history_missing", systemImage: "doc")
            }
        case .graded(let id):
            if let attempt = attempts.first(where: { $0.id == id }),
               let exercise = exercises.first(where: { $0.id == attempt.exerciseID }) {
                ReviewGradeView(exercise: exercise, attempt: attempt)
            } else {
                ContentUnavailableView("history_missing", systemImage: "doc")
            }
        case .phrase(let id):
            if let phrase = phrases.first(where: { $0.id == id }) {
                PhrasePracticeView(phrase: phrase) {
                    self.screen = nil
                }
            } else {
                ContentUnavailableView("history_missing", systemImage: "doc")
            }
        }
    }

    private func dueItems(_ direction: Direction) -> [ReviewDueItem] {
        let sources = exercises.map { exercise in
            ReviewSource(
                id: exercise.id,
                direction: exercise.direction,
                languageCode: exercise.languageCode,
                kind: exercise.kind,
                submitted: exercise.submitted,
                submittedAt: exercise.updatedAt == .distantPast ? exercise.createdAt : exercise.updatedAt,
                weightedScore: exercise.weightedScore
            )
        }
        let marks = attempts.map { attempt in
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
        return ReviewSchedule.dueItems(
            sources: sources,
            marks: marks,
            direction: direction,
            languageCode: model.settings.activeLanguage.rawValue,
            today: Date(),
            calendar: .current,
            policy: model.settings.reviewPolicy
        )
    }

    private func duePhrases(_ direction: Direction) -> [PhraseDueItem] {
        let sources = phrases.map { phrase in
            PhraseSource(
                id: phrase.id,
                direction: phrase.direction,
                languageCode: phrase.languageCode,
                createdAt: phrase.createdAt
            )
        }
        let marks = phraseReviews.map { review in
            PhraseReviewMark(
                id: review.id,
                phraseID: review.phraseID,
                reviewedAt: review.createdAt,
                remembered: review.remembered,
                intervalDays: review.intervalDays,
                dueDay: review.dueDay
            )
        }
        return PhraseSchedule.dueItems(
            phrases: sources,
            marks: marks,
            direction: direction,
            languageCode: model.settings.activeLanguage.rawValue,
            today: Date(),
            calendar: .current
        )
    }
}

private struct ReviewGradeView: View {
    @Environment(AppModel.self) private var model
    var exercise: Exercise
    var attempt: ReviewAttempt

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LookupPassage(exercise: exercise, text: exercise.sourceText)
                    .promptSurface()
                VStack(alignment: .leading, spacing: 8) {
                    Text("review_this_score")
                        .font(.headline)
                    Text("\(attempt.weightedScore)")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                    HStack {
                        component("review_faith", attempt.faithfulness)
                        component("review_express", attempt.expressiveness)
                        component("review_elegance", attempt.elegance)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
                VStack(alignment: .leading, spacing: 8) {
                    Text("review_corrected")
                        .font(.headline)
                    DiffText(user: attempt.userText, corrected: attempt.correctedText, notes: attempt.storedEditNotes())
                    if model.explainingID == attempt.id {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("ai_explaining")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if model.explainFailedID == attempt.id, let message = model.explainMessage, attempt.storedEditNotes().isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
                VStack(alignment: .leading, spacing: 8) {
                    Text("review_exemplar")
                        .font(.headline)
                    LookupPassage(exercise: exercise, text: exercise.exemplarText)
                    Text("review_exemplar_score")
                        .font(.headline)
                    Text("\(exercise.exemplarWeightedScore)")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                    Text("review_weights")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        component("review_faith", exercise.exemplarFaithfulness)
                        component("review_express", exercise.exemplarExpressiveness)
                        component("review_elegance", exercise.exemplarElegance)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            }
            .padding(20)
            .pageColumn()
        }
        .navigationTitle("tab_review")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            #if os(iOS)
            GlossBar()
            #endif
        }
    }

    private func component(_ title: LocalizedStringKey, _ value: Int) -> some View {
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

private struct PhrasePracticeView: View {
    @Environment(AppModel.self) private var model
    var phrase: PhrasePair
    var onDone: () -> Void
    @State private var draft = ""
    @State private var revealed = false
    @FocusState private var writing: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(phrase.promptText)
                    .font(.title3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .promptSurface()
                if revealed {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("phrase_yours")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : draft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("phrase_answer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(phrase.answerText)
                            .font(.title3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                    HStack(spacing: 12) {
                        Button("phrase_right") { finish(true) }
                            .glassButton(prominent: true)
                            .keyboardShortcut(KeyEquivalent("1"), modifiers: [])
                        Button("phrase_wrong") { finish(false) }
                            .glassButton(prominent: false)
                            .keyboardShortcut(KeyEquivalent("2"), modifiers: [])
                    }
                } else {
                    TextField("phrase_answer", text: $draft, axis: .vertical)
                        .lineLimit(3...8)
                        .textFieldStyle(.plain)
                        .focused($writing)
                        .onKeyPress(.return) {
                            revealed = true
                            return .handled
                        }
                        .glassCard()
                    Button("phrase_complete") { revealed = true }
                        .glassButton(prominent: true)
                }
            }
            .padding(20)
            .pageColumn()
        }
        .navigationTitle("phrase_phrases")
        .onAppear { writing = true }
    }

    private func finish(_ remembered: Bool) {
        model.gradePhrase(phrase, remembered: remembered)
        onDone()
    }
}
