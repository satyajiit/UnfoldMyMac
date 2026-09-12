import Foundation

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
