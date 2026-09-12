import Foundation
import Observation
import UnfoldMyMacCore

struct WallpaperConnectionSettings: Codable, Equatable {
    var enabled = false
    var username: String?
    var path: String?
}

struct WallpaperSetupRequest: Identifiable {
    let id = UUID()
    let template: WallpaperTemplate
    let applyAfterSetup: Bool
}

/// Owns template-specific configuration and the setup transaction, independently of rendering.
@MainActor @Observable final class WallpaperSetupController {
    var request: WallpaperSetupRequest?
    var draft: [String: WallpaperConnectionSettings] = [:]
    private(set) var connections: [String: [String: WallpaperConnectionSettings]]
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored var onApply: ((String) -> Void)?
    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "unfoldmymac.wallpaper.connections.v1"

    init(defaults: UserDefaults) {
        self.defaults = defaults
        connections = defaults.data(forKey: Self.key).flatMap {
            try? JSONDecoder().decode([String: [String: WallpaperConnectionSettings]].self, from: $0)
        } ?? [:]
        // Preserve previously enabled local adapters. A legacy global GitHub
        // username is deliberately not treated as a template's verified setup.
        if defaults.data(forKey: Self.key) == nil, defaults.data(forKey: "unfoldmymac.wallpaper.v1") != nil {
            let old = WallpaperPreferences.load(from: defaults)
            connections["codex-foundry"] = ["codex-history": .init(enabled: old.codexConnected != false)]
            connections["claude-current"] = ["claude-code": .init(enabled: old.claudeConnected, path: old.claudeRoot)]
            if let path = old.toolPath {
                for id in ["daydream", "codex-foundry", "grok-horizon"] {
                    connections[id, default: [:]]["tool-file"] = .init(enabled: true, path: path)
                }
            }
            if let data = try? JSONEncoder().encode(connections) { defaults.set(data, forKey: Self.key) }
        }
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
        if let data = try? JSONEncoder().encode(connections) { defaults.set(data, forKey: Self.key) }
        self.request = nil; draft = [:]
        onChange?()
        if request.applyAfterSetup { onApply?(request.template.id) }
    }
}
