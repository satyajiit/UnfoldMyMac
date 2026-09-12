import Foundation

/// The saved values of one effect's parameters, keyed by `EffectParameterSpec.key`. Encoded flat, exactly as
/// earlier releases wrote `strength` and `reveal`; keys this build does not know are carried through untouched.
public struct EffectParameters: Codable, Equatable, Sendable {
    public var values: [String: EffectParameterValue]

    public init(values: [String: EffectParameterValue]) { self.values = values }
    public init(strength: Double = 1, reveal: ArtRevealMotion? = nil) {
        values = ["strength": .number(strength)]
        if let reveal { values["reveal"] = .choice(reveal.rawValue) }
    }
    public var strength: Double {
        get { values["strength"]?.number ?? 1 }
        set { values["strength"] = .number(newValue) }
    }
    public var reveal: ArtRevealMotion? {
        get { values["reveal"]?.choice.flatMap(ArtRevealMotion.init(rawValue:)) }
        set { values["reveal"] = newValue.map { .choice($0.rawValue) } }
    }
    public subscript(key: String) -> EffectParameterValue? {
        get { values[key] }
        set { values[key] = newValue }
    }

    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        values = [:]
        for key in container.allKeys {
            if let value = try? container.decode(EffectParameterValue.self, forKey: key) { values[key.stringValue] = value }
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        for (key, value) in values.sorted(by: { $0.key < $1.key }) { try container.encode(value, forKey: Key(stringValue: key)) }
    }
}
