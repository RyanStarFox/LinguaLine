import Foundation

public enum ChinesePinyin {
    public static func marks(of text: String) -> String {
        var source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let paren = source.firstIndex(where: { $0 == "（" || $0 == "(" }) {
            source = String(source[..<paren]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !source.isEmpty, let transformed = source.applyingTransform(.mandarinToLatin, reverse: false) else {
            return ""
        }
        return transformed
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
