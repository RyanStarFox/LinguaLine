import SwiftUI
import SwiftData
import TranslationCore

enum HistoryRange: String, CaseIterable, Identifiable {
    case all
    case week
    case month
    case quarter
    var id: String { rawValue }

    func contains(_ date: Date, now: Date = Date()) -> Bool {
        switch self {
        case .all: return true
        case .week: return date >= now.addingTimeInterval(-7 * 86_400)
        case .month: return date >= now.addingTimeInterval(-30 * 86_400)
        case .quarter: return date >= now.addingTimeInterval(-90 * 86_400)
        }
    }
}

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Exercise.createdAt, order: .reverse) private var exercises: [Exercise]
    @Query private var reviewAttempts: [ReviewAttempt]
    @State private var query = ""
    @State private var direction: Direction?
    @State private var range: HistoryRange = .all
    @State private var sort: ScoreSort = .newest
    @State private var band: ScoreBand = .all
    @State private var confirmOlder = false
    @State private var showCustomDate = false
    @State private var olderCutoff = Date().addingTimeInterval(-30 * 86_400)
    @State private var openedID: UUID?

    var body: some View {
        NavigationStack {
            historyList
                .navigationDestination(item: $openedID) { id in
                    HistoryExercisePage(exerciseID: id)
                }
        }
    }

    private var historyList: some View {
        List {
            ForEach(visible) { exercise in
                let answers = answers(for: exercise)
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        openedID = exercise.id
                    } label: {
                        historyRow(exercise, latest: answers.first)
                    }
                    .buttonStyle(.plain)
                    if answers.count > 1 {
                        DisclosureGroup {
                            ForEach(Array(answers.dropFirst())) { answer in
                                historyAnswerLine(answer)
                            }
                        } label: {
                            Text("history_earlier")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .swipeActions {
                    Button("common_delete", role: .destructive) {
                        model.deleteExercise(exercise)
                    }
                }
            }
        }
        .refreshable { await model.syncNow() }
        .navigationTitle("tab_history")
        .searchable(text: $query, prompt: Text("history_search"))
        .toolbar { filterMenu }
        .overlay {
            if visible.isEmpty {
                ContentUnavailableView("history_empty", systemImage: "clock")
            }
        }
        .confirmationDialog("history_confirm_older", isPresented: $confirmOlder) {
            Button("history_days_7", role: .destructive) { model.deleteExercises(before: Date().addingTimeInterval(-7 * 86_400)) }
            Button("history_days_30", role: .destructive) { model.deleteExercises(before: Date().addingTimeInterval(-30 * 86_400)) }
            Button("history_days_90", role: .destructive) { model.deleteExercises(before: Date().addingTimeInterval(-90 * 86_400)) }
            Button("history_custom") {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    showCustomDate = true
                }
            }
            Button("common_cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCustomDate) {
            NavigationStack {
                DatePicker("history_custom", selection: $olderCutoff, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(20)
                    .navigationTitle("history_custom")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common_cancel") { showCustomDate = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("common_delete", role: .destructive) {
                                model.deleteExercises(before: olderCutoff)
                                showCustomDate = false
                            }
                        }
                    }
            }
            #if os(iOS)
            .presentationDetents([.medium, .large])
            #endif
        }
    }

    private func historyRow(_ exercise: Exercise, latest: HistoryAnswer?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.sourceText)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let latest {
                Text(latest.userText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            HStack(alignment: .center, spacing: 8) {
                metaTag(model.settings.directionText(exercise.direction))
                if let latest {
                    Text(latest.first ? "history_answer_first" : "history_answer_review")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let latest {
                    Text("\(latest.score)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .layoutPriority(1)
                } else {
                    Text("history_unfinished")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .layoutPriority(1)
                }
            }
            Text((latest?.date ?? exercise.createdAt), format: .dateTime.year().month().day())
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func historyAnswerLine(_ answer: HistoryAnswer) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(answer.first ? "history_answer_first" : "history_answer_review")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(answer.date, format: .dateTime.year().month().day())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 8)
                Text("\(answer.score)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
            Text(answer.userText)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func answers(for exercise: Exercise) -> [HistoryAnswer] {
        var items: [HistoryAnswer] = []
        if exercise.submitted {
            items.append(HistoryAnswer(
                id: exercise.id,
                date: exercise.createdAt,
                first: true,
                userText: exercise.userText,
                score: exercise.weightedScore
            ))
        }
        items += reviewAttempts.filter { $0.exerciseID == exercise.id }.map { attempt in
            HistoryAnswer(
                id: attempt.id,
                date: attempt.createdAt,
                first: false,
                userText: attempt.userText,
                score: attempt.weightedScore
            )
        }
        return items.sorted { $0.date > $1.date }
    }

    private func metaTag(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }

    private var visible: [Exercise] {
        let rows = exercises.filter { exercise in
            exercise.kind != .ready
                && range.contains(exercise.createdAt)
                && (direction == nil || exercise.direction == direction)
                && band.matches(score: answers(for: exercise).first?.score)
                && matches(exercise)
        }
        return ScoreList.ordered(rows, sort: sort, date: { answers(for: $0).first?.date ?? $0.createdAt }, score: { answers(for: $0).first?.score })
    }

    private func matches(_ exercise: Exercise) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.isEmpty { return true }
        return exercise.sourceText.localizedCaseInsensitiveContains(needle)
            || exercise.userText.localizedCaseInsensitiveContains(needle)
            || exercise.exemplarText.localizedCaseInsensitiveContains(needle)
            || exercise.correctedText.localizedCaseInsensitiveContains(needle)
            || reviewAttempts.contains { attempt in
                attempt.exerciseID == exercise.id
                    && (attempt.userText.localizedCaseInsensitiveContains(needle)
                        || attempt.correctedText.localizedCaseInsensitiveContains(needle))
            }
    }

    @ToolbarContentBuilder
    private var filterMenu: some ToolbarContent {
        ToolbarItem {
            Menu {
                Picker("history_direction", selection: $direction) {
                    Text("history_all").tag(Optional<Direction>.none)
                    Text(model.settings.directionText(.zhToForeign)).tag(Optional(Direction.zhToForeign))
                    Text(model.settings.directionText(.foreignToZh)).tag(Optional(Direction.foreignToZh))
                }
                Picker("history_range", selection: $range) {
                    Text("history_range_all").tag(HistoryRange.all)
                    Text("history_range_7").tag(HistoryRange.week)
                    Text("history_range_30").tag(HistoryRange.month)
                    Text("history_range_90").tag(HistoryRange.quarter)
                }
                Picker("history_score", selection: $band) {
                    Text("history_score_all").tag(ScoreBand.all)
                    Text("history_score_90").tag(ScoreBand.from90)
                    Text("history_score_80").tag(ScoreBand.from80)
                    Text("history_score_70").tag(ScoreBand.from70)
                    Text("history_score_under70").tag(ScoreBand.under70)
                }
                Picker("history_sort", selection: $sort) {
                    Text("history_sort_new").tag(ScoreSort.newest)
                    Text("history_sort_old").tag(ScoreSort.oldest)
                    Text("history_sort_score_high").tag(ScoreSort.high)
                    Text("history_sort_score_low").tag(ScoreSort.low)
                }
                Button("history_delete_older") { confirmOlder = true }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
    }
}

private struct HistoryAnswer: Identifiable {
    var id: UUID
    var date: Date
    var first: Bool
    var userText: String
    var score: Int
}

private struct HistoryExercisePage: View {
    var exerciseID: UUID
    @Query private var exercises: [Exercise]

    var body: some View {
        if let exercise = exercises.first(where: { $0.id == exerciseID }) {
            HistoryExerciseContent(exercise: exercise)
        } else {
            ContentUnavailableView("history_missing", systemImage: "doc")
        }
    }
}

private struct HistoryExerciseContent: View {
    @Bindable var exercise: Exercise

    var body: some View {
        if exercise.submitted {
            ReviewView(exercise: exercise, foldsAnswers: true)
        } else {
            PracticeView(exercise: exercise)
        }
    }
}
