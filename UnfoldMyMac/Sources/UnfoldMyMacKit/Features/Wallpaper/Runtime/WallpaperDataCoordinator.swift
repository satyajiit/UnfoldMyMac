import UnfoldMyMacCore

/// The two data hubs: one feeding the desktop, one feeding a preview of a different template. Providers are
/// assembled from each template and its connections; the hubs match them by identity, so an unchanged
/// provider keeps running across every refresh.
@MainActor final class WallpaperDataCoordinator {
    let desktop = WallpaperDataHub()
    let preview = WallpaperDataHub()
    private let registry: WallpaperConnectorRegistry
    private var sampling = false

    init(registry: WallpaperConnectorRegistry = .standard) { self.registry = registry }

    /// `nil` templates stop that hub's providers; `sampling` false stops both and clears their snapshots.
    func update(desktop desktopTemplate: WallpaperTemplate?, preview previewTemplate: WallpaperTemplate?,
                connections: [String: [String: WallpaperConnectionSettings]], sampling: Bool) {
        guard sampling else { stop(); return }
        desktop.update(desktopTemplate.map { providers(for: $0, connections: connections) } ?? [])
        preview.update(previewTemplate.map { providers(for: $0, connections: connections) } ?? [])
        self.sampling = true
    }
    /// A new preview template starts from an empty snapshot rather than showing the previous one's values.
    func resetPreview() { preview.stop() }
    func resetDesktop() { desktop.stop() }
    /// Connections changed: every provider is rebuilt on the next update.
    func reset() { desktop.stop(); preview.stop(); sampling = false }
    func stop() {
        guard sampling else { return }
        reset()
    }
    private func providers(for template: WallpaperTemplate, connections: [String: [String: WallpaperConnectionSettings]]) -> [any WallpaperDataProvider] {
        WallpaperProviderAssembly.providers(for: template, connections: connections[template.id] ?? [:], registry: registry)
    }
}
