import Foundation

public struct WallpaperChannel: Codable, Equatable, Sendable {
    public var metric: String
    public var scale: Double
    public var isValid: Bool { !metric.isEmpty && metric.count <= 100 && scale.isFinite && scale > 0 }
}

/// Positions and font sizes are fractions of a 1600 × 1000 design canvas.
/// The compositor letterboxes that canvas so text never stretches on other displays.
