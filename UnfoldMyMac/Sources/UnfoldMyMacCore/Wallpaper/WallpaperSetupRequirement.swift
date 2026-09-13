import Foundation

public struct WallpaperSetupRequirement: Codable, Equatable, Sendable, Identifiable {
    public var kind: WallpaperConnectorID
    public var required: Bool
    public var id: String { kind.rawValue }
    public init(kind: WallpaperConnectorID, required: Bool) { self.kind = kind; self.required = required }
}
