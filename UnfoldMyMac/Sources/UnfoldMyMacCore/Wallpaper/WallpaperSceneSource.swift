import Foundation

/// A parameter a scene shader declares; templates override the default by key in `params`.
public struct WallpaperSceneParameter: Codable, Equatable, Sendable, Identifiable {
    public var key: String
    public var `default`: Double
    public var minimum: Double? = nil
    public var maximum: Double? = nil
    public var id: String { key }
    public init(key: String, default: Double, minimum: Double? = nil, maximum: Double? = nil) {
        self.key = key; self.default = `default`; self.minimum = minimum; self.maximum = maximum
    }
    public var isValid: Bool {
        WallpaperSceneSource.isIdentifier(key) && `default`.isFinite && (minimum ?? 0).isFinite && (maximum ?? 0).isFinite &&
        (minimum == nil || maximum == nil || minimum! < maximum!)
    }
    private enum CodingKeys: String, CodingKey { case key, `default`, minimum = "min", maximum = "max" }
}

/// A template-owned scene shader: the `.metal` file beside `template.json`, its fragment function, the shared
/// modules it needs, how it is compiled and the parameters it exposes. Never accepted from imports.
public struct WallpaperSceneSource: Codable, Equatable, Sendable {
    public static let maximumParameters = 8
    public var source: String
    public var fragment: String
    public var dependencies: [String]? = nil
    public var mathMode: String? = nil
    public var params: [WallpaperSceneParameter]? = nil
    /// Omitted scenes retain the engine cap. Bundled cinematic scenes may opt into Retina pixels.
    public var resolution: String? = nil
    public var liveInputs: Bool? = nil
    public init(source: String, fragment: String, dependencies: [String]? = nil, mathMode: String? = nil, params: [WallpaperSceneParameter]? = nil) {
        self.source = source; self.fragment = fragment; self.dependencies = dependencies; self.mathMode = mathMode; self.params = params
    }
    public static let mathModes: Set<String> = ["fast", "relaxed", "safe"]
    public static func isIdentifier(_ text: String) -> Bool { text.range(of: #"^[A-Za-z_][A-Za-z0-9_]{0,63}$"#, options: .regularExpression) != nil }
    public var isValid: Bool {
        source.range(of: #"^[A-Za-z0-9_-]{1,64}\.metal$"#, options: .regularExpression) != nil && Self.isIdentifier(fragment) &&
        (dependencies ?? []).count <= 8 && Set(dependencies ?? []).count == (dependencies ?? []).count &&
        (dependencies ?? []).allSatisfy { $0.range(of: #"^[A-Za-z0-9_-]{1,64}$"#, options: .regularExpression) != nil } &&
        (mathMode == nil || Self.mathModes.contains(mathMode!)) &&
        (resolution == nil || resolution == "native" || resolution == "capped") &&
        (params ?? []).count <= Self.maximumParameters && Set((params ?? []).map(\.key)).count == (params ?? []).count &&
        (params ?? []).allSatisfy(\.isValid)
    }
    public var parameterKeys: Set<String> { Set((params ?? []).map(\.key)) }
}
