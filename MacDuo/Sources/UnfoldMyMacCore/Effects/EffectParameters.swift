import Foundation

public struct EffectParameters: Codable, Equatable, Sendable {
    public var strength: Double
    public var reveal: ArtRevealMotion?
    public init(strength: Double = 1, reveal: ArtRevealMotion? = nil) { self.strength = strength; self.reveal = reveal }
    private enum CodingKeys: String, CodingKey { case strength, reveal }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        strength = try values.decodeIfPresent(Double.self, forKey: .strength) ?? 1
        reveal = try values.decodeIfPresent(ArtRevealMotion.self, forKey: .reveal)
    }
}
