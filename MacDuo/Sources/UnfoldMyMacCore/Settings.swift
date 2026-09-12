import Foundation

public enum AppearancePreference: String, Codable, CaseIterable, Sendable {
    case system, light, dark
}

public struct UnfoldMyMacSettings: Codable, Equatable, Sendable {
    public var effect: EffectID = .frost
    public var activation: Double = EffectMath.defaultActivation
    public var completionFraction: Double = 0.8
    public var appearance: AppearancePreference = .system
    public var showAngle = true
    public var parameters: [String: EffectParameters] = [:]
    public init() {}
    private enum CodingKeys: String, CodingKey { case effect, activation, completionFraction, appearance, showAngle, parameters }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        effect = try values.decodeIfPresent(EffectID.self, forKey: .effect) ?? .frost
        activation = try values.decodeIfPresent(Double.self, forKey: .activation) ?? EffectMath.defaultActivation
        completionFraction = try values.decodeIfPresent(Double.self, forKey: .completionFraction) ?? 0.8
        appearance = try values.decodeIfPresent(AppearancePreference.self, forKey: .appearance) ?? .system
        showAngle = try values.decodeIfPresent(Bool.self, forKey: .showAngle) ?? true
        parameters = try values.decodeIfPresent([String: EffectParameters].self, forKey: .parameters) ?? [:]
        sanitize()
    }
    public func parameters(for id: EffectID) -> EffectParameters { parameters[id.rawValue] ?? .init() }
    public mutating func sanitize() {
        activation = activation.isFinite ? min(180, max(60, activation)).rounded() : EffectMath.defaultActivation
        completionFraction = completionFraction.isFinite ? min(1, max(0.4, completionFraction)) : 0.8
        for (key, value) in parameters {
            parameters[key] = .init(strength: value.strength.isFinite ? min(1, max(0, value.strength)) : 1, reveal: value.reveal)
        }
    }
}

@MainActor public protocol SettingsStoring {
    func load() -> UnfoldMyMacSettings
    func save(_ settings: UnfoldMyMacSettings)
}

@MainActor public final class DefaultsSettingsStore: SettingsStoring {
    private let defaults: UserDefaults
    public static let key = "unfoldmymac.settings.v1"
    public static let legacyKey = "luma.settings.v1"
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func load() -> UnfoldMyMacSettings {
        if let data = defaults.data(forKey: Self.key), var value = try? JSONDecoder().decode(UnfoldMyMacSettings.self, from: data) {
            value.sanitize()
            return value
        }
        if let data = defaults.data(forKey: Self.legacyKey), var value = try? JSONDecoder().decode(UnfoldMyMacSettings.self, from: data) {
            value.sanitize()
            save(value)
            return value
        }
        var value = UnfoldMyMacSettings()
        if let activation = defaults.object(forKey: "activation") as? Double { value.activation = activation }
        if let raw = defaults.object(forKey: "style") as? Int { value.effect = raw == 2 ? .veil : .frost }
        value.sanitize()
        save(value)
        return value
    }
    public func save(_ settings: UnfoldMyMacSettings) {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: Self.key) }
    }
}

public struct DisplaySafetyGate: Sendable {
    public enum State: String, Sendable {
        case closed = "Paused · lid closed"
        case noDisplay = "Paused · built-in display unavailable"
        case noSensor = "Paused · sensor unavailable"
        case recovering = "Waiting for built-in display…"
        case ready = "Ready"
    }
    public private(set) var state: State = .recovering
    public var recoveryDelay: TimeInterval = 0.5
    private var readySince: TimeInterval?
    public init() {}
    public mutating func reset() { readySince = nil; state = .recovering }
    @discardableResult public mutating func update(lidClosed: Bool, builtInAvailable: Bool, sensorAvailable: Bool, now: TimeInterval) -> Bool {
        if lidClosed { state = .closed }
        else if !builtInAvailable { state = .noDisplay }
        else if !sensorAvailable { state = .noSensor }
        else {
            if readySince == nil { readySince = now }
            state = now - (readySince ?? now) >= recoveryDelay ? .ready : .recovering
            return state == .ready
        }
        readySince = nil
        return false
    }
}

/// Fixed, opaque sRGB surfaces used for measurable text contrast.
public enum UnfoldMyMacColors {
    public static let lightCanvas: UInt32 = 0xF5F5F5
    public static let lightCard: UInt32 = 0xFFFFFF
    public static let lightInk: UInt32 = 0x1D1D1F
    public static let lightSecondary: UInt32 = 0x595963
    public static let lightAccent: UInt32 = 0x005BC6
    public static let darkCanvas: UInt32 = 0x1A1A1A
    public static let darkCard: UInt32 = 0x242424
    public static let darkInk: UInt32 = 0xF5F5F7
    public static let darkSecondary: UInt32 = 0xB9B9C3
    public static let darkControlAccent: UInt32 = 0x1870DA
    public static let darkAccent: UInt32 = 0x8FBFFF
    public static func luminance(_ hex: UInt32) -> Double {
        func linear(_ value: UInt32) -> Double {
            let c = Double(value) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear((hex >> 16) & 255) + 0.7152 * linear((hex >> 8) & 255) + 0.0722 * linear(hex & 255)
    }
    public static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let x = luminance(a), y = luminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
