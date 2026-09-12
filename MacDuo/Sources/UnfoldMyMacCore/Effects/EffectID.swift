import Foundation

public struct EffectID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let frost = EffectID(rawValue: "frost")
    public static let veil = EffectID(rawValue: "veil")
    public static let fade = EffectID(rawValue: "fade")
    public static let curtains = EffectID(rawValue: "curtains")
    public static let reverie = EffectID(rawValue: "reverie")
    public static let neonCoast = EffectID(rawValue: "neon-coast")
    public static let rise = EffectID(rawValue: "rise")
    public static let current = EffectID(rawValue: "current")
}
