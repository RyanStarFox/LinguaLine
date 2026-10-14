import SwiftUI
import TranslationCore

enum LanguageTitle {
    static func key(_ language: PracticeLanguage) -> LocalizedStringKey {
        LocalizedStringKey(storageKey(language))
    }

    static func string(_ language: PracticeLanguage) -> String {
        String(localized: String.LocalizationValue(storageKey(language)))
    }

    private static func storageKey(_ language: PracticeLanguage) -> String {
        switch language {
        case .chinese: "language_zh"
        case .english: "language_en"
        case .japanese: "language_ja"
        case .korean: "language_ko"
        case .french: "language_fr"
        case .german: "language_de"
        case .spanish: "language_es"
        case .russian: "language_ru"
        case .portuguese: "language_pt"
        case .italian: "language_it"
        case .arabic: "language_ar"
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case today
    case calendar
    case review
    case history
    case stats
    case favorites
    case settings

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .today: "tab_today"
        case .calendar: "tab_calendar"
        case .review: "tab_review"
        case .history: "tab_history"
        case .stats: "tab_stats"
        case .favorites: "tab_favorites"
        case .settings: "tab_settings"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .calendar: "calendar"
        case .review: "arrow.clockwise"
        case .history: "clock"
        case .stats: "chart.bar"
        case .favorites: "bookmark"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var section: AppSection? = .today

    var body: some View {
        #if os(macOS)
        split
        #else
        if sizeClass == .regular {
            split
        } else {
            tabs
        }
        #endif
    }

    private var split: some View {
        NavigationSplitView {
            List(selection: $section) {
                ForEach(AppSection.allCases) { item in
                    Label(LocalizedStringKey(item.titleKey), systemImage: item.symbol)
                        .tag(item)
                }
            }
            .navigationTitle("today_title")
        } detail: {
            sectionView(section ?? .today)
        }
    }

    private var tabs: some View {
        TabView(selection: $section) {
            ForEach(AppSection.allCases) { item in
                sectionView(item)
                    .tabItem { Label(LocalizedStringKey(item.titleKey), systemImage: item.symbol) }
                    .tag(Optional(item))
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: AppSection) -> some View {
        switch section {
        case .today: TodayView()
        case .calendar: StreakCalendarView(embedded: true)
        case .review: ReviewQueueView()
        case .history: HistoryView()
        case .stats: StatsView()
        case .favorites: FavoritesView()
        case .settings: SettingsView()
        }
    }
}
