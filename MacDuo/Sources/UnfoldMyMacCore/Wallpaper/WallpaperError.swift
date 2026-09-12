import Foundation

public enum WallpaperError: Error, LocalizedError, Equatable {
    case invalidData
    /// The document is not a template at all: not JSON, too large, or missing its version.
    case invalidTemplate
    case invalidField(String)
    case unsupportedVersion(Int)
    case unknownConnector(String)
    case duplicateID(String)
    case missingShader(String)
    case missingAsset(String)
    case unavailable(String)
    public var errorDescription: String? {
        switch self {
        case .invalidData: "The data source returned an invalid or unsupported snapshot."
        case .invalidTemplate: "This wallpaper template could not be read."
        case .invalidField(let field): "The template field ‘\(field)’ is missing, malformed or out of range."
        case .unsupportedVersion(let version): "This template is version \(version); this build reads versions 1 to \(WallpaperTemplate.currentVersion)."
        case .unknownConnector(let id): "This template needs the connection ‘\(id)’, which this version does not provide."
        case .duplicateID(let id): "A wallpaper with the ID ‘\(id)’ is already registered."
        case .missingShader(let id): "The renderer ‘\(id)’ is not installed."
        case .missingAsset(let name): "The asset ‘\(name)’ is not installed."
        case .unavailable(let reason): reason
        }
    }
}
