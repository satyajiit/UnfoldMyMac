import Foundation

/// Row-major scalar field. Values are normalized to 0...1; orientation belongs to the provider.
public struct WallpaperScalarGrid: Codable, Equatable, Sendable {
    public let revision: String
    public let width: Int
    public let height: Int
    public let values: [Float]
    public init(revision: String, width: Int, height: Int, values: [Float]) {
        self.revision = revision; self.width = width; self.height = height; self.values = values
    }
    public var isValid: Bool {
        !revision.isEmpty && revision.count <= 128 && (1...512).contains(width) &&
        (1...512).contains(height) && values.count == width * height &&
        values.allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}
