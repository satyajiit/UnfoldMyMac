import Foundation

/// Coordinates are screen-aligned. Closure is calibrated visual progress: 0 clear, 1 complete.
public struct EffectContext: Equatable, Sendable {
    public let closure: Double
    public let parameters: EffectParameters
    public let reduceTransparency: Bool
    public let time: TimeInterval
    public let reduceMotion: Bool
    public init(closure: Double, parameters: EffectParameters = .init(), reduceTransparency: Bool = false,
                time: TimeInterval = 0, reduceMotion: Bool = false) {
        self.closure = min(1, max(0, closure.isFinite ? closure : 0))
        self.parameters = parameters
        self.reduceTransparency = reduceTransparency
        self.time = time.isFinite ? max(0, time) : 0
        self.reduceMotion = reduceMotion
    }
    public var motion: Double {
        let x = min(1, closure * 2)
        return (x + EffectMath.smoothstep(x)) / 2
    }
    public var finalFade: Double { max(0, closure * 2 - 1) }
    public var strength: Double { min(1, max(0, parameters.strength.isFinite ? parameters.strength : 1)) }
}
