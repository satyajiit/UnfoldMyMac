import Foundation
import os

/// The extension runs inside WallpaperAgent's sandbox, where it cannot write to `/tmp` and has no window to
/// print to. `os_log` is the only channel out; read it with
/// `log show --predicate 'subsystem == "com.unfoldmymac.wallpaper"'`.
enum WallpaperProviderLog {
    private static let log = Logger(subsystem: "com.unfoldmymac.wallpaper", category: "provider")
    static func note(_ message: String) { log.notice("\(message, privacy: .public)") }
    static func fault(_ message: String) { log.error("\(message, privacy: .public)") }
}
