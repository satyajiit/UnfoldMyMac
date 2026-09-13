import Foundation

@MainActor public final class UserDefaultsPreferencesStore: PreferencesStore {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func data(forKey key: String) -> Data? { defaults.data(forKey: key) }
    public func set(_ data: Data, forKey key: String) { defaults.set(data, forKey: key) }
    public func object(forKey key: String) -> Any? { defaults.object(forKey: key) }
    public func removeObject(forKey key: String) { defaults.removeObject(forKey: key) }
}
