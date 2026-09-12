import Foundation
import Testing
import UnfoldMyMacCore

// Phase 7: parameters are a flat key→value blob, exactly the JSON earlier releases wrote.
@Test func effectParametersEncodeFlatAndCarryUnknownKeys() throws {
    let legacy = Data(#"{"strength":0.42,"reveal":"straight"}"#.utf8)
    let decoded = try JSONDecoder().decode(EffectParameters.self, from: legacy)
    #expect(decoded == EffectParameters(strength: 0.42, reveal: .straight))
    #expect(decoded.strength == 0.42 && decoded.reveal == .straight)
    let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
    #expect(String(data: try encoder.encode(decoded), encoding: .utf8) == #"{"reveal":"straight","strength":0.42}"#, "Flat, no wrapper object")
    let extended = try JSONDecoder().decode(EffectParameters.self, from: Data(#"{"strength":0.5,"glow":true,"palette":"dusk","reveal":null,"count":3}"#.utf8))
    #expect(extended["glow"] == .flag(true) && extended["palette"] == .choice("dusk") && extended["count"] == .number(3))
    #expect(extended.reveal == nil, "A null value is absent, as before")
    let again = try JSONDecoder().decode(EffectParameters.self, from: JSONEncoder().encode(extended))
    #expect(again == extended, "Keys this build does not know survive a save")
    var settings = UnfoldMyMacSettings()
    settings.parameters["x"] = EffectParameters(values: ["strength": .number(7), "glow": .flag(true)])
    settings.sanitize()
    #expect(settings.parameters["x"]?.strength == 1 && settings.parameters["x"]?["glow"] == .flag(true), "Sanitising clamps strength and keeps the rest")
}

@Test func parameterSpecsClampByKindAndValidateTheirShape() throws {
    let slider = EffectParameterSpec(key: "depth", title: "Depth", kind: .slider, range: 0.2...0.8, step: 0.1, default: .number(0.5))
    #expect(slider.clamp(.number(2)) == .number(0.8) && slider.clamp(.number(-1)) == .number(0.2) && slider.clamp(.choice("x")) == .number(0.5))
    #expect(slider.clamp(.number(.nan)) == .number(0.5))
    let reveal = EffectParameterSpec.reveal(default: .burst)
    #expect(reveal.clamp(.choice("diagonal")) == .choice("diagonal") && reveal.clamp(.choice("nope")) == .choice("burst") && reveal.clamp(.number(1)) == .choice("burst"))
    let toggle = EffectParameterSpec(key: "glow", title: "Glow", kind: .toggle, default: .flag(false))
    #expect(toggle.clamp(.flag(true)) == .flag(true) && toggle.clamp(.number(1)) == .flag(false))
    #expect(!EffectParameterSpec(key: "", title: "x", kind: .slider, default: .number(0)).isValid)
    #expect(!EffectParameterSpec(key: "k", title: "x", kind: .choice, default: .choice("a"), choices: []).isValid)
    #expect(!EffectParameterSpec(key: "k", title: "x", kind: .slider, range: 1...1, default: .number(1)).isValid)
    let json = Data(#"{"key":"speed","title":"Speed","kind":"slider","range":[0,2],"step":0.5,"format":"number","default":1}"#.utf8)
    let decoded = try JSONDecoder().decode(EffectParameterSpec.self, from: json)
    #expect(decoded.minimum == 0 && decoded.maximum == 2 && decoded.step == 0.5 && decoded.format == .number && decoded.default == .number(1))
    #expect(try JSONDecoder().decode(EffectParameterSpec.self, from: JSONEncoder().encode(decoded)) == decoded)
}

@Test func effectManifestRejectsVersionDuplicatesAndMissingFallbacks() throws {
    func entry(_ id: String, renderer: String = "native:veil") -> EffectManifestEntry {
        .init(id: .init(rawValue: id), title: id, subtitle: "", detail: "", symbol: "circle", category: .glass, tags: ["t"], cover: "Covers/\(id)", renderer: renderer, renderingLabel: "Native", parameters: [.strength(title: "Intensity")])
    }
    let valid = EffectManifest(default: .frost, fallback: .veil, reduceTransparencyFallback: .fade, effects: [entry("frost"), entry("veil"), entry("fade")])
    #expect(try valid.validated().effects.count == 3)
    #expect(throws: EffectManifestError.unsupportedVersion(9)) { try EffectManifest(version: 9, default: .veil, fallback: .veil, reduceTransparencyFallback: .veil, effects: [entry("veil")]).validated() }
    #expect(throws: EffectManifestError.duplicateID("veil")) { try EffectManifest(default: .veil, fallback: .veil, reduceTransparencyFallback: .veil, effects: [entry("veil"), entry("veil")]).validated() }
    #expect(throws: EffectManifestError.missingEffect("fade")) { try EffectManifest(default: .veil, fallback: .veil, reduceTransparencyFallback: .fade, effects: [entry("veil")]).validated() }
    #expect(throws: EffectManifestError.invalidEntry("bad")) { try EffectManifest(default: .veil, fallback: .veil, reduceTransparencyFallback: .veil, effects: [entry("veil"), entry("bad", renderer: "")]).validated() }
    let json = Data(#"{"version":1,"default":"veil","fallback":"veil","reduceTransparencyFallback":"veil","effects":[{"id":"veil","title":"Veil","cover":"Covers/Veil","renderer":"native:veil","tags":["Glass"]}]}"#.utf8)
    let decoded = try EffectManifest.decode(json)
    #expect(decoded.effects[0].parameters == [.strength(title: "Intensity")] && decoded.effects[0].renderingLabel == "Native" && !decoded.effects[0].capabilities.requiresCapture)
}
