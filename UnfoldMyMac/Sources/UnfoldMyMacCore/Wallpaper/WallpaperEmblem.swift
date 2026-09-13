import Foundation

/// Original, untinted artwork placed on the same fitted canvas as text.
public struct WallpaperEmblem: Codable, Equatable, Sendable {
    public var asset: String
    public var x: Double
    public var y: Double
    public var width: Double

    public var isValid: Bool {
        asset.count <= 80 && asset.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil &&
        [x, y, width].allSatisfy(\.isFinite) &&
        (0...1).contains(x) && (0...1).contains(y) && (0.02...0.3).contains(width) && x + width <= 1
    }
}
