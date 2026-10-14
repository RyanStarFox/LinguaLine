import Foundation

public enum LLMClientError: Error, LocalizedError, Sendable {
    case missingConfiguration
    case badURL
    case transport(String)
    case http(Int, String)
    case emptyContent
    case invalidJSON

    public var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "还没有可用的大模型接口。请先在设置里填写地址、模型名和密钥。"
        case .badURL:
            "接口地址无法识别。"
        case let .transport(message):
            message
        case let .http(code, body):
            "接口返回 \(code)。\(body)"
        case .emptyContent:
            "接口没有返回内容。"
        case .invalidJSON:
            "接口返回的不是可用的 JSON。"
        }
    }
}

public struct LLMClient: Sendable {
    private let session: URLSession
    private let loadKey: @Sendable (String) -> String?
    private let recordUsage: @Sendable (String, String, Int, Int) -> Void

    public init(
        session: URLSession = .shared,
        loadKey: @escaping @Sendable (String) -> String?,
        recordUsage: @escaping @Sendable (String, String, Int, Int) -> Void = { _, _, _, _ in }
    ) {
        self.session = session
        self.loadKey = loadKey
        self.recordUsage = recordUsage
    }

    public func completeJSON(task: LLMTask, settings: LLMSettings, prompt: String, temperature: Double) async throws -> LLMJSON.Payload {
        let first = try await complete(task: task, settings: settings, prompt: prompt, temperature: temperature)
        if let payload = try? LLMJSON.decode(first) {
            return payload
        }
        let second = try await complete(
            task: task,
            settings: settings,
            prompt: prompt + "\n上一次没有返回合法 JSON。这次只返回一个 JSON 对象，不要使用 Markdown。",
            temperature: 0
        )
        do {
            return try LLMJSON.decode(second)
        } catch {
            throw LLMClientError.invalidJSON
        }
    }

    public func complete(task: LLMTask, settings: LLMSettings, prompt: String, temperature: Double) async throws -> String {
        let identity = LLMRouting.identity(for: task, settings: settings)
        let config = settings.config(for: task)
        guard config.isComplete else { throw LLMClientError.missingConfiguration }
        guard let key = loadKey(identity.keyAccount), !key.isEmpty else {
            throw LLMClientError.missingConfiguration
        }
        let exchange = try await send(
            kind: identity.kind,
            baseURL: identity.baseURL,
            model: identity.model,
            key: key,
            prompt: prompt,
            temperature: temperature,
            timeout: 90,
            suppressThinking: true
        )
        if exchange.inputTokens > 0 || exchange.outputTokens > 0 {
            recordUsage(identity.keyAccount, identity.model, exchange.inputTokens, exchange.outputTokens)
        }
        return exchange.text
    }

    public func probe(kind: LLMProtocolKind, baseURL: String, model: String, key: String) async throws -> String {
        try await send(
            kind: kind,
            baseURL: baseURL,
            model: model,
            key: key,
            prompt: "Reply with ok.",
            temperature: 0,
            timeout: 30,
            suppressThinking: true
        ).text
    }

    private func send(
        kind: LLMProtocolKind,
        baseURL: String,
        model: String,
        key: String,
        prompt: String,
        temperature: Double,
        timeout: TimeInterval,
        suppressThinking: Bool
    ) async throws -> LLMExchange {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !trimmedModel.isEmpty,
              !trimmedKey.isEmpty else {
            throw LLMClientError.missingConfiguration
        }
        guard let url = endpointURL(kind: kind, baseURL: baseURL) else {
            throw LLMClientError.badURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        if kind == .anthropic {
            request.setValue(trimmedKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
        request.httpBody = try JSONSerialization.data(
            withJSONObject: requestBody(
                kind: kind,
                model: trimmedModel,
                prompt: prompt,
                temperature: temperature,
                suppressThinking: suppressThinking
            )
        )
        do {
            return try await execute(request, kind: kind)
        } catch let error as LLMClientError where suppressThinking && Self.rejectedThinkingFlag(error) {
            request.httpBody = try JSONSerialization.data(
                withJSONObject: requestBody(
                    kind: kind,
                    model: trimmedModel,
                    prompt: prompt,
                    temperature: temperature,
                    suppressThinking: false
                )
            )
            return try await execute(request, kind: kind)
        }
    }

    private func execute(_ request: URLRequest, kind: LLMProtocolKind) async throws -> LLMExchange {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LLMClientError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw LLMClientError.transport("没有收到 HTTP 响应。")
        }
        guard (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8)?.prefix(240) ?? ""
            throw LLMClientError.http(http.statusCode, String(snippet))
        }
        let parsed = try TokenUsageReading.exchange(kind: kind, body: data)
        if parsed.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LLMClientError.emptyContent
        }
        return LLMExchange(text: parsed.text, inputTokens: parsed.inputTokens, outputTokens: parsed.outputTokens)
    }

    private static func rejectedThinkingFlag(_ error: LLMClientError) -> Bool {
        guard case let .http(400, body) = error else { return false }
        let lowered = body.lowercased()
        return lowered.contains("enable_thinking")
            || lowered.contains("reasoning_effort")
            || lowered.contains("chat_template_kwargs")
    }

    private func endpointURL(kind: LLMProtocolKind, baseURL: String) -> URL? {
        var raw = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while raw.hasSuffix("/") { raw.removeLast() }
        switch kind {
        case .openAI:
            if !raw.hasSuffix("/chat/completions") {
                raw += "/chat/completions"
            }
        case .anthropic:
            if !raw.hasSuffix("/messages") {
                if raw.hasSuffix("/v1") {
                    raw += "/messages"
                } else {
                    raw += "/v1/messages"
                }
            }
        }
        return URL(string: raw)
    }

    private func requestBody(
        kind: LLMProtocolKind,
        model: String,
        prompt: String,
        temperature: Double,
        suppressThinking: Bool
    ) -> [String: Any] {
        switch kind {
        case .openAI:
            var body: [String: Any] = [
                "model": model,
                "temperature": temperature,
                "messages": [
                    ["role": "system", "content": "你只按用户要求返回内容。"],
                    ["role": "user", "content": prompt],
                ],
            ]
            if suppressThinking {
                body["enable_thinking"] = false
                body["reasoning_effort"] = "none"
                body["chat_template_kwargs"] = ["enable_thinking": false]
            }
            return body
        case .anthropic:
            return [
                "model": model,
                "max_tokens": 4096,
                "temperature": temperature,
                "system": "你只按用户要求返回内容。",
                "messages": [
                    ["role": "user", "content": prompt],
                ],
            ]
        }
    }

}

private struct LLMExchange: Sendable {
    var text: String
    var inputTokens: Int
    var outputTokens: Int
}

public struct TokenTally: Codable, Equatable, Sendable {
    public var input: Int
    public var output: Int

    public init(input: Int = 0, output: Int = 0) {
        self.input = input
        self.output = output
    }
}

public enum TokenUsageReading {
    public static func exchange(kind: LLMProtocolKind, body: Data) throws -> (text: String, inputTokens: Int, outputTokens: Int) {
        switch kind {
        case .openAI:
            let decoded = try JSONDecoder().decode(OpenAIEnvelope.self, from: body)
            let text = decoded.choices.first?.message.content ?? ""
            return (text, decoded.usage?.promptTokens ?? 0, decoded.usage?.completionTokens ?? 0)
        case .anthropic:
            let decoded = try JSONDecoder().decode(AnthropicEnvelope.self, from: body)
            let text = decoded.content.compactMap(\.text).joined()
            return (text, decoded.usage?.inputTokens ?? 0, decoded.usage?.outputTokens ?? 0)
        }
    }

    public static func tokens(kind: LLMProtocolKind, body: Data) -> TokenTally {
        guard let exchange = try? exchange(kind: kind, body: body) else {
            return TokenTally()
        }
        return TokenTally(input: exchange.inputTokens, output: exchange.outputTokens)
    }
}

public struct TokenDayRecord: Codable, Equatable, Sendable {
    public var day: String
    public var account: String
    public var model: String
    public var input: Int
    public var output: Int

    public init(day: String, account: String, model: String = "", input: Int, output: Int) {
        self.day = day
        self.account = account
        self.model = model
        self.input = input
        self.output = output
    }

    private enum CodingKeys: String, CodingKey {
        case day
        case account
        case model
        case input
        case output
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(String.self, forKey: .day)
        account = try container.decode(String.self, forKey: .account)
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        input = try container.decode(Int.self, forKey: .input)
        output = try container.decode(Int.self, forKey: .output)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        try container.encode(account, forKey: .account)
        try container.encode(model, forKey: .model)
        try container.encode(input, forKey: .input)
        try container.encode(output, forKey: .output)
    }
}

public struct ModelTokenPrice: Codable, Equatable, Sendable {
    public var model: String
    public var currencyCode: String
    public var inputPerMillion: String
    public var outputPerMillion: String

    public init(model: String, currencyCode: String = "CNY", inputPerMillion: String = "", outputPerMillion: String = "") {
        self.model = model
        self.currencyCode = currencyCode
        self.inputPerMillion = inputPerMillion
        self.outputPerMillion = outputPerMillion
    }
}

public enum TokenMoney {
    public static func amount(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    public static func cost(input: Int, output: Int, price: ModelTokenPrice) -> Decimal? {
        let inputPrice = amount(price.inputPerMillion)
        let outputPrice = amount(price.outputPerMillion)
        guard inputPrice != nil || outputPrice != nil else { return nil }
        let million = Decimal(1_000_000)
        let inputPart = Decimal(input) / million * (inputPrice ?? 0)
        let outputPart = Decimal(output) / million * (outputPrice ?? 0)
        return inputPart + outputPart
    }

    public static func text(_ value: Decimal, currencyCode: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        formatter.roundingMode = .halfEven
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}

public enum TokenSpan: String, CaseIterable, Hashable, Sendable {
    case day
    case month
    case year
}

public enum TokenUnit: String, CaseIterable, Hashable, Sendable {
    case one
    case thousand
    case million
    case billion

    public static let storageKey = "stats.token.unit.v1"

    public var divisor: Int {
        switch self {
        case .one: 1
        case .thousand: 1_000
        case .million: 1_000_000
        case .billion: 1_000_000_000
        }
    }

    public var fractionDigits: Int {
        switch self {
        case .one: 0
        case .thousand: 3
        case .million: 6
        case .billion: 9
        }
    }

    public static var stored: TokenUnit {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let unit = TokenUnit(rawValue: raw) else { return .one }
        return unit
    }

    public func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
    }

    public func scale(_ count: Int) -> Double {
        Double(count) / Double(divisor)
    }

    public func text(_ count: Int, locale: Locale = .current) -> String {
        Self.format(Decimal(count) / Decimal(divisor), fractionDigits: fractionDigits, locale: locale)
    }

    public func axisText(_ value: Double, locale: Locale = .current) -> String {
        Self.format(Decimal(value), fractionDigits: fractionDigits, locale: locale)
    }

    public var suffix: String {
        switch self {
        case .one: ""
        case .thousand: "K"
        case .million: "M"
        case .billion: "B"
        }
    }

    public static func fitting(_ count: Int) -> TokenUnit {
        let magnitude = abs(count)
        if magnitude >= 1_000_000_000 { return .billion }
        if magnitude >= 1_000_000 { return .million }
        if magnitude >= 1_000 { return .thousand }
        return .one
    }

    public static func compactText(_ count: Int, locale: Locale = .current) -> String {
        let sign = count < 0 ? "-" : ""
        let magnitude = abs(count)
        var unit = fitting(magnitude)
        guard unit != .one else {
            return sign + format(Decimal(magnitude), fractionDigits: 0, locale: locale)
        }
        var scaled = Decimal(magnitude) / Decimal(unit.divisor)
        var digits = compactDigits(scaled)
        var shown = rounded(scaled, digits: digits)
        if shown >= 1000, let next = unit.nextLarger {
            unit = next
            scaled = Decimal(magnitude) / Decimal(unit.divisor)
            digits = compactDigits(scaled)
            shown = rounded(scaled, digits: digits)
        }
        return sign + format(shown, fractionDigits: digits, locale: locale) + unit.suffix
    }

    public func axisCompact(_ value: Double, locale: Locale = .current) -> String {
        if value == 0 { return "0" }
        let digits = Self.compactDigits(Decimal(value))
        return Self.format(Decimal(value), fractionDigits: digits, locale: locale) + suffix
    }

    private var nextLarger: TokenUnit? {
        switch self {
        case .one: .thousand
        case .thousand: .million
        case .million: .billion
        case .billion: nil
        }
    }

    private static func compactDigits(_ scaled: Decimal) -> Int {
        let magnitude = scaled < 0 ? -scaled : scaled
        if magnitude >= 100 { return 0 }
        if magnitude >= 10 { return 1 }
        return 2
    }

    private static func rounded(_ value: Decimal, digits: Int) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, digits, .bankers)
        return result
    }

    private static func format(_ value: Decimal, fractionDigits: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        formatter.roundingMode = .halfEven
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0"
    }
}

public struct TokenBucket: Equatable, Sendable, Identifiable {
    public var id: String { key }
    public var key: String
    public var label: String
    public var input: Int
    public var output: Int
    public var total: Int { input + output }

    public init(key: String, label: String, input: Int, output: Int) {
        self.key = key
        self.label = label
        self.input = input
        self.output = output
    }
}

public struct TokenSegment: Equatable, Sendable, Identifiable {
    public var id: String { "\(key)|\(model)" }
    public var key: String
    public var label: String
    public var model: String
    public var input: Int
    public var output: Int
    public var total: Int { input + output }

    public init(key: String, label: String, model: String, input: Int, output: Int) {
        self.key = key
        self.label = label
        self.model = model
        self.input = input
        self.output = output
    }
}

public enum TokenSeries {
    public static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func parse(day: String, calendar: Calendar) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    public static func withModels(_ records: [TokenDayRecord], accountModels: [String: String]) -> [TokenDayRecord] {
        records.map { record in
            var copy = record
            let existing = record.model.trimmingCharacters(in: .whitespacesAndNewlines)
            if !existing.isEmpty {
                copy.model = existing
                return copy
            }
            let fallback = accountModels[record.account]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            copy.model = fallback.isEmpty ? record.account : fallback
            return copy
        }
    }

    public static func buckets(
        records: [TokenDayRecord],
        span: TokenSpan,
        ending: Date,
        calendar: Calendar,
        count: Int,
        model: String? = nil
    ) -> [TokenBucket] {
        periods(span: span, ending: ending, calendar: calendar, count: count).map { period in
            let matched = records.filter { record in
                guard model == nil || record.model == model else { return false }
                guard let date = parse(day: record.day, calendar: calendar) else { return false }
                return date >= period.start && date < period.next
            }
            return TokenBucket(
                key: period.key,
                label: period.label,
                input: matched.reduce(0) { $0 + $1.input },
                output: matched.reduce(0) { $0 + $1.output }
            )
        }
    }

    public static func segments(
        records: [TokenDayRecord],
        span: TokenSpan,
        ending: Date,
        calendar: Calendar,
        count: Int
    ) -> [TokenSegment] {
        periods(span: span, ending: ending, calendar: calendar, count: count).flatMap { period in
            let matched = records.filter { record in
                guard let date = parse(day: record.day, calendar: calendar) else { return false }
                return date >= period.start && date < period.next
            }
            var order: [String] = []
            var totals: [String: (input: Int, output: Int)] = [:]
            for record in matched {
                if totals[record.model] == nil {
                    order.append(record.model)
                }
                var pair = totals[record.model] ?? (0, 0)
                pair.input += record.input
                pair.output += record.output
                totals[record.model] = pair
            }
            if order.isEmpty {
                return [TokenSegment(key: period.key, label: period.label, model: "", input: 0, output: 0)]
            }
            return order.compactMap { name in
                guard let pair = totals[name], pair.input + pair.output > 0 else { return nil }
                return TokenSegment(key: period.key, label: period.label, model: name, input: pair.input, output: pair.output)
            }
        }
    }

    private static func periods(
        span: TokenSpan,
        ending: Date,
        calendar: Calendar,
        count: Int
    ) -> [(start: Date, next: Date, key: String, label: String)] {
        let length = max(count, 1)
        let current = periodStart(span, date: ending, calendar: calendar)
        var starts: [Date] = []
        var cursor = current
        for _ in 0..<length {
            starts.append(cursor)
            guard let previous = calendar.date(byAdding: component(span), value: -1, to: cursor) else { break }
            cursor = previous
        }
        return starts.reversed().map { start in
            let next = calendar.date(byAdding: component(span), value: 1, to: start) ?? start
            return (
                start,
                next,
                bucketKey(start, span: span, calendar: calendar),
                label(start, span: span, calendar: calendar)
            )
        }
    }

    public static func window(span: TokenSpan, ending: Date, calendar: Calendar, count: Int) -> Range<Date>? {
        let length = max(count, 1)
        let current = periodStart(span, date: ending, calendar: calendar)
        guard let next = calendar.date(byAdding: component(span), value: 1, to: current),
              let start = calendar.date(byAdding: component(span), value: -(length - 1), to: current) else {
            return nil
        }
        return start..<next
    }

    private static func periodStart(_ span: TokenSpan, date: Date, calendar: Calendar) -> Date {
        switch span {
        case .day:
            return calendar.startOfDay(for: date)
        case .month:
            let parts = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: parts) ?? calendar.startOfDay(for: date)
        case .year:
            let parts = calendar.dateComponents([.year], from: date)
            return calendar.date(from: parts) ?? calendar.startOfDay(for: date)
        }
    }

    private static func component(_ span: TokenSpan) -> Calendar.Component {
        switch span {
        case .day: .day
        case .month: .month
        case .year: .year
        }
    }

    private static func bucketKey(_ date: Date, span: TokenSpan, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        switch span {
        case .day:
            return dayKey(date, calendar: calendar)
        case .month:
            return String(format: "%04d-%02d", year, month)
        case .year:
            return String(format: "%04d", year)
        }
    }

    private static func label(_ date: Date, span: TokenSpan, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        switch span {
        case .day:
            return "\(month)/\(day)"
        case .month:
            return "\(year)/\(month)"
        case .year:
            return "\(year)"
        }
    }
}

private struct TokenArchive: Codable {
    var totals: [String: TokenTally]
    var days: [TokenDayRecord]
}

@MainActor
@Observable
public final class TokenLedger {
    public private(set) var totals: [String: TokenTally] = [:]
    public private(set) var days: [TokenDayRecord] = []
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "llm.tokens.v1") {
        self.defaults = defaults
        self.key = key
        guard let data = defaults.data(forKey: key) else { return }
        if let archive = try? JSONDecoder().decode(TokenArchive.self, from: data) {
            totals = archive.totals
            days = archive.days
        } else if let stored = try? JSONDecoder().decode([String: TokenTally].self, from: data) {
            totals = stored
        }
    }

    public func tally(for account: String) -> TokenTally {
        totals[account] ?? TokenTally()
    }

    public var lifetime: TokenTally {
        totals.values.reduce(into: TokenTally()) { total, tally in
            total.input += tally.input
            total.output += tally.output
        }
    }

    public var dated: TokenTally {
        days.reduce(into: TokenTally()) { total, record in
            total.input += record.input
            total.output += record.output
        }
    }

    public var hasUndated: Bool {
        lifetime.input + lifetime.output > dated.input + dated.output
    }

    public var modelNames: [String] {
        var seen: [String] = []
        for record in days {
            let name = record.model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !seen.contains(name) else { continue }
            seen.append(name)
        }
        return seen.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public func buckets(
        span: TokenSpan,
        ending: Date = Date(),
        calendar: Calendar = .current,
        count: Int,
        model: String? = nil
    ) -> [TokenBucket] {
        TokenSeries.buckets(records: days, span: span, ending: ending, calendar: calendar, count: count, model: model)
    }

    public func segments(
        span: TokenSpan,
        ending: Date = Date(),
        calendar: Calendar = .current,
        count: Int
    ) -> [TokenSegment] {
        TokenSeries.segments(records: days, span: span, ending: ending, calendar: calendar, count: count)
    }

    public func tally(
        model: String,
        span: TokenSpan,
        ending: Date = Date(),
        calendar: Calendar = .current,
        count: Int
    ) -> TokenTally {
        guard let window = TokenSeries.window(span: span, ending: ending, calendar: calendar, count: count) else {
            return TokenTally()
        }
        return days.reduce(into: TokenTally()) { total, record in
            guard record.model == model,
                  let date = TokenSeries.parse(day: record.day, calendar: calendar),
                  window.contains(date) else { return }
            total.input += record.input
            total.output += record.output
        }
    }

    public func tally(
        for account: String,
        span: TokenSpan,
        ending: Date = Date(),
        calendar: Calendar = .current,
        count: Int
    ) -> TokenTally {
        guard let window = TokenSeries.window(span: span, ending: ending, calendar: calendar, count: count) else {
            return TokenTally()
        }
        return days.reduce(into: TokenTally()) { total, record in
            guard record.account == account,
                  let date = TokenSeries.parse(day: record.day, calendar: calendar),
                  window.contains(date) else { return }
            total.input += record.input
            total.output += record.output
        }
    }

    public func add(
        account: String,
        input: Int,
        output: Int,
        model: String = "",
        on date: Date = Date(),
        calendar: Calendar = .current
    ) {
        guard input > 0 || output > 0 else { return }
        let model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        var current = tally(for: account)
        current.input += input
        current.output += output
        totals[account] = current
        let day = TokenSeries.dayKey(date, calendar: calendar)
        if let index = days.firstIndex(where: { $0.day == day && $0.account == account && $0.model == model }) {
            days[index].input += input
            days[index].output += output
        } else {
            days.append(TokenDayRecord(day: day, account: account, model: model, input: input, output: output))
        }
        let archive = TokenArchive(totals: totals, days: days)
        if let data = try? JSONEncoder().encode(archive) {
            defaults.set(data, forKey: key)
        }
    }
}

private struct OpenAIEnvelope: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            var content: String?
        }
        var message: Message
    }
    struct Usage: Decodable {
        var promptTokens: Int?
        var completionTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
        }
    }
    var choices: [Choice]
    var usage: Usage?
}

private struct AnthropicEnvelope: Decodable {
    struct Block: Decodable {
        var text: String?
    }
    struct Usage: Decodable {
        var inputTokens: Int?
        var outputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }
    var content: [Block]
    var usage: Usage?
}
