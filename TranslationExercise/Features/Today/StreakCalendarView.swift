import SwiftUI
import SwiftData
import TranslationCore

private enum CalendarScope: String, CaseIterable, Identifiable {
    case month
    case week
    var id: String { rawValue }
}

struct StreakCalendarView: View {
    var embedded: Bool = false

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query private var streaks: [StreakRecord]
    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]
    @State private var scope: CalendarScope = .month
    @State private var month = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summary
                    Picker("streak_calendar_title", selection: $scope) {
                        Text("streak_view_month").tag(CalendarScope.month)
                        Text("streak_view_week").tag(CalendarScope.week)
                    }
                    .pickerStyle(.segmented)
                    legend
                    if scope == .month {
                        monthCard
                    } else {
                        weekCards
                    }
                }
                .padding(20)
                .pageColumn()
            }
            .navigationTitle("streak_calendar_title")
            .toolbar {
                if !embedded {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common_done") { dismiss() }
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: String(localized: "streak_days"), streaks.first?.current ?? 0))
                    .font(.title2.weight(.semibold))
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<StreakEngine.shieldCap, id: \.self) { index in
                        Image(systemName: index < shieldCount ? "shield.fill" : "shield")
                            .foregroundStyle(index < shieldCount ? Color.accentColor : Color.secondary)
                    }
                }
                .font(.title3)
                .accessibilityLabel(String(format: String(localized: "streak_shield_count"), shieldCount))
            }
            Text("streak_shield_rule")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if model.streakCanRepair() {
                Text("streak_repair_hint")
                    .font(.subheadline)
                Button("streak_use_shield") {
                    model.repairStreak()
                }
                .glassButton(prominent: true)
                if bothDoneToday {
                    Button("streak_decline_repair") {
                        model.declineStreakRepair()
                    }
                    .glassButton(prominent: false)
                }
            } else if missedCount > 0 {
                Text(String(format: String(localized: "streak_gap_unrepairable"), missedCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(color: Color.accentColor.opacity(0.22), title: "streak_legend_done")
            legendItem(color: Color.primary.opacity(0.08), title: "streak_legend_partial")
            legendItem(color: Color.orange.opacity(0.18), title: "streak_legend_shield")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendItem(color: Color, title: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 14)
            Text(title)
        }
    }

    private var monthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                Spacer()
                VStack(spacing: 2) {
                    Text(month.formatted(.dateTime.year().month()))
                        .font(.headline)
                    if let average = monthAverage {
                        Text(String(format: String(localized: "streak_month_average"), average))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("streak_no_average")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(isCurrentMonth)
            }
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                    dayCell(date)
                }
            }
        }
        .glassCard()
    }

    private var weekCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(weekStarts, id: \.self) { start in
                weekCard(start)
            }
        }
    }

    private func weekCard(_ start: Date) -> some View {
        let days = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
        let scores = days.flatMap { dayStats[DayKey.string(from: $0)].map(\.scores) ?? [] }
        let end = days.last ?? start
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(weekTitle(start, end))
                    .font(.headline)
                Spacer()
                if let average = ScoreAverage.mean(scores) {
                    Text(String(format: String(localized: "streak_week_average"), average))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.self) { date in
                    dayCell(date)
                }
            }
        }
        .glassCard()
    }

    private func dayCell(_ date: Date?) -> some View {
        let stat = date.flatMap { dayStats[DayKey.string(from: $0)] }
        let today = date.map { Calendar.current.isDateInToday($0) } ?? false
        let future = date.map { Calendar.current.startOfDay(for: $0) > Calendar.current.startOfDay(for: Date()) } ?? false
        return VStack(spacing: 2) {
            if let date {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.caption.weight(.semibold))
                if let average = stat?.average {
                    Text("\(average)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else if stat?.shielded == true {
                    Image(systemName: "shield.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Color.clear.frame(height: 11)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .foregroundStyle(future ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
        .background(cellFill(stat, day: date.map { DayKey.string(from: $0) }), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            if today {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
            }
        }
    }

    private func cellFill(_ stat: DayStat?, day: String?) -> Color {
        guard let stat else { return .clear }
        if let day, quotaMet(on: day) {
            return Color.accentColor.opacity(0.22)
        }
        if stat.shielded && stat.scores.isEmpty {
            return Color.orange.opacity(0.18)
        }
        if !stat.scores.isEmpty || stat.streakDirections > 0 {
            return Color.primary.opacity(0.08)
        }
        return .clear
    }

    private var dayStats: [String: DayStat] {
        let language = model.settings.activeLanguage.rawValue
        let shielded = Set(streaks.first?.shieldedDayKeys ?? [])
        var directions: [String: Set<String>] = [:]
        var scores: [String: [Int]] = [:]
        for exercise in exercises where exercise.submitted && exercise.languageCode == language && exercise.kind != .ready {
            let key = Self.dayKey(for: exercise)
            if exercise.kind == .daily {
                directions[key, default: []].insert(exercise.directionRaw)
            }
            scores[key, default: []].append(exercise.weightedScore)
        }
        var keys = Set(scores.keys)
        keys.formUnion(shielded)
        var result: [String: DayStat] = [:]
        for key in keys {
            result[key] = DayStat(
                streakDirections: directions[key]?.count ?? 0,
                scores: scores[key] ?? [],
                shielded: shielded.contains(key)
            )
        }
        return result
    }

    private var monthCells: [Date?] {
        CalendarLayout.monthCells(containing: month, calendar: .current)
    }

    private var weekStarts: [Date] {
        CalendarLayout.recentWeeks(ending: Date(), count: 3, calendar: .current)
    }

    private var weekdaySymbols: [String] {
        let symbols = Calendar.current.shortWeekdaySymbols
        let first = max(0, Calendar.current.firstWeekday - 1)
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private var monthAverage: Int? {
        let parts = Calendar.current.dateComponents([.year, .month], from: month)
        let prefix = String(format: "%04d-%02d-", parts.year ?? 0, parts.month ?? 0)
        let scores = dayStats.filter { $0.key.hasPrefix(prefix) }.flatMap(\.value.scores)
        return ScoreAverage.mean(scores)
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private var shieldCount: Int {
        min(StreakEngine.shieldCap, streaks.first?.shields ?? 0)
    }

    private var missedCount: Int {
        StreakEngine.missedDays(since: streaks.first?.lastCompletedDay, on: Date(), calendar: .current).count
    }

    private var bothDoneToday: Bool {
        quotaMet(on: DayKey.string(from: Date()))
    }

    private func quotaMet(on day: String) -> Bool {
        DailyQuota.requirementsMet(
            nativeToPractice: submittedIndices(on: day, direction: .zhToForeign),
            practiceToNative: submittedIndices(on: day, direction: .foreignToZh),
            nativeToPracticeTarget: model.settings.dailyTarget(for: .zhToForeign),
            practiceToNativeTarget: model.settings.dailyTarget(for: .foreignToZh)
        )
    }

    private func submittedIndices(on day: String, direction: Direction) -> Set<Int> {
        let language = model.settings.activeLanguage.rawValue
        return Set(exercises.compactMap { exercise -> Int? in
            guard exercise.kind == .daily, exercise.submitted, exercise.languageCode == language, exercise.direction == direction else { return nil }
            guard Self.dayKey(for: exercise) == day, let key = exercise.dailyKey else { return nil }
            return DayKey.dailyIndex(in: key)
        })
    }

    private func shiftMonth(_ value: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: value, to: month) else { return }
        if value > 0 && Calendar.current.compare(next, to: Date(), toGranularity: .month) == .orderedDescending {
            return
        }
        month = next
    }

    private func weekTitle(_ start: Date, _ end: Date) -> String {
        let left = start.formatted(.dateTime.month().day())
        let right = end.formatted(.dateTime.month().day())
        return "\(left) – \(right)"
    }

    private static func dayKey(for exercise: Exercise) -> String {
        if let dailyKey = exercise.dailyKey {
            let prefix = dailyKey.split(separator: "|", maxSplits: 1).first.map(String.init) ?? ""
            if prefix.count == 10 { return prefix }
        }
        return DayKey.string(from: exercise.createdAt)
    }
}
