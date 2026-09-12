import Foundation

/// The single place that knows how the Kit resource bundle is laid out.
/// Everything else asks for a resource by role, never by bundle path.
enum BundleResourcesError: LocalizedError, Equatable {
    case missing(String)
    var errorDescription: String? {
        switch self { case .missing(let path): "The bundled resource ‘\(path)’ is missing." }
    }
}

enum BundleResources {
    enum ShaderFamily: String {
        case effects = "Shaders/Effects"
        case wallpaper = "Shaders/Wallpaper"
    }

    static func shader(_ name: String, family: ShaderFamily) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "metal", subdirectory: family.rawValue)
    }
    static func shaderSource(_ name: String, family: ShaderFamily) throws -> String {
        guard let url = shader(name, family: family) else { throw BundleResourcesError.missing("\(family.rawValue)/\(name).metal") }
        return try String(contentsOf: url, encoding: .utf8)
    }
    /// A PNG under `Resources/<folder>/`; `artwork`, `cover`, `wallpaperMark` and `wallpaperCover` name the folders the app ships.
    static func image(_ name: String, folder: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources/\(folder)")
    }
    static func artwork(_ name: String) -> URL? { image(name, folder: "Artwork") }
    static func cover(_ name: String) -> URL? { image(name, folder: "Covers") }
    static func wallpaperMark(_ name: String) -> URL? { image(name, folder: "WallpaperMarks") }
    static func wallpaperCover(_ name: String) -> URL? { image(name, folder: "WallpaperCovers") }
    static func font(_ name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Resources/Fonts")
    }
    static var brandLogo: URL? { image("UnfoldMyMacLogo", folder: "Brand") }
    static var artworkManifest: URL? {
        Bundle.module.url(forResource: "Artworks", withExtension: "json", subdirectory: "Resources/Library")
    }
    static var wallpaperTemplates: URL? {
        Bundle.module.url(forResource: "Wallpapers", withExtension: nil, subdirectory: "Resources")
    }
}
