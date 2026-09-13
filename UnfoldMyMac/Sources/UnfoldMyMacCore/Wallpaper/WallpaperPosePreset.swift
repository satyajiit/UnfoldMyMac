import Foundation

/// A fixed scene pose: what covers and stills are rendered at, and what Reduce Motion holds.
public struct WallpaperPosePreset: Codable, Equatable, Sendable {
    public var time: Double
    public var energy: Double
    public var channels: [Double]? = nil
    public init(time: Double, energy: Double, channels: [Double]? = nil) { self.time = time; self.energy = energy; self.channels = channels }
    public static let cover = WallpaperPosePreset(time: 4, energy: 0.35)
    public static let still = WallpaperPosePreset(time: 0, energy: 0)
    public var isValid: Bool {
        time.isFinite && (0...3600).contains(time) && energy.isFinite && (0...1).contains(energy) &&
        (channels == nil || (channels!.count <= 4 && channels!.allSatisfy { $0.isFinite && (0...1).contains($0) }))
    }
    public var channelVector: SIMD4<Float> {
        var vector = SIMD4<Float>.zero
        for (index, value) in (channels ?? []).prefix(4).enumerated() { vector[index] = Float(value) }
        return vector
    }
}
