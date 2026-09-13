import Foundation

/// One of up to four extra normalised signals a scene reads as `u.channels`.
public struct WallpaperChannel: Codable, Equatable, Sendable {
    public var metric: String
    public var scale: Double
    /// Easing rate toward a new value in 1/s; the template's `reactiveSmoothing` when absent.
    public var smoothing: Double? = nil
    public init(metric: String, scale: Double, smoothing: Double? = nil) { self.metric = metric; self.scale = scale; self.smoothing = smoothing }
    public var isValid: Bool {
        !metric.isEmpty && metric.count <= 100 && metric.contains(".") && scale.isFinite && scale > 0 &&
        (smoothing == nil || WallpaperTemplate.smoothingRange.contains(smoothing!))
    }
}
