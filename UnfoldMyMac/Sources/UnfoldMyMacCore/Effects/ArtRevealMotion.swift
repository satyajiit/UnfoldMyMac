import Foundation

/// A reveal is independent of its image. Stable string keys are used in catalogs and settings.
public enum ArtRevealMotion: String, CaseIterable, Codable, Sendable, Identifiable {
    case curved, diagonal, straight, burst
    public var id: String { rawValue }
    public var shaderIndex: UInt32 {
        switch self { case .curved: 0; case .diagonal: 1; case .straight: 2; case .burst: 3 }
    }
    public var title: String {
        switch self { case .curved: "Sculpted"; case .diagonal: "Diagonal"; case .straight: "Slide"; case .burst: "Burst" }
    }
}
