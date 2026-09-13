import AppKit
import Observation
import UnfoldMyMacCore

@MainActor protocol EffectRenderer: AnyObject {
    var view: NSView { get }
    var ready: Bool { get }
    var animatesWithTime: Bool { get }
    var lastGPUTime: Double { get }
    func prepare(size: CGSize, scale: CGFloat)
    func update(_ context: EffectContext)
    func stop()
}

extension EffectRenderer {
    var animatesWithTime: Bool { false }
    var lastGPUTime: Double { 0 }
}
