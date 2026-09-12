import Foundation
import SwiftUI

/// Facts about the running process that views show or hand to helpers; injected so previews and tests can substitute them.
struct AppInfo: Sendable {
    var version: String
    var executablePath: String
    static let live = AppInfo(version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
                              executablePath: Bundle.main.executableURL?.path ?? CommandLine.arguments[0])
}

extension EnvironmentValues {
    @Entry var appInfo = AppInfo.live
    @Entry var workspace: any WorkspaceOpening = SystemWorkspace()
    @Entry var filePicker: any FilePicking = OpenPanelFilePicker()
    /// Environment defaults are read while SwiftUI evaluates bodies on the main thread.
    var coverImages: CoverImageStore {
        get { self[CoverImagesKey.self] }
        set { self[CoverImagesKey.self] = newValue }
    }
}

private struct CoverImagesKey: EnvironmentKey {
    static var defaultValue: CoverImageStore { MainActor.assumeIsolated { CoverImageStore.fallback } }
}
