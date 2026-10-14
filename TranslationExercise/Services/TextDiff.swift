import Foundation
import NaturalLanguage

public enum DiffOp: Equatable, Sendable {
    case same(String)
    case delete(String)
    case insert(String)
}

public struct DiffPiece: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case same
        case delete
        case insert
    }

    public var token: String
    public var kind: Kind
    /// 连续的增删算同一处，和 `hunks` 的下标一致。没改动的词没有这个下标。
    public var hunk: Int?

    public init(token: String, kind: Kind, hunk: Int?) {
        self.token = token
        self.kind = kind
        self.hunk = hunk
    }
}

public enum TextDiff {
    public static func diff(user: String, corrected: String) -> [DiffOp] {
        diffTokens(tokens(user), tokens(corrected))
    }

    public static func editRatio(user: String, corrected: String) -> Double {
        let ops = diff(user: user, corrected: corrected)
        let userCount = tokens(user).count
        let correctedCount = tokens(corrected).count
        let changed = ops.reduce(into: 0) { count, op in
            switch op {
            case .same: break
            case .delete, .insert: count += 1
            }
        }
        let denominator = max(userCount, correctedCount, 1)
        return Double(changed) / Double(denominator)
    }

    public static func tokens(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var result: [String] = []
        var cursor = text.startIndex
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            if cursor < range.lowerBound {
                appendMarks(in: text[cursor..<range.lowerBound], to: &result)
            }
            let token = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty {
                result.append(token)
            }
            cursor = range.upperBound
            return true
        }
        if cursor < text.endIndex {
            appendMarks(in: text[cursor...], to: &result)
        }
        if result.isEmpty {
            return text.map(String.init).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        return result
    }

    private static func appendMarks(in gap: Substring, to result: inout [String]) {
        for character in gap where isMark(character) {
            result.append(String(character))
        }
    }

    private static func isMark(_ character: Character) -> Bool {
        character.unicodeScalars.contains { CharacterSet.punctuationCharacters.contains($0) }
    }

    static func diffTokens(_ source: [String], _ target: [String]) -> [DiffOp] {
        let rows = source.count
        let columns = target.count
        var lengths = Array(repeating: Array(repeating: 0, count: columns + 1), count: rows + 1)
        if rows > 0, columns > 0 {
            for row in 1...rows {
                for column in 1...columns {
                    if source[row - 1] == target[column - 1] {
                        lengths[row][column] = lengths[row - 1][column - 1] + 1
                    } else {
                        lengths[row][column] = max(lengths[row - 1][column], lengths[row][column - 1])
                    }
                }
            }
        }

        var reversed: [DiffOp] = []
        var row = rows
        var column = columns
        while row > 0 || column > 0 {
            if row > 0, column > 0, source[row - 1] == target[column - 1] {
                reversed.append(.same(source[row - 1]))
                row -= 1
                column -= 1
            } else if column > 0, row == 0 || lengths[row][column - 1] >= lengths[row - 1][column] {
                reversed.append(.insert(target[column - 1]))
                column -= 1
            } else if row > 0 {
                reversed.append(.delete(source[row - 1]))
                row -= 1
            }
        }
        return Array(reversed.reversed())
    }

    public static func pieces(user: String, corrected: String) -> [DiffPiece] {
        var pieces: [DiffPiece] = []
        var hunk = -1
        var open = false
        for op in diff(user: user, corrected: corrected) {
            switch op {
            case let .same(token):
                open = false
                pieces.append(DiffPiece(token: token, kind: .same, hunk: nil))
            case let .delete(token):
                if !open {
                    hunk += 1
                    open = true
                }
                pieces.append(DiffPiece(token: token, kind: .delete, hunk: hunk))
            case let .insert(token):
                if !open {
                    hunk += 1
                    open = true
                }
                pieces.append(DiffPiece(token: token, kind: .insert, hunk: hunk))
            }
        }
        return pieces
    }

    public static func hunks(user: String, corrected: String) -> [EditHunk] {
        var hunks: [EditHunk] = []
        var removed: [String] = []
        var added: [String] = []
        func flush() {
            guard !removed.isEmpty || !added.isEmpty else { return }
            hunks.append(EditHunk(before: joined(removed), after: joined(added)))
            removed = []
            added = []
        }
        for op in diff(user: user, corrected: corrected) {
            switch op {
            case .same:
                flush()
            case let .delete(token):
                removed.append(token)
            case let .insert(token):
                added.append(token)
            }
        }
        flush()
        return hunks
    }

    public static func joined(_ tokens: [String]) -> String {
        var text = ""
        for token in tokens {
            if !text.isEmpty, needsSpace(before: token) {
                text += " "
            }
            text += token
        }
        return text
    }

    public static func needsSpace(before token: String) -> Bool {
        guard let scalar = token.unicodeScalars.first, scalar.isASCII else { return false }
        return CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar)
    }
}

public struct EditHunk: Equatable, Sendable, Codable {
    public var before: String
    public var after: String
    public var reason: String

    public init(before: String, after: String, reason: String = "") {
        self.before = before
        self.after = after
        self.reason = reason
    }
}

public struct TokenSelection: Equatable, Sendable {
    public var anchor: Int?
    public var extent: Int?
    public var armed = false

    public init() {}

    /// 第一次点中一个词。再点另一个词，范围扩到两点之间。再点则从新词重新开始。点同一个词则取消。
    public mutating func tap(_ index: Int) -> ClosedRange<Int>? {
        guard index >= 0 else { return nil }
        if armed, let anchor {
            if anchor == index, extent == index {
                clear()
                return nil
            }
            extent = index
            armed = false
        } else {
            anchor = index
            extent = index
            armed = true
        }
        guard let anchor, let extent else { return nil }
        return min(anchor, extent)...max(anchor, extent)
    }

    public mutating func clear() {
        anchor = nil
        extent = nil
        armed = false
    }
}

public enum EditNotes {
    public static func zip(hunks: [EditHunk], reasons: [String]) -> [EditHunk] {
        hunks.enumerated().map { index, hunk in
            let reason = index < reasons.count ? reasons[index].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            return EditHunk(before: hunk.before, after: hunk.after, reason: reason)
        }
    }

    public static func encode(_ notes: [EditHunk]) -> String {
        guard let data = try? JSONEncoder().encode(notes),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    public static func decode(_ json: String) -> [EditHunk] {
        guard let data = json.data(using: .utf8),
              let notes = try? JSONDecoder().decode([EditHunk].self, from: data) else { return [] }
        return notes
    }
}
