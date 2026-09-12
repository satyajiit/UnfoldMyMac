/// Receives captured desktop frames. Only capture-fed pipelines implement it; the session checks for it.
@MainActor protocol DesktopFrameSink: AnyObject {
    func receive(_ frame: DesktopFrame)
}
