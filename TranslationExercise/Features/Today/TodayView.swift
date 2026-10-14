import SwiftUI
import SwiftData
import TranslationCore

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Exercise.createdAt, order: .reverse) private var exercises: [Exercise]
    @Query private var skills: [DirectionSkill]
    @Query private var streaks: [StreakRecord]
    @State private var path = NavigationPath()
    @State private var placementSheet: Direction?
    @State private var showStreakCalendar = false

    var body: some View {
        NavigationStack(path: $path) {
            PageScroll(refresh: { await model.syncNow() }) { span in
                VStack(alignment: .leading, spacing: 16) {
                    streakHeader
                    dailyBoard(span)
                    if bothDone {
                        extraButtons
                    }
                }
            }
            .navigationTitle("today_title")
            .navigationDestination(for: UUID.self) { id in
                if let exercise = exercises.first(where: { $0.id == id }) {
                    destination(for: exercise)
                }
            }
            .overlay {
                if model.celebrate {
                    ConfettiView()
                }
            }
            .sheet(item: $placementSheet) { direction in
                PlacementView(direction: direction)
            }
            .sheet(isPresented: $showStreakCalendar) {
                StreakCalendarView()
            }
            .task(id: dailyRefreshID) {
                model.ensureSkills()
                await model.ensureDailyPair()
            }
            .task(id: model.celebrate) {
                guard model.celebrate else { return }
                try? await Task.sleep(for: .seconds(3))
                model.celebrate = false
            }
        }
    }

    private var streakHeader: some View {
        Button {
            showStreakCalendar = true
        } label: {
            HStack {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: String(localized: "streak_days"), streaks.first?.current ?? 0))
                        .font(.headline)
                    Text(LanguageTitle.key(model.settings.activeLanguage))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if canRepair, missedStreakDays > 0 {
                        Text(String(format: String(localized: "streak_can_repair"), missedStreakDays))
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    if let message = model.statusMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                Spacer()
                if (streaks.first?.shields ?? 0) > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<(streaks.first?.shields ?? 0), id: \.self) { _ in
                            Image(systemName: "shield.fill")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(String(format: String(localized: "streak_shield_count"), streaks.first?.shields ?? 0))
                }
                if model.isWorking {
                    ProgressView()
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .glassCard()
    }

    private var canRepair: Bool {
        guard let streak = streaks.first else { return false }
        return StreakEngine.repair(state: streak.snapshot, on: Date(), calendar: .current) != nil
    }

    private var missedStreakDays: Int {
        StreakEngine.missedDays(since: streaks.first?.lastCompletedDay, on: Date(), calendar: .current).count
    }

    private var dailyRefreshID: String {
        "\(model.settings.activeLanguageCode)|\(model.settings.nativeLanguageCode)|\(model.settings.dailyTarget(for: .zhToForeign))|\(model.settings.dailyTarget(for: .foreignToZh))"
    }

    @ViewBuilder
    private func dailyBoard(_ span: PageSpan) -> some View {
        if span == .paired {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(pairedRows, id: \.self) { index in
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(activeDirections) { direction in
                            if dailySlots(direction).contains(index) {
                                dailyCard(
                                    direction,
                                    index: index,
                                    includePlacement: index == dailySlots(direction).first,
                                    slotLabel: dailySlots(direction).count > 1 ? "\(index + 1)" : nil,
                                    stretch: true
                                )
                            } else {
                                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(activeDirections) { direction in
                    dailyDirection(direction)
                }
            }
        }
    }

    private var pairedRows: [Int] {
        Array(Set(activeDirections.flatMap { dailySlots($0) })).sorted()
    }

    @ViewBuilder
    private func dailyDirection(_ direction: Direction) -> some View {
        let slots = dailySlots(direction)
        ForEach(slots, id: \.self) { index in
            dailyCard(
                direction,
                index: index,
                includePlacement: index == slots.first,
                slotLabel: slots.count > 1 ? "\(index + 1)" : nil,
                stretch: false
            )
        }
    }

    private func dailyCard(_ direction: Direction, index: Int, includePlacement: Bool, slotLabel: String?, stretch: Bool) -> some View {
        let exercise = daily(direction, index: index)
        let skill = skills.first { $0.languageCode == model.settings.activeLanguage.rawValue && $0.direction == direction }
        let level = skill?.level ?? Difficulty.skippedLevel
        let profile = Difficulty.profile(language: model.settings.activeLanguage, level: level)
        let needsTest = includePlacement && skill?.placementDone != true
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                openDaily(exercise, direction: direction, index: index)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(model.settings.directionText(direction))
                            .font(.headline)
                        if let slotLabel {
                            Text(slotLabel)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(LocalizedStringKey(profile.usageDisplayKey))
                        .font(.subheadline)
                    Text("\(profile.examPrompt) · \(profile.vocabulary)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if needsTest {
                        Text("today_placement_body")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let exercise {
                        Text(exercise.sourceText)
                            .lineLimit(4)
                    } else if model.apiReady(for: .generate) {
                        if let message = model.statusMessage {
                            Text(message)
                                .font(.callout)
                                .foregroundStyle(.red)
                        }
                    } else {
                        Text("today_configure_api")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if stretch {
                        Spacer(minLength: 0)
                    }
                    dailyStatus(exercise)
                }
                .frame(maxWidth: .infinity, maxHeight: stretch ? .infinity : nil, alignment: .topLeading)
                .contentShape(Rectangle())
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: stretch ? .infinity : nil, alignment: .topLeading)

            if needsTest {
                HStack {
                    Button("placement_start") {
                        placementSheet = direction
                        Task { await model.startPlacement(direction: direction) }
                    }
                    .glassButton(prominent: true)
                    Button("placement_skip") { model.skipPlacement(direction: direction) }
                        .glassButton(prominent: false)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: stretch ? .infinity : nil, alignment: .topLeading)
        .glassCard()
    }

    @ViewBuilder
    private func dailyStatus(_ exercise: Exercise?) -> some View {
        if let exercise, exercise.submitted {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(exercise.weightedScore)")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                HStack {
                    componentScore("review_faith", exercise.faithfulness)
                    componentScore("review_express", exercise.expressiveness)
                    componentScore("review_elegance", exercise.elegance)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            Label {
                Text("history_unfinished")
            } icon: {
                Image(systemName: "circle.dashed")
                    .foregroundStyle(Color.accentColor)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
        }
    }

    private func componentScore(_ title: LocalizedStringKey, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openDaily(_ exercise: Exercise?, direction: Direction, index: Int) {
        if let exercise {
            path.append(exercise.id)
        } else if model.apiReady(for: .generate) {
            Task { await openGenerated(direction, index: index) }
        }
    }

    private var extraButtons: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("today_both_done")
                .font(.headline)
            Text("today_extra_prompt")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                ForEach(Direction.allCases.filter { model.settings.dailyTarget(for: $0) > 0 }) { direction in
                    Button(model.settings.directionText(direction)) {
                        Task {
                            if let exercise = await model.generateExtra(direction: direction) {
                                path.append(exercise.id)
                            }
                        }
                    }
                    .glassButton(prominent: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var bothDone: Bool {
        DailyQuota.requirementsMet(
            nativeToPractice: submittedIndices(.zhToForeign),
            practiceToNative: submittedIndices(.foreignToZh),
            nativeToPracticeTarget: model.settings.dailyTarget(for: .zhToForeign),
            practiceToNativeTarget: model.settings.dailyTarget(for: .foreignToZh)
        )
    }

    private func openGenerated(_ direction: Direction, index: Int) async {
        model.statusMessage = nil
        do {
            let created = try await model.generate(
                language: model.settings.activeLanguage,
                direction: direction,
                kind: .daily,
                dailyIndex: index
            )
            path.append(created.id)
        } catch {
            model.statusMessage = error.localizedDescription
        }
    }

    private var activeDirections: [Direction] {
        let listed = Direction.allCases.filter { direction in
            model.settings.dailyTarget(for: direction) > 0 || todaysDailies(direction).contains(where: \.submitted)
        }
        return listed
    }

    private func dailySlots(_ direction: Direction) -> [Int] {
        let target = model.settings.dailyTarget(for: direction)
        var slots = Set(target > 0 ? Array(0..<target) : [])
        for exercise in todaysDailies(direction) where exercise.submitted {
            let index = DayKey.dailyIndex(in: exercise.dailyKey ?? "")
            if index >= target {
                slots.insert(index)
            }
        }
        return slots.sorted()
    }

    private func submittedIndices(_ direction: Direction) -> Set<Int> {
        Set(todaysDailies(direction).filter(\.submitted).map { DayKey.dailyIndex(in: $0.dailyKey ?? "") })
    }

    private func todaysDailies(_ direction: Direction) -> [Exercise] {
        exercises.filter { exercise in
            exercise.kind == .daily && DayKey.matches(
                exercise.dailyKey ?? "",
                day: Date(),
                language: model.settings.activeLanguage,
                direction: direction,
                native: model.settings.nativeLanguage
            )
        }
    }

    private func daily(_ direction: Direction, index: Int) -> Exercise? {
        let key = DayKey.dailyKey(day: Date(), language: model.settings.activeLanguage, direction: direction, index: index, native: model.settings.nativeLanguage)
        return exercises.first { $0.dailyKey == key && $0.kind == .daily }
    }

    @ViewBuilder
    private func destination(for exercise: Exercise) -> some View {
        if exercise.submitted {
            ReviewView(exercise: exercise)
        } else {
            PracticeView(exercise: exercise)
        }
    }

}
