import Foundation

/// Test and preview backend; nothing touches disk.
@MainActor public final class InMemoryPreferencesStore: PreferencesStore {
    public private(set) var storage: [String: Any] = [:]
    public init() {}
    public func data(forKey key: String) -> Data? { storage[key] as? Data }
    public func set(_ data: Data, forKey key: String) { storage[key] = data }
    public func object(forKey key: String) -> Any? { storage[key] }
    public func removeObject(forKey key: String) { storage[key] = nil }
    /// Seeds a raw value the way an older release would have written it.
    public func setRaw(_ value: Any, forKey key: String) { storage[key] = value }
}
