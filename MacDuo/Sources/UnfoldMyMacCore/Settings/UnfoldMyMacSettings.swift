import Foundation

public struct UnfoldMyMacSettings: Codable, Equatable, Sendable {
    public var effect: EffectID = .frost
    public var activation: Double = EffectMath.defaultActivation
    public var completionFraction: Double = EffectTuning.defaultCompletionFraction
    public var appearance: AppearancePreference = .system
    public var showAngle = true
    public var parameters: [String: EffectParameters] = [:]
    public init() {}
    private enum CodingKeys: String, CodingKey { case effect, activation, completionFraction, appearance, showAngle, parameters }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        effect = try values.decodeIfPresent(EffectID.self, forKey: .effect) ?? .frost
        activation = try values.decodeIfPresent(Double.self, forKey: .activation) ?? EffectMath.defaultActivation
        completionFraction = try values.decodeIfPresent(Double.self, forKey: .completionFraction) ?? EffectTuning.defaultCompletionFraction
        appearance = try values.decodeIfPresent(AppearancePreference.self, forKey: .appearance) ?? .system
        showAngle = try values.decodeIfPresent(Bool.self, forKey: .showAngle) ?? true
        parameters = try values.decodeIfPresent([String: EffectParameters].self, forKey: .parameters) ?? [:]
        sanitize()
    }
    public func parameters(for id: EffectID) -> EffectParameters { parameters[id.rawValue] ?? .init() }
    /// Drops parameters saved for effects that are no longer registered. Returns whether anything changed.
    @discardableResult public mutating func reconcile(effects: [EffectID]) -> Bool {
        let known = Set(effects.map(\.rawValue))
        let orphaned = parameters.keys.filter { !known.contains($0) }
        for key in orphaned { parameters[key] = nil }
        return !orphaned.isEmpty
    }
    public mutating func sanitize() {
        activation = activation.isFinite ? activation.clamped(to: EffectTuning.activationRange).rounded() : EffectMath.defaultActivation
        completionFraction = completionFraction.isFinite ? completionFraction.clamped(to: EffectTuning.completionRange) : EffectTuning.defaultCompletionFraction
        for (key, value) in parameters {
            parameters[key] = .init(strength: value.strength.isFinite ? min(1, max(0, value.strength)) : 1, reveal: value.reveal)
        }
    }
}
