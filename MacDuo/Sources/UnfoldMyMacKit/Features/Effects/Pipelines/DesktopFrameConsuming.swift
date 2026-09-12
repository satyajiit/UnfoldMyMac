import AppKit
import Observation
import UnfoldMyMacCore

@MainActor protocol DesktopFrameConsuming: EffectRenderer {
    func receive(_ frame: DesktopFrame)
}
