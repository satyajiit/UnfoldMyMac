import Foundation
import UnfoldMyMacCore

/// Editing what the user brought in: a template folder, a scene's name, the shared custom background.
///
/// These change what the catalog holds rather than what is on screen, which is why they live apart from
/// the runtime façade — but they still go through it, because every edit has to be reflected in the
/// rendered cover and in whatever the app is showing right now.
extension WallpaperModel {
    /// Copies `url` in as the shared custom background and switches image-based scenes to it.
    func importBackground(_ url: URL) {
        Task { [weak self] in
            do { try await WallpaperBackgroundImporter.save(url); self?.setCustomBackground(true) }
            catch { self?.error = error.localizedDescription }
        }
    }
    func importTemplate(_ url: URL) {
        do {
            guard let factory = pipelineFactory else { return }
            let template = try catalog.importTemplate(url) { try factory.validate($0) }
            covers.invalidate(template.id); covers.request([template])
            select(template.id)
        } catch { self.error = error.localizedDescription }
    }
    func renameTemplate(_ id: String, title: String) {
        do {
            try catalog.rename(id, title: title)
            guard let template = catalog.template(id) else { return }
            covers.invalidate(id); covers.request([template])
            if selectedID == id { select(id) }
        } catch { self.error = error.localizedDescription }
    }
    /// Removes an imported template; a desktop showing it stops first and the preview moves to the first scene.
    func removeTemplate(_ id: String) {
        do {
            if enabled, preferences.templateID == id { stopWallpaper() }
            try catalog.remove(id); covers.invalidate(id)
            if selectedID == id { discardPreview(); if let first = templates.first?.id { select(first) } }
        } catch { self.error = error.localizedDescription }
    }
}
