import Foundation

public struct DictionaryRecord: Equatable, Sendable {
    public var head: String
    public var gloss: String
    public var reading: String

    public init(head: String, gloss: String, reading: String) {
        self.head = head
        self.gloss = gloss
        self.reading = reading
    }
}

public enum CedictIndex {
    public static func records(in text: String) -> [DictionaryRecord] {
        var merged: [String: Accumulator] = [:]
        text.enumerateLines { rawLine, _ in
            guard let line = parsed(rawLine) else { return }
            let forward = clip(line.glosses.joined(separator: "；"), limit: 180)
            add(line.simplified, gloss: forward, reading: line.reading, into: &merged)
            if line.traditional != line.simplified {
                add(line.traditional, gloss: forward, reading: line.reading, into: &merged)
            }
            let reverse = line.simplified + (line.reading.isEmpty ? "" : "（\(line.reading)）")
            for key in reverseKeys(in: line.glosses) {
                add(key, gloss: reverse, reading: "", into: &merged)
            }
        }
        return merged.map { head, item in
            DictionaryRecord(head: head, gloss: item.glosses.joined(separator: "；"), reading: item.reading)
        }
    }

    public static func lookupKeys(for term: String, sourceIsChinese: Bool) -> [String] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
        guard !trimmed.isEmpty else { return [] }
        if sourceIsChinese || containsHan(trimmed) || containsKana(trimmed) {
            return windows(trimmed, maxLength: sourceIsChinese ? 8 : 12)
        }
        var keys: [String] = []
        var seen = Set<String>()
        func push(_ raw: String) {
            let piece = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: .punctuationCharacters)
            let key = normalize(piece)
            guard (1...32).contains(key.count), seen.insert(key).inserted else { return }
            keys.append(key)
        }
        push(trimmed)
        for part in trimmed.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }) {
            push(String(part))
        }
        return keys
    }

    private static func windows(_ trimmed: String, maxLength: Int) -> [String] {
        let chars = Array(trimmed.filter { !$0.isWhitespace && !$0.isPunctuation })
        guard !chars.isEmpty else { return [] }
        let slice = Array(chars.prefix(64))
        var keys: [String] = []
        var seen = Set<String>()
        let longest = min(maxLength, slice.count)
        for length in stride(from: longest, through: 1, by: -1) {
            for start in 0...(slice.count - length) {
                let key = String(slice[start..<(start + length)])
                if seen.insert(key).inserted {
                    keys.append(key)
                }
            }
        }
        return keys
    }

    private static func containsKana(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) }
    }

    private struct Accumulator {
        var glosses: [String]
        var reading: String
    }

    private struct Line {
        var traditional: String
        var simplified: String
        var reading: String
        var glosses: [String]
    }

    private static let articles: Set<String> = ["to", "a", "an", "the", "of", "der", "die", "das", "ein", "eine", "le", "la", "les", "un", "une"]

    private static func add(_ head: String, gloss: String, reading: String, into merged: inout [String: Accumulator]) {
        let key = normalize(head)
        let gloss = clip(gloss, limit: 180)
        guard key.count >= 1, key.count <= 64, !gloss.isEmpty else { return }
        var slot = merged[key] ?? Accumulator(glosses: [], reading: "")
        if !slot.glosses.contains(gloss), slot.glosses.count < 6 {
            slot.glosses.append(gloss)
        }
        if slot.reading.isEmpty {
            slot.reading = reading
        }
        merged[key] = slot
    }

    private static func parsed(_ rawLine: String) -> Line? {
        var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.hasPrefix("\u{feff}") { line.removeFirst() }
        if line.isEmpty || line.hasPrefix("#") { return nil }
        guard let bracket = line.range(of: " ["),
              let close = line.range(of: "] /", range: bracket.upperBound..<line.endIndex) else { return nil }
        let heads = line[..<bracket.lowerBound].split(separator: " ").map(String.init)
        guard let traditional = heads.first, !traditional.isEmpty else { return nil }
        let simplified = heads.count >= 2 ? heads[1] : traditional
        let reading = String(line[bracket.upperBound..<close.lowerBound]).trimmingCharacters(in: .whitespaces)
        var glosses = line[close.upperBound...].split(separator: "/").map { cleanGloss(String($0)) }
        glosses.removeAll { $0.isEmpty }
        if glosses.count > 4 { glosses = Array(glosses.prefix(4)) }
        guard !glosses.isEmpty else { return nil }
        return Line(traditional: traditional, simplified: simplified, reading: reading, glosses: glosses)
    }

    private static func cleanGloss(_ raw: String) -> String {
        var text = raw.replacing(/\[[^\]]+\]/, with: "")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("("), text.hasSuffix(")"), text.count > 2 {
            text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private static func reverseKeys(in glosses: [String]) -> [String] {
        var keys: [String] = []
        var seen = Set<String>()
        for gloss in glosses {
            var text = gloss
            if let paren = text.firstIndex(of: "(") {
                text = String(text[..<paren])
            }
            for part in text.split(separator: ",") {
                var piece = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if piece.lowercased().hasPrefix("to ") {
                    piece = String(piece.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                let words = piece.split(separator: " ").map(String.init)
                if words.count >= 2, articles.contains(words[0].lowercased()) {
                    piece = words.dropFirst().joined(separator: " ")
                }
                guard piece.count >= 2, piece.count <= 32, piece.split(separator: " ").count <= 4 else { continue }
                guard piece.unicodeScalars.allSatisfy({ !CharacterSet.decimalDigits.contains($0) }) else { continue }
                guard piece.contains(where: { $0.isLetter }) else { continue }
                guard !containsHan(piece) else { continue }
                let key = normalize(piece)
                guard !articles.contains(key), seen.insert(key).inserted else { continue }
                keys.append(piece)
            }
        }
        return keys
    }

    private static func normalize(_ head: String) -> String {
        let trimmed = head.trimmingCharacters(in: .whitespacesAndNewlines)
        if containsHan(trimmed) { return trimmed }
        return trimmed.lowercased()
    }

    private static func containsHan(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x3400...0x9FFF).contains($0.value) }
    }

    private static func clip(_ text: String, limit: Int) -> String {
        if text.count <= limit { return text }
        return String(text.prefix(limit))
    }
}
