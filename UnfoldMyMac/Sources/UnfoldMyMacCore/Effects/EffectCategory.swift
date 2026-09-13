import Foundation

public enum EffectCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case glass, image, motion
    public var id: String { rawValue }
    public var title: String {
        switch self { case .glass: "Glass & Light"; case .image: "Image Art"; case .motion: "Motion & 3D" }
    }
}
