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
}
