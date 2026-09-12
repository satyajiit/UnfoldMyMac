import Foundation
import Testing
@testable import UnfoldMyMacCore

private func v1(_ overrides: [String: Any] = [:], layers: [[String: Any]]? = nil) throws -> Data {
    var json: [String: Any] = ["version": 1, "id": "sample", "title": "Sample", "subtitle": "", "author": "", "tags": ["t"], "shader": "pulse",
        "accent": 0xA8E0C0, "background": 0x101820, "reactiveMetric": "mac.cpu", "reactiveScale": 100,
        "layers": layers ?? [["id": "a", "kind": "text", "content": "x", "format": "text", "x": 0.1, "y": 0.1, "width": 0.5, "size": 0.03, "color": 0xF0F0F0, "rotation": 0]]]
    for (key, value) in overrides { json[key] = value is NSNull ? nil : value }
    return try JSONSerialization.data(withJSONObject: json)
}
private let host = WallpaperTemplateSchema.Context(categories: ["mac", "ai"], connectors: ["github-profile", "tool-file"],
                                                   namespaces: ["mac", "scene", "github", "tool", "countdown"], sceneParameters: ["pulse": ["spin"]])

@Test func version1DocumentsMigrateToCurrentDefaults() throws {
    let document = try WallpaperTemplateSchema.decode(try v1(), context: host)
    #expect(document.sourceVersion == 1 && document.template.version == WallpaperTemplate.currentVersion && document.warnings.isEmpty)
    let template = document.template
    #expect(template.canvasSize == .standard && template.coverPose == .cover && template.stillPose == .still && template.smoothingRate == 4)
    #expect(template.idleEnergy == nil && template.params == nil && template.scene == nil && template.category == nil)
    #expect(template.styled(over: .standard) == .standard)
    #expect(WallpaperPose(template: template, snapshot: WallpaperSnapshot()).energy == 0)
    var idle = template; idle.idleEnergy = 0.3
    #expect(WallpaperPose(template: idle, snapshot: WallpaperSnapshot()).energy == 0.3, "W6: no data rests at idleEnergy")
    var snapshot = WallpaperSnapshot(); snapshot.sources["mac"] = .init(timestamp: .now, numbers: ["mac.cpu": 50])
    #expect(WallpaperPose(template: idle, snapshot: snapshot).energy == 0.5, "Data always wins over idleEnergy")
    #expect(throws: WallpaperError.unsupportedVersion(3)) { try WallpaperTemplateSchema.decode(try v1(["version": 3])) }
    #expect(throws: WallpaperError.invalidTemplate) { try WallpaperTemplateSchema.decode(Data("not json".utf8)) }
    #expect(throws: WallpaperError.invalidTemplate) { try WallpaperTemplateSchema.decode(Data(repeating: 0x20, count: WallpaperTemplateSchema.maximumBytes + 1)) }
}

@Test func unknownLayerKindsAndFormatsDegradeToTextWithWarnings() throws {
    let layers: [[String: Any]] = [
        ["id": "a", "kind": "hologram", "content": "x", "format": "text", "x": 0.1, "y": 0.1, "width": 0.5, "size": 0.03, "color": 0xF0F0F0, "rotation": 0],
        ["id": "b", "kind": "metric", "content": "—", "binding": "mac.cpu", "format": "kelvin", "x": 0.1, "y": 0.5, "width": 0.5, "size": 0.03, "color": 0xF0F0F0, "rotation": 0]]
    let document = try WallpaperTemplateSchema.decode(try v1(layers: layers), context: host)
    #expect(document.template.layers.map(\.kind) == [.text, .metric] && document.template.layers.map(\.format) == [.text, .text])
    #expect(document.warnings.map(\.code) == [.unknownLayerKind, .unknownLayerFormat])
    #expect(document.warnings[0].message.contains("hologram") && document.warnings[1].message.contains("kelvin"))
}

@Test func lintNamesWhatTheHostCannotProvide() throws {
    let data = try v1(["category": "space", "params": ["spin": 1, "wobble": 2], "channels": [["metric": "github.crowd", "scale": 1]],
                       "setup": [["kind": "github-profile", "required": true], ["kind": "spotify", "required": false]]],
                      layers: [["id": "dim", "kind": "text", "content": "x", "binding": "weather.temp", "format": "text", "x": 0.1, "y": 0.1, "width": 0.5, "size": 0.03, "color": 0x202830, "rotation": 0]])
    let document = try WallpaperTemplateSchema.decode(data, context: host)
    #expect(document.warnings.map(\.code) == [.lowContrast, .unknownCategory, .unknownConnector, .unboundNamespace, .unknownParameter])
    #expect(document.warnings[3].message.contains("weather") && document.warnings[4].message.contains("wobble"))
    #expect(try WallpaperTemplateSchema.decode(data).warnings.map(\.code) == [.lowContrast], "Without host knowledge only content checks run")
    let required = try v1(["setup": [["kind": "spotify", "required": true]]])
    #expect(throws: WallpaperError.unknownConnector("spotify")) { try WallpaperTemplateSchema.decode(required, context: host) }
    #expect(try WallpaperTemplateSchema.decode(required).template.setup?.first?.kind == WallpaperConnectorID(rawValue: "spotify"))
}

@Test func everyNewRejectionNamesItsField() throws {
    func field(_ overrides: [String: Any], layers: [[String: Any]]? = nil) -> String? {
        do { _ = try WallpaperTemplateSchema.decode(try v1(overrides, layers: layers)); return nil }
        catch WallpaperError.invalidField(let name) { return name } catch { return "other: \(error)" }
    }
    #expect(field(["reactiveMetric": "cpu"]) == "reactiveMetric")
    #expect(field(["reactiveMetric": ""]) == "reactiveMetric")
    #expect(field(["accent": 0x1FFFFFF]) == "accent")
    #expect(field(["fpsCeiling": 0]) == "fpsCeiling")
    #expect(field(["idleEnergy": 1.5]) == "idleEnergy")
    #expect(field(["reactiveSmoothing": 0.1]) == "reactiveSmoothing")
    #expect(field(["canvas": ["width": 100, "height": 100]]) == "canvas")
    #expect(field(["cover": ["time": -1, "energy": 0.5]]) == "cover")
    #expect(field(["order": -1]) == "order")
    #expect(field(["category": "Bad Category"]) == "category")
    #expect(field(["params": ["1bad": 1]]) == "params.1bad")
    #expect(field(["params": Dictionary(uniqueKeysWithValues: (0..<9).map { ("p\($0)", 1.0) })]) == "params")
    #expect(field(["scene": ["source": "../Scene.metal", "fragment": "f"]]) == "scene")
    #expect(field(["scene": ["source": "Scene.metal", "fragment": "f", "params": [["key": "a", "default": 1], ["key": "a", "default": 2]]]]) == "scene")
    #expect(field(["scene": ["source": "Scene.metal", "fragment": "f", "mathMode": "sloppy"]]) == "scene")
    #expect(field(["shader": NSNull()]) == "other: invalidTemplate", "Without a scene the shader id is required")
    #expect(field(["channels": [["metric": "mac.cpu", "scale": 1, "smoothing": 99]]]) == "channels[0]")
    #expect(field(["setup": [["kind": "Bad Kind", "required": false]]]) == "setup[0].kind")
    #expect(field([:], layers: [["id": "a", "kind": "text", "content": "x", "format": "text", "x": 0.6, "y": 0.1, "width": 0.5, "size": 0.03, "color": 0xF0F0F0, "rotation": 0]]) == "layers[0]", "x + width must stay on the canvas")
    #expect(field([:], layers: [["id": "a", "kind": "text", "content": "x", "format": "text", "x": 0.1, "y": 0.1, "width": 0.5, "size": 0.03, "color": 0x1000000, "rotation": 0]]) == "layers[0]")
    let scene: [String: Any] = ["source": "Scene.metal", "fragment": "sampleFragment", "dependencies": ["RaceCar"], "mathMode": "fast", "params": [["key": "spin", "default": 0.5, "min": 0, "max": 1]]]
    let owned = try WallpaperTemplateSchema.decode(try v1(["shader": NSNull(), "scene": scene, "params": ["spin": 0.9]]))
    #expect(owned.template.shader == "sample", "A template-owned scene registers under the template id unless it names another")
    #expect(owned.template.scene?.parameterKeys == ["spin"] && owned.warnings.isEmpty)
    let named = try WallpaperTemplateSchema.decode(try v1(["shader": "shared-scene", "scene": scene]))
    #expect(named.template.shader == "shared-scene")
}
