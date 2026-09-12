import AppKit
import QuartzCore
import UnfoldMyMacCore

@MainActor final class NativeEffectRenderer: EffectRenderer {
    enum Kind { case veil, fade }
    let view: NSView = NSView()
    let ready = true
    private let kind: Kind
    private let material = NSVisualEffectView()
    private let shade = CAGradientLayer()
    private var lastContext: EffectContext?
    init(kind: Kind) {
        self.kind = kind
        view.wantsLayer = true
        material.blendingMode = .behindWindow
        material.material = .fullScreenUI
        material.state = .active
        material.autoresizingMask = [.width, .height]
        if kind == .veil { view.addSubview(material) }
        shade.startPoint = CGPoint(x: 0.5, y: 0)
        shade.endPoint = CGPoint(x: 0.5, y: 1)
        view.layer?.addSublayer(shade)
    }
    func prepare(size: CGSize, scale: CGFloat) {
        view.frame = CGRect(origin: .zero, size: size)
        material.frame = view.bounds
        CATransaction.begin(); CATransaction.setDisableActions(true)
        shade.frame = view.bounds
        CATransaction.commit()
        lastContext = nil
    }
    func update(_ context: EffectContext) {
        guard context != lastContext else { return }
        lastContext = context
        let samples = 64
        CATransaction.begin(); CATransaction.setDisableActions(true)
        shade.colors = (0..<samples).map { i in
            let edge = Double(i) / Double(samples - 1)
            let opacity: Double
            if kind == .fade || context.reduceTransparency {
                opacity = EffectMath.darkening(edge: edge, context: context)
            } else {
                opacity = 1 - (1 - 0.22 * context.motion * pow(edge, 1.35) * context.strength) * (1 - context.finalFade)
            }
            return NSColor.black.withAlphaComponent(opacity).cgColor
        }
        shade.locations = (0..<samples).map { NSNumber(value: Double($0) / Double(samples - 1)) }
        material.isHidden = context.reduceTransparency || context.closure == 0
        if kind == .veil && !context.reduceTransparency {
            // AppKit owns the blur radius. The alpha mask controls material coverage only.
            let mask = NSImage(size: NSSize(width: 1, height: 256), flipped: false) { rect in
                for row in 0..<256 {
                    let edge = Double(row) / 255
                    NSColor.white.withAlphaComponent(context.motion * pow(edge, 1.35) * context.strength).setFill()
                    NSRect(x: 0, y: row, width: 1, height: 1).fill()
                }
                return true
            }
            material.maskImage = mask
        }
        CATransaction.commit()
    }
    func stop() { view.removeFromSuperview(); lastContext = nil }
}
