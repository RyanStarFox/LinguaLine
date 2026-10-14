import Foundation
import SQLite3
import TranslationCore

enum DictionaryFormat: Sendable {
    case cedict
    case japaneseChineseJSON
}

struct DictionaryOffer: Identifiable, Sendable {
    var id: String
    var title: String
    var detailKey: String
    var language: PracticeLanguage
    var url: URL
    var approximateBytes: Int64
    var gzip: Bool
    var format: DictionaryFormat

    static let all: [DictionaryOffer] = [
        DictionaryOffer(
            id: "cedict",
            title: "CC-CEDICT",
            detailKey: "dict_cedict_detail",
            language: .english,
            url: URL(string: "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz")!,
            approximateBytes: 4_000_000,
            gzip: true,
            format: .cedict
        ),
        DictionaryOffer(
            id: "cfdict",
            title: "CFDICT",
            detailKey: "dict_cfdict_detail",
            language: .french,
            url: URL(string: "https://chine.in/assets/cfdict/cfdict.u8")!,
            approximateBytes: 3_500_000,
            gzip: false,
            format: .cedict
        ),
        DictionaryOffer(
            id: "handedict",
            title: "HanDeDict",
            detailKey: "dict_handedict_detail",
            language: .german,
            url: URL(string: "https://raw.githubusercontent.com/gugray/HanDeDict/master/handedict.u8")!,
            approximateBytes: 62_000_000,
            gzip: false,
            format: .cedict
        ),
        DictionaryOffer(
            id: "jczh",
            title: "日中词库",
            detailKey: "dict_jczh_detail",
            language: .japanese,
            url: URL(string: "https://raw.githubusercontent.com/lxl66566/Japanese-Chinese-thesaurus/main/final.json")!,
            approximateBytes: 880_000,
            gzip: false,
            format: .japaneseChineseJSON
        ),
    ]
}

enum ByteCountText {
    static func string(_ bytes: Int64) -> String {
        let value = Double(bytes)
        if bytes < 1024 * 1024 {
            return String(format: "%.0f KB", value / 1024)
        }
        return String(format: "%.0f MB", value / 1024 / 1024)
    }
}

@MainActor
@Observable
final class DictionaryLibrary {
    var progress: [String: Double] = [:]
    var installed: [String: Int64] = [:]
    var errors: [String: String] = [:]

    private var handles: [String: OpaquePointer] = [:]
    private var transfers: [String: DictionaryTransfer] = [:]

    func refresh() {
        for offer in DictionaryOffer.all {
            let url = Self.databaseURL(offer.id)
            if FileManager.default.fileExists(atPath: url.path),
               let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
                installed[offer.id] = size
            } else {
                installed[offer.id] = nil
                close(offer.id)
            }
        }
    }

    func download(_ id: String) async {
        guard let offer = DictionaryOffer.all.first(where: { $0.id == id }), progress[id] == nil else { return }
        errors[id] = nil
        progress[id] = 0
        let transfer = DictionaryTransfer()
        transfers[id] = transfer
        defer {
            transfers[id] = nil
            progress[id] = nil
        }
        do {
            let downloaded = try await transfer.download(offer.url) { [weak self] fraction in
                Task { @MainActor in
                    self?.progress[id] = min(0.45, fraction * 0.45)
                }
            }
            defer { try? FileManager.default.removeItem(at: downloaded) }
            progress[id] = 0.55
            let text = try await Task.detached { () -> String in
                let data = try Data(contentsOf: downloaded)
                let plain = offer.gzip ? try Gzip.inflate(data) : data
                return String(decoding: plain, as: UTF8.self)
            }.value
            try Task.checkCancellation()
            progress[id] = 0.75
            let destination = Self.databaseURL(id)
            let partial = destination.appendingPathExtension("partial")
            let format = offer.format
            try await Task.detached {
                try DictionaryDatabase.write(text: text, format: format, to: partial)
            }.value
            try Task.checkCancellation()
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: partial, to: destination)
            close(id)
            refresh()
        } catch is CancellationError {
            errors[id] = nil
        } catch let error as URLError where error.code == .cancelled {
            errors[id] = nil
        } catch {
            errors[id] = error.localizedDescription
        }
    }

    func cancel(_ id: String) {
        transfers[id]?.cancel()
    }

    func delete(_ id: String) {
        cancel(id)
        close(id)
        let url = Self.databaseURL(id)
        try? FileManager.default.removeItem(at: url)
        installed[id] = nil
        errors[id] = nil
    }

    func lookup(term: String, language: PracticeLanguage, sourceIsChinese: Bool) -> (key: String, gloss: String, reading: String)? {
        let keys = CedictIndex.lookupKeys(for: term, sourceIsChinese: sourceIsChinese)
        guard !keys.isEmpty else { return nil }
        for offer in DictionaryOffer.all where offer.language == language && installed[offer.id] != nil {
            guard let db = open(offer.id) else { continue }
            for key in keys {
                if let hit = DictionaryDatabase.lookup(key, in: db) {
                    return (key, hit.gloss, hit.reading)
                }
            }
        }
        return nil
    }

    private func open(_ id: String) -> OpaquePointer? {
        if let handle = handles[id] { return handle }
        var db: OpaquePointer?
        guard sqlite3_open_v2(Self.databaseURL(id).path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            return nil
        }
        handles[id] = db
        return db
    }

    private func close(_ id: String) {
        if let handle = handles[id] {
            sqlite3_close(handle)
            handles[id] = nil
        }
    }

    private static func databaseURL(_ id: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Dictionaries", isDirectory: true).appendingPathComponent("\(id).sqlite")
    }
}

private enum Gzip {
    static func inflate(_ data: Data) throws -> Data {
        try data.withUnsafeBytes { buffer in
            guard let source = buffer.bindMemory(to: UInt8.self).baseAddress else {
                throw DictionaryStoreError.unreadable
            }
            var output: UnsafeMutablePointer<UInt8>?
            var count = 0
            let status = te_gunzip(source, buffer.count, &output, &count)
            guard status == 0, let output, count > 0 else {
                throw DictionaryStoreError.unreadable
            }
            defer { free(output) }
            return Data(bytes: output, count: count)
        }
    }
}

private enum DictionaryStoreError: LocalizedError {
    case unreadable
    case empty

    var errorDescription: String? {
        switch self {
        case .unreadable:
            String(localized: "dict_error_unreadable")
        case .empty:
            String(localized: "dict_error_empty")
        }
    }
}

private enum DictionaryDatabase {
    static func write(text: String, format: DictionaryFormat, to url: URL) throws {
        let records: [DictionaryRecord]
        switch format {
        case .cedict:
            records = CedictIndex.records(in: text)
        case .japaneseChineseJSON:
            records = JapaneseChineseIndex.records(in: Data(text.utf8))
        }
        guard !records.isEmpty else { throw DictionaryStoreError.empty }
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else {
            throw DictionaryStoreError.unreadable
        }
        defer { sqlite3_close(db) }
        try exec("PRAGMA journal_mode = OFF; PRAGMA synchronous = OFF;", in: db)
        try exec("CREATE TABLE entries (head TEXT PRIMARY KEY, gloss TEXT NOT NULL, reading TEXT NOT NULL);", in: db)
        try exec("BEGIN;", in: db)
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO entries (head, gloss, reading) VALUES (?, ?, ?);", -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw DictionaryStoreError.unreadable
        }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for record in records {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            _ = record.head.withCString { head in
                sqlite3_bind_text(statement, 1, head, -1, transient)
            }
            _ = record.gloss.withCString { gloss in
                sqlite3_bind_text(statement, 2, gloss, -1, transient)
            }
            _ = record.reading.withCString { reading in
                sqlite3_bind_text(statement, 3, reading, -1, transient)
            }
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DictionaryStoreError.unreadable
            }
        }
        try exec("COMMIT;", in: db)
    }

    static func lookup(_ key: String, in db: OpaquePointer) -> (gloss: String, reading: String)? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT gloss, reading FROM entries WHERE head = ? LIMIT 1;", -1, &statement, nil) == SQLITE_OK,
              let statement else { return nil }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        _ = key.withCString { sqlite3_bind_text(statement, 1, $0, -1, transient) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        let gloss = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
        let reading = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
        guard !gloss.isEmpty else { return nil }
        return (gloss, reading)
    }

    private static func exec(_ sql: String, in db: OpaquePointer) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw DictionaryStoreError.unreadable
        }
    }
}

private final class DictionaryTransfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var session: URLSession!
    private var task: URLSessionDownloadTask?
    private var continuation: CheckedContinuation<URL, Error>?
    private let lock = NSLock()
    private var onFraction: (@Sendable (Double) -> Void)?

    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    func download(_ url: URL, onFraction: @escaping @Sendable (Double) -> Void) async throws -> URL {
        self.onFraction = onFraction
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let task = session.downloadTask(with: url)
            self.task = task
            task.resume()
        }
    }

    func cancel() {
        task?.cancel()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let fraction: Double
        if totalBytesExpectedToWrite > 0 {
            fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            fraction = min(0.9, Double(totalBytesWritten) / 4_000_000)
        }
        onFraction?(fraction)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            finish(.success(destination))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}
