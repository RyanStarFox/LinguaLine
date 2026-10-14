import Foundation

public enum ScoreMath {
    public static func weighted(faithfulness: Int, expressiveness: Int, elegance: Int) -> Int {
        let faith = clamp(faithfulness)
        let express = clamp(expressiveness)
        let eleg = clamp(elegance)
        let raw = Double(faith) * 0.4 + Double(express) * 0.4 + Double(eleg) * 0.2
        return Int(raw.rounded())
    }

    public static func clamp(_ value: Int) -> Int {
        min(100, max(0, value))
    }
}
