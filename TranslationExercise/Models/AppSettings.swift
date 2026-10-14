import Foundation
import TranslationCore

struct AppSettings: Codable, Equatable {
    var uiLanguageCode: String?
    var enabledLanguageCodes: [String]
    var activeLanguageCode: String
    var nativeLanguageCode: String
    var script: ChineseScript
    var length: LengthPreset
    var llm: LLMSettings
    var favoriteFolderID: UUID?
    var preferDictionary: Bool
    var dailyTargetZhToForeign: Int
    var dailyTargetForeignToZh: Int
    var reviewRetireScore: Int
    var reviewGrowScore: Int
    var reviewGrowFactor: Int
    var reviewHoldScore: Int
    var reviewShrinkFactor: Int
    var reviewBands: [ReviewBand]
    var modelPrices: [ModelTokenPrice]
    var syncMode: SyncMode
    var webdavURL: String
    var webdavUser: String
    var webdavPath: String
    var settingsRevision: Date

    private enum CodingKeys: String, CodingKey {
        case uiLanguageCode
        case enabledLanguageCodes
        case activeLanguageCode
        case nativeLanguageCode
        case script
        case length
        case llm
        case favoriteFolderID
        case preferDictionary
        case dailyTargetZhToForeign
        case dailyTargetForeignToZh
        case reviewRetireScore
        case reviewGrowScore
        case reviewGrowFactor
        case reviewHoldScore
        case reviewShrinkFactor
        case reviewBands
        case modelPrices
        case syncMode
        case webdavURL
        case webdavUser
        case webdavPath
        case settingsRevision
    }

    static let storageKey = "app.settings.v1"

    init(
        uiLanguageCode: String?,
        enabledLanguageCodes: [String],
        activeLanguageCode: String,
        nativeLanguageCode: String = PracticeLanguage.chinese.rawValue,
        script: ChineseScript,
        length: LengthPreset,
        llm: LLMSettings,
        favoriteFolderID: UUID?,
        preferDictionary: Bool = true,
        dailyTargetZhToForeign: Int = 1,
        dailyTargetForeignToZh: Int = 1,
        reviewRetireScore: Int = ReviewPolicy.standard.retireScore,
        reviewGrowScore: Int = ReviewPolicy.standard.growScore,
        reviewGrowFactor: Int = ReviewPolicy.standard.growFactor,
        reviewHoldScore: Int = ReviewPolicy.standard.holdScore,
        reviewShrinkFactor: Int = ReviewPolicy.standard.shrinkFactor,
        reviewBands: [ReviewBand] = [],
        modelPrices: [ModelTokenPrice] = [],
        syncMode: SyncMode = .off,
        webdavURL: String = "",
        webdavUser: String = "",
        webdavPath: String = "sync.json",
        settingsRevision: Date = .distantPast
    ) {
        self.uiLanguageCode = uiLanguageCode
        self.enabledLanguageCodes = enabledLanguageCodes
        self.activeLanguageCode = activeLanguageCode
        self.nativeLanguageCode = nativeLanguageCode
        self.script = script
        self.length = length
        self.llm = llm
        self.favoriteFolderID = favoriteFolderID
        self.preferDictionary = preferDictionary
        self.dailyTargetZhToForeign = dailyTargetZhToForeign
        self.dailyTargetForeignToZh = dailyTargetForeignToZh
        let policy = Self.reviewPolicy(bands: reviewBands, retireScore: reviewRetireScore, growScore: reviewGrowScore, growFactor: reviewGrowFactor, holdScore: reviewHoldScore, shrinkFactor: reviewShrinkFactor)
        self.reviewBands = policy.bands
        self.reviewRetireScore = policy.retireScore
        self.reviewGrowScore = policy.growScore
        self.reviewGrowFactor = policy.growFactor
        self.reviewHoldScore = policy.holdScore
        self.reviewShrinkFactor = policy.shrinkFactor
        self.modelPrices = modelPrices
        self.syncMode = syncMode
        self.webdavURL = webdavURL
        self.webdavUser = webdavUser
        self.webdavPath = webdavPath
        self.settingsRevision = settingsRevision
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uiLanguageCode = try container.decodeIfPresent(String.self, forKey: .uiLanguageCode)
        enabledLanguageCodes = try container.decode([String].self, forKey: .enabledLanguageCodes)
        activeLanguageCode = try container.decode(String.self, forKey: .activeLanguageCode)
        nativeLanguageCode = try container.decodeIfPresent(String.self, forKey: .nativeLanguageCode) ?? PracticeLanguage.chinese.rawValue
        script = try container.decode(ChineseScript.self, forKey: .script)
        length = try container.decode(LengthPreset.self, forKey: .length)
        llm = try container.decode(LLMSettings.self, forKey: .llm)
        favoriteFolderID = try container.decodeIfPresent(UUID.self, forKey: .favoriteFolderID)
        preferDictionary = try container.decodeIfPresent(Bool.self, forKey: .preferDictionary) ?? true
        let storedNativeTarget = try container.decodeIfPresent(Int.self, forKey: .dailyTargetZhToForeign) ?? 1
        let storedPracticeTarget = try container.decodeIfPresent(Int.self, forKey: .dailyTargetForeignToZh) ?? 1
        if let pair = DailyQuota.accepted(nativeToPractice: storedNativeTarget, practiceToNative: storedPracticeTarget) {
            dailyTargetZhToForeign = pair.nativeToPractice
            dailyTargetForeignToZh = pair.practiceToNative
        } else {
            dailyTargetZhToForeign = 1
            dailyTargetForeignToZh = 1
        }
        let storedPolicy = Self.reviewPolicy(
            bands: try container.decodeIfPresent([ReviewBand].self, forKey: .reviewBands) ?? [],
            retireScore: try container.decodeIfPresent(Int.self, forKey: .reviewRetireScore) ?? ReviewPolicy.standard.retireScore,
            growScore: try container.decodeIfPresent(Int.self, forKey: .reviewGrowScore) ?? ReviewPolicy.standard.growScore,
            growFactor: try container.decodeIfPresent(Int.self, forKey: .reviewGrowFactor) ?? ReviewPolicy.standard.growFactor,
            holdScore: try container.decodeIfPresent(Int.self, forKey: .reviewHoldScore) ?? ReviewPolicy.standard.holdScore,
            shrinkFactor: try container.decodeIfPresent(Int.self, forKey: .reviewShrinkFactor) ?? ReviewPolicy.standard.shrinkFactor
        )
        reviewBands = storedPolicy.bands
        reviewRetireScore = storedPolicy.retireScore
        reviewGrowScore = storedPolicy.growScore
        reviewGrowFactor = storedPolicy.growFactor
        reviewHoldScore = storedPolicy.holdScore
        reviewShrinkFactor = storedPolicy.shrinkFactor
        modelPrices = try container.decodeIfPresent([ModelTokenPrice].self, forKey: .modelPrices) ?? []
        syncMode = try container.decodeIfPresent(SyncMode.self, forKey: .syncMode) ?? .off
        webdavURL = try container.decodeIfPresent(String.self, forKey: .webdavURL) ?? ""
        webdavUser = try container.decodeIfPresent(String.self, forKey: .webdavUser) ?? ""
        webdavPath = try container.decodeIfPresent(String.self, forKey: .webdavPath) ?? "sync.json"
        settingsRevision = try container.decodeIfPresent(Date.self, forKey: .settingsRevision) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(uiLanguageCode, forKey: .uiLanguageCode)
        try container.encode(enabledLanguageCodes, forKey: .enabledLanguageCodes)
        try container.encode(activeLanguageCode, forKey: .activeLanguageCode)
        try container.encode(nativeLanguageCode, forKey: .nativeLanguageCode)
        try container.encode(script, forKey: .script)
        try container.encode(length, forKey: .length)
        try container.encode(llm, forKey: .llm)
        try container.encodeIfPresent(favoriteFolderID, forKey: .favoriteFolderID)
        try container.encode(preferDictionary, forKey: .preferDictionary)
        try container.encode(dailyTargetZhToForeign, forKey: .dailyTargetZhToForeign)
        try container.encode(dailyTargetForeignToZh, forKey: .dailyTargetForeignToZh)
        try container.encode(reviewRetireScore, forKey: .reviewRetireScore)
        try container.encode(reviewGrowScore, forKey: .reviewGrowScore)
        try container.encode(reviewGrowFactor, forKey: .reviewGrowFactor)
        try container.encode(reviewHoldScore, forKey: .reviewHoldScore)
        try container.encode(reviewShrinkFactor, forKey: .reviewShrinkFactor)
        try container.encode(reviewBands, forKey: .reviewBands)
        try container.encode(modelPrices, forKey: .modelPrices)
        try container.encode(syncMode, forKey: .syncMode)
        try container.encode(webdavURL, forKey: .webdavURL)
        try container.encode(webdavUser, forKey: .webdavUser)
        try container.encode(webdavPath, forKey: .webdavPath)
        try container.encode(settingsRevision, forKey: .settingsRevision)
    }

    static var initial: AppSettings {
        AppSettings(
            uiLanguageCode: nil,
            enabledLanguageCodes: [PracticeLanguage.english.rawValue],
            activeLanguageCode: PracticeLanguage.english.rawValue,
            script: .hans,
            length: .medium,
            llm: LLMSettings(),
            favoriteFolderID: nil
        )
    }

    var activeLanguage: PracticeLanguage {
        PracticeLanguage(rawValue: activeLanguageCode) ?? .english
    }

    var enabledLanguages: [PracticeLanguage] {
        enabledLanguageCodes.compactMap(PracticeLanguage.init(rawValue:))
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    var nativeLanguage: PracticeLanguage {
        PracticeLanguage(rawValue: nativeLanguageCode) ?? .chinese
    }

    var reviewPolicy: ReviewPolicy {
        get {
            Self.reviewPolicy(
                bands: reviewBands,
                retireScore: reviewRetireScore,
                growScore: reviewGrowScore,
                growFactor: reviewGrowFactor,
                holdScore: reviewHoldScore,
                shrinkFactor: reviewShrinkFactor
            )
        }
        set {
            let policy = newValue.clamped()
            reviewBands = policy.bands
            reviewRetireScore = policy.retireScore
            reviewGrowScore = policy.growScore
            reviewGrowFactor = policy.growFactor
            reviewHoldScore = policy.holdScore
            reviewShrinkFactor = policy.shrinkFactor
        }
    }

    private static func reviewPolicy(
        bands: [ReviewBand],
        retireScore: Int,
        growScore: Int,
        growFactor: Int,
        holdScore: Int,
        shrinkFactor: Int
    ) -> ReviewPolicy {
        if bands.isEmpty {
            return ReviewPolicy(
                retireScore: retireScore,
                growScore: growScore,
                growFactor: growFactor,
                holdScore: holdScore,
                shrinkFactor: shrinkFactor
            ).clamped()
        }
        return ReviewPolicy(bands: bands).clamped()
    }

    func dailyTarget(for direction: Direction) -> Int {
        switch direction {
        case .zhToForeign: dailyTargetZhToForeign
        case .foreignToZh: dailyTargetForeignToZh
        }
    }

    func directionText(_ direction: Direction) -> String {
        let source = direction.source(native: nativeLanguage, practice: activeLanguage)
        let target = direction.target(native: nativeLanguage, practice: activeLanguage)
        return String(
            format: String(localized: "direction_pair"),
            LanguageTitle.string(source),
            LanguageTitle.string(target)
        )
    }

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return makeFirstLaunch()
        }
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard var settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return makeFirstLaunch()
        }
        var dirty = false
        if object?["settingsRevision"] == nil {
            settings.settingsRevision = Date()
            dirty = true
        }
        if object?["nativeLanguageCode"] == nil {
            settings.nativeLanguageCode = PracticeLanguage.chinese.rawValue
            dirty = true
        }
        if object?["reviewBands"] == nil {
            dirty = true
        }
        if settings.nativeLanguage == settings.activeLanguage {
            settings.activeLanguageCode = PracticeLanguage.fallback(excluding: settings.nativeLanguage).rawValue
            dirty = true
        }
        if dirty { settings.save() }
        return settings
    }

    private static func makeFirstLaunch() -> AppSettings {
        var settings = AppSettings.initial
        let matched = PracticeLanguage.fromSystem(preferredLanguages: Locale.preferredLanguages)
        settings.nativeLanguageCode = matched.language.rawValue
        if matched.language == .chinese {
            settings.script = matched.script
        }
        if settings.activeLanguage == matched.language {
            settings.activeLanguageCode = PracticeLanguage.fallback(excluding: matched.language).rawValue
        }
        settings.settingsRevision = Date()
        settings.save()
        return settings
    }
}

enum SyncMode: String, Codable, CaseIterable, Identifiable {
    case off
    case icloud
    case webdav

    var id: String { rawValue }
}

enum UILanguage: String, CaseIterable, Identifiable {
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en
    case ja
    case ko
    case fr
    case de
    case es

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .zhHans: "ui_zh_hans"
        case .zhHant: "ui_zh_hant"
        case .en: "ui_en"
        case .ja: "ui_ja"
        case .ko: "ui_ko"
        case .fr: "ui_fr"
        case .de: "ui_de"
        case .es: "ui_es"
        }
    }
}
