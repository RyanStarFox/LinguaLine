import Foundation

public struct SyncRecord: Codable, Equatable, Sendable, Identifiable {
    public var kind: String
    public var id: String
    public var updatedAt: Date
    public var deletedAt: Date?
    public var body: Data

    public init(kind: String, id: String, updatedAt: Date, deletedAt: Date? = nil, body: Data = Data()) {
        self.kind = kind
        self.id = id
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.body = body
    }

    public var recordKey: String { "\(kind)|\(id)" }
}

public struct SyncFile: Codable, Equatable, Sendable {
    public var records: [SyncRecord]

    public init(records: [SyncRecord]) {
        self.records = records
    }
}

public enum SyncMerge {
    public static func merge(local: [SyncRecord], remote: [SyncRecord]) -> [SyncRecord] {
        var map: [String: SyncRecord] = [:]
        for record in local + remote {
            let key = record.recordKey
            if let existing = map[key] {
                map[key] = preferred(existing, record)
            } else {
                map[key] = record
            }
        }
        return map.values.sorted { $0.recordKey < $1.recordKey }
    }

    private static func preferred(_ lhs: SyncRecord, _ rhs: SyncRecord) -> SyncRecord {
        let left = stamp(lhs)
        let right = stamp(rhs)
        if left == right {
            if lhs.deletedAt == nil { return lhs }
            if rhs.deletedAt == nil { return rhs }
            return lhs
        }
        return right > left ? rhs : lhs
    }

    private static func stamp(_ record: SyncRecord) -> Date {
        if let deletedAt = record.deletedAt {
            return max(record.updatedAt, deletedAt)
        }
        return record.updatedAt
    }
}
