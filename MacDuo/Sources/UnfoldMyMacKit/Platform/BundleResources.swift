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
    /// The Kit resource bundle. A packaged app carries it in `Contents/Resources`; SwiftPM's generated
    /// accessor only looks beside the executable and then in the build directory, which exists on the
    /// build machine alone, so the packaged location is checked first.
    static let bundle: Bundle = {
        let name = "UnfoldMyMac_UnfoldMyMacKit.bundle"
        if let packaged = Bundle.main.resourceURL?.appendingPathComponent(name), let bundle = Bundle(url: packaged) { return bundle }
        return Bundle.module
    }()
    enum ShaderFamily: String {
        case effects = "Shaders/Effects"
        case wallpaper = "Shaders/Wallpaper"
    }

    static func shader(_ name: String, family: ShaderFamily) -> URL? {
        bundle.url(forResource: name, withExtension: "metal", subdirectory: family.rawValue)
    }
    /// A precompiled shader unit written by `script/compile_shaders.sh`, named by its source digest.
    static func compiledShader(_ digest: String) -> URL? {
        bundle.url(forResource: digest, withExtension: "metallib", subdirectory: "Shaders/Compiled")
    }
    static func shaderSource(_ name: String, family: ShaderFamily) throws -> String {
        guard let url = shader(name, family: family) else { throw BundleResourcesError.missing("\(family.rawValue)/\(name).metal") }
        return try String(contentsOf: url, encoding: .utf8)
    }
    /// A PNG under `Resources/<folder>/`; `artwork`, `cover`, `wallpaperMark` and `wallpaperCover` name the folders the app ships.
    static func image(_ name: String, folder: String) -> URL? {
        bundle.url(forResource: name, withExtension: "png", subdirectory: "Resources/\(folder)")
    }
    static func artwork(_ name: String) -> URL? { image(name, folder: "Artwork") }
    static func cover(_ name: String) -> URL? { image(name, folder: "Covers") }
    static func wallpaperMark(_ name: String) -> URL? { image(name, folder: "WallpaperMarks") }
    static func wallpaperCover(_ name: String) -> URL? { image(name, folder: "WallpaperCovers") }
    static func font(_ name: String) -> URL? {
        bundle.url(forResource: name, withExtension: "ttf", subdirectory: "Resources/Fonts")
    }
    static var brandLogo: URL? { image("UnfoldMyMacLogo", folder: "Brand") }
    static var artworkManifest: URL? {
        bundle.url(forResource: "Artworks", withExtension: "json", subdirectory: "Resources/Library")
    }
    static var wallpaperTemplates: URL? {
        bundle.url(forResource: "Wallpapers", withExtension: nil, subdirectory: "Resources")
    }
}
