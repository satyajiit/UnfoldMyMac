import Foundation

public struct UnfoldMyMacSettings: Codable, Equatable, Sendable {
    public var effect: EffectID = .frost
    public var activation: Double = EffectMath.defaultActivation
    public var completionFraction: Double = EffectTuning.defaultCompletionFraction
    public var appearance: AppearancePreference = .system
    public var showAngle = true
    public var parameters: [String: EffectParameters] = [:]
    public init() {}
    /// Current key, the pre-rename JSON key, and the two raw keys the first release wrote.
    public static let key = PreferenceKey<UnfoldMyMacSettings>("unfoldmymac.settings.v1", legacyNames: ["luma.settings.v1", "activation", "style"],
        default: { UnfoldMyMacSettings() },
        migrate: { store in
            let activation = store.object(forKey: "activation") as? Double
            let style = store.object(forKey: "style") as? Int
            guard activation != nil || style != nil else { return nil }
            var value = UnfoldMyMacSettings()
            if let activation { value.activation = activation }
            if let style { value.effect = style == 2 ? .veil : .frost }
            return value
        },
        sanitize: { $0.sanitize() })
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
            var next = value
            next.strength = value.strength.isFinite ? min(1, max(0, value.strength)) : 1
            parameters[key] = next
        }
    }
}
