import Foundation

struct GardenMotionSample: Sendable {
    var acceleration: SIMD3<Double>?
    var rotation: SIMD3<Double>?
}

@MainActor protocol GardenMotionReading: AnyObject {
    var diagnostic: String { get }
    func start()
    func read(now: Double) -> GardenMotionSample
    func stop()
}
