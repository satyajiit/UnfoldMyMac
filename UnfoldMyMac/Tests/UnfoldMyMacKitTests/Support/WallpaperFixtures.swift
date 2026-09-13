import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

/// The number of template folders the bundle ships; tests derive counts from content instead of pinning them.
@MainActor func bundledTemplateCount() -> Int {
    guard let directory = BundleResources.wallpaperTemplates else { return 0 }
    return WallpaperTemplateLoader.load(directory: directory, context: .init()).items.count
}
/// The flat version 1 documents the templates shipped as before Phase 7, keyed by template id.
func templateV1Fixtures() throws -> [String: Data] {
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/templates-v1")
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
    return Dictionary(uniqueKeysWithValues: try files.map { ($0.deletingPathExtension().lastPathComponent, try Data(contentsOf: $0)) })
}
