import UnfoldMyMacCore

/// Whatever the desktop windows follow: the live data hub in the app, a scripted state in the benchmark.
@MainActor protocol WallpaperSnapshotSource: AnyObject, Sendable {
    var snapshot: WallpaperSnapshot { get }
    var liveInputs: WallpaperLiveInputs { get }
}

extension WallpaperSnapshotSource { var liveInputs: WallpaperLiveInputs { .init() } }

extension WallpaperDataHub: WallpaperSnapshotSource {}
