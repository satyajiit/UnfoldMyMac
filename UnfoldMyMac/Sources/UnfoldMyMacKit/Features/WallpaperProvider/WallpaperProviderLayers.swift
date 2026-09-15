import AppKit
import SwiftUI
import UnfoldMyMacCore

/// The scene's readouts, above the Metal surface, inside the extension's remote layer tree.
///
/// Twenty of the twenty-two bundled scenes carry text layers, and they are the point of most of them — a
/// wallpaper that shows a number is not the same wallpaper with the number missing.
///
/// In the app these are SwiftUI in an `NSHostingView` above the Metal view inside a real window. Here
/// there is no window, and that is the whole difficulty: an `NSHostingView` outside a window composites
/// its first frame and then never updates again, because AppKit only drives a view's display cycle from
/// the window it belongs to. Reassigning the root view does not help — the update is scheduled, not run.
///
/// So the views are rendered explicitly with `ImageRenderer`, which evaluates a SwiftUI body on demand
/// with no window anywhere, and the result becomes this layer's contents. Rendering is driven by the data
/// rather than by the display link: the readouts change when the numbers do, which is a few times a
/// minute, while the scene underneath keeps its own frame rate.
///
/// `WallpaperSurfaceModel` and `WallpaperLayersRoot` are the same types the desktop windows use, so both
/// paths draw the same design from the same state rather than two descriptions of it.
@MainActor final class WallpaperProviderLayers {
    let layer = CALayer()
    private let model = WallpaperSurfaceModel()
    private var size: CGSize
    private var scale: CGFloat
    /// What the current image was drawn from, so unchanged data never costs a render. Keyed on the values
    /// the views can actually read rather than on the snapshot: every sample carries a new timestamp even
    /// when nothing it reports has moved, and re-rendering a full-resolution image for that is pure waste.
    private var rendered: String?

    init?(template: WallpaperTemplate, styleSheet: WallpaperStyle, size: CGSize, scale: CGFloat) {
        guard !template.layers.isEmpty else { return nil }
        self.size = size
        self.scale = scale
        model.reset(template: template, styleSheet: styleSheet)
        layer.frame = CGRect(origin: .zero, size: size)
        layer.contentsScale = scale
        layer.isOpaque = false
        // The readouts are laid out for the whole surface; scaling them would misplace every anchor.
        layer.contentsGravity = .resize
        layer.masksToBounds = true
        draw()
    }

    func resize(to size: CGSize, scale: CGFloat) {
        guard self.size != size || self.scale != scale else { return }
        self.size = size
        self.scale = scale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = CGRect(origin: .zero, size: size)
        layer.contentsScale = scale
        CATransaction.commit()
        rendered = nil
        draw()
    }

    func update(snapshot: WallpaperSnapshot, animated: Bool) {
        let key = Self.renderKey(for: snapshot)
        guard rendered != key else { return }
        model.update(snapshot: snapshot)
        model.setAnimated(animated)
        rendered = key
        draw()
    }

    /// Every value a layer can display, and nothing else. Grids drive the Metal scene rather than the
    /// readouts, so they are deliberately absent: a grid changing must not force a text re-render.
    private static func renderKey(for snapshot: WallpaperSnapshot) -> String {
        var parts: [String] = []
        for (namespace, sample) in snapshot.sources.sorted(by: { $0.key < $1.key }) {
            parts.append(namespace)
            parts.append(sample.status)
            for (key, value) in sample.numbers.sorted(by: { $0.key < $1.key }) { parts.append("\(key)=\(value)") }
            for (key, value) in sample.text.sorted(by: { $0.key < $1.key }) { parts.append("\(key)=\(value)") }
        }
        for (namespace, message) in snapshot.errors.sorted(by: { $0.key < $1.key }) { parts.append("!\(namespace)=\(message)") }
        return parts.joined(separator: "\u{1F}")
    }

    private func draw() {
        guard size.width > 0, size.height > 0 else { return }
        let renderer = ImageRenderer(content: WallpaperLayersRoot(surface: model).frame(width: size.width, height: size.height))
        renderer.scale = scale
        renderer.isOpaque = false
        guard let image = renderer.cgImage else {
            WallpaperProviderLog.fault("the scene's readouts could not be rendered")
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.contents = image
        CATransaction.commit()
    }
}
