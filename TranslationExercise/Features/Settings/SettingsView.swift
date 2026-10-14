import SwiftUI
import TranslationCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var pendingDelete: String?
    @State private var webdavPassword = ""

    var body: some View {
        NavigationStack {
            PageScroll { span in
                settingsColumns(span)
            }
            .navigationTitle("tab_settings")
                .environment(\.locale, locale)
                .onAppear {
                    model.dictionaries.refresh()
                    webdavPassword = model.webdavPassword
                }
                .confirmationDialog(
                    "settings_dictionary_delete_confirm",
                    isPresented: deleteDialogPresented,
                    titleVisibility: .visible
                ) {
                    Button("settings_dictionary_delete", role: .destructive) {
                        if let id = pendingDelete {
                            model.deleteDictionary(id)
                        }
                        pendingDelete = nil
                    }
                    Button("common_close", role: .cancel) { pendingDelete = nil }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dictionaryCard: some View {
        let pair = [model.settings.nativeLanguage, model.settings.activeLanguage]
        let recommended = DictionaryOffer.all.filter { pair.contains(.chinese) && pair.contains($0.language) }
        let others = DictionaryOffer.all.filter { offer in !recommended.contains { $0.id == offer.id } }
        return VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: preferDictionary) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings_dictionary_prefer")
                    Text("settings_dictionary_prefer_detail")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            Text("settings_dictionary_caption")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if recommended.isEmpty {
                Text("settings_dictionary_unavailable")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("settings_dictionary_recommended")
                    .font(.subheadline.weight(.semibold))
                ForEach(recommended) { offer in
                    dictionaryRow(offer)
                }
            }
            if !others.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(others.enumerated()), id: \.element.id) { index, offer in
                            if index > 0 { Divider() }
                            dictionaryRow(offer)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("settings_dictionary_others")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .glassCard()
    }

    private func dictionaryRow(_ offer: DictionaryOffer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(offer.title)
                .font(.headline)
            Text(LocalizedStringKey(offer.detailKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let fraction = model.dictionaries.progress[offer.id] {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                HStack {
                    Text(fraction < 0.7 ? "settings_dictionary_download" : "settings_dictionary_indexing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("settings_dictionary_cancel") { model.dictionaries.cancel(offer.id) }
                        .glassButton(prominent: false)
                }
            } else if let bytes = model.dictionaries.installed[offer.id] {
                HStack {
                    Text(ByteCountText.string(bytes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("settings_dictionary_delete") { pendingDelete = offer.id }
                        .glassButton(prominent: false)
                }
            } else {
                HStack {
                    Text(ByteCountText.string(offer.approximateBytes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("settings_dictionary_download") {
                        Task { await model.downloadDictionary(offer.id) }
                    }
                    .glassButton(prominent: true)
                }
            }
            if let message = model.dictionaries.errors[offer.id] {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
    }

    private var preferDictionary: Binding<Bool> {
        Binding(
            get: { model.settings.preferDictionary },
            set: { model.setPreferDictionary($0) }
        )
    }

    private var syncCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingRow("settings_sync_mode") {
                ChoiceMenu(selection: syncMode) {
                    Text("settings_sync_off").tag(SyncMode.off)
                    Text("settings_sync_icloud").tag(SyncMode.icloud)
                    Text("settings_sync_webdav").tag(SyncMode.webdav)
                } title: {
                    Text(syncModeTitle)
                }
            }
            if model.settings.syncMode == .webdav {
                TextField("settings_webdav_url", text: webdavURL)
                    .textFieldStyle(.roundedBorder)
                TextField("settings_webdav_user", text: webdavUser)
                    .textFieldStyle(.roundedBorder)
                SecureField("settings_webdav_password", text: $webdavPassword)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: webdavPassword) { _, value in
                        model.setWebdavPassword(value)
                    }
                TextField("settings_webdav_path", text: webdavPath)
                    .textFieldStyle(.roundedBorder)
            }
            if model.settings.syncMode != .off {
                Button("settings_sync_now") {
                    Task { await model.syncNow() }
                }
                .glassButton(prominent: true)
                .disabled(model.syncing)
                if model.syncing {
                    ProgressView()
                }
                if let status = model.syncStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                } else if let synced = model.lastSyncAt {
                    Text(synced, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .glassCard()
    }

    private var webdavURL: Binding<String> {
        Binding(get: { model.settings.webdavURL }, set: { model.settings.webdavURL = $0 })
    }

    private var webdavUser: Binding<String> {
        Binding(get: { model.settings.webdavUser }, set: { model.settings.webdavUser = $0 })
    }

    private var webdavPath: Binding<String> {
        Binding(get: { model.settings.webdavPath }, set: { model.settings.webdavPath = $0 })
    }

    private var syncModeTitle: LocalizedStringKey {
        switch model.settings.syncMode {
        case .off: "settings_sync_off"
        case .icloud: "settings_sync_icloud"
        case .webdav: "settings_sync_webdav"
        }
    }

    private var deleteDialogPresented: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }

    @ViewBuilder
    private func settingsColumns(_ span: PageSpan) -> some View {
        if span == .paired {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top, spacing: 20) {
                    practiceGroup
                        .frame(maxWidth: .infinity, alignment: .top)
                    reviewGroup
                        .frame(maxWidth: .infinity, alignment: .top)
                }
                dictionaryGroup
                syncGroup
                modelGroup(paired: true)
            }
        } else {
            VStack(alignment: .leading, spacing: 28) {
                practiceGroup
                reviewGroup
                dictionaryGroup
                syncGroup
                modelGroup(paired: false)
            }
        }
    }

    private var practiceGroup: some View {
        settingsGroup("settings_group_practice") { practiceCard }
    }

    private var reviewGroup: some View {
        settingsGroup("settings_group_review") { reviewCard }
    }

    private var dictionaryGroup: some View {
        settingsGroup("settings_group_dictionary") { dictionaryCard }
    }

    private var syncGroup: some View {
        settingsGroup("settings_group_sync") { syncCard }
    }

    private func modelGroup(paired: Bool) -> some View {
        settingsGroup("settings_group_model") {
            Text("settings_token_note")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if paired {
                HStack(alignment: .top, spacing: 16) {
                    EndpointCard(
                        title: "settings_default",
                        caption: "settings_general_uses",
                        config: defaultConfig,
                        account: "llm.default"
                    )
                    EndpointCard(
                        title: "settings_translation",
                        caption: "settings_translation_uses",
                        config: translationConfig,
                        account: "llm.translation"
                    )
                }
            } else {
                EndpointCard(
                    title: "settings_default",
                    caption: "settings_general_uses",
                    config: defaultConfig,
                    account: "llm.default"
                )
                EndpointCard(
                    title: "settings_translation",
                    caption: "settings_translation_uses",
                    config: translationConfig,
                    account: "llm.translation"
                )
            }
            if !otherPricedModels.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("settings_price_used")
                        .font(.headline)
                    ForEach(otherPricedModels, id: \.self) { name in
                        Text(name)
                            .font(.subheadline.weight(.semibold))
                        ModelPriceFields(modelName: name)
                    }
                }
                .glassCard()
            }
        }
    }

    private var practiceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingRow("settings_ui_language") {
                ChoiceMenu(selection: uiLanguage) {
                    Text("settings_follow_system").tag(Optional<String>.none)
                    ForEach(UILanguage.allCases) { language in
                        Text(LocalizedStringKey(language.titleKey)).tag(Optional(language.rawValue))
                    }
                } title: {
                    Text(interfaceTitle)
                }
            }
            Divider()
            settingRow("settings_native_language") {
                ChoiceMenu(selection: nativeLanguage) {
                    ForEach(PracticeLanguage.allCases) { language in
                        Text(LanguageTitle.key(language)).tag(language)
                    }
                } title: {
                    Text(LanguageTitle.key(model.settings.nativeLanguage))
                }
            }
            Divider()
            settingRow("settings_practice_languages") {
                ChoiceMenu(selection: practiceLanguage) {
                    ForEach(PracticeLanguage.allCases) { language in
                        Text(LanguageTitle.key(language)).tag(language)
                    }
                } title: {
                    Text(LanguageTitle.key(model.settings.activeLanguage))
                }
            }
            if model.settings.nativeLanguage == .chinese || model.settings.activeLanguage == .chinese {
                Divider()
                settingRow("settings_script") {
                    ScriptChoice(script: script)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("settings_length")
                lengthChoices
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("settings_daily_count")
                dailyCountStepper(.zhToForeign)
                dailyCountStepper(.foreignToZh)
                Text("settings_daily_count_hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .glassCard()
    }

    private var reviewCard: some View {
        let policy = model.settings.reviewPolicy
        let bands = policy.orderedBands
        return VStack(alignment: .leading, spacing: 14) {
            ForEach(bands) { band in
                reviewBandRow(band, policy: policy)
                if band.id != bands.last?.id {
                    Divider()
                }
            }
            Button {
                model.setReviewPolicy { $0 = $0.insertingBand() }
            } label: {
                Label("settings_review_add", systemImage: "plus")
            }
            .disabled(!policy.canInsertBand)
            Text("settings_review_hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private func reviewBandRow(_ band: ReviewBand, policy: ReviewPolicy) -> some View {
        let floor = band.minScore == 0
        let kind = ReviewBandKind(band.change)
        let choices = floor ? ReviewBandKind.intervals : ReviewBandKind.allCases
        let factor = ReviewBandKind.factor(in: band.change)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if floor {
                    Text("settings_review_below")
                    Spacer(minLength: 12)
                } else {
                    Stepper(
                        value: Binding(
                            get: { band.minScore },
                            set: { next in
                                model.setReviewPolicy { $0 = $0.updatingScore(id: band.id, score: next) }
                            }
                        ),
                        in: policy.scoreBounds(for: band.id)
                    ) {
                        HStack {
                            Text("settings_review_from")
                            Spacer(minLength: 12)
                            Text("\(band.minScore)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if kind.usesFactor {
                    Stepper(
                        value: Binding(
                            get: { factor },
                            set: { next in
                                model.setReviewPolicy { $0 = $0.updatingChange(id: band.id, change: kind.change(factor: next)) }
                            }
                        ),
                        in: ReviewPolicy.factorRange
                    ) {
                        Text(kind == .multiply ? "×\(factor)" : "÷\(factor)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 120)
                }
                if policy.orderedBands.count > 2, !floor {
                    Button {
                        model.setReviewPolicy { $0 = $0.removingBand(id: band.id) }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            EqualChoiceBar(
                choices: choices,
                selection: Binding(
                    get: { kind },
                    set: { next in
                        model.setReviewPolicy { $0 = $0.updatingChange(id: band.id, change: next.change(keeping: band.change)) }
                    }
                ),
                title: { $0.title }
            )
        }
    }

    private func dailyCountStepper(_ direction: Direction) -> some View {
        Stepper(value: dailyTarget(direction), in: 0...DailyQuota.maximumPerDirection) {
            HStack {
                Text(model.settings.directionText(direction))
                Spacer(minLength: 12)
                Text("\(model.settings.dailyTarget(for: direction))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var lengthChoices: some View {
        HStack(spacing: 8) {
            ForEach(LengthPreset.allCases) { preset in
                let selected = model.settings.length == preset
                let zh = LengthPolicy.spec(preset: preset, language: model.settings.activeLanguage, direction: .zhToForeign, native: model.settings.nativeLanguage)
                let foreign = LengthPolicy.spec(preset: preset, language: model.settings.activeLanguage, direction: .foreignToZh, native: model.settings.nativeLanguage)
                Button {
                    model.setLength(preset)
                } label: {
                    let zhText = span(zh)
                    let foreignText = span(foreign)
                    VStack(spacing: 2) {
                        Text(lengthTitle(preset))
                            .font(.subheadline.weight(.semibold))
                        Text(zhText)
                            .font(.caption2)
                        if zhText != foreignText {
                            Text(foreignText)
                                .font(.caption2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selected ? AnyShapeStyle(Color.accentColor.opacity(0.18)) : AnyShapeStyle(Color.primary.opacity(0.05)))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func settingsGroup<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
                .padding(.leading, 4)
            content()
        }
    }

    private func settingRow<Control: View>(_ title: LocalizedStringKey, @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            control()
        }
    }

    private func span(_ spec: LengthSpec) -> String {
        "\(spec.range.lowerBound)–\(spec.range.upperBound) \(unit(spec.unit))"
    }

    private func lengthTitle(_ preset: LengthPreset) -> LocalizedStringKey {
        switch preset {
        case .short: "settings_short"
        case .medium: "settings_medium"
        case .long: "settings_long"
        }
    }

    private func unit(_ unit: LengthUnit) -> String {
        unit == .characters ? String(localized: "unit_chars") : String(localized: "unit_words")
    }

    private var locale: Locale {
        if let code = model.settings.uiLanguageCode {
            return Locale(identifier: code)
        }
        return .autoupdatingCurrent
    }

    private var script: Binding<ChineseScript> {
        Binding(
            get: { model.settings.script },
            set: { model.setScript($0) }
        )
    }

    private var nativeLanguage: Binding<PracticeLanguage> {
        Binding(
            get: { model.settings.nativeLanguage },
            set: { model.selectNativeLanguage($0) }
        )
    }

    private var syncMode: Binding<SyncMode> {
        Binding(
            get: { model.settings.syncMode },
            set: { model.settings.syncMode = $0 }
        )
    }

    private func dailyTarget(_ direction: Direction) -> Binding<Int> {
        Binding(
            get: { model.settings.dailyTarget(for: direction) },
            set: { model.setDailyTarget($0, for: direction) }
        )
    }

    private var practiceLanguage: Binding<PracticeLanguage> {
        Binding(
            get: { model.settings.activeLanguage },
            set: { model.selectPracticeLanguage($0) }
        )
    }

    private var interfaceTitle: LocalizedStringKey {
        guard let code = model.settings.uiLanguageCode,
              let language = UILanguage(rawValue: code) else {
            return "settings_follow_system"
        }
        return LocalizedStringKey(language.titleKey)
    }

    private var uiLanguage: Binding<String?> {
        Binding(
            get: { model.settings.uiLanguageCode },
            set: { model.settings.uiLanguageCode = $0 }
        )
    }

    private var defaultConfig: Binding<EndpointConfig> {
        Binding(
            get: { model.settings.llm.defaultEndpoint },
            set: { model.settings.llm.defaultEndpoint = $0 }
        )
    }

    private var translationConfig: Binding<EndpointConfig> {
        Binding(
            get: { model.settings.llm.translationEndpoint },
            set: { model.settings.llm.translationEndpoint = $0 }
        )
    }

    private var otherPricedModels: [String] {
        let current = [
            model.settings.llm.defaultEndpoint.model,
            model.settings.llm.translationEndpoint.model,
        ].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return model.tokenLedger.modelNames.filter { name in
            !current.contains(name)
        }
    }
}

private enum ChoiceMenuMetrics {
    static let width: CGFloat = 156
    static let height: CGFloat = 32
}

private struct ChoiceMenu<Selection: Hashable, Options: View>: View {
    @Binding var selection: Selection
    @ViewBuilder var options: () -> Options
    var title: () -> Text

    var body: some View {
        Menu {
            Picker(selection: $selection) {
                options()
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
        } label: {
            ZStack {
                title()
                    .lineLimit(1)
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: ChoiceMenuMetrics.width, height: ChoiceMenuMetrics.height)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            }
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        #endif
        .buttonStyle(.plain)
        .frame(width: ChoiceMenuMetrics.width, height: ChoiceMenuMetrics.height, alignment: .trailing)
    }
}

private struct EqualChoiceBar<Selection: Hashable>: View {
    var choices: [Selection]
    @Binding var selection: Selection
    var title: (Selection) -> LocalizedStringKey

    var body: some View {
        HStack(spacing: 2) {
            ForEach(choices, id: \.self) { item in
                segment(item)
            }
        }
        .padding(2)
        .frame(maxWidth: .infinity)
        .frame(height: ChoiceMenuMetrics.height)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
    }

    private func segment(_ item: Selection) -> some View {
        let selected = selection == item
        return Button {
            selection = item
        } label: {
            Text(title(item))
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(selected ? 0.18 : 0))
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ProtocolKindPicker: View {
    @Binding var kind: LLMProtocolKind

    var body: some View {
        HStack(spacing: 2) {
            segment(.openAI, "settings_openai")
            segment(.anthropic, "settings_anthropic")
        }
        .padding(2)
        .frame(maxWidth: .infinity)
        .frame(height: ChoiceMenuMetrics.height)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("settings_protocol")
    }

    private func segment(_ value: LLMProtocolKind, _ title: LocalizedStringKey) -> some View {
        let selected = kind == value
        return Button {
            kind = value
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(selected ? 0.18 : 0))
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ScriptChoice: View {
    @Binding var script: ChineseScript

    var body: some View {
        HStack(spacing: 2) {
            segment(.hans, "settings_hans")
            segment(.hant, "settings_hant")
        }
        .padding(2)
        .frame(width: ChoiceMenuMetrics.width, height: ChoiceMenuMetrics.height)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
    }

    private func segment(_ value: ChineseScript, _ title: LocalizedStringKey) -> some View {
        let selected = script == value
        return Button {
            script = value
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.18))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct EndpointCard: View {
    @Environment(AppModel.self) private var model
    var title: LocalizedStringKey
    var caption: LocalizedStringKey
    @Binding var config: EndpointConfig
    var account: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            EndpointFields(config: $config, account: account)
            Text(tokenLine)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private var tokenLine: String {
        let tally = model.tokenLedger.tally(for: account)
        let input = tally.input.formatted(.number.grouping(.automatic))
        let output = tally.output.formatted(.number.grouping(.automatic))
        return String(format: String(localized: "settings_token_usage"), input, output)
    }
}

private struct EndpointFields: View {
    @Environment(AppModel.self) private var model
    @Binding var config: EndpointConfig
    var account: String
    @State private var secret = ""
    @State private var testing = false
    @State private var message: String?
    @State private var connected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("settings_protocol")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                ProtocolKindPicker(kind: $config.kind)
            }
            LabeledWell(title: "settings_base_url", text: $config.baseURL)
            LabeledWell(title: "settings_model", text: $config.model)
            if !config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ModelPriceFields(modelName: config.model.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            LabeledWell(title: "settings_api_key", text: $secret, secure: true)
            if model.hasKey(account: account) {
                Label("settings_key_saved", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button("settings_save_key") {
                    guard !secret.isEmpty else { return }
                    try? model.saveKey(secret, account: account)
                    secret = ""
                }
                .glassButton(prominent: false)
                .disabled(secret.isEmpty)
                Button("settings_clear_key", role: .destructive) {
                    model.clearKey(account: account)
                    secret = ""
                    message = nil
                }
                .glassButton(prominent: false)
                Spacer(minLength: 0)
                Button {
                    Task { await runTest() }
                } label: {
                    HStack(spacing: 6) {
                        if testing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(testing ? "settings_test_working" : "settings_test_connection")
                    }
                }
                .glassButton(prominent: true)
                .disabled(testing || !canTest)
            }
            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(connected ? Color.green : Color.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var canTest: Bool {
        config.isComplete && (model.hasKey(account: account) || !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func runTest() async {
        let snapshot = config
        let typed = secret
        let unsaved = !typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        testing = true
        connected = false
        message = String(localized: "settings_test_working")
        defer { testing = false }
        do {
            try await model.testEndpoint(snapshot, account: account, typedKey: typed)
            connected = true
            message = String(localized: unsaved ? "settings_test_ok_unsaved" : "settings_test_ok")
        } catch {
            connected = false
            message = error.localizedDescription
        }
    }
}

private struct ModelPriceFields: View {
    @Environment(AppModel.self) private var model
    var modelName: String

    var body: some View {
        let price = priceBinding
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("settings_price_currency")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Picker("settings_price_currency", selection: price.currencyCode) {
                    Text("settings_price_cny").tag("CNY")
                    Text("settings_price_usd").tag("USD")
                }
                .labelsHidden()
                .frame(maxWidth: 180)
            }
            LabeledWell(title: "settings_price_input", text: price.inputPerMillion)
            LabeledWell(title: "settings_price_output", text: price.outputPerMillion)
            Text("settings_price_hint")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var priceBinding: Binding<ModelTokenPrice> {
        Binding(
            get: {
                model.settings.modelPrices.first { $0.model == modelName }
                    ?? ModelTokenPrice(model: modelName)
            },
            set: { next in
                var prices = model.settings.modelPrices.filter { $0.model != modelName }
                var stored = next
                stored.model = modelName
                let blank = stored.inputPerMillion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && stored.outputPerMillion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if !(blank && stored.currencyCode == "CNY") {
                    prices.append(stored)
                }
                model.settings.modelPrices = prices
            }
        )
    }
}

private struct LabeledWell: View {
    var title: LocalizedStringKey
    @Binding var text: String
    var secure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Group {
                if secure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .textFieldStyle(.plain)
            .textInputAutocapitalizationNever()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            }
        }
    }
}

private extension View {
    func textInputAutocapitalizationNever() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }
}

private enum ReviewBandKind: String, CaseIterable, Identifiable {
    case retire
    case multiply
    case keep
    case divide

    var id: String { rawValue }

    static let intervals: [ReviewBandKind] = [.multiply, .keep, .divide]

    var title: LocalizedStringKey {
        switch self {
        case .retire: "settings_review_retire_action"
        case .multiply: "settings_review_multiply_action"
        case .keep: "settings_review_keep_action"
        case .divide: "settings_review_divide_action"
        }
    }

    var usesFactor: Bool {
        self == .multiply || self == .divide
    }

    init(_ change: ReviewChange) {
        switch change {
        case .retire: self = .retire
        case .multiply: self = .multiply
        case .keep: self = .keep
        case .divide: self = .divide
        }
    }

    func change(keeping existing: ReviewChange) -> ReviewChange {
        change(factor: Self.factor(in: existing))
    }

    func change(factor: Int) -> ReviewChange {
        switch self {
        case .retire: .retire
        case .keep: .keep
        case .multiply: .multiply(factor)
        case .divide: .divide(factor)
        }
    }

    static func factor(in change: ReviewChange) -> Int {
        switch change {
        case let .multiply(value), let .divide(value):
            value
        case .retire, .keep:
            ReviewPolicy.factorRange.lowerBound
        }
    }
}
