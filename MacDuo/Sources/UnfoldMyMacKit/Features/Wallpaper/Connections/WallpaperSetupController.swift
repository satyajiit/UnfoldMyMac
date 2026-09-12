import Foundation
import Observation
import UnfoldMyMacCore

/// Owns template-specific configuration and the setup transaction, independently of rendering.
@MainActor @Observable final class WallpaperSetupController {
    var request: WallpaperSetupRequest?
    var draft: [String: WallpaperConnectionSettings] = [:]
    private(set) var connections: [String: [String: WallpaperConnectionSettings]]
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored var onApply: ((String) -> Void)?
    @ObservationIgnored private let preferences: any PreferencesStore
    /// Per-template connection settings. The first read on a pre-connections install preserves the
    /// previously enabled local adapters; a legacy global GitHub username is deliberately not treated
    /// as a template's verified setup.
    static let key = PreferenceKey<[String: [String: WallpaperConnectionSettings]]>("unfoldmymac.wallpaper.connections.v1",
        default: { [:] },
        migrate: { store in
            guard store.data(forKey: WallpaperPreferences.key.name) != nil else { return nil }
            let old = store.load(WallpaperPreferences.key)
            var connections: [String: [String: WallpaperConnectionSettings]] = [:]
            connections["codex-foundry"] = ["codex-history": .init(enabled: old.codexConnected != false)]
            connections["claude-current"] = ["claude-code": .init(enabled: old.claudeConnected, path: old.claudeRoot)]
            if let path = old.toolPath {
                for id in ["daydream", "codex-foundry", "grok-horizon"] {
                    connections[id, default: [:]]["tool-file"] = .init(enabled: true, path: path)
                }
            }
            return connections
        })

    init(preferences: any PreferencesStore) {
        self.preferences = preferences
        connections = preferences.load(Self.key)
    }
    func configuration(_ kind: WallpaperSetupRequirement.Kind, for templateID: String) -> WallpaperConnectionSettings {
        connections[templateID]?[kind.rawValue] ?? .init()
    }
    func isReady(_ template: WallpaperTemplate) -> Bool {
        Self.isReady(template, connections: connections[template.id] ?? [:])
    }
    var draftReady: Bool {
        guard let request else { return false }
        return Self.isReady(request.template, connections: draft)
    }
    static func isReady(_ template: WallpaperTemplate, connections: [String: WallpaperConnectionSettings]) -> Bool {
        (template.setup ?? []).filter(\.required).allSatisfy { requirement in
            guard let value = connections[requirement.id], value.enabled else { return false }
            switch requirement.kind {
            case .githubProfile: return value.username.flatMap { try? GitHubProfileClient.username($0) } != nil
            case .toolFile: return value.path?.isEmpty == false
            default: return true
            }
        }
    }
    func open(_ template: WallpaperTemplate, applyAfterSetup: Bool = false) {
        draft = connections[template.id] ?? [:]
        request = .init(template: template, applyAfterSetup: applyAfterSetup)
    }
    func cancel() { request = nil; draft = [:] }
    func finish() {
        guard let request, !request.applyAfterSetup || draftReady else { return }
        connections[request.template.id] = draft
        preferences.save(connections, for: Self.key)
        self.request = nil; draft = [:]
        onChange?()
        if request.applyAfterSetup { onApply?(request.template.id) }
    }
}
