import SwiftUI
import SwiftData
import TranslationCore

struct FavoritesView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \FavoriteFolder.createdAt) private var folders: [FavoriteFolder]
    @Query(sort: \FavoriteItem.createdAt, order: .reverse) private var items: [FavoriteItem]
    @State private var folderID: UUID?
    @State private var query = ""
    @State private var direction: Direction?
    @State private var language: String?
    @State private var sort: ScoreSort = .newest
    @State private var band: ScoreBand = .all
    @State private var selection = Set<UUID>()
    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    #endif
    @State private var newFolderName = ""
    @State private var showNewFolder = false
    @State private var selectedItem: FavoriteItem?

    var body: some View {
        NavigationStack {
            List(selection: $selection) {
                ForEach(visibleFolders) { folder in
                    Button {
                        folderID = folder.id
                        model.settings.favoriteFolderID = folder.id
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                            Text(folder.name)
                            if folder.pinned {
                                Image(systemName: "pin.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions {
                        Button(folder.pinned ? "favorites_unpin" : "favorites_pin") {
                            model.togglePin(folder: folder)
                        }
                        .tint(.orange)
                        Button("common_delete", role: .destructive) {
                            model.deleteFolders([folder.id])
                        }
                    }
                }
                ForEach(visibleItems) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        favoriteRow(item)
                    }
                    .buttonStyle(.plain)
                    .tag(item.id)
                    .swipeActions {
                        Button(item.pinned ? "favorites_unpin" : "favorites_pin") {
                            model.togglePin(item: item)
                        }
                        .tint(.orange)
                        Button("common_delete", role: .destructive) {
                            model.deleteItems([item.id])
                        }
                    }
                }
            }
            .navigationTitle(currentTitle)
            .searchable(text: $query, prompt: Text("history_search"))
            #if os(iOS)
            .environment(\.editMode, $editMode)
            #endif
            .toolbar { toolbar }
            .overlay {
                if visibleFolders.isEmpty && visibleItems.isEmpty {
                    ContentUnavailableView("favorites_empty", systemImage: "bookmark")
                }
            }
            .alert("favorites_new_folder", isPresented: $showNewFolder) {
                TextField("favorites_folder_name", text: $newFolderName)
                Button("common_save") {
                    model.createFolder(name: newFolderName, parentID: folderID)
                    newFolderName = ""
                }
                Button("common_cancel", role: .cancel) { newFolderName = "" }
            }
            .sheet(item: $selectedItem) { item in
                FavoriteDetail(item: item)
            }
        }
    }

    private func favoriteRow(_ item: FavoriteItem) -> some View {
        let direction = item.directionRaw == Direction.zhToForeign.rawValue ? Direction.zhToForeign : Direction.foreignToZh
        let language = PracticeLanguage(rawValue: item.languageCode) ?? .english
        return VStack(alignment: .leading, spacing: 4) {
            Text(item.sourceText)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(alignment: .center, spacing: 6) {
                metaTag(LanguageTitle.key(language))
                metaTag(model.settings.directionText(direction))
                Spacer(minLength: 8)
                Text("\(item.weightedScore)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .layoutPriority(1)
                if item.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func metaTag(_ title: String) -> some View {
        metaTag(Text(title))
    }

    private func metaTag(_ title: LocalizedStringKey) -> some View {
        metaTag(Text(title))
    }

    private func metaTag(_ label: Text) -> some View {
        label
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }

    private var currentTitle: String {
        if let folderID, let folder = folders.first(where: { $0.id == folderID }) {
            return folder.name
        }
        return String(localized: "tab_favorites")
    }

    private var visibleFolders: [FavoriteFolder] {
        folders
            .filter { $0.parentID == folderID }
            .sorted { lhs, rhs in
                if lhs.pinned != rhs.pinned { return lhs.pinned && !rhs.pinned }
                return lhs.sortIndex < rhs.sortIndex
            }
    }

    private var visibleItems: [FavoriteItem] {
        let rows = items.filter { item in
            item.folderID == folderID
                && (direction == nil || item.directionRaw == direction?.rawValue)
                && (language == nil || item.languageCode == language)
                && band.matches(score: item.weightedScore)
                && matches(item)
        }
        return ScoreList.ordered(rows, sort: sort, date: \.createdAt, score: { Optional($0.weightedScore) }, pinned: \.pinned)
    }

    private func matches(_ item: FavoriteItem) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.isEmpty { return true }
        return item.sourceText.localizedCaseInsensitiveContains(needle)
            || item.userText.localizedCaseInsensitiveContains(needle)
            || item.exemplarText.localizedCaseInsensitiveContains(needle)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if folderID != nil {
                Button("favorites_back") {
                    let parent = folders.first { $0.id == folderID }?.parentID
                    folderID = parent
                    model.settings.favoriteFolderID = parent
                }
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button("favorites_new_folder") { showNewFolder = true }
            #if os(iOS)
            Button(editMode == .active ? "common_done" : "favorites_select") {
                editMode = editMode == .active ? .inactive : .active
                if editMode == .inactive { selection.removeAll() }
            }
            #endif
            if !selection.isEmpty {
                Button("favorites_delete_selected", role: .destructive) {
                    model.deleteItems(selection)
                    selection.removeAll()
                    #if os(iOS)
                    editMode = .inactive
                    #endif
                }
            }
            Menu {
                Picker("history_direction", selection: $direction) {
                    Text("history_all").tag(Optional<Direction>.none)
                    Text(model.settings.directionText(.zhToForeign)).tag(Optional(Direction.zhToForeign))
                    Text(model.settings.directionText(.foreignToZh)).tag(Optional(Direction.foreignToZh))
                }
                Picker("favorites_filter_language", selection: $language) {
                    Text("history_all").tag(Optional<String>.none)
                    ForEach(PracticeLanguage.allCases) { language in
                        Text(LanguageTitle.key(language)).tag(Optional(language.rawValue))
                    }
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
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
    }
}

private struct FavoriteDetail: View {
    var item: FavoriteItem

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(item.sourceText)
                        .font(.title3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                    Text("\(item.weightedScore)")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                    DiffText(user: item.userText, corrected: item.correctedText)
                        .glassCard()
                    Text(item.exemplarText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                }
                .padding(20)
                .pageColumn()
            }
            .navigationTitle("tab_favorites")
        }
    }
}
