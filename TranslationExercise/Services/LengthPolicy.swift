import Foundation

public enum LengthPreset: String, CaseIterable, Codable, Sendable, Identifiable {
    case short
    case medium
    case long

    public var id: String { rawValue }
}

public enum LengthUnit: String, Equatable, Sendable {
    case characters
    case words
}

public struct LengthSpec: Equatable, Sendable {
    public var range: ClosedRange<Int>
    public var sentenceRange: ClosedRange<Int>
    public var unit: LengthUnit

    public init(range: ClosedRange<Int>, sentenceRange: ClosedRange<Int>, unit: LengthUnit) {
        self.range = range
        self.sentenceRange = sentenceRange
        self.unit = unit
    }
}

public enum LengthPolicy {
    public static func spec(preset: LengthPreset, language: PracticeLanguage, direction: Direction, native: PracticeLanguage = .chinese) -> LengthSpec {
        let source = direction.source(native: native, practice: language)
        let unit: LengthUnit = source.usesCharacterCount ? .characters : .words
        switch preset {
        case .short:
            return LengthSpec(
                range: unit == .characters ? 20...40 : 10...20,
                sentenceRange: 1...2,
                unit: unit
            )
        case .medium:
            return LengthSpec(
                range: unit == .characters ? 60...100 : 30...50,
                sentenceRange: 2...4,
                unit: unit
            )
        case .long:
            return LengthSpec(
                range: unit == .characters ? 150...250 : 80...130,
                sentenceRange: 4...8,
                unit: unit
            )
        }
    }
}
