import AppKit
import Observation
import SwiftUI
import UnfoldMyMacCore

/// A floating transport for the running preview, shown at the bottom of the built-in display.
@MainActor final class PreviewPanelController {
    private let model: UnfoldMyMacModel
    private let displays: any DisplayProviding
    private var panel: NSPanel?
    private var observation: Task<Void, Never>?

    init(model: UnfoldMyMacModel, displays: any DisplayProviding) { self.model = model; self.displays = displays }
    func start() {
        let model = self.model
        observation = Task { [weak self] in
            for await previewing in Observations({ model.isPreviewing }) { self?.refresh(previewing: previewing) }
        }
    }
    func stop() { observation?.cancel(); observation = nil }
    isolated deinit { stop() }

    private func refresh(previewing: Bool) {
        guard previewing else { panel?.orderOut(nil); return }
        let panel = self.panel ?? makePanel()
        guard let screen = displays.builtInScreen() else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.minY + 40))
        panel.makeKeyAndOrderFront(nil)
    }
    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 200), styleMask: [.titled, .utilityWindow], backing: .buffered, defer: false)
        panel.title = "\(AppIdentity.name) Preview"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: EffectHost.level.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: PreviewControls(model: model))
        self.panel = panel
        return panel
    }
}
