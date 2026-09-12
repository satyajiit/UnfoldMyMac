import AppKit
import UnfoldMyMacKit

if CommandLine.arguments.contains("--wallpaper-claude-hook") { exit(WallpaperClaudeHook.run()) }
if CommandLine.arguments.contains("--wallpaper-codex-hook") { exit(WallpaperCodexHook.run()) }
if CommandLine.arguments.contains("--probe") { exit(UnfoldMyMacDiagnostics.probe() ? 0 : 1) }
if CommandLine.arguments.contains("--shader-check") { exit(UnfoldMyMacDiagnostics.checkShader() ? 0 : 1) }
if CommandLine.arguments.contains("--wallpaper-benchmark") { UnfoldMyMacDiagnostics.benchmarkWallpaper(); exit(0) }
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppController()
app.delegate = delegate
app.run()
