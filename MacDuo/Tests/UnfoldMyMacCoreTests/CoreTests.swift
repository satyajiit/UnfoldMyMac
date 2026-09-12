import Foundation
import Testing
@testable import UnfoldMyMacCore

@Test func closureMappingAndClamping() {
    #expect(EffectMath.closure(lid: 125, activation: 125) == 0)
    #expect(EffectMath.closure(lid: 65, activation: 125) == 0.5)
    #expect(EffectMath.closure(lid: 5, activation: 125) == 1)
    #expect(EffectMath.closure(lid: 180, activation: 125) == 0)
    #expect(EffectMath.closure(lid: -3, activation: 125) == 1)
    #expect(EffectMath.closure(lid: .nan, activation: 125) == 0)
}
@Test func liveTriggerIsInclusiveAndKeepsCalibratedCompletion() {
    for activation in [60.0, 108, 125, 180] {
        for end in [0.4, 0.8, 1.0] {
            func progress(_ lid: Double) -> Double {
                EffectMath.liveProgress(lid: lid, activation: activation, completionFraction: end)
            }
            #expect(progress(activation + 0.001) == 0)
            #expect(progress(activation) > 0)
            #expect(progress(activation - 0.001) > progress(activation))
            #expect(progress(activation - 1) > progress(activation))
            let finish = EffectMath.completionAngle(activation: activation, completionFraction: end)
            #expect(abs(progress(finish) - 1) < 1e-12)
            #expect(progress(finish - 1) == 1)
        }
    }
    #expect(EffectMath.liveProgress(lid: .nan, activation: 125, completionFraction: 0.8) == 0)
    var settings = UnfoldMyMacSettings()
    settings.activation = 108.7; settings.sanitize()
    #expect(settings.activation == 109)
}
@Test func referenceCurvesAndHinge() {
    let half = EffectContext(closure: 0.5)
    #expect(EffectMath.blurRadius(edge: 1, context: half) == 72)
    #expect(EffectMath.blurRadius(edge: 0, context: half) == 0)
    #expect(EffectMath.darkening(edge: 0.2, context: half) == 0)
    #expect(EffectMath.darkening(edge: 1, context: half) == 1)
    #expect(EffectMath.darkening(edge: 0, context: .init(closure: 1)) == 1)
    for i in 0..<100 {
        let a = EffectContext(closure: Double(i) / 100)
        let b = EffectContext(closure: Double(i + 1) / 100)
        #expect(EffectMath.blurRadius(edge: 0.8, context: a) <= EffectMath.blurRadius(edge: 0.8, context: b))
        #expect(EffectMath.darkening(edge: 0.8, context: a) <= EffectMath.darkening(edge: 0.8, context: b))
    }
}
@Test func playbackAndStrength() {
    #expect(EffectMath.playClosure(seconds: 0.5) == 0)
    #expect(EffectMath.playClosure(seconds: 4.8) == 1)
    #expect(EffectMath.blurRadius(edge: 1, context: .init(closure: 0.5, parameters: .init(strength: 0.5))) == 36)
    #expect(EffectContext(closure: .nan).closure == 0)
    #expect(EffectContext(closure: 2).closure == 1)
}
@Test func safetyRecoveryRestartsAfterEachInterruption() {
    var gate = DisplaySafetyGate()
    let outcome1 = !gate.update(lidClosed: false, builtInAvailable: true, sensorAvailable: true, now: 0)
    #expect(outcome1)
    let outcome2 = gate.update(lidClosed: false, builtInAvailable: true, sensorAvailable: true, now: 0.6)
    #expect(outcome2)
    let outcome3 = !gate.update(lidClosed: true, builtInAvailable: true, sensorAvailable: true, now: 1)
    #expect(outcome3)
    #expect(gate.state == .closed)
    let outcome4 = !gate.update(lidClosed: false, builtInAvailable: true, sensorAvailable: true, now: 1.1)
    #expect(outcome4)
    let outcome5 = gate.update(lidClosed: false, builtInAvailable: true, sensorAvailable: true, now: 1.7)
    #expect(outcome5)
    let outcome6 = !gate.update(lidClosed: false, builtInAvailable: false, sensorAvailable: true, now: 2)
    #expect(outcome6)
    #expect(gate.state == .noDisplay)
    let outcome7 = !gate.update(lidClosed: false, builtInAvailable: true, sensorAvailable: false, now: 3)
    #expect(outcome7)
    #expect(gate.state == .noSensor)
}
@Test @MainActor func legacySettingsMigrationAndPersistence() throws {
    let name = "UnfoldMyMacTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(110.0, forKey: "activation")
    defaults.set(2, forKey: "style")
    let store = UserDefaultsPreferencesStore(defaults: defaults)
    var value = store.load(UnfoldMyMacSettings.key)
    #expect(value.effect == .veil)
    #expect(value.activation == 110)
    value.effect = .fade
    value.appearance = .dark
    value.parameters["fade"] = .init(strength: 0.4)
    store.save(value, for: UnfoldMyMacSettings.key)
    #expect(store.load(UnfoldMyMacSettings.key) == value)
    defaults.set(0, forKey: "style")
    #expect(store.load(UnfoldMyMacSettings.key).effect == .fade) // Legacy data must never overwrite migrated preferences.
}
@Test @MainActor func legacySettingsKeyMigratesToUnfoldMyMacKey() throws {
    let name = "UnfoldMyMacTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    var original = UnfoldMyMacSettings()
    original.effect = .fade
    original.activation = 100
    original.appearance = .dark
    original.parameters["fade"] = .init(strength: 0.4)
    defaults.set(try JSONEncoder().encode(original), forKey: "luma.settings.v1")
    let store = UserDefaultsPreferencesStore(defaults: defaults)
    #expect(store.load(UnfoldMyMacSettings.key) == original)
    #expect(defaults.data(forKey: UnfoldMyMacSettings.key.name) != nil)
    #expect(try JSONDecoder().decode(UnfoldMyMacSettings.self, from: try #require(defaults.data(forKey: "unfoldmymac.settings.v1"))) == original)
}
@Test @MainActor func allLegacyStylesAndInvalidActivation() throws {
    for raw in [0, 1, 2, 3, 100] {
        let name = "UnfoldMyMacTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.set(raw, forKey: "style"); defaults.set(900.0, forKey: "activation")
        let value = UserDefaultsPreferencesStore(defaults: defaults).load(UnfoldMyMacSettings.key)
        #expect(value.effect == (raw == 2 ? .veil : .frost))
        #expect(value.activation == 180)
        defaults.removePersistentDomain(forName: name)
    }
}
@Test func textAndAccentContrast() {
    let pairs: [(String, UInt32, UInt32, Double)] = [
        ("Light primary", UnfoldMyMacColors.lightInk, UnfoldMyMacColors.lightCanvas, 7),
        ("Light secondary", UnfoldMyMacColors.lightSecondary, UnfoldMyMacColors.lightCanvas, 4.5),
        ("Light card secondary", UnfoldMyMacColors.lightSecondary, UnfoldMyMacColors.lightCard, 4.5),
        ("Light accent", UnfoldMyMacColors.lightAccent, UnfoldMyMacColors.lightCard, 4.5),
        ("White on blue action", 0xFFFFFF, UnfoldMyMacColors.lightAccent, 4.5),
        ("Dark primary", UnfoldMyMacColors.darkInk, UnfoldMyMacColors.darkCanvas, 7),
        ("Dark secondary", UnfoldMyMacColors.darkSecondary, UnfoldMyMacColors.darkCanvas, 4.5),
        ("Dark card secondary", UnfoldMyMacColors.darkSecondary, UnfoldMyMacColors.darkCard, 4.5),
        ("White on dark control", 0xFFFFFF, UnfoldMyMacColors.darkControlAccent, 4.5),
        ("Dark control boundary", UnfoldMyMacColors.darkControlAccent, UnfoldMyMacColors.darkCard, 3),
        ("Dark accent", UnfoldMyMacColors.darkAccent, UnfoldMyMacColors.darkCard, 4.5),
    ]
    for (name, fg, bg, minimum) in pairs {
        let ratio = UnfoldMyMacColors.contrast(fg, bg)
        print("\(name): \(String(format: "%.2f", ratio)):1")
        #expect(ratio >= minimum, "\(name) contrast failed")
    }
}

@Test func calibratedCompletionArrivesEarlyAndHolds() {
    #expect(EffectMath.calibratedClosure(0, completionFraction: 0.8) == 0)
    #expect(EffectMath.calibratedClosure(0.4, completionFraction: 0.8) == 0.5)
    #expect(EffectMath.calibratedClosure(0.8, completionFraction: 0.8) == 1)
    #expect(EffectMath.calibratedClosure(1, completionFraction: 0.8) == 1)
    #expect(EffectMath.completionAngle(activation: 125, completionFraction: 0.8) == 29)
    #expect(EffectMath.calibratedClosure(0.8, completionFraction: 1) == 0.8)
    #expect(EffectMath.calibratedClosure(.nan, completionFraction: 0.8) == 0)
    let calibrated = EffectContext(closure: EffectMath.calibratedClosure(0.8, completionFraction: 0.8))
    #expect(EffectMath.darkening(edge: 0, context: calibrated) == 1)
    #expect(EffectMath.darkening(edge: 1, context: calibrated) == 1)
}

@Test func productIdentityUsesUnfoldMyMacBundle() {
    #expect(AppIdentity.name == "UnfoldMyMac")
    #expect(AppIdentity.bundleIdentifier == "com.unfoldmymac")
}

@Test func earlierSettingsGainCalibrationWithoutLosingPreferences() throws {
    var original = UnfoldMyMacSettings()
    original.effect = .veil; original.activation = 112; original.appearance = .dark
    original.parameters["veil"] = .init(strength: 0.6)
    let data = try JSONEncoder().encode(original)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object.removeValue(forKey: "completionFraction")
    let legacy = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(UnfoldMyMacSettings.self, from: legacy)
    #expect(decoded == original)
    #expect(decoded.completionFraction == 0.8)
    var custom = decoded; custom.completionFraction = 0.6
    #expect(try JSONDecoder().decode(UnfoldMyMacSettings.self, from: JSONEncoder().encode(custom)) == custom)
}
