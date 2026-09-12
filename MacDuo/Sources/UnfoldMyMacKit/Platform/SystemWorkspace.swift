import AppKit

@MainActor final class SystemWorkspace: WorkspaceOpening {
    nonisolated init() {}
    func open(_ url: URL) { NSWorkspace.shared.open(url) }
}
