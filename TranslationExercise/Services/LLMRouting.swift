import Foundation

public enum LLMProtocolKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case openAI
    case anthropic

    public var id: String { rawValue }
}

public enum LLMTask: String, CaseIterable, Codable, Sendable, Identifiable {
    case generate
    case placement
    case grade
    case correct
    case exemplar
    case vocabulary

    public var id: String { rawValue }

    public var usesTranslationModel: Bool {
        switch self {
        case .correct, .exemplar, .vocabulary:
            true
        case .generate, .placement, .grade:
            false
        }
    }
}

public struct EndpointConfig: Codable, Equatable, Sendable {
    public var kind: LLMProtocolKind
    public var baseURL: String
    public var model: String

    public init(kind: LLMProtocolKind = .openAI, baseURL: String = "", model: String = "") {
        self.kind = kind
        self.baseURL = baseURL
        self.model = model
    }

    public var isComplete: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct LLMSettings: Codable, Equatable, Sendable {
    public var defaultEndpoint: EndpointConfig
    public var translationEndpoint: EndpointConfig
    public var overrides: [String: EndpointConfig]

    public init(
        defaultEndpoint: EndpointConfig = EndpointConfig(),
        translationEndpoint: EndpointConfig = EndpointConfig(),
        overrides: [String: EndpointConfig] = [:]
    ) {
        self.defaultEndpoint = defaultEndpoint
        self.translationEndpoint = translationEndpoint
        self.overrides = overrides
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultEndpoint = try container.decodeIfPresent(EndpointConfig.self, forKey: .defaultEndpoint) ?? EndpointConfig()
        translationEndpoint = try container.decodeIfPresent(EndpointConfig.self, forKey: .translationEndpoint) ?? EndpointConfig()
        overrides = try container.decodeIfPresent([String: EndpointConfig].self, forKey: .overrides) ?? [:]
        if !translationEndpoint.isComplete {
            for task in LLMTask.allCases where task.usesTranslationModel {
                if let existing = overrides[task.rawValue], existing.isComplete {
                    translationEndpoint = existing
                    break
                }
            }
        }
        for task in LLMTask.allCases where task.usesTranslationModel {
            overrides[task.rawValue] = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultEndpoint, forKey: .defaultEndpoint)
        try container.encode(translationEndpoint, forKey: .translationEndpoint)
        try container.encode(overrides, forKey: .overrides)
    }

    private enum CodingKeys: String, CodingKey {
        case defaultEndpoint
        case translationEndpoint
        case overrides
    }

    public func config(for task: LLMTask) -> EndpointConfig {
        if let override = overrides[task.rawValue], override.isComplete {
            return override
        }
        if task.usesTranslationModel, translationEndpoint.isComplete {
            return translationEndpoint
        }
        return defaultEndpoint
    }

    public func keyAccount(for task: LLMTask) -> String {
        if let override = overrides[task.rawValue], override.isComplete {
            return "llm.\(task.rawValue)"
        }
        if task.usesTranslationModel, translationEndpoint.isComplete {
            return "llm.translation"
        }
        return "llm.default"
    }
}

public struct EndpointIdentity: Equatable, Sendable {
    public var kind: LLMProtocolKind
    public var baseURL: String
    public var model: String
    public var keyAccount: String
}

public enum LLMRouting {
    public static func identity(for task: LLMTask, settings: LLMSettings) -> EndpointIdentity {
        let config = settings.config(for: task)
        return EndpointIdentity(
            kind: config.kind,
            baseURL: config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            model: config.model.trimmingCharacters(in: .whitespacesAndNewlines),
            keyAccount: settings.keyAccount(for: task)
        )
    }

    public static func mergesReview(settings: LLMSettings) -> Bool {
        let grade = identity(for: .grade, settings: settings)
        return grade == identity(for: .correct, settings: settings)
            && grade == identity(for: .exemplar, settings: settings)
    }
}

public enum LLMJSON {
    public struct Payload: Decodable, Sendable {
        public var topic: String?
        public var text: String?
        public var faithfulness: Int?
        public var expressiveness: Int?
        public var elegance: Int?
        public var corrected: String?
        public var exemplar: String?
        public var exemplarFaithfulness: Int?
        public var exemplarExpressiveness: Int?
        public var exemplarElegance: Int?
        public var errorTags: [String]?
        public var gloss: String?
        public var ipa: String?
        public var reasons: [String]?
    }

    public static func decode(_ text: String) throws -> Payload {
        let data = try jsonData(from: text)
        return try JSONDecoder().decode(Payload.self, from: data)
    }

    static func jsonData(from text: String) throws -> Data {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            trimmed = trimmed.replacingOccurrences(of: "```json", with: "")
            trimmed = trimmed.replacingOccurrences(of: "```", with: "")
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
            trimmed = String(trimmed[start...end])
        }
        guard let data = trimmed.data(using: .utf8) else {
            throw LLMParseError.empty
        }
        return data
    }
}

public enum LLMParseError: Error {
    case empty
}
