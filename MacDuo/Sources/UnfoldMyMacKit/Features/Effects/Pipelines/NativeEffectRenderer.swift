import AppKit
import QuartzCore
import UnfoldMyMacCore

/// Veil (system material behind a masked gradient) and Fade (gradient only). The gradient colours and the
/// material mask depend on two numbers, so they are memoised on a quantised key instead of being rebuilt every
/// frame (L8).
@MainActor final class NativeEffectRenderer: EffectRenderer {
    enum Kind { case veil, fade }
    private struct ShadeKey: Hashable { let coverage: Int; let fade: Int; let dim: Bool }
    /// Coverage and fade steps, rounded up so the subtle onset frame never quantises to nothing.
    static let quantisation = 128
    static let memoLimit = 64
    private static let samples = 64
    private static let maskRows = 256
    let view: NSView = NSView()
    let ready = true
    private let kind: Kind
    private let material = NSVisualEffectView()
    private let shade = CAGradientLayer()
    private var lastContext: EffectContext?
    private var shades: [ShadeKey: [CGColor]] = [:]
    private var masks: [Int: NSImage] = [:]

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
        shade.locations = (0..<Self.samples).map { NSNumber(value: Double($0) / Double(Self.samples - 1)) }
        view.layer?.addSublayer(shade)
    }
    var memoisedShades: Int { shades.count }
    var memoisedMasks: Int { masks.count }

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
        let dim = kind == .fade || context.reduceTransparency
        let key = ShadeKey(coverage: Self.quantise(context.motion * context.strength), fade: Self.quantise(context.finalFade), dim: dim)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        shade.colors = shadeColors(for: key)
        material.isHidden = context.reduceTransparency || context.closure == 0
        if kind == .veil, !context.reduceTransparency {
            // AppKit owns the blur radius. The alpha mask controls material coverage only.
            material.maskImage = mask(coverage: key.coverage)
        }
        CATransaction.commit()
    }
    func stop() { view.removeFromSuperview(); lastContext = nil }

    private static func quantise(_ value: Double) -> Int { Int((min(1, max(0, value.isFinite ? value : 0)) * Double(quantisation)).rounded(.up)) }
    private func shadeColors(for key: ShadeKey) -> [CGColor] {
        if let colors = shades[key] { return colors }
        if shades.count >= Self.memoLimit { shades.removeAll(keepingCapacity: true) }
        let coverage = Double(key.coverage) / Double(Self.quantisation), fade = Double(key.fade) / Double(Self.quantisation)
        let colors = (0..<Self.samples).map { index -> CGColor in
            let edge = Double(index) / Double(Self.samples - 1)
            let opacity = key.dim ? EffectMath.darkening(edge: edge, coverage: coverage, finalFade: fade)
                                  : 1 - (1 - 0.22 * EffectMath.veilCoverage(edge: edge, coverage: coverage)) * (1 - fade)
            return NSColor.black.withAlphaComponent(opacity).cgColor
        }
        shades[key] = colors
        return colors
    }
    private func mask(coverage step: Int) -> NSImage {
        if let mask = masks[step] { return mask }
        if masks.count >= Self.memoLimit { masks.removeAll(keepingCapacity: true) }
        let coverage = Double(step) / Double(Self.quantisation), rows = Self.maskRows
        let mask = NSImage(size: NSSize(width: 1, height: rows), flipped: false) { _ in
            for row in 0..<rows {
                NSColor.white.withAlphaComponent(EffectMath.veilCoverage(edge: Double(row) / Double(rows - 1), coverage: coverage)).setFill()
                NSRect(x: 0, y: row, width: 1, height: 1).fill()
            }
            return true
        }
        masks[step] = mask
        return mask
    }
}
