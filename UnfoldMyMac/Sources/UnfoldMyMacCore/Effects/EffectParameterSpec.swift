import Foundation

/// What an effect lets the user adjust, declared by content. The inspector renders these generically; a
/// pipeline reads the saved value by key.
public struct EffectParameterSpec: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case slider, choice, toggle }
    public enum Format: String, Codable, Sendable { case percent, number }
    public struct Choice: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let title: String
        public init(id: String, title: String) { self.id = id; self.title = title }
    }
    public let key: String
    public let title: String
    public let kind: Kind
    public let minimum: Double
    public let maximum: Double
    public let step: Double
    public let format: Format
    public let `default`: EffectParameterValue
    public let choices: [Choice]
    public let group: String?
    public var groupTitle: String { group ?? (key == "reveal" ? "Motion & reveal" : "Appearance") }
    public var id: String { key }

    public init(key: String, title: String, kind: Kind, range: ClosedRange<Double> = 0...1, step: Double = 0.01,
                format: Format = .percent, default: EffectParameterValue, choices: [Choice] = [], group: String? = nil) {
        self.group = group
        self.key = key; self.title = title; self.kind = kind
        minimum = range.lowerBound; maximum = range.upperBound; self.step = step; self.format = format
        self.default = `default`; self.choices = choices
    }
    /// The intensity slider every bundled effect has had; the title is the effect's own word for it.
    public static func strength(title: String) -> EffectParameterSpec {
        .init(key: "strength", title: title, kind: .slider, default: .number(1))
    }
    public static func reveal(default motion: ArtRevealMotion) -> EffectParameterSpec {
        .init(key: "reveal", title: "Reveal", kind: .choice, default: .choice(motion.rawValue),
              choices: ArtRevealMotion.allCases.map { .init(id: $0.rawValue, title: $0.title) })
    }
    public var isValid: Bool {
        guard (group?.count ?? 0) <= 60, !key.isEmpty, key.count <= 40, !title.isEmpty, [minimum, maximum, step].allSatisfy(\.isFinite) else { return false }
        switch kind {
        case .slider: return minimum < maximum && step > 0 && `default`.number != nil
        case .choice: return !choices.isEmpty && Set(choices.map(\.id)).count == choices.count && `default`.choice.map { id in choices.contains { $0.id == id } } == true
        case .toggle: return `default`.flag != nil
        }
    }
    /// The value as the pipeline may use it: sliders inside their range, choices among the declared ones.
    public func clamp(_ value: EffectParameterValue) -> EffectParameterValue {
        switch kind {
        case .slider:
            guard let number = value.number, number.isFinite else { return `default` }
            return .number(min(maximum, max(minimum, number)))
        case .choice:
            guard let id = value.choice, choices.contains(where: { $0.id == id }) else { return `default` }
            return value
        case .toggle: return value.flag == nil ? `default` : value
        }
    }

    private enum CodingKeys: String, CodingKey { case key, title, kind, range, step, format, `default`, choices, group }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        group = try values.decodeIfPresent(String.self, forKey: .group)
        key = try values.decode(String.self, forKey: .key)
        title = try values.decode(String.self, forKey: .title)
        kind = try values.decode(Kind.self, forKey: .kind)
        let range = try values.decodeIfPresent([Double].self, forKey: .range) ?? [0, 1]
        minimum = range.first ?? 0; maximum = range.count > 1 ? range[1] : 1
        step = try values.decodeIfPresent(Double.self, forKey: .step) ?? 0.01
        format = try values.decodeIfPresent(Format.self, forKey: .format) ?? .percent
        `default` = try values.decode(EffectParameterValue.self, forKey: .default)
        choices = try values.decodeIfPresent([Choice].self, forKey: .choices) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encodeIfPresent(group, forKey: .group)
        try values.encode(key, forKey: .key); try values.encode(title, forKey: .title); try values.encode(kind, forKey: .kind)
        try values.encode([minimum, maximum], forKey: .range); try values.encode(step, forKey: .step)
        try values.encode(format, forKey: .format); try values.encode(`default`, forKey: .default)
        if !choices.isEmpty { try values.encode(choices, forKey: .choices) }
    }
}
