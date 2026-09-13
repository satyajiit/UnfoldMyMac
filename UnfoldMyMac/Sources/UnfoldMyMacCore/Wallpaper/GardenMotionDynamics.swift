import Foundation

/// Relative gravity supplies tilt; damped angular velocity supplies a brief, bounded stirring force.
public struct GardenMotionDynamics: Sendable {
    public private(set) var tilt = SIMD2<Double>.zero
    public private(set) var stir = 0.0
    private var baseline: SIMD3<Double>?
    public init() {}

    public mutating func sample(acceleration: SIMD3<Double>?, rotation: SIMD3<Double>?, delta: Double) {
        let dt = min(0.1, max(0, delta))
        var target = SIMD2<Double>.zero
        var movement = 0.0
        if let acceleration, acceleration.x.isFinite, acceleration.y.isFinite, acceleration.z.isFinite {
            if baseline == nil { baseline = acceleration }
            let relative = acceleration - (baseline ?? acceleration)
            target = SIMD2(relative.x, -relative.y) * 3.5
        } else { baseline = nil }
        if let rotation, rotation.x.isFinite, rotation.y.isFinite, rotation.z.isFinite {
            // Ignore the sensor's small zero-rate bias. Never integrate yaw, which would drift.
            movement = min(1, max(0, sqrt(rotation.x*rotation.x + rotation.y*rotation.y + rotation.z*rotation.z)-1.5)/35)
        }
        for axis in 0..<2 {
            target[axis] = min(1, max(-1, target[axis]))
            tilt[axis] += (target[axis]-tilt[axis]) * (1-exp(-dt*4))
        }
        stir += (movement-stir) * (1-exp(-dt*(movement > stir ? 8 : 2)))
    }
    public mutating func reset() { self = .init() }
}
