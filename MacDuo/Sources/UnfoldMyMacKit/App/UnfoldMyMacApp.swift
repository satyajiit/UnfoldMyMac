import AppKit

/// Process entry point: command-line modes run and exit; otherwise the app launches.
@MainActor public enum UnfoldMyMacApp {
    public static func main(_ arguments: [String] = CommandLine.arguments) -> Never {
        if arguments.contains("--wallpaper-claude-hook") { exit(WallpaperClaudeHook.run()) }
        if arguments.contains("--wallpaper-codex-hook") { exit(WallpaperCodexHook.run()) }
        if arguments.contains("--probe") { exit(UnfoldMyMacDiagnostics.probe() ? 0 : 1) }
        if arguments.contains("--shader-check") { exit(UnfoldMyMacDiagnostics.checkShader() ? 0 : 1) }
        if arguments.contains("--wallpaper-benchmark") { UnfoldMyMacDiagnostics.benchmarkWallpaper(); exit(0) }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = AppController()
        app.delegate = delegate
        app.run()
        exit(0)
    }
}
