import AppKit
import UnfoldMyMacCore

/// What the views read off the model that is derived rather than owned. Everything here is a plain
/// function of state the model already holds, which is why it can live beside it: nothing in this file
/// touches the collaborators the model keeps private.
extension WallpaperModel {
    var templates: [WallpaperTemplate] { catalog.templates }
    var thumbnails: [String: NSImage] { covers.images }
    var selected: WallpaperTemplate? { catalog.template(selectedID) }
    var activeTitle: String { catalog.template(preferences.templateID)?.title ?? "Wallpaper" }
    var isSelectedApplied: Bool { enabled && preferences.templateID == selectedID }
    var previewSnapshot: WallpaperSnapshot { isSelectedApplied ? data.snapshot : previewData.snapshot }
    /// The slowest desktop display while applied; the preview card's own surface otherwise.
    var stats: RenderStats { enabled ? desktop.surface.worstStats : previewStats }
    /// The displays this scene is put on: one entry, always the primary. See `WallpaperDesktopCoordinator`
    /// for why, and `WallpaperDisplayRow` for why the interface shows a choice of one rather than nothing.
    var displayTargets: [WallpaperBackdropScreen] { desktop.target.map { [$0] } ?? [] }
}
