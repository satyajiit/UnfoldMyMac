import Foundation

/// Reads a template document of any supported version: size cap, version gate, dictionary-level migration,
/// open-enum normalisation, decoding, validation and lint, in that order. Callers keep the original bytes.
public enum WallpaperTemplateSchema {
    public static let maximumBytes = 131_072

    /// What the host knows, so lint can name what a template asks for and does not get. Nil skips that check.
    public struct Context: Sendable {
        public var categories: Set<String>? = nil
        public var connectors: Set<String>? = nil
        public var namespaces: Set<String>? = nil
        /// Parameter keys declared by shared scene shaders, by shader id.
        public var sceneParameters: [String: Set<String>]? = nil
        public init(categories: Set<String>? = nil, connectors: Set<String>? = nil, namespaces: Set<String>? = nil, sceneParameters: [String: Set<String>]? = nil) {
            self.categories = categories; self.connectors = connectors; self.namespaces = namespaces; self.sceneParameters = sceneParameters
        }
    }

    public static func decode(_ data: Data, context: Context = .init()) throws -> WallpaperTemplateDocument {
        guard data.count <= maximumBytes, var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WallpaperError.invalidTemplate
        }
        guard let version = object["version"] as? Int else { throw WallpaperError.invalidTemplate }
        guard (1...WallpaperTemplate.currentVersion).contains(version) else { throw WallpaperError.unsupportedVersion(version) }
        migrate(&object, from: version)
        var warnings = normalizeOpenEnums(&object)
        let template: WallpaperTemplate
        do { template = try JSONDecoder().decode(WallpaperTemplate.self, from: JSONSerialization.data(withJSONObject: object)).validated() }
        catch let error as WallpaperError { throw error }
        catch { throw WallpaperError.invalidTemplate }
        warnings += try WallpaperTemplateLint.check(template, context: context)
        return WallpaperTemplateDocument(raw: data, sourceVersion: version, template: template, warnings: warnings)
    }

    /// Version 2 is additive: a version 1 document only gains the current version number. A template-owned
    /// scene registers under the template's id, so `shader` may be omitted beside a `scene`.
    static func migrate(_ object: inout [String: Any], from version: Int) {
        object["version"] = WallpaperTemplate.currentVersion
        if object["shader"] == nil, object["scene"] != nil, let id = object["id"] { object["shader"] = id }
    }

    /// Layer kinds and formats this build does not know degrade to plain text instead of rejecting the template.
    static func normalizeOpenEnums(_ object: inout [String: Any]) -> [WallpaperTemplateWarning] {
        guard var layers = object["layers"] as? [[String: Any]] else { return [] }
        var warnings: [WallpaperTemplateWarning] = []
        let kinds = Set(["text", "metric", "sticker"]), formats = Set(["text", "integer", "compact", "percent", "gigabytes"])
        for index in layers.indices {
            let id = layers[index]["id"] as? String ?? "\(index)"
            if let kind = layers[index]["kind"] as? String, !kinds.contains(kind) {
                layers[index]["kind"] = "text"
                warnings.append(.init(.unknownLayerKind, "Layer ‘\(id)’ uses the layer kind ‘\(kind)’, which this version shows as text."))
            }
            if let format = layers[index]["format"] as? String, !formats.contains(format) {
                layers[index]["format"] = "text"
                warnings.append(.init(.unknownLayerFormat, "Layer ‘\(id)’ uses the format ‘\(format)’, which this version shows as text."))
            }
        }
        object["layers"] = layers
        return warnings
    }
}
