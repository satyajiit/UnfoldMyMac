import Foundation

/// One saved effect parameter. Encoded as the bare JSON scalar, so `{"strength":0.42,"reveal":"straight"}`
/// stays the on-disk shape it has always been.
public enum EffectParameterValue: Hashable, Sendable, Codable {
    case number(Double)
    case choice(String)
    case flag(Bool)

    public var number: Double? { if case .number(let value) = self { value } else { nil } }
    public var choice: String? { if case .choice(let value) = self { value } else { nil } }
    public var flag: Bool? { if case .flag(let value) = self { value } else { nil } }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let flag = try? container.decode(Bool.self) { self = .flag(flag) }
        else if let number = try? container.decode(Double.self) { self = .number(number) }
        else { self = .choice(try container.decode(String.self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let value): try container.encode(value)
        case .choice(let value): try container.encode(value)
        case .flag(let value): try container.encode(value)
        }
    }
}
