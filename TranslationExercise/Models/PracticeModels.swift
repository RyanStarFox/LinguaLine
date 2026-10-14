import Foundation
import SQLite3
import SwiftData
import TranslationCore

@Model
final class Exercise {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var dailyKey: String?
    var languageCode: String = "en"
    var directionRaw: String = Direction.zhToForeign.rawValue
    var kindRaw: String = ExerciseKind.daily.rawValue
    var topic: String = ""
    var sourceText: String = ""
    var userDraft: String = ""
    var submitted: Bool = false
    var userText: String = ""
    var correctedText: String = ""
    var exemplarText: String = ""
    var faithfulness: Int = 0
    var expressiveness: Int = 0
    var elegance: Int = 0
    var weightedScore: Int = 0
    var exemplarFaithfulness: Int = 0
    var exemplarExpressiveness: Int = 0
    var exemplarElegance: Int = 0
    var exemplarWeightedScore: Int = 0
    var errorTags: [String] = []
    var editNotesJSON: String = ""
    var stockLevel: Int = -1
    var stockPresetRaw: String = ""
    var stockScriptRaw: String = ""
    var updatedAt: Date = Date.distantPast

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        dailyKey: String? = nil,
        languageCode: String,
        direction: Direction,
        kind: ExerciseKind,
        topic: String,
        sourceText: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.dailyKey = dailyKey
        self.languageCode = languageCode
        self.directionRaw = direction.rawValue
        self.kindRaw = kind.rawValue
        self.topic = topic
        self.sourceText = sourceText
        self.updatedAt = Date()
    }

    var direction: Direction {
        Direction(rawValue: directionRaw) ?? .zhToForeign
    }

    var kind: ExerciseKind {
        ExerciseKind(rawValue: kindRaw) ?? .daily
    }

    func storedEditNotes() -> [EditHunk] {
        EditNotes.decode(editNotesJSON)
    }

    func storeEditNotes(_ notes: [EditHunk]) {
        editNotesJSON = EditNotes.encode(notes)
    }
}

@Model
final class DirectionSkill {
    var languageCode: String = "en"
    var directionRaw: String = Direction.zhToForeign.rawValue
    var level: Int = Difficulty.skippedLevel
    var placementDone: Bool = false
    var placementStep: Int = 0
    var recentSources: [String] = []
    var updatedAt: Date = Date.distantPast

    init(languageCode: String, direction: Direction) {
        self.languageCode = languageCode
        self.directionRaw = direction.rawValue
        self.updatedAt = Date()
    }

    var direction: Direction {
        Direction(rawValue: directionRaw) ?? .zhToForeign
    }
}

@Model
final class StreakRecord {
    var current: Int = 0
    var lastCompletedDay: Date?
    var lastCelebratedMultiple: Int = 0
    var shields: Int = 0
    var shieldsGrantedForRun: Int = 0
    var shieldedDayKeys: [String] = []
    var updatedAt: Date = Date.distantPast

    init() {}

    var snapshot: StreakSnapshot {
        StreakSnapshot(
            current: current,
            lastCompletedDay: lastCompletedDay,
            lastCelebratedMultiple: lastCelebratedMultiple,
            shields: shields,
            shieldsGrantedForRun: shieldsGrantedForRun,
            shieldedDayKeys: shieldedDayKeys
        )
    }

    func apply(_ snapshot: StreakSnapshot) {
        current = snapshot.current
        lastCompletedDay = snapshot.lastCompletedDay
        lastCelebratedMultiple = snapshot.lastCelebratedMultiple
        shields = snapshot.shields
        shieldsGrantedForRun = snapshot.shieldsGrantedForRun
        shieldedDayKeys = snapshot.shieldedDayKeys
        updatedAt = Date()
    }
}

@Model
final class FavoriteFolder {
    var id: UUID = UUID()
    var name: String = ""
    var parentID: UUID?
    var pinned: Bool = false
    var sortIndex: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date.distantPast

    init(name: String, parentID: UUID?, sortIndex: Int) {
        self.id = UUID()
        self.name = name
        self.parentID = parentID
        self.sortIndex = sortIndex
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class FavoriteItem {
    var id: UUID = UUID()
    var folderID: UUID?
    var pinned: Bool = false
    var createdAt: Date = Date()
    var sourceAttemptID: UUID?
    var languageCode: String = "en"
    var directionRaw: String = Direction.zhToForeign.rawValue
    var topic: String = ""
    var sourceText: String = ""
    var userText: String = ""
    var correctedText: String = ""
    var exemplarText: String = ""
    var weightedScore: Int = 0
    var faithfulness: Int = 0
    var expressiveness: Int = 0
    var elegance: Int = 0
    var exemplarWeightedScore: Int = 0
    var exemplarFaithfulness: Int = 0
    var exemplarExpressiveness: Int = 0
    var exemplarElegance: Int = 0
    var exerciseDate: Date = Date()
    var updatedAt: Date = Date.distantPast

    init(folderID: UUID?, exercise: Exercise) {
        self.id = UUID()
        self.folderID = folderID
        self.pinned = false
        self.createdAt = Date()
        self.sourceAttemptID = exercise.id
        self.languageCode = exercise.languageCode
        self.directionRaw = exercise.directionRaw
        self.topic = exercise.topic
        self.sourceText = exercise.sourceText
        self.userText = exercise.userText
        self.correctedText = exercise.correctedText
        self.exemplarText = exercise.exemplarText
        self.weightedScore = exercise.weightedScore
        self.faithfulness = exercise.faithfulness
        self.expressiveness = exercise.expressiveness
        self.elegance = exercise.elegance
        self.exemplarWeightedScore = exercise.exemplarWeightedScore
        self.exemplarFaithfulness = exercise.exemplarFaithfulness
        self.exemplarExpressiveness = exercise.exemplarExpressiveness
        self.exemplarElegance = exercise.exemplarElegance
        self.exerciseDate = exercise.createdAt
        self.updatedAt = Date()
    }
}

@Model
final class ReviewAttempt {
    var id: UUID = UUID()
    var exerciseID: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date.distantPast
    var userText: String = ""
    var correctedText: String = ""
    var faithfulness: Int = 0
    var expressiveness: Int = 0
    var elegance: Int = 0
    var weightedScore: Int = 0
    var directionRaw: String = Direction.zhToForeign.rawValue
    var languageCode: String = "en"
    var intervalDays: Int = 1
    var dueDay: Date = Date()
    var editNotesJSON: String = ""

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        createdAt: Date = Date(),
        userText: String,
        correctedText: String,
        faithfulness: Int,
        expressiveness: Int,
        elegance: Int,
        weightedScore: Int,
        direction: Direction,
        languageCode: String,
        intervalDays: Int,
        dueDay: Date
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.userText = userText
        self.correctedText = correctedText
        self.faithfulness = faithfulness
        self.expressiveness = expressiveness
        self.elegance = elegance
        self.weightedScore = weightedScore
        self.directionRaw = direction.rawValue
        self.languageCode = languageCode
        self.intervalDays = intervalDays
        self.dueDay = dueDay
    }

    var direction: Direction {
        Direction(rawValue: directionRaw) ?? .zhToForeign
    }

    func storedEditNotes() -> [EditHunk] {
        EditNotes.decode(editNotesJSON)
    }

    func storeEditNotes(_ notes: [EditHunk]) {
        editNotesJSON = EditNotes.encode(notes)
    }
}

@Model
final class PhrasePair {
    var id: UUID = UUID()
    var exerciseID: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date.distantPast
    var languageCode: String = "en"
    var directionRaw: String = Direction.zhToForeign.rawValue
    var promptText: String = ""
    var answerText: String = ""

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        createdAt: Date = Date(),
        languageCode: String,
        direction: Direction,
        promptText: String,
        answerText: String
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.languageCode = languageCode
        self.directionRaw = direction.rawValue
        self.promptText = promptText
        self.answerText = answerText
    }

    var direction: Direction {
        Direction(rawValue: directionRaw) ?? .zhToForeign
    }
}

@Model
final class PhraseReview {
    var id: UUID = UUID()
    var phraseID: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date.distantPast
    var remembered: Bool = false
    var intervalDays: Int = 1
    var dueDay: Date = Date()

    init(
        id: UUID = UUID(),
        phraseID: UUID,
        createdAt: Date = Date(),
        remembered: Bool,
        intervalDays: Int,
        dueDay: Date
    ) {
        self.id = id
        self.phraseID = phraseID
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.remembered = remembered
        self.intervalDays = intervalDays
        self.dueDay = dueDay
    }
}

@Model
final class DeletionMark {
    var markID: String = ""
    var kind: String = ""
    var recordID: String = ""
    var deletedAt: Date = Date()

    init(kind: String, recordID: String, deletedAt: Date = Date()) {
        self.kind = kind
        self.recordID = recordID
        self.markID = "\(kind)|\(recordID)"
        self.deletedAt = deletedAt
    }
}

enum PracticeStore {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Exercise.self,
            DirectionSkill.self,
            StreakRecord.self,
            FavoriteFolder.self,
            FavoriteItem.self,
            ReviewAttempt.self,
            PhrasePair.self,
            PhraseReview.self,
            DeletionMark.self,
        ])
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            : ModelConfiguration(schema: schema, url: try storeURL(), cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// SwiftData 不指定路径时会写进所有未沙盒应用共用的 `default.store`。
    /// 这里固定到本应用自己的目录；若那里还没有库，且旧的共用文件里已有题目，就把旧库复制过来。
    static func storeURL() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support.appendingPathComponent("app.translationexercise.daily", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("exercises.store")
        let legacy = support.appendingPathComponent("default.store")
        if !FileManager.default.fileExists(atPath: destination.path) {
            try LegacyStoreMigration.adoptIfNeeded(into: destination, legacy: legacy)
        } else {
            LegacyStoreMigration.foldNewerLegacy(into: destination, legacy: legacy)
        }
        return destination
    }
}

private enum LegacyStoreMigration {
    static func adoptIfNeeded(into destination: URL, legacy: URL) throws {
        guard FileManager.default.fileExists(atPath: legacy.path), try containsExercises(legacy) else { return }
        do {
            try backup(from: legacy, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: destination)
        }
    }

    /// 旧的共用库如果在这份副本之后又写过，先换成旧库的最新内容，再把副本里独有的已提交题目补回去。
    static func foldNewerLegacy(into destination: URL, legacy: URL) {
        guard FileManager.default.fileExists(atPath: legacy.path),
              let legacyDate = modified(legacy),
              let destinationDate = modified(destination),
              legacyDate > destinationDate,
              (try? containsExercises(legacy)) == true,
              (try? containsExercises(destination)) == true else { return }
        let preserved = (try? rows(in: destination, missingFrom: legacy)) ?? []
        let streak = try? streak(in: destination)
        let incoming = destination.appendingPathExtension("incoming")
        try? FileManager.default.removeItem(at: incoming)
        do {
            try backup(from: legacy, to: incoming)
            try insert(preserved, into: incoming)
            if let streak, (try? currentStreak(in: incoming)) == 0 {
                try writeStreak(streak, into: incoming)
            }
            removeSidecars(of: destination)
            let retired = destination.appendingPathExtension("retired")
            try? FileManager.default.removeItem(at: retired)
            try FileManager.default.moveItem(at: destination, to: retired)
            try FileManager.default.moveItem(at: incoming, to: destination)
            try? FileManager.default.removeItem(at: retired)
        } catch {
            try? FileManager.default.removeItem(at: incoming)
        }
    }

    private static func backup(from sourceURL: URL, to destinationURL: URL) throws {
        var source: OpaquePointer?
        var target: OpaquePointer?
        guard sqlite3_open_v2(sourceURL.path, &source, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(source)
            throw CocoaError(.fileReadUnknown)
        }
        defer { sqlite3_close(source) }
        guard sqlite3_open(destinationURL.path, &target) == SQLITE_OK else {
            sqlite3_close(target)
            throw CocoaError(.fileWriteUnknown)
        }
        defer { sqlite3_close(target) }
        guard let backup = sqlite3_backup_init(target, "main", source, "main") else {
            throw CocoaError(.fileWriteUnknown)
        }
        let step = sqlite3_backup_step(backup, -1)
        sqlite3_backup_finish(backup)
        guard step == SQLITE_DONE else { throw CocoaError(.fileWriteUnknown) }
    }

    private static func containsExercises(_ url: URL) throws -> Bool {
        try query(url, sql: "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'ZEXERCISE' LIMIT 1").next()
    }

    private static func rows(in source: URL, missingFrom other: URL) throws -> [PreservedExercise] {
        let present = try dailyKeys(in: other)
        var found: [PreservedExercise] = []
        try query(source, sql: "SELECT \(exerciseColumns) FROM ZEXERCISE WHERE ZDAILYKEY IS NOT NULL AND ZDAILYKEY != '' AND ZSUBMITTED = 1") { statement in
            let key = sqlite3_column_text(statement, 15).map { String(cString: $0) } ?? ""
            guard !key.isEmpty, !present.contains(key) else { return }
            var values: [SQLValue] = []
            for index in 0..<Int32(exerciseColumnCount) {
                values.append(SQLValue(statement, index: index))
            }
            found.append(PreservedExercise(values: values))
        }
        return found
    }

    private static func dailyKeys(in url: URL) throws -> Set<String> {
        var keys = Set<String>()
        try query(url, sql: "SELECT ZDAILYKEY FROM ZEXERCISE WHERE ZDAILYKEY IS NOT NULL") { statement in
            if let text = sqlite3_column_text(statement, 0) {
                keys.insert(String(cString: text))
            }
        }
        return keys
    }

    private static func insert(_ rows: [PreservedExercise], into url: URL) throws {
        guard !rows.isEmpty else { return }
        let database = try open(url, readonly: false)
        defer { sqlite3_close(database) }
        var next = try int64(database, sql: "SELECT COALESCE(MAX(Z_PK), 0) FROM ZEXERCISE")
        let placeholders = Array(repeating: "?", count: exerciseColumnCount).joined(separator: ",")
        let sql = "INSERT INTO ZEXERCISE (Z_PK, \(exerciseColumns)) VALUES (?, \(placeholders))"
        for row in rows {
            next += 1
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { continue }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, next)
            for (offset, value) in row.values.enumerated() {
                value.bind(statement, index: Int32(offset) + 2)
            }
            sqlite3_step(statement)
        }
        var update: OpaquePointer?
        sqlite3_prepare_v2(database, "UPDATE Z_PRIMARYKEY SET Z_MAX = ? WHERE Z_NAME = 'Exercise'", -1, &update, nil)
        sqlite3_bind_int64(update, 1, next)
        sqlite3_step(update)
        sqlite3_finalize(update)
    }

    private static func streak(in url: URL) throws -> SavedStreak? {
        var saved: SavedStreak?
        try query(url, sql: "SELECT ZCURRENT, ZLASTCOMPLETEDDAY, ZLASTCELEBRATEDMULTIPLE, ZSHIELDS, ZSHIELDSGRANTEDFORRUN, ZUPDATEDAT, ZSHIELDEDDAYKEYS FROM ZSTREAKRECORD LIMIT 1") { statement in
            let current = sqlite3_column_int64(statement, 0)
            guard current > 0 else { return }
            saved = SavedStreak(
                current: current,
                lastCompletedDay: sqlite3_column_double(statement, 1),
                lastCelebratedMultiple: sqlite3_column_int64(statement, 2),
                shields: sqlite3_column_int64(statement, 3),
                shieldsGrantedForRun: sqlite3_column_int64(statement, 4),
                updatedAt: sqlite3_column_double(statement, 5),
                shieldedDayKeys: SQLValue(statement, index: 6)
            )
        }
        return saved
    }

    private static func currentStreak(in url: URL) throws -> Int64 {
        let database = try open(url, readonly: true)
        defer { sqlite3_close(database) }
        return try int64(database, sql: "SELECT COALESCE(ZCURRENT, 0) FROM ZSTREAKRECORD LIMIT 1")
    }

    private static func writeStreak(_ streak: SavedStreak, into url: URL) throws {
        let database = try open(url, readonly: false)
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        let sql = "UPDATE ZSTREAKRECORD SET ZCURRENT = ?, ZLASTCOMPLETEDDAY = ?, ZLASTCELEBRATEDMULTIPLE = ?, ZSHIELDS = ?, ZSHIELDSGRANTEDFORRUN = ?, ZUPDATEDAT = ?, ZSHIELDEDDAYKEYS = ?"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, streak.current)
        sqlite3_bind_double(statement, 2, streak.lastCompletedDay)
        sqlite3_bind_int64(statement, 3, streak.lastCelebratedMultiple)
        sqlite3_bind_int64(statement, 4, streak.shields)
        sqlite3_bind_int64(statement, 5, streak.shieldsGrantedForRun)
        sqlite3_bind_double(statement, 6, streak.updatedAt)
        streak.shieldedDayKeys.bind(statement, index: 7)
        sqlite3_step(statement)
    }

    private static func int64(_ database: OpaquePointer?, sql: String) throws -> Int64 {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return sqlite3_column_int64(statement, 0)
    }

    private static func query(_ url: URL, sql: String, body: (OpaquePointer?) -> Void = { _ in }) throws -> QueryResult {
        let database = try open(url, readonly: true)
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return QueryResult(hasRow: false)
        }
        defer { sqlite3_finalize(statement) }
        var hasRow = false
        while sqlite3_step(statement) == SQLITE_ROW {
            hasRow = true
            body(statement)
        }
        return QueryResult(hasRow: hasRow)
    }

    private static func open(_ url: URL, readonly: Bool) throws -> OpaquePointer? {
        var database: OpaquePointer?
        let flags = readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        guard sqlite3_open_v2(url.path, &database, flags, nil) == SQLITE_OK else {
            sqlite3_close(database)
            throw CocoaError(.fileReadUnknown)
        }
        return database
    }

    private static func modified(_ url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    private static func removeSidecars(of url: URL) {
        let manager = FileManager.default
        try? manager.removeItem(atPath: url.path + "-wal")
        try? manager.removeItem(atPath: url.path + "-shm")
    }

    private static let exerciseColumns = """
    Z_ENT, Z_OPT, ZELEGANCE, ZEXEMPLARELEGANCE, ZEXEMPLAREXPRESSIVENESS, ZEXEMPLARFAITHFULNESS, \
    ZEXEMPLARWEIGHTEDSCORE, ZEXPRESSIVENESS, ZFAITHFULNESS, ZSTOCKLEVEL, ZSUBMITTED, ZWEIGHTEDSCORE, \
    ZCREATEDAT, ZUPDATEDAT, ZCORRECTEDTEXT, ZDAILYKEY, ZDIRECTIONRAW, ZEXEMPLARTEXT, ZKINDRAW, \
    ZLANGUAGECODE, ZSOURCETEXT, ZSTOCKPRESETRAW, ZSTOCKSCRIPTRAW, ZTOPIC, ZUSERDRAFT, ZUSERTEXT, ZID, ZERRORTAGS
    """

    private static let exerciseColumnCount = 28
}

private struct QueryResult {
    var hasRow: Bool
    func next() -> Bool { hasRow }
}

private struct PreservedExercise {
    var values: [SQLValue]
}

private struct SavedStreak {
    var current: Int64
    var lastCompletedDay: Double
    var lastCelebratedMultiple: Int64
    var shields: Int64
    var shieldsGrantedForRun: Int64
    var updatedAt: Double
    var shieldedDayKeys: SQLValue
}

private enum SQLValue {
    case null
    case int(Int64)
    case double(Double)
    case text(String)
    case blob(Data)

    init(_ statement: OpaquePointer?, index: Int32) {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER:
            self = .int(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT:
            self = .double(sqlite3_column_double(statement, index))
        case SQLITE_TEXT:
            self = .text(sqlite3_column_text(statement, index).map { String(cString: $0) } ?? "")
        case SQLITE_BLOB:
            let count = Int(sqlite3_column_bytes(statement, index))
            if let bytes = sqlite3_column_blob(statement, index) {
                self = .blob(Data(bytes: bytes, count: count))
            } else {
                self = .null
            }
        default:
            self = .null
        }
    }

    func bind(_ statement: OpaquePointer?, index: Int32) {
        switch self {
        case .null:
            sqlite3_bind_null(statement, index)
        case let .int(value):
            sqlite3_bind_int64(statement, index, value)
        case let .double(value):
            sqlite3_bind_double(statement, index, value)
        case let .text(value):
            sqlite3_bind_text(statement, index, value, -1, Self.transient)
        case let .blob(value):
            value.withUnsafeBytes { buffer in
                sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(buffer.count), Self.transient)
            }
        }
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
