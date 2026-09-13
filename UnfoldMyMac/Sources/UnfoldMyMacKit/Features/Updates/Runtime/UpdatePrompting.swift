/// The shell asks only whether an update wants a sheet, so its navigation tests need no updater.
@MainActor protocol UpdatePrompting: AnyObject {
    var promptPending: Bool { get }
    func windowDidBecomeVisible()
    func dismissPrompt()
}
