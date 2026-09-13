import Foundation

/// Something a template author should know that does not stop the template from rendering.
public struct WallpaperTemplateWarning: Equatable, Sendable, CustomStringConvertible {
    public enum Code: String, Sendable {
        case unknownLayerKind, unknownLayerFormat, lowContrast, unknownCategory, unknownConnector, unboundNamespace, unknownParameter
    }
    public let code: Code
    public let message: String
    public init(_ code: Code, _ message: String) { self.code = code; self.message = message }
    public var description: String { message }
}

/// A decoded template with what was learned on the way: the bytes it came from, the version it was written in
/// and the warnings linting raised.
public struct WallpaperTemplateDocument: Sendable {
    public let raw: Data
    public let sourceVersion: Int
    public let template: WallpaperTemplate
    public let warnings: [WallpaperTemplateWarning]
    public init(raw: Data, sourceVersion: Int, template: WallpaperTemplate, warnings: [WallpaperTemplateWarning]) {
        self.raw = raw; self.sourceVersion = sourceVersion; self.template = template; self.warnings = warnings
    }
}
