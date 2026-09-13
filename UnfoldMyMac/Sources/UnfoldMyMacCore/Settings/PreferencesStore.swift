import Foundation

/// Raw keyed storage behind `PreferenceKey`. Implementations only move bytes; typing, defaults and
/// migration live in the extension so every backend behaves identically.
@MainActor public protocol PreferencesStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
    func object(forKey key: String) -> Any?
    func removeObject(forKey key: String)
}

public extension PreferencesStore {
    func load<Value>(_ key: PreferenceKey<Value>) -> Value {
        if var value = decode(Value.self, forKey: key.name) { key.sanitize(&value); return value }
        for legacy in key.legacyNames {
            if var value = decode(Value.self, forKey: legacy) { key.sanitize(&value); adopt(value, for: key); return value }
        }
        if var value = key.migrate?(self) { key.sanitize(&value); adopt(value, for: key); return value }
        var value = key.makeDefault(); key.sanitize(&value); return value
    }
    func save<Value>(_ value: Value, for key: PreferenceKey<Value>) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        set(data, forKey: key.name)
    }
    private func decode<Value: Decodable>(_ type: Value.Type, forKey name: String) -> Value? {
        data(forKey: name).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
    /// Writes the migrated value under the current name, then removes the legacy names so they can never shadow it.
    private func adopt<Value>(_ value: Value, for key: PreferenceKey<Value>) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        set(data, forKey: key.name)
        for legacy in key.legacyNames { removeObject(forKey: legacy) }
    }
}
