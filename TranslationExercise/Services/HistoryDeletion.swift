import Foundation

public struct AttemptStamp: Equatable, Sendable {
    public var id: UUID
    public var createdAt: Date

    public init(id: UUID, createdAt: Date) {
        self.id = id
        self.createdAt = createdAt
    }
}

public struct FavoriteStamp: Equatable, Sendable {
    public var id: UUID
    public var sourceText: String
    public var sourceAttemptID: UUID?

    public init(id: UUID, sourceText: String, sourceAttemptID: UUID?) {
        self.id = id
        self.sourceText = sourceText
        self.sourceAttemptID = sourceAttemptID
    }
}

public enum HistoryDeletion {
    public static func ids(in attempts: [AttemptStamp], before cutoff: Date) -> Set<UUID> {
        Set(attempts.filter { $0.createdAt < cutoff }.map(\.id))
    }

    public static func removing(_ attempts: [AttemptStamp], ids: Set<UUID>) -> [AttemptStamp] {
        attempts.filter { !ids.contains($0.id) }
    }
}

public enum FavoriteIndependence {
    public static func afterAttemptDeletion(_ favorites: [FavoriteStamp]) -> [FavoriteStamp] {
        favorites
    }
}

public enum FolderTree {
    public static func canPlace(_ folderID: UUID, under parentID: UUID?, parentOf: (UUID) -> UUID?) -> Bool {
        var cursor = parentID
        var guardCount = 0
        while let current = cursor {
            if current == folderID { return false }
            cursor = parentOf(current)
            guardCount += 1
            if guardCount > 64 { return false }
        }
        return true
    }

    public static func descendantIDs(of root: UUID, childrenOf: (UUID) -> [UUID]) -> Set<UUID> {
        var result: Set<UUID> = [root]
        var queue = [root]
        while let current = queue.first {
            queue.removeFirst()
            for child in childrenOf(current) where result.insert(child).inserted {
                queue.append(child)
            }
        }
        return result
    }
}
