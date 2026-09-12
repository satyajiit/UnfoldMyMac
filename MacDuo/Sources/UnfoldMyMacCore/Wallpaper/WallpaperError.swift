import Foundation

public enum WallpaperError: Error, LocalizedError, Equatable {
    case invalidData, invalidTemplate, duplicateID(String), missingShader(String), unavailable(String)
    public var errorDescription: String? {
        switch self {
        case .invalidData: "The data source returned an invalid or unsupported snapshot."
        case .invalidTemplate: "This wallpaper template is invalid or uses an unsupported version."
        case .duplicateID(let id): "A wallpaper with the ID ‘\(id)’ is already registered."
        case .missingShader(let id): "The renderer ‘\(id)’ is not installed."
        case .unavailable(let reason): reason
        }
    }
}
