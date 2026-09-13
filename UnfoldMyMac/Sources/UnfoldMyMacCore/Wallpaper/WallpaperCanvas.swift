import Foundation

/// Template layout coordinates are fractions of a design canvas; every display fits it letterboxed.
/// The standard canvas is 1600 × 1000; a template may declare its own proportions.
public struct WallpaperCanvas: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
    public static let standard = WallpaperCanvas(width: 1600, height: 1000)
    public var isValid: Bool {
        width.isFinite && height.isFinite && (200...8000).contains(width) && (200...8000).contains(height) && (0.5...4).contains(width / height)
    }
    /// The letterboxed scale for a surface of `width` × `height` and the fitted canvas size at that scale.
    public func fit(width surfaceWidth: Double, height surfaceHeight: Double) -> WallpaperCanvasFit {
        let scale = min(surfaceWidth / width, surfaceHeight / height)
        return WallpaperCanvasFit(scale: scale, width: width * scale, height: height * scale)
    }
}

/// A canvas fitted to a surface: the uniform scale and the fitted size in surface points.
public struct WallpaperCanvasFit: Equatable, Sendable {
    public let scale: Double
    public let width: Double
    public let height: Double
    public init(scale: Double, width: Double, height: Double) { self.scale = scale; self.width = width; self.height = height }
}
