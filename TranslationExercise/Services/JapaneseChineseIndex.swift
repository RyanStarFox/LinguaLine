import Foundation

public enum JapaneseChineseIndex {
    public static func records(in data: Data) -> [DictionaryRecord] {
        var payload = data
        if payload.starts(with: [0xEF, 0xBB, 0xBF]) {
            payload = payload.dropFirst(3)
        }
        guard let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            return []
        }
        var merged: [String: Accumulator] = [:]
        var reverses: [(head: String, gloss: String)] = []
        for (rawHead, rawValue) in object {
            guard let value = rawValue as? String else { continue }
            let head = rawHead.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = split(value)
            let gloss = clip(parts.gloss)
            guard !head.isEmpty, !gloss.isEmpty else { continue }
            add(head, gloss: gloss, reading: parts.reading, into: &merged)
            if !parts.reading.isEmpty, parts.reading != head {
                add(parts.reading, gloss: gloss, reading: "", into: &merged)
            }
            let reverse = head + (parts.reading.isEmpty ? "" : "（\(parts.reading)）")
            for key in chineseKeys(in: parts.gloss) where key != head {
                reverses.append((key, reverse))
            }
        }
        for item in reverses where merged[item.head] == nil {
            add(item.head, gloss: item.gloss, reading: "", into: &merged)
        }
        return merged.map { head, item in
            DictionaryRecord(head: head, gloss: item.glosses.joined(separator: "；"), reading: item.reading)
        }
    }

    private struct Accumulator {
        var glosses: [String]
        var reading: String
    }

    private static func add(_ head: String, gloss: String, reading: String, into merged: inout [String: Accumulator]) {
        let key = head.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private static func split(_ value: String) -> (reading: String, gloss: String) {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let open = text.first, open == "(" || open == "（" else {
            return ("", stripTag(stripPitch(text)))
        }
        let close: Character = open == "(" ? ")" : "）"
        guard let end = text.firstIndex(of: close) else {
            return ("", stripTag(stripPitch(text)))
        }
        let reading = stripPitch(String(text[text.index(after: text.startIndex)..<end]))
        let gloss = stripTag(stripPitch(String(text[text.index(after: end)...])))
        return (reading, gloss)
    }

    private static func stripPitch(_ text: String) -> String {
        let marks = "0123456789⓪①②③④⑤⑥⑦⑧⑨⑩"
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = result.last, marks.contains(last) {
            result.removeLast()
        }
        while let first = result.first, marks.contains(first) {
            result.removeFirst()
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripTag(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("【"), let end = result.firstIndex(of: "】") {
            result = String(result[result.index(after: end)...])
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func chineseKeys(in gloss: String) -> [String] {
        var text = gloss
        if let paren = text.firstIndex(where: { $0 == "(" || $0 == "（" }) {
            text = String(text[..<paren])
        }
        var keys: [String] = []
        var seen = Set<String>()
        for part in text.split(whereSeparator: { "，,、；;".contains($0) }) {
            let piece = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (1...8).contains(piece.count), seen.insert(piece).inserted else { continue }
            guard piece.unicodeScalars.contains(where: { (0x3400...0x9FFF).contains($0.value) }) else { continue }
            guard !piece.unicodeScalars.contains(where: { CharacterSet.decimalDigits.contains($0) }) else { continue }
            guard !piece.contains(where: isKana) else { continue }
            keys.append(piece)
        }
        return keys
    }

    private static func isKana(_ character: Character) -> Bool {
        character.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) }
    }

    private static func clip(_ text: String) -> String {
        if text.count <= 180 { return text }
        return String(text.prefix(180))
    }
}
