import Foundation
import SwiftData
import TranslationCore

struct PracticeSyncSettings: Codable, Equatable {
    var nativeLanguageCode: String
    var activeLanguageCode: String
    var enabledLanguageCodes: [String]
    var script: ChineseScript
    var length: LengthPreset
    var preferDictionary: Bool
    var dailyTargetZhToForeign: Int
    var dailyTargetForeignToZh: Int
    var reviewRetireScore: Int
    var reviewGrowScore: Int
    var reviewGrowFactor: Int
    var reviewHoldScore: Int
    var reviewShrinkFactor: Int
    var reviewBands: [ReviewBand]

    enum CodingKeys: String, CodingKey {
        case nativeLanguageCode
        case activeLanguageCode
        case enabledLanguageCodes
        case script
        case length
        case preferDictionary
        case dailyTargetZhToForeign
        case dailyTargetForeignToZh
        case reviewRetireScore
        case reviewGrowScore
        case reviewGrowFactor
        case reviewHoldScore
        case reviewShrinkFactor
        case reviewBands
    }

    init(
        nativeLanguageCode: String,
        activeLanguageCode: String,
        enabledLanguageCodes: [String],
        script: ChineseScript,
        length: LengthPreset,
        preferDictionary: Bool,
        dailyTargetZhToForeign: Int = 1,
        dailyTargetForeignToZh: Int = 1,
        reviewRetireScore: Int = ReviewPolicy.standard.retireScore,
        reviewGrowScore: Int = ReviewPolicy.standard.growScore,
        reviewGrowFactor: Int = ReviewPolicy.standard.growFactor,
        reviewHoldScore: Int = ReviewPolicy.standard.holdScore,
        reviewShrinkFactor: Int = ReviewPolicy.standard.shrinkFactor,
        reviewBands: [ReviewBand] = []
    ) {
        let policy = Self.policy(bands: reviewBands, retireScore: reviewRetireScore, growScore: reviewGrowScore, growFactor: reviewGrowFactor, holdScore: reviewHoldScore, shrinkFactor: reviewShrinkFactor)
        self.nativeLanguageCode = nativeLanguageCode
        self.activeLanguageCode = activeLanguageCode
        self.enabledLanguageCodes = enabledLanguageCodes
        self.script = script
        self.length = length
        self.preferDictionary = preferDictionary
        self.dailyTargetZhToForeign = dailyTargetZhToForeign
        self.dailyTargetForeignToZh = dailyTargetForeignToZh
        self.reviewRetireScore = policy.retireScore
        self.reviewGrowScore = policy.growScore
        self.reviewGrowFactor = policy.growFactor
        self.reviewHoldScore = policy.holdScore
        self.reviewShrinkFactor = policy.shrinkFactor
        self.reviewBands = policy.bands
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nativeLanguageCode = try container.decode(String.self, forKey: .nativeLanguageCode)
        activeLanguageCode = try container.decode(String.self, forKey: .activeLanguageCode)
        enabledLanguageCodes = try container.decode([String].self, forKey: .enabledLanguageCodes)
        script = try container.decode(ChineseScript.self, forKey: .script)
        length = try container.decode(LengthPreset.self, forKey: .length)
        preferDictionary = try container.decodeIfPresent(Bool.self, forKey: .preferDictionary) ?? true
        dailyTargetZhToForeign = try container.decodeIfPresent(Int.self, forKey: .dailyTargetZhToForeign) ?? 1
        dailyTargetForeignToZh = try container.decodeIfPresent(Int.self, forKey: .dailyTargetForeignToZh) ?? 1
        let policy = Self.policy(
            bands: try container.decodeIfPresent([ReviewBand].self, forKey: .reviewBands) ?? [],
            retireScore: try container.decodeIfPresent(Int.self, forKey: .reviewRetireScore) ?? ReviewPolicy.standard.retireScore,
            growScore: try container.decodeIfPresent(Int.self, forKey: .reviewGrowScore) ?? ReviewPolicy.standard.growScore,
            growFactor: try container.decodeIfPresent(Int.self, forKey: .reviewGrowFactor) ?? ReviewPolicy.standard.growFactor,
            holdScore: try container.decodeIfPresent(Int.self, forKey: .reviewHoldScore) ?? ReviewPolicy.standard.holdScore,
            shrinkFactor: try container.decodeIfPresent(Int.self, forKey: .reviewShrinkFactor) ?? ReviewPolicy.standard.shrinkFactor
        )
        reviewRetireScore = policy.retireScore
        reviewGrowScore = policy.growScore
        reviewGrowFactor = policy.growFactor
        reviewHoldScore = policy.holdScore
        reviewShrinkFactor = policy.shrinkFactor
        reviewBands = policy.bands
    }

    private static func policy(
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nativeLanguageCode, forKey: .nativeLanguageCode)
        try container.encode(activeLanguageCode, forKey: .activeLanguageCode)
        try container.encode(enabledLanguageCodes, forKey: .enabledLanguageCodes)
        try container.encode(script, forKey: .script)
        try container.encode(length, forKey: .length)
        try container.encode(preferDictionary, forKey: .preferDictionary)
        try container.encode(dailyTargetZhToForeign, forKey: .dailyTargetZhToForeign)
        try container.encode(dailyTargetForeignToZh, forKey: .dailyTargetForeignToZh)
        try container.encode(reviewRetireScore, forKey: .reviewRetireScore)
        try container.encode(reviewGrowScore, forKey: .reviewGrowScore)
        try container.encode(reviewGrowFactor, forKey: .reviewGrowFactor)
        try container.encode(reviewHoldScore, forKey: .reviewHoldScore)
        try container.encode(reviewShrinkFactor, forKey: .reviewShrinkFactor)
        try container.encode(reviewBands, forKey: .reviewBands)
    }
}

struct ExerciseRecord: Codable {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var dailyKey: String?
    var languageCode: String
    var directionRaw: String
    var kindRaw: String
    var topic: String
    var sourceText: String
    var userDraft: String
    var submitted: Bool
    var userText: String
    var correctedText: String
    var exemplarText: String
    var faithfulness: Int
    var expressiveness: Int
    var elegance: Int
    var weightedScore: Int
    var exemplarFaithfulness: Int
    var exemplarExpressiveness: Int
    var exemplarElegance: Int
    var exemplarWeightedScore: Int
    var errorTags: [String]
    var editNotesJSON: String

    enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, dailyKey, languageCode, directionRaw, kindRaw, topic, sourceText
        case userDraft, submitted, userText, correctedText, exemplarText
        case faithfulness, expressiveness, elegance, weightedScore
        case exemplarFaithfulness, exemplarExpressiveness, exemplarElegance, exemplarWeightedScore
        case errorTags, editNotesJSON
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        dailyKey = try container.decodeIfPresent(String.self, forKey: .dailyKey)
        languageCode = try container.decode(String.self, forKey: .languageCode)
        directionRaw = try container.decode(String.self, forKey: .directionRaw)
        kindRaw = try container.decode(String.self, forKey: .kindRaw)
        topic = try container.decode(String.self, forKey: .topic)
        sourceText = try container.decode(String.self, forKey: .sourceText)
        userDraft = try container.decodeIfPresent(String.self, forKey: .userDraft) ?? ""
        submitted = try container.decodeIfPresent(Bool.self, forKey: .submitted) ?? false
        userText = try container.decodeIfPresent(String.self, forKey: .userText) ?? ""
        correctedText = try container.decodeIfPresent(String.self, forKey: .correctedText) ?? ""
        exemplarText = try container.decodeIfPresent(String.self, forKey: .exemplarText) ?? ""
        faithfulness = try container.decodeIfPresent(Int.self, forKey: .faithfulness) ?? 0
        expressiveness = try container.decodeIfPresent(Int.self, forKey: .expressiveness) ?? 0
        elegance = try container.decodeIfPresent(Int.self, forKey: .elegance) ?? 0
        weightedScore = try container.decodeIfPresent(Int.self, forKey: .weightedScore) ?? 0
        exemplarFaithfulness = try container.decodeIfPresent(Int.self, forKey: .exemplarFaithfulness) ?? 0
        exemplarExpressiveness = try container.decodeIfPresent(Int.self, forKey: .exemplarExpressiveness) ?? 0
        exemplarElegance = try container.decodeIfPresent(Int.self, forKey: .exemplarElegance) ?? 0
        exemplarWeightedScore = try container.decodeIfPresent(Int.self, forKey: .exemplarWeightedScore) ?? 0
        errorTags = try container.decodeIfPresent([String].self, forKey: .errorTags) ?? []
        editNotesJSON = try container.decodeIfPresent(String.self, forKey: .editNotesJSON) ?? ""
    }

    init(
        id: UUID,
        createdAt: Date,
        updatedAt: Date,
        dailyKey: String?,
        languageCode: String,
        directionRaw: String,
        kindRaw: String,
        topic: String,
        sourceText: String,
        userDraft: String,
        submitted: Bool,
        userText: String,
        correctedText: String,
        exemplarText: String,
        faithfulness: Int,
        expressiveness: Int,
        elegance: Int,
        weightedScore: Int,
        exemplarFaithfulness: Int,
        exemplarExpressiveness: Int,
        exemplarElegance: Int,
        exemplarWeightedScore: Int,
        errorTags: [String],
        editNotesJSON: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dailyKey = dailyKey
        self.languageCode = languageCode
        self.directionRaw = directionRaw
        self.kindRaw = kindRaw
        self.topic = topic
        self.sourceText = sourceText
        self.userDraft = userDraft
        self.submitted = submitted
        self.userText = userText
        self.correctedText = correctedText
        self.exemplarText = exemplarText
        self.faithfulness = faithfulness
        self.expressiveness = expressiveness
        self.elegance = elegance
        self.weightedScore = weightedScore
        self.exemplarFaithfulness = exemplarFaithfulness
        self.exemplarExpressiveness = exemplarExpressiveness
        self.exemplarElegance = exemplarElegance
        self.exemplarWeightedScore = exemplarWeightedScore
        self.errorTags = errorTags
        self.editNotesJSON = editNotesJSON
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(dailyKey, forKey: .dailyKey)
        try container.encode(languageCode, forKey: .languageCode)
        try container.encode(directionRaw, forKey: .directionRaw)
        try container.encode(kindRaw, forKey: .kindRaw)
        try container.encode(topic, forKey: .topic)
        try container.encode(sourceText, forKey: .sourceText)
        try container.encode(userDraft, forKey: .userDraft)
        try container.encode(submitted, forKey: .submitted)
        try container.encode(userText, forKey: .userText)
        try container.encode(correctedText, forKey: .correctedText)
        try container.encode(exemplarText, forKey: .exemplarText)
        try container.encode(faithfulness, forKey: .faithfulness)
        try container.encode(expressiveness, forKey: .expressiveness)
        try container.encode(elegance, forKey: .elegance)
        try container.encode(weightedScore, forKey: .weightedScore)
        try container.encode(exemplarFaithfulness, forKey: .exemplarFaithfulness)
        try container.encode(exemplarExpressiveness, forKey: .exemplarExpressiveness)
        try container.encode(exemplarElegance, forKey: .exemplarElegance)
        try container.encode(exemplarWeightedScore, forKey: .exemplarWeightedScore)
        try container.encode(errorTags, forKey: .errorTags)
        try container.encode(editNotesJSON, forKey: .editNotesJSON)
    }
}

struct SkillRecord: Codable {
    var languageCode: String
    var directionRaw: String
    var level: Int
    var placementDone: Bool
    var placementStep: Int
    var recentSources: [String]
    var updatedAt: Date
}

struct StreakSyncRecord: Codable {
    var current: Int
    var lastCompletedDay: Date?
    var lastCelebratedMultiple: Int
    var updatedAt: Date
    var shields: Int
    var shieldsGrantedForRun: Int
    var shieldedDayKeys: [String]

    enum CodingKeys: String, CodingKey {
        case current, lastCompletedDay, lastCelebratedMultiple, updatedAt
        case shields, shieldsGrantedForRun, shieldedDayKeys
    }

    init(
        current: Int,
        lastCompletedDay: Date?,
        lastCelebratedMultiple: Int,
        updatedAt: Date,
        shields: Int,
        shieldsGrantedForRun: Int,
        shieldedDayKeys: [String]
    ) {
        self.current = current
        self.lastCompletedDay = lastCompletedDay
        self.lastCelebratedMultiple = lastCelebratedMultiple
        self.updatedAt = updatedAt
        self.shields = shields
        self.shieldsGrantedForRun = shieldsGrantedForRun
        self.shieldedDayKeys = shieldedDayKeys
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        current = try container.decode(Int.self, forKey: .current)
        lastCompletedDay = try container.decodeIfPresent(Date.self, forKey: .lastCompletedDay)
        lastCelebratedMultiple = try container.decodeIfPresent(Int.self, forKey: .lastCelebratedMultiple) ?? 0
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        shields = try container.decodeIfPresent(Int.self, forKey: .shields) ?? 0
        shieldsGrantedForRun = try container.decodeIfPresent(Int.self, forKey: .shieldsGrantedForRun) ?? 0
        shieldedDayKeys = try container.decodeIfPresent([String].self, forKey: .shieldedDayKeys) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(current, forKey: .current)
        try container.encodeIfPresent(lastCompletedDay, forKey: .lastCompletedDay)
        try container.encode(lastCelebratedMultiple, forKey: .lastCelebratedMultiple)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(shields, forKey: .shields)
        try container.encode(shieldsGrantedForRun, forKey: .shieldsGrantedForRun)
        try container.encode(shieldedDayKeys, forKey: .shieldedDayKeys)
    }
}

struct FolderRecord: Codable {
    var id: UUID
    var name: String
    var parentID: UUID?
    var pinned: Bool
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date
}

struct FavoriteRecord: Codable {
    var id: UUID
    var folderID: UUID?
    var pinned: Bool
    var createdAt: Date
    var sourceAttemptID: UUID?
    var languageCode: String
    var directionRaw: String
    var topic: String
    var sourceText: String
    var userText: String
    var correctedText: String
    var exemplarText: String
    var weightedScore: Int
    var faithfulness: Int
    var expressiveness: Int
    var elegance: Int
    var exemplarWeightedScore: Int
    var exemplarFaithfulness: Int
    var exemplarExpressiveness: Int
    var exemplarElegance: Int
    var exerciseDate: Date
    var updatedAt: Date
}

struct ReviewAttemptRecord: Codable {
    var id: UUID
    var exerciseID: UUID
    var createdAt: Date
    var updatedAt: Date
    var userText: String
    var correctedText: String
    var faithfulness: Int
    var expressiveness: Int
    var elegance: Int
    var weightedScore: Int
    var directionRaw: String
    var languageCode: String
    var intervalDays: Int
    var dueDay: Date
    var editNotesJSON: String

    enum CodingKeys: String, CodingKey {
        case id, exerciseID, createdAt, updatedAt
        case userText, correctedText
        case faithfulness, expressiveness, elegance, weightedScore
        case directionRaw, languageCode
        case intervalDays, dueDay, editNotesJSON
    }

    init(
        id: UUID,
        exerciseID: UUID,
        createdAt: Date,
        updatedAt: Date,
        userText: String,
        correctedText: String,
        faithfulness: Int,
        expressiveness: Int,
        elegance: Int,
        weightedScore: Int,
        directionRaw: String,
        languageCode: String,
        intervalDays: Int,
        dueDay: Date,
        editNotesJSON: String = ""
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.userText = userText
        self.correctedText = correctedText
        self.faithfulness = faithfulness
        self.expressiveness = expressiveness
        self.elegance = elegance
        self.weightedScore = weightedScore
        self.directionRaw = directionRaw
        self.languageCode = languageCode
        self.intervalDays = intervalDays
        self.dueDay = dueDay
        self.editNotesJSON = editNotesJSON
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        exerciseID = try container.decode(UUID.self, forKey: .exerciseID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        userText = try container.decodeIfPresent(String.self, forKey: .userText) ?? ""
        correctedText = try container.decodeIfPresent(String.self, forKey: .correctedText) ?? ""
        faithfulness = try container.decodeIfPresent(Int.self, forKey: .faithfulness) ?? 0
        expressiveness = try container.decodeIfPresent(Int.self, forKey: .expressiveness) ?? 0
        elegance = try container.decodeIfPresent(Int.self, forKey: .elegance) ?? 0
        weightedScore = try container.decodeIfPresent(Int.self, forKey: .weightedScore) ?? 0
        directionRaw = try container.decodeIfPresent(String.self, forKey: .directionRaw) ?? Direction.zhToForeign.rawValue
        languageCode = try container.decodeIfPresent(String.self, forKey: .languageCode) ?? ""
        intervalDays = try container.decodeIfPresent(Int.self, forKey: .intervalDays) ?? 1
        dueDay = try container.decodeIfPresent(Date.self, forKey: .dueDay) ?? createdAt
        editNotesJSON = try container.decodeIfPresent(String.self, forKey: .editNotesJSON) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(exerciseID, forKey: .exerciseID)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(userText, forKey: .userText)
        try container.encode(correctedText, forKey: .correctedText)
        try container.encode(faithfulness, forKey: .faithfulness)
        try container.encode(expressiveness, forKey: .expressiveness)
        try container.encode(elegance, forKey: .elegance)
        try container.encode(weightedScore, forKey: .weightedScore)
        try container.encode(directionRaw, forKey: .directionRaw)
        try container.encode(languageCode, forKey: .languageCode)
        try container.encode(intervalDays, forKey: .intervalDays)
        try container.encode(dueDay, forKey: .dueDay)
        try container.encode(editNotesJSON, forKey: .editNotesJSON)
    }
}

struct PhrasePairRecord: Codable {
    var id: UUID
    var exerciseID: UUID
    var createdAt: Date
    var updatedAt: Date
    var languageCode: String
    var directionRaw: String
    var promptText: String
    var answerText: String
}

struct PhraseReviewRecord: Codable {
    var id: UUID
    var phraseID: UUID
    var createdAt: Date
    var updatedAt: Date
    var remembered: Bool
    var intervalDays: Int
    var dueDay: Date
}

enum SyncCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func body<T: Encodable>(_ value: T) throws -> Data {
        try encoder().encode(value)
    }

    static func value<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder().decode(type, from: data)
    }
}

private final class DataBox: @unchecked Sendable {
    var data: Data?
}

enum SyncFailure: LocalizedError {
    case iCloudUnavailable
    case webdavAddress
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            String(localized: "sync_error_icloud")
        case .webdavAddress:
            String(localized: "sync_error_webdav_address")
        case .transport(let message):
            message
        }
    }
}

enum SyncTransport {
    static func download(settings: AppSettings, password: String) async throws -> Data? {
        switch settings.syncMode {
        case .off:
            return nil
        case .icloud:
            return try await iCloudDownload()
        case .webdav:
            return try await webdavDownload(settings: settings, password: password)
        }
    }

    static func upload(settings: AppSettings, password: String, data: Data) async throws {
        switch settings.syncMode {
        case .off:
            return
        case .icloud:
            try await iCloudUpload(data)
        case .webdav:
            try await webdavUpload(settings: settings, password: password, data: data)
        }
    }

    private static func iCloudFile() throws -> URL {
        guard let base = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.app.translationexercise.daily") else {
            throw SyncFailure.iCloudUnavailable
        }
        let folder = base.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("sync.json")
    }

    private static func iCloudDownload() async throws -> Data? {
        let file = try iCloudFile()
        if !FileManager.default.fileExists(atPath: file.path) {
            return nil
        }
        let box = DataBox()
        try await coordinate(file, writing: false) { url in
            box.data = try Data(contentsOf: url)
        }
        return box.data
    }

    private static func iCloudUpload(_ data: Data) async throws {
        let file = try iCloudFile()
        try await coordinate(file, writing: true) { url in
            try data.write(to: url, options: .atomic)
        }
    }

    private static func coordinate(_ file: URL, writing: Bool, body: @escaping (URL) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .utility).async {
                var coordinationError: NSError?
                let coordinator = NSFileCoordinator()
                let options: NSFileCoordinator.ReadingOptions = writing ? [] : []
                var finished = false
                if writing {
                    coordinator.coordinate(writingItemAt: file, options: .forReplacing, error: &coordinationError) { url in
                        finished = true
                        do {
                            try body(url)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                } else {
                    coordinator.coordinate(readingItemAt: file, options: options, error: &coordinationError) { url in
                        finished = true
                        do {
                            try body(url)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                if !finished {
                    continuation.resume(throwing: coordinationError ?? SyncFailure.iCloudUnavailable)
                }
            }
        }
    }

    private static func webdavFile(settings: AppSettings) throws -> URL {
        let root = settings.webdavURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = settings.webdavPath.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: root), components.scheme == "https" || components.scheme == "http" else {
            throw SyncFailure.webdavAddress
        }
        let basePath = components.path.hasSuffix("/") ? components.path : components.path + "/"
        components.path = basePath + (path.isEmpty ? "sync.json" : path)
        guard let url = components.url else { throw SyncFailure.webdavAddress }
        return url
    }

    private static func authorized(_ request: URLRequest, settings: AppSettings, password: String) -> URLRequest {
        var request = request
        let token = Data("\(settings.webdavUser):\(password)".utf8).base64EncodedString()
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private static func webdavDownload(settings: AppSettings, password: String) async throws -> Data? {
        let url = try webdavFile(settings: settings)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request = authorized(request, settings: settings, password: password)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncFailure.transport(String(localized: "sync_error_transport")) }
        if http.statusCode == 404 { return nil }
        guard (200...299).contains(http.statusCode) else {
            throw SyncFailure.transport(String(format: String(localized: "sync_error_status"), http.statusCode))
        }
        return data
    }

    private static func webdavUpload(settings: AppSettings, password: String, data: Data) async throws {
        let url = try webdavFile(settings: settings)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request = authorized(request, settings: settings, password: password)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) || http.statusCode == 201 || http.statusCode == 204 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw SyncFailure.transport(String(format: String(localized: "sync_error_status"), code))
        }
    }
}

extension AppModel {
    func syncNow() async {
        guard settings.syncMode != .off, !syncing else { return }
        syncing = true
        defer { syncing = false }
        do {
            let local = try exportSyncRecords()
            let remoteData = try await SyncTransport.download(settings: settings, password: webdavPassword)
            let remote = try remoteData.map { try SyncCoding.decoder().decode(SyncFile.self, from: $0).records } ?? []
            let merged = SyncMerge.merge(local: local, remote: remote)
            try applySyncRecords(merged)
            let file = try SyncCoding.encoder().encode(SyncFile(records: merged))
            try await SyncTransport.upload(settings: settings, password: webdavPassword, data: file)
            lastSyncAt = Date()
            syncStatus = nil
        } catch {
            syncStatus = error.localizedDescription
        }
    }

    func noteDeletion(kind: String, recordID: String) {
        let mark = DeletionMark(kind: kind, recordID: recordID)
        context.insert(mark)
    }

    private func exportSyncRecords() throws -> [SyncRecord] {
        var records: [SyncRecord] = []
        for exercise in allExercises() where exercise.kind != .ready {
            let body = ExerciseRecord(
                id: exercise.id,
                createdAt: exercise.createdAt,
                updatedAt: exercise.updatedAt,
                dailyKey: exercise.dailyKey,
                languageCode: exercise.languageCode,
                directionRaw: exercise.directionRaw,
                kindRaw: exercise.kindRaw,
                topic: exercise.topic,
                sourceText: exercise.sourceText,
                userDraft: exercise.userDraft,
                submitted: exercise.submitted,
                userText: exercise.userText,
                correctedText: exercise.correctedText,
                exemplarText: exercise.exemplarText,
                faithfulness: exercise.faithfulness,
                expressiveness: exercise.expressiveness,
                elegance: exercise.elegance,
                weightedScore: exercise.weightedScore,
                exemplarFaithfulness: exercise.exemplarFaithfulness,
                exemplarExpressiveness: exercise.exemplarExpressiveness,
                exemplarElegance: exercise.exemplarElegance,
                exemplarWeightedScore: exercise.exemplarWeightedScore,
                errorTags: exercise.errorTags,
                editNotesJSON: exercise.editNotesJSON
            )
            records.append(SyncRecord(kind: "exercise", id: exercise.id.uuidString, updatedAt: exercise.updatedAt, body: try SyncCoding.body(body)))
        }
        for attempt in allReviewAttempts() {
            let body = ReviewAttemptRecord(
                id: attempt.id,
                exerciseID: attempt.exerciseID,
                createdAt: attempt.createdAt,
                updatedAt: attempt.updatedAt,
                userText: attempt.userText,
                correctedText: attempt.correctedText,
                faithfulness: attempt.faithfulness,
                expressiveness: attempt.expressiveness,
                elegance: attempt.elegance,
                weightedScore: attempt.weightedScore,
                directionRaw: attempt.directionRaw,
                languageCode: attempt.languageCode,
                intervalDays: attempt.intervalDays,
                dueDay: attempt.dueDay,
                editNotesJSON: attempt.editNotesJSON
            )
            records.append(SyncRecord(kind: "review", id: attempt.id.uuidString, updatedAt: attempt.updatedAt, body: try SyncCoding.body(body)))
        }
        for phrase in allPhrases() {
            let body = PhrasePairRecord(
                id: phrase.id,
                exerciseID: phrase.exerciseID,
                createdAt: phrase.createdAt,
                updatedAt: phrase.updatedAt,
                languageCode: phrase.languageCode,
                directionRaw: phrase.directionRaw,
                promptText: phrase.promptText,
                answerText: phrase.answerText
            )
            records.append(SyncRecord(kind: "phrase", id: phrase.id.uuidString, updatedAt: phrase.updatedAt, body: try SyncCoding.body(body)))
        }
        for review in allPhraseReviews() {
            let body = PhraseReviewRecord(
                id: review.id,
                phraseID: review.phraseID,
                createdAt: review.createdAt,
                updatedAt: review.updatedAt,
                remembered: review.remembered,
                intervalDays: review.intervalDays,
                dueDay: review.dueDay
            )
            records.append(SyncRecord(kind: "phraseReview", id: review.id.uuidString, updatedAt: review.updatedAt, body: try SyncCoding.body(body)))
        }
        for skill in allSkills() {
            let body = SkillRecord(
                languageCode: skill.languageCode,
                directionRaw: skill.directionRaw,
                level: skill.level,
                placementDone: skill.placementDone,
                placementStep: skill.placementStep,
                recentSources: skill.recentSources,
                updatedAt: skill.updatedAt
            )
            let id = "\(skill.languageCode)|\(skill.directionRaw)"
            records.append(SyncRecord(kind: "skill", id: id, updatedAt: skill.updatedAt, body: try SyncCoding.body(body)))
        }
        if let streak = streakRecord() {
            let body = StreakSyncRecord(
                current: streak.current,
                lastCompletedDay: streak.lastCompletedDay,
                lastCelebratedMultiple: streak.lastCelebratedMultiple,
                updatedAt: streak.updatedAt,
                shields: streak.shields,
                shieldsGrantedForRun: streak.shieldsGrantedForRun,
                shieldedDayKeys: streak.shieldedDayKeys
            )
            records.append(SyncRecord(kind: "streak", id: "main", updatedAt: streak.updatedAt, body: try SyncCoding.body(body)))
        }
        for folder in allFolders() {
            let body = FolderRecord(
                id: folder.id,
                name: folder.name,
                parentID: folder.parentID,
                pinned: folder.pinned,
                sortIndex: folder.sortIndex,
                createdAt: folder.createdAt,
                updatedAt: folder.updatedAt
            )
            records.append(SyncRecord(kind: "folder", id: folder.id.uuidString, updatedAt: folder.updatedAt, body: try SyncCoding.body(body)))
        }
        for item in allItems() {
            let body = FavoriteRecord(
                id: item.id,
                folderID: item.folderID,
                pinned: item.pinned,
                createdAt: item.createdAt,
                sourceAttemptID: item.sourceAttemptID,
                languageCode: item.languageCode,
                directionRaw: item.directionRaw,
                topic: item.topic,
                sourceText: item.sourceText,
                userText: item.userText,
                correctedText: item.correctedText,
                exemplarText: item.exemplarText,
                weightedScore: item.weightedScore,
                faithfulness: item.faithfulness,
                expressiveness: item.expressiveness,
                elegance: item.elegance,
                exemplarWeightedScore: item.exemplarWeightedScore,
                exemplarFaithfulness: item.exemplarFaithfulness,
                exemplarExpressiveness: item.exemplarExpressiveness,
                exemplarElegance: item.exemplarElegance,
                exerciseDate: item.exerciseDate,
                updatedAt: item.updatedAt
            )
            records.append(SyncRecord(kind: "favorite", id: item.id.uuidString, updatedAt: item.updatedAt, body: try SyncCoding.body(body)))
        }
        let practice = PracticeSyncSettings(
            nativeLanguageCode: settings.nativeLanguageCode,
            activeLanguageCode: settings.activeLanguageCode,
            enabledLanguageCodes: settings.enabledLanguageCodes,
            script: settings.script,
            length: settings.length,
            preferDictionary: settings.preferDictionary,
            dailyTargetZhToForeign: settings.dailyTargetZhToForeign,
            dailyTargetForeignToZh: settings.dailyTargetForeignToZh,
            reviewRetireScore: settings.reviewRetireScore,
            reviewGrowScore: settings.reviewGrowScore,
            reviewGrowFactor: settings.reviewGrowFactor,
            reviewHoldScore: settings.reviewHoldScore,
            reviewShrinkFactor: settings.reviewShrinkFactor,
            reviewBands: settings.reviewBands
        )
        records.append(SyncRecord(kind: "settings", id: "practice", updatedAt: settings.settingsRevision, body: try SyncCoding.body(practice)))
        for mark in allDeletionMarks() {
            records.append(SyncRecord(kind: mark.kind, id: mark.recordID, updatedAt: mark.deletedAt, deletedAt: mark.deletedAt))
        }
        return records
    }

    private func applySyncRecords(_ records: [SyncRecord]) throws {
        for record in records where record.deletedAt != nil {
            removeLocal(kind: record.kind, id: record.id, at: record.deletedAt ?? record.updatedAt)
            rememberDeletion(kind: record.kind, id: record.id, at: record.deletedAt ?? record.updatedAt)
        }
        for record in records where record.deletedAt == nil {
            forgetDeletion(kind: record.kind, id: record.id)
            try restore(record)
        }
        save()
    }

    private func restore(_ record: SyncRecord) throws {
        switch record.kind {
        case "exercise":
            let body = try SyncCoding.value(ExerciseRecord.self, from: record.body)
            let exercise: Exercise
            if let existing = allExercises().first(where: { $0.id == body.id }) {
                exercise = existing
            } else {
                exercise = Exercise(
                    id: body.id,
                    createdAt: body.createdAt,
                    dailyKey: body.dailyKey,
                    languageCode: body.languageCode,
                    direction: Direction(rawValue: body.directionRaw) ?? .zhToForeign,
                    kind: ExerciseKind(rawValue: body.kindRaw) ?? .daily,
                    topic: body.topic,
                    sourceText: body.sourceText
                )
                context.insert(exercise)
            }
            exercise.createdAt = body.createdAt
            exercise.updatedAt = body.updatedAt
            exercise.dailyKey = body.dailyKey
            exercise.languageCode = body.languageCode
            exercise.directionRaw = body.directionRaw
            exercise.kindRaw = body.kindRaw
            exercise.topic = body.topic
            exercise.sourceText = body.sourceText
            exercise.userDraft = body.userDraft
            exercise.submitted = body.submitted
            exercise.userText = body.userText
            exercise.correctedText = body.correctedText
            exercise.exemplarText = body.exemplarText
            exercise.faithfulness = body.faithfulness
            exercise.expressiveness = body.expressiveness
            exercise.elegance = body.elegance
            exercise.weightedScore = body.weightedScore
            exercise.exemplarFaithfulness = body.exemplarFaithfulness
            exercise.exemplarExpressiveness = body.exemplarExpressiveness
            exercise.exemplarElegance = body.exemplarElegance
            exercise.exemplarWeightedScore = body.exemplarWeightedScore
            exercise.errorTags = body.errorTags
            exercise.editNotesJSON = body.editNotesJSON
        case "review":
            let body = try SyncCoding.value(ReviewAttemptRecord.self, from: record.body)
            let attempt = allReviewAttempts().first { $0.id == body.id } ?? {
                let created = ReviewAttempt(
                    id: body.id,
                    exerciseID: body.exerciseID,
                    createdAt: body.createdAt,
                    userText: body.userText,
                    correctedText: body.correctedText,
                    faithfulness: body.faithfulness,
                    expressiveness: body.expressiveness,
                    elegance: body.elegance,
                    weightedScore: body.weightedScore,
                    direction: Direction(rawValue: body.directionRaw) ?? .zhToForeign,
                    languageCode: body.languageCode,
                    intervalDays: body.intervalDays,
                    dueDay: body.dueDay
                )
                context.insert(created)
                return created
            }()
            attempt.exerciseID = body.exerciseID
            attempt.createdAt = body.createdAt
            attempt.updatedAt = body.updatedAt
            attempt.userText = body.userText
            attempt.correctedText = body.correctedText
            attempt.faithfulness = body.faithfulness
            attempt.expressiveness = body.expressiveness
            attempt.elegance = body.elegance
            attempt.weightedScore = body.weightedScore
            attempt.directionRaw = body.directionRaw
            attempt.languageCode = body.languageCode
            attempt.intervalDays = body.intervalDays
            attempt.dueDay = body.dueDay
            attempt.editNotesJSON = body.editNotesJSON
        case "phrase":
            let body = try SyncCoding.value(PhrasePairRecord.self, from: record.body)
            let phrase = allPhrases().first { $0.id == body.id } ?? {
                let created = PhrasePair(
                    id: body.id,
                    exerciseID: body.exerciseID,
                    createdAt: body.createdAt,
                    languageCode: body.languageCode,
                    direction: Direction(rawValue: body.directionRaw) ?? .zhToForeign,
                    promptText: body.promptText,
                    answerText: body.answerText
                )
                context.insert(created)
                return created
            }()
            phrase.exerciseID = body.exerciseID
            phrase.createdAt = body.createdAt
            phrase.updatedAt = body.updatedAt
            phrase.languageCode = body.languageCode
            phrase.directionRaw = body.directionRaw
            phrase.promptText = body.promptText
            phrase.answerText = body.answerText
        case "phraseReview":
            let body = try SyncCoding.value(PhraseReviewRecord.self, from: record.body)
            let review = allPhraseReviews().first { $0.id == body.id } ?? {
                let created = PhraseReview(
                    id: body.id,
                    phraseID: body.phraseID,
                    createdAt: body.createdAt,
                    remembered: body.remembered,
                    intervalDays: body.intervalDays,
                    dueDay: body.dueDay
                )
                context.insert(created)
                return created
            }()
            review.phraseID = body.phraseID
            review.createdAt = body.createdAt
            review.updatedAt = body.updatedAt
            review.remembered = body.remembered
            review.intervalDays = body.intervalDays
            review.dueDay = body.dueDay
        case "skill":
            let body = try SyncCoding.value(SkillRecord.self, from: record.body)
            let direction = Direction(rawValue: body.directionRaw) ?? .zhToForeign
            let language = PracticeLanguage(rawValue: body.languageCode) ?? .english
            let skill = skill(language: language, direction: direction)
            skill.level = body.level
            skill.placementDone = body.placementDone
            skill.placementStep = body.placementStep
            skill.recentSources = body.recentSources
            skill.updatedAt = body.updatedAt
        case "streak":
            let body = try SyncCoding.value(StreakSyncRecord.self, from: record.body)
            let streak = streakRecord() ?? {
                let created = StreakRecord()
                context.insert(created)
                return created
            }()
            streak.current = body.current
            streak.lastCompletedDay = body.lastCompletedDay
            streak.lastCelebratedMultiple = body.lastCelebratedMultiple
            streak.shields = body.shields
            streak.shieldsGrantedForRun = body.shieldsGrantedForRun
            streak.shieldedDayKeys = body.shieldedDayKeys
            streak.updatedAt = body.updatedAt
        case "folder":
            let body = try SyncCoding.value(FolderRecord.self, from: record.body)
            let folder = allFolders().first { $0.id == body.id } ?? {
                let created = FavoriteFolder(name: body.name, parentID: body.parentID, sortIndex: body.sortIndex)
                created.id = body.id
                context.insert(created)
                return created
            }()
            folder.name = body.name
            folder.parentID = body.parentID
            folder.pinned = body.pinned
            folder.sortIndex = body.sortIndex
            folder.createdAt = body.createdAt
            folder.updatedAt = body.updatedAt
        case "favorite":
            let body = try SyncCoding.value(FavoriteRecord.self, from: record.body)
            let item = allItems().first { $0.id == body.id } ?? {
                let placeholder = Exercise(languageCode: body.languageCode, direction: .zhToForeign, kind: .extra, topic: "", sourceText: "")
                let created = FavoriteItem(folderID: body.folderID, exercise: placeholder)
                created.id = body.id
                context.insert(created)
                return created
            }()
            item.folderID = body.folderID
            item.pinned = body.pinned
            item.createdAt = body.createdAt
            item.sourceAttemptID = body.sourceAttemptID
            item.languageCode = body.languageCode
            item.directionRaw = body.directionRaw
            item.topic = body.topic
            item.sourceText = body.sourceText
            item.userText = body.userText
            item.correctedText = body.correctedText
            item.exemplarText = body.exemplarText
            item.weightedScore = body.weightedScore
            item.faithfulness = body.faithfulness
            item.expressiveness = body.expressiveness
            item.elegance = body.elegance
            item.exemplarWeightedScore = body.exemplarWeightedScore
            item.exemplarFaithfulness = body.exemplarFaithfulness
            item.exemplarExpressiveness = body.exemplarExpressiveness
            item.exemplarElegance = body.exemplarElegance
            item.exerciseDate = body.exerciseDate
            item.updatedAt = body.updatedAt
        case "settings":
            let body = try SyncCoding.value(PracticeSyncSettings.self, from: record.body)
            guard record.updatedAt > settings.settingsRevision else { return }
            settings.nativeLanguageCode = body.nativeLanguageCode
            settings.activeLanguageCode = body.activeLanguageCode
            settings.enabledLanguageCodes = body.enabledLanguageCodes
            settings.script = body.script
            settings.length = body.length
            settings.preferDictionary = body.preferDictionary
            if let pair = DailyQuota.accepted(nativeToPractice: body.dailyTargetZhToForeign, practiceToNative: body.dailyTargetForeignToZh) {
                settings.dailyTargetZhToForeign = pair.nativeToPractice
                settings.dailyTargetForeignToZh = pair.practiceToNative
            }
            settings.reviewPolicy = body.reviewBands.isEmpty
                ? ReviewPolicy(
                    retireScore: body.reviewRetireScore,
                    growScore: body.reviewGrowScore,
                    growFactor: body.reviewGrowFactor,
                    holdScore: body.reviewHoldScore,
                    shrinkFactor: body.reviewShrinkFactor
                )
                : ReviewPolicy(bands: body.reviewBands)
            settings.settingsRevision = record.updatedAt
            if settings.nativeLanguage == settings.activeLanguage {
                settings.activeLanguageCode = PracticeLanguage.fallback(excluding: settings.nativeLanguage).rawValue
            }
        default:
            break
        }
    }

    func tombstoneReviews(of exerciseID: UUID, at date: Date = Date()) {
        for attempt in allReviewAttempts() where attempt.exerciseID == exerciseID {
            rememberDeletion(kind: "review", id: attempt.id.uuidString, at: date)
            context.delete(attempt)
        }
    }

    func tombstonePhrases(of exerciseID: UUID, at date: Date = Date()) {
        for phrase in allPhrases() where phrase.exerciseID == exerciseID {
            tombstonePhraseReviews(of: phrase.id, at: date)
            rememberDeletion(kind: "phrase", id: phrase.id.uuidString, at: date)
            context.delete(phrase)
        }
    }

    func tombstonePhraseReviews(of phraseID: UUID, at date: Date = Date()) {
        for review in allPhraseReviews() where review.phraseID == phraseID {
            rememberDeletion(kind: "phraseReview", id: review.id.uuidString, at: date)
            context.delete(review)
        }
    }

    private func removeLocal(kind: String, id: String, at date: Date) {
        switch kind {
        case "exercise":
            guard let uuid = UUID(uuidString: id) else { return }
            tombstoneReviews(of: uuid, at: date)
            tombstonePhrases(of: uuid, at: date)
            if let exercise = allExercises().first(where: { $0.id == uuid }) {
                context.delete(exercise)
            }
        case "review":
            if let uuid = UUID(uuidString: id), let attempt = allReviewAttempts().first(where: { $0.id == uuid }) {
                context.delete(attempt)
            }
        case "phrase":
            guard let uuid = UUID(uuidString: id) else { return }
            tombstonePhraseReviews(of: uuid, at: date)
            if let phrase = allPhrases().first(where: { $0.id == uuid }) {
                context.delete(phrase)
            }
        case "phraseReview":
            if let uuid = UUID(uuidString: id), let review = allPhraseReviews().first(where: { $0.id == uuid }) {
                context.delete(review)
            }
        case "folder":
            if let uuid = UUID(uuidString: id), let folder = allFolders().first(where: { $0.id == uuid }) {
                context.delete(folder)
            }
        case "favorite":
            if let uuid = UUID(uuidString: id), let item = allItems().first(where: { $0.id == uuid }) {
                context.delete(item)
            }
        default:
            break
        }
    }

    private func rememberDeletion(kind: String, id: String, at date: Date) {
        if let existing = allDeletionMarks().first(where: { $0.kind == kind && $0.recordID == id }) {
            if date > existing.deletedAt { existing.deletedAt = date }
            return
        }
        context.insert(DeletionMark(kind: kind, recordID: id, deletedAt: date))
    }

    private func forgetDeletion(kind: String, id: String) {
        for mark in allDeletionMarks() where mark.kind == kind && mark.recordID == id {
            context.delete(mark)
        }
    }

    func allDeletionMarks() -> [DeletionMark] {
        (try? context.fetch(FetchDescriptor<DeletionMark>())) ?? []
    }
}
