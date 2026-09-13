import Foundation

public enum ContentCollection: String, CaseIterable, Codable, Sendable {
    case wallpapers, scenes
    public var title: String { self == .scenes ? "Creative Scenes" : "Dynamic Wallpapers" }
    public var subtitle: String {
        self == .scenes ? "Small worlds. Unexpected possibilities." : "A desktop with a life of its own."
    }
    public var banner: String { self == .scenes ? "CreativeScenes" : "DynamicWallpapers" }
    public var actionTitle: String { self == .scenes ? "Use scene" : "Use wallpaper" }
}
