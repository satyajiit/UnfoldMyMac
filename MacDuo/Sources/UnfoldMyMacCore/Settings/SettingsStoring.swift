import Foundation

@MainActor public protocol SettingsStoring {
    func load() -> UnfoldMyMacSettings
    func save(_ settings: UnfoldMyMacSettings)
}
