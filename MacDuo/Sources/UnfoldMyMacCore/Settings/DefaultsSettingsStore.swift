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
            if write(value) { removeLegacyKeys() }
            return value
        }
        var value = UnfoldMyMacSettings()
        if let activation = defaults.object(forKey: "activation") as? Double { value.activation = activation }
        if let raw = defaults.object(forKey: "style") as? Int { value.effect = raw == 2 ? .veil : .frost }
        value.sanitize()
        if write(value) { removeLegacyKeys() }
        return value
    }
    public func save(_ settings: UnfoldMyMacSettings) { write(settings) }
    @discardableResult private func write(_ settings: UnfoldMyMacSettings) -> Bool {
        guard let data = try? JSONEncoder().encode(settings) else { return false }
        defaults.set(data, forKey: Self.key)
        return true
    }
    /// Once the current key holds the migrated value, the pre-rename keys only invite confusion.
    private func removeLegacyKeys() {
        for key in [Self.legacyKey, "activation", "style"] { defaults.removeObject(forKey: key) }
    }
}
