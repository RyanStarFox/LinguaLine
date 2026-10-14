import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers
import TranslationCore

enum StatsBlock: String, Codable, CaseIterable, Identifiable {
    case overview
    case directions
    case levels
    case scores
    case trend
    case tokens
    case recent

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .overview: "stats_block_overview"
        case .directions: "stats_block_directions"
        case .levels: "stats_block_levels"
        case .scores: "stats_block_scores"
        case .trend: "stats_block_trend"
        case .tokens: "stats_block_tokens"
        case .recent: "stats_block_recent"
        }
    }
}

struct StatsLayout: Codable, Equatable {
    struct Item: Codable, Equatable, Identifiable {
        var id: StatsBlock
        var shown: Bool
        var columns: Int

        init(id: StatsBlock, shown: Bool, columns: Int = 1) {
            self.id = id
            self.shown = shown
            self.columns = columns
        }

        private enum CodingKeys: String, CodingKey {
            case id, shown, columns
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(StatsBlock.self, forKey: .id)
            shown = try container.decodeIfPresent(Bool.self, forKey: .shown) ?? true
            columns = try container.decodeIfPresent(Int.self, forKey: .columns) ?? 1
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(shown, forKey: .shown)
            try container.encode(columns, forKey: .columns)
        }
    }

    struct Band: Identifiable {
        var id: String
        var blocks: [StatsBlock]
    }

    var items: [Item]

    static let standardWide = StatsLayout(items: [
        Item(id: .overview, shown: true, columns: 1),
        Item(id: .directions, shown: true, columns: 1),
        Item(id: .levels, shown: true, columns: 2),
        Item(id: .scores, shown: true, columns: 2),
        Item(id: .trend, shown: true, columns: 2),
        Item(id: .tokens, shown: true, columns: 2),
        Item(id: .recent, shown: true, columns: 2),
    ])

    static let standardNarrow = StatsLayout(items: StatsBlock.allCases.map { Item(id: $0, shown: true, columns: 1) })

    var visible: [StatsBlock] {
        items.filter(\.shown).map(\.id)
    }

    func wideBands() -> [Band] {
        let shown = items.filter(\.shown)
        var result: [Band] = []
        var index = 0
        while index < shown.count {
            let item = shown[index]
            if item.columns < 2, index + 1 < shown.count, shown[index + 1].columns < 2 {
                let next = shown[index + 1]
                result.append(Band(id: "\(item.id.rawValue)+\(next.id.rawValue)", blocks: [item.id, next.id]))
                index += 2
            } else {
                result.append(Band(id: item.id.rawValue, blocks: [item.id]))
                index += 1
            }
        }
        return result
    }

    mutating func complete() {
        for block in StatsBlock.allCases where !items.contains(where: { $0.id == block }) {
            let columns = StatsLayout.standardWide.items.first { $0.id == block }?.columns ?? 1
            items.append(Item(id: block, shown: true, columns: columns))
        }
    }

    mutating func place(_ block: StatsBlock, before target: StatsBlock?, shown: Bool) {
        guard let from = items.firstIndex(where: { $0.id == block }) else { return }
        if target == block, items[from].shown == shown { return }
        var item = items.remove(at: from)
        item.shown = shown
        if let target, let index = items.firstIndex(where: { $0.id == target }) {
            items.insert(item, at: index)
        } else if shown {
            let index = items.lastIndex(where: \.shown).map { $0 + 1 } ?? 0
            items.insert(item, at: index)
        } else {
            items.append(item)
        }
    }

    mutating func setColumns(for block: StatsBlock, _ columns: Int) {
        guard let index = items.firstIndex(where: { $0.id == block }) else { return }
        items[index].columns = columns >= 2 ? 2 : 1
    }

    static func load(wide: Bool) -> StatsLayout {
        let key = wide ? "stats.layout.wide.v1" : "stats.layout.narrow.v1"
        if var saved = decode(key) {
            saved.complete()
            return saved
        }
        if var saved = decode("stats.layout.v1") {
            saved.complete()
            if wide { saved.applyLegacySpans() }
            return saved
        }
        return wide ? .standardWide : .standardNarrow
    }

    static func save(_ layout: StatsLayout, wide: Bool) {
        let key = wide ? "stats.layout.wide.v1" : "stats.layout.narrow.v1"
        guard let data = try? JSONEncoder().encode(layout) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func decode(_ key: String) -> StatsLayout? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StatsLayout.self, from: data)
    }

    private mutating func applyLegacySpans() {
        for index in items.indices {
            switch items[index].id {
            case .scores, .trend, .tokens, .recent:
                items[index].columns = 2
            case .overview, .directions, .levels:
                items[index].columns = 1
            }
        }
    }
}

struct StatsView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Exercise.createdAt, order: .reverse) private var exercises: [Exercise]
    @Query private var skills: [DirectionSkill]
    @Query private var streaks: [StreakRecord]
    @State private var wideLayout = StatsLayout.load(wide: true)
    @State private var narrowLayout = StatsLayout.load(wide: false)
    @State private var arrange = false
    @State private var arrangeWide = true
    @State private var pageSpan: PageSpan = .paired
    @State private var tokenSpan: TokenSpan = .day
    @State private var tokenModel = ""

    var body: some View {
        NavigationStack {
            PageScroll { span in
                statsPage(layout(for: span), span: span)
                    .onAppear { pageSpan = span }
                    .onChange(of: span) { _, new in pageSpan = new }
            }
            .navigationTitle("tab_stats")
            .toolbar {
                Button("stats_arrange", systemImage: "slider.horizontal.3") {
                    arrangeWide = pageSpan == .paired
                    arrange = true
                }
            }
            .sheet(isPresented: $arrange) {
                StatsArrangeSheet(
                    layout: arrangeWide ? $wideLayout : $narrowLayout,
                    wide: arrangeWide
                )
            }
            .background(Color.clear)
        }
    }

    private func layout(for span: PageSpan) -> StatsLayout {
        span == .paired ? wideLayout : narrowLayout
    }

    @ViewBuilder
    private func statsPage(_ layout: StatsLayout, span: PageSpan) -> some View {
        if layout.visible.isEmpty {
            Text("stats_none_shown")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
        } else if span == .paired {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(layout.wideBands()) { band in
                    bandView(band, span: span)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(layout.visible) { block in
                    section(block, span: span, fillsRow: false)
                }
            }
        }
    }

    @ViewBuilder
    private func bandView(_ band: StatsLayout.Band, span: PageSpan) -> some View {
        if band.blocks.count == 2 {
            HStack(alignment: .top, spacing: 12) {
                ForEach(band.blocks) { block in
                    section(block, span: span, fillsRow: false)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        } else if let block = band.blocks.first {
            section(block, span: span, fillsRow: true)
        }
    }

    @ViewBuilder
    private func section(_ block: StatsBlock, span: PageSpan, fillsRow: Bool) -> some View {
        switch block {
        case .overview: overviewTiles
        case .directions: directionTiles
        case .levels: levels(sideBySide: fillsRow)
        case .scores: scores(wide: fillsRow && span == .paired)
        case .trend: trend
        case .tokens: tokens
        case .recent: recent
        }
    }

    private var overviewTiles: some View {
        HStack(alignment: .top, spacing: 12) {
            metricTile(streakDays, "stats_streak")
            metricTile(items.count, "stats_done")
        }
    }

    private var directionTiles: some View {
        HStack(alignment: .top, spacing: 12) {
            metricTile(PracticeStats.count(items, direction: .zhToForeign), title: model.settings.directionText(.zhToForeign))
            metricTile(PracticeStats.count(items, direction: .foreignToZh), title: model.settings.directionText(.foreignToZh))
        }
    }

    private func metricTile(_ value: Int, _ title: LocalizedStringKey) -> some View {
        metricTile(value, title: Text(title))
    }

    private func metricTile(_ value: Int, title: String) -> some View {
        metricTile(value, title: Text(verbatim: title))
    }

    private func metricTile(_ value: Int, title: Text) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(value)")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            title
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .glassCard()
    }

    private func levels(sideBySide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("stats_level")
                .font(.headline)
            if sideBySide {
                HStack(alignment: .top, spacing: 28) {
                    levelRow(.zhToForeign)
                    levelRow(.foreignToZh)
                }
            } else {
                ForEach(Direction.allCases) { direction in
                    levelRow(direction)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func levelRow(_ direction: Direction) -> some View {
        let skill = skills.first {
            $0.languageCode == model.settings.activeLanguage.rawValue && $0.direction == direction
        }
        let placed = skill?.placementDone == true
        let level = skill?.level ?? Difficulty.skippedLevel
        let profile = Difficulty.profile(language: model.settings.activeLanguage, level: level)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.settings.directionText(direction))
                    .font(.subheadline)
                Spacer()
                if placed {
                    Text("\(level)")
                        .font(.title3.weight(.semibold).monospacedDigit())
                    Text(LocalizedStringKey(profile.usageDisplayKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("stats_unplaced")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: placed ? geo.size.width * CGFloat(level) / 100 : 0)
                }
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scores(wide: Bool) -> some View {
        let spread = PracticeStats.spread(items)
        return VStack(alignment: .leading, spacing: 16) {
            Text("stats_scores")
                .font(.headline)
            if items.isEmpty {
                Text("stats_empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if wide {
                HStack(spacing: 12) {
                    scoreTile(spread.average, "stats_average")
                    scoreTile(spread.recentAverage, "stats_recent")
                    scoreTile(spread.best, "stats_best")
                    scoreTile(spread.lowest, "stats_lowest")
                }
                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 14) {
                        gauge(spread.faithAverage, "review_faith")
                        gauge(spread.expressAverage, "review_express")
                        gauge(spread.eleganceAverage, "review_elegance")
                    }
                    .frame(maxWidth: 280, alignment: .leading)
                    distribution(spread)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                directionChart
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    scoreTile(spread.average, "stats_average")
                    scoreTile(spread.recentAverage, "stats_recent")
                    scoreTile(spread.best, "stats_best")
                    scoreTile(spread.lowest, "stats_lowest")
                }
                VStack(alignment: .leading, spacing: 14) {
                    gauge(spread.faithAverage, "review_faith")
                    gauge(spread.expressAverage, "review_express")
                    gauge(spread.eleganceAverage, "review_elegance")
                }
                distribution(spread)
                directionChart
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func scoreTile(_ value: Int?, _ title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value.map(String.init) ?? "—")
                .font(.title.weight(.semibold).monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func gauge(_ value: Int?, _ title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(value.map(String.init) ?? "—")
                    .font(.headline.monospacedDigit())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * CGFloat(value ?? 0) / 100)
                }
            }
            .frame(height: 6)
        }
    }

    private func distribution(_ spread: ScoreSpread) -> some View {
        let slices = bandSlices(spread)
        return VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                let visible = slices.filter { $0.count > 0 }
                let gap = CGFloat(max(visible.count - 1, 0)) * 2
                let usable = max(geo.size.width - gap, 0)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.06))
                    HStack(spacing: 2) {
                        ForEach(visible) { slice in
                            Capsule()
                                .fill(Color.accentColor.opacity(slice.opacity))
                                .frame(width: spread.total == 0 ? 0 : max(usable * CGFloat(slice.count) / CGFloat(spread.total), 4))
                        }
                    }
                }
            }
            .frame(height: 12)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(slices) { slice in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.accentColor.opacity(slice.opacity))
                            .frame(width: 7, height: 7)
                        Text(slice.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(slice.count)")
                            .font(.caption.monospacedDigit())
                    }
                }
            }
        }
    }

    private func bandSlices(_ spread: ScoreSpread) -> [BandSlice] {
        [
            BandSlice(id: "90", title: "history_score_90", count: spread.from90, opacity: 1),
            BandSlice(id: "80", title: "history_score_80", count: spread.from80, opacity: 0.72),
            BandSlice(id: "70", title: "history_score_70", count: spread.from70, opacity: 0.48),
            BandSlice(id: "under", title: "history_score_under70", count: spread.under70, opacity: 0.28),
        ]
    }

    @ViewBuilder
    private var directionChart: some View {
        let bars = directionBars
        if !bars.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("stats_by_direction")
                    .font(.subheadline.weight(.semibold))
                Chart(bars) { bar in
                    BarMark(
                        x: .value("score", bar.score),
                        y: .value("direction", bar.title)
                    )
                    .foregroundStyle(Color.accentColor.opacity(bar.direction == .zhToForeign ? 1 : 0.62))
                    .cornerRadius(5)
                    .annotation(position: .overlay, alignment: .trailing) {
                        Text("\(bar.score)")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.primary)
                            .padding(.trailing, 6)
                    }
                }
                .chartXScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: [0, 50, 100]) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .frame(height: 128)
            }
        }
    }

    private var trend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("stats_trend")
                .font(.headline)
            if trendPoints.count < 2 {
                Text("stats_empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(trendPoints) { point in
                    AreaMark(
                        x: .value("when", point.date),
                        y: .value("score", point.score)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.28), Color.accentColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("when", point.date),
                        y: .value("score", point.score)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    PointMark(
                        x: .value("when", point.date),
                        y: .value("score", point.score)
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(28)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100])
                }
                .frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var tokens: some View {
        let records = TokenSeries.withModels(model.tokenLedger.days, accountModels: accountModels)
        let segments = TokenSeries.segments(records: records, span: tokenSpan, ending: Date(), calendar: .current, count: tokenCount)
        let names = tokenNames(in: segments)
        let selected = names.contains(tokenModel) ? tokenModel : ""
        let buckets = TokenSeries.buckets(
            records: records,
            span: tokenSpan,
            ending: Date(),
            calendar: .current,
            count: tokenCount,
            model: selected.isEmpty ? nil : selected
        )
        let windowSum = buckets.reduce(0) { $0 + $1.total }
        let shown = selected.isEmpty ? names : [selected]
        let cost = priceText(names: shown, segments: segments)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("stats_block_tokens")
                    .font(.headline)
                Spacer(minLength: 12)
                if names.count > 1 {
                    Picker("stats_token_model", selection: $tokenModel) {
                        Text("stats_token_all_models").tag("")
                        ForEach(names, id: \.self) { name in
                            Text(tokenModelTitle(name)).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }
            if model.tokenLedger.lifetime.input + model.tokenLedger.lifetime.output == 0 {
                Text("stats_token_empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Picker("stats_block_tokens", selection: $tokenSpan) {
                    Text("stats_token_day").tag(TokenSpan.day)
                    Text("stats_token_month").tag(TokenSpan.month)
                    Text("stats_token_year").tag(TokenSpan.year)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 240, alignment: .leading)
                HStack(alignment: .lastTextBaseline, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TokenUnit.compactText(windowSum))
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text("stats_token_span")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    if let cost {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(cost)
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text("stats_token_cost")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if windowSum > 0 {
                    tokenChart(buckets: buckets, segments: segments, names: names, selected: selected, unit: TokenUnit.fitting(buckets.map(\.total).max() ?? 0))
                }
                if !shown.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(shown.enumerated()), id: \.element) { index, name in
                            if index > 0 {
                                Divider()
                            }
                            modelUsageRow(name: name, tally: tally(for: name, in: segments), index: names.firstIndex(of: name) ?? index)
                        }
                    }
                }
                if model.tokenLedger.hasUndated {
                    Text("stats_token_undated")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var accountModels: [String: String] {
        let llm = model.settings.llm
        var map: [String: String] = [:]
        func put(_ account: String, _ name: String) {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                map[account] = trimmed
            }
        }
        put("llm.default", llm.defaultEndpoint.model)
        put("llm.translation", llm.translationEndpoint.model)
        for task in LLMTask.allCases {
            put("llm.\(task.rawValue)", llm.config(for: task).model)
        }
        return map
    }

    private func tokenNames(in segments: [TokenSegment]) -> [String] {
        var seen: [String] = []
        for segment in segments where segment.total > 0 && !segment.model.isEmpty && !seen.contains(segment.model) {
            seen.append(segment.model)
        }
        return seen.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func tally(for name: String, in segments: [TokenSegment]) -> TokenTally {
        segments.reduce(into: TokenTally()) { total, segment in
            guard segment.model == name else { return }
            total.input += segment.input
            total.output += segment.output
        }
    }

    @ViewBuilder
    private func tokenChart(buckets: [TokenBucket], segments: [TokenSegment], names: [String], selected: String, unit: TokenUnit) -> some View {
        let shown = selected.isEmpty ? names : names.filter { $0 == selected }
        let split = shown.count > 1
        let titles = shown.map { tokenModelTitle($0) }
        let visible = segments.filter { segment in
            segment.total > 0 && (selected.isEmpty || segment.model == selected)
        }
        let chart = Chart {
            ForEach(buckets) { bucket in
                BarMark(
                    x: .value("period", bucket.label),
                    y: .value("tokens", 0)
                )
                .foregroundStyle(Color.accentColor.opacity(0.001))
            }
            if split {
                ForEach(visible) { segment in
                    BarMark(
                        x: .value("period", segment.label),
                        y: .value("tokens", unit.scale(segment.total))
                    )
                    .foregroundStyle(by: .value("model", tokenModelTitle(segment.model)))
                    .cornerRadius(3)
                }
            } else {
                ForEach(buckets) { bucket in
                    BarMark(
                        x: .value("period", bucket.label),
                        y: .value("tokens", unit.scale(bucket.total))
                    )
                    .foregroundStyle(tokenColor(names.firstIndex(of: selected.isEmpty ? (names.first ?? "") : selected) ?? 0))
                    .cornerRadius(3)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(unit.axisCompact(number))
                    }
                }
            }
        }
        .frame(height: split ? 210 : 168)
        if split, !titles.isEmpty {
            chart
                .chartForegroundStyleScale(
                    domain: titles,
                    range: shown.indices.map { tokenColor(names.firstIndex(of: shown[$0]) ?? $0) }
                )
                .chartLegend(position: .bottom, alignment: .leading)
        } else {
            chart
                .chartLegend(.hidden)
        }
    }

    private func modelUsageRow(name: String, tally: TokenTally, index: Int) -> some View {
        let quoted = priceText(model: name, tally: tally)
        return HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(tokenColor(index))
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(tokenModelTitle(name))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(tokenSplit(tally))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(TokenUnit.compactText(tally.input + tally.output))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                if let quoted {
                    Text(quoted)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func tokenSplit(_ tally: TokenTally) -> String {
        let input = TokenUnit.compactText(tally.input)
        let output = TokenUnit.compactText(tally.output)
        return String(format: String(localized: "stats_token_io"), input, output)
    }

    private func priceText(names: [String], segments: [TokenSegment]) -> String? {
        var totals: [String: Decimal] = [:]
        var order: [String] = []
        for name in names {
            guard let price = storedPrice(name),
                  let cost = TokenMoney.cost(input: tally(for: name, in: segments).input, output: tally(for: name, in: segments).output, price: price) else { continue }
            if totals[price.currencyCode] == nil {
                order.append(price.currencyCode)
            }
            totals[price.currencyCode, default: 0] += cost
        }
        let parts = order.map { TokenMoney.text(totals[$0] ?? 0, currencyCode: $0) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func priceText(model name: String, tally: TokenTally) -> String? {
        guard let price = storedPrice(name),
              let cost = TokenMoney.cost(input: tally.input, output: tally.output, price: price) else {
            return nil
        }
        return TokenMoney.text(cost, currencyCode: price.currencyCode)
    }

    private func storedPrice(_ name: String) -> ModelTokenPrice? {
        let prices = model.settings.modelPrices
        if let exact = prices.first(where: { $0.model == name }) {
            return exact
        }
        return prices.first { $0.model.caseInsensitiveCompare(name) == .orderedSame }
    }

    private func tokenModelTitle(_ name: String) -> String {
        switch name {
        case "llm.default":
            String(localized: "stats_token_general")
        case "llm.translation":
            String(localized: "stats_token_translation")
        case "":
            String(localized: "stats_token_unnamed")
        default:
            name
        }
    }

    private func tokenColor(_ index: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.16, green: 0.39, blue: 0.78),
            Color(red: 0.18, green: 0.62, blue: 0.55),
            Color(red: 0.84, green: 0.49, blue: 0.20),
            Color(red: 0.55, green: 0.36, blue: 0.74),
            Color(red: 0.76, green: 0.28, blue: 0.36),
            Color(red: 0.35, green: 0.48, blue: 0.28),
        ]
        return palette[index % palette.count]
    }

    private var tokenCount: Int {
        switch tokenSpan {
        case .day: 14
        case .month: 12
        case .year: 5
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("stats_recent_items")
                .font(.headline)
            if recentExercises.isEmpty {
                Text("stats_empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentExercises) { exercise in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.sourceText)
                                .lineLimit(1)
                            Text(model.settings.directionText(exercise.direction))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.06), in: Capsule())
                        }
                        Spacer(minLength: 8)
                        Text("\(exercise.weightedScore)")
                            .font(.title3.weight(.semibold).monospacedDigit())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var directionBars: [DirectionBar] {
        Direction.allCases.compactMap { direction in
            let scores = items.filter { $0.direction == direction }.map(\.weighted)
            guard let average = ScoreAverage.mean(scores) else { return nil }
            return DirectionBar(
                direction: direction,
                title: model.settings.directionText(direction),
                score: average
            )
        }
    }

    private var trendPoints: [TrendPoint] {
        let ordered = items.sorted { $0.submittedAt < $1.submittedAt }.suffix(30)
        return ordered.enumerated().map { index, item in
            TrendPoint(id: index, date: item.submittedAt, score: item.weighted)
        }
    }

    private var items: [PracticeStatItem] {
        finished.map { exercise in
            PracticeStatItem(
                direction: exercise.direction,
                weighted: exercise.weightedScore,
                faithfulness: exercise.faithfulness,
                expressiveness: exercise.expressiveness,
                elegance: exercise.elegance,
                submittedAt: exercise.updatedAt == .distantPast ? exercise.createdAt : exercise.updatedAt
            )
        }
    }

    private var recentExercises: [Exercise] {
        Array(finished.prefix(6))
    }

    private var finished: [Exercise] {
        exercises.filter { exercise in
            exercise.submitted
                && exercise.kind != .ready
                && exercise.languageCode == model.settings.activeLanguage.rawValue
        }
    }

    private var streakDays: Int {
        streaks.first?.current ?? 0
    }
}

private struct BandSlice: Identifiable {
    var id: String
    var title: LocalizedStringKey
    var count: Int
    var opacity: Double
}

private struct DirectionBar: Identifiable {
    var direction: Direction
    var title: String
    var score: Int
    var id: String { direction.rawValue }
}

private struct TrendPoint: Identifiable {
    var id: Int
    var date: Date
    var score: Int
}

private struct StatsDrag: Codable, Transferable {
    var id: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

private struct StatsArrangeSheet: View {
    @Binding var layout: StatsLayout
    var wide: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var hovering: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(wide ? "stats_arrange_wide" : "stats_arrange_narrow")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("stats_arrange_shown")
                        .font(.headline)
                    if wide {
                        VStack(spacing: 8) {
                            ForEach(layout.wideBands()) { band in
                                HStack(alignment: .top, spacing: 8) {
                                    ForEach(band.blocks) { block in
                                        if let item = layout.items.first(where: { $0.id == block }) {
                                            arrangeRow(item, shown: true)
                                        }
                                    }
                                }
                            }
                        }
                        dropWell(title: "stats_arrange_end", target: nil, shown: true)
                    } else if layout.visible.isEmpty {
                        dropWell(title: "stats_arrange_end", target: nil, shown: true)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(layout.items.filter(\.shown)) { item in
                                arrangeRow(item, shown: true)
                            }
                        }
                        dropWell(title: "stats_arrange_end", target: nil, shown: true)
                    }
                    Text("stats_arrange_hidden")
                        .font(.headline)
                    let hidden = layout.items.filter { !$0.shown }
                    if hidden.isEmpty {
                        dropWell(title: "stats_arrange_hidden_empty", target: nil, shown: false)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(hidden) { item in
                                arrangeRow(item, shown: false)
                            }
                        }
                        dropWell(title: "stats_arrange_hidden_empty", target: nil, shown: false)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("stats_arrange")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("stats_arrange_reset") {
                        layout = wide ? .standardWide : .standardNarrow
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common_done") { dismiss() }
                }
            }
            .onChange(of: layout) { _, new in
                StatsLayout.save(new, wide: wide)
            }
        }
        #if os(macOS)
        .frame(minWidth: wide ? 520 : 420, minHeight: 560)
        #endif
    }

    private func arrangeRow(_ item: StatsLayout.Item, shown: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(item.id.title)
                .frame(maxWidth: .infinity, alignment: .leading)
            if wide, shown {
                Button(item.columns >= 2 ? "stats_arrange_span_full" : "stats_arrange_span_half") {
                    layout.setColumns(for: item.id, item.columns >= 2 ? 1 : 2)
                }
                .buttonStyle(.borderless)
            }
            Button {
                layout.place(item.id, before: nil, shown: !shown)
            } label: {
                Image(systemName: shown ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(hovering == item.id.rawValue ? 0.12 : 0.05))
        }
        .draggable(StatsDrag(id: item.id.rawValue))
        .dropDestination(for: StatsDrag.self) { dropped, _ in
            guard let block = dropped.first.flatMap({ StatsBlock(rawValue: $0.id) }) else { return false }
            layout.place(block, before: item.id, shown: shown)
            return true
        } isTargeted: { targeted in
            hovering = targeted ? item.id.rawValue : (hovering == item.id.rawValue ? nil : hovering)
        }
    }

    private func dropWell(title: LocalizedStringKey, target: StatsBlock?, shown: Bool) -> some View {
        let key = shown ? "shown-end" : "hidden-end"
        return Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(hovering == key ? 0.8 : 0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .dropDestination(for: StatsDrag.self) { dropped, _ in
                guard let block = dropped.first.flatMap({ StatsBlock(rawValue: $0.id) }) else { return false }
                layout.place(block, before: target, shown: shown)
                return true
            } isTargeted: { targeted in
                hovering = targeted ? key : (hovering == key ? nil : hovering)
            }
    }
}
