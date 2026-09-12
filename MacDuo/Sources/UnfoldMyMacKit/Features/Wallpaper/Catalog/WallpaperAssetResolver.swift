import Foundation
import UnfoldMyMacCore

/// Where a template's files are: its own folder first (`<image>.png`, `marks/<mark>.png`, `cover.png`, its scene
/// source), then the shared `Resources/Artwork` and `Resources/WallpaperMarks` folders every template may use.
struct WallpaperAssetResolver: Sendable {
    let folder: URL?
    /// Shared folders only: flat templates, imports and tests that build templates by hand.
    static let shared = WallpaperAssetResolver(folder: nil)

    init(folder: URL?) { self.folder = folder }
    func image(_ name: String) -> URL? { local(name) ?? BundleResources.artwork(name) }
    func mark(_ name: String) -> URL? { local("marks/\(name)") ?? BundleResources.wallpaperMark(name) }
    func cover(for template: WallpaperTemplate) -> URL? { local("cover") }
    /// The template-owned `.metal` named by its `scene.source`.
    func shader(_ source: String) -> URL? {
        guard let folder, !source.contains("/"), !source.contains("..") else { return nil }
        let url = folder.appendingPathComponent(source)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    private func local(_ name: String) -> URL? {
        guard let folder, !name.contains("..") else { return nil }
        let url = folder.appendingPathComponent(name + ".png")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
