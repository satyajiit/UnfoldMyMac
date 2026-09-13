import SwiftUI
import UnfoldMyMacCore

/// The typography rules for one layer, resolved once from the template's style over the shared sheet (P20).
struct WallpaperLayerStyle: Equatable {
    let fontName: String
    /// Font size as a fraction of the canvas width.
    let size: Double
    /// Letter spacing in canvas points; multiplied by the fitted scale at render time.
    let tracking: CGFloat
    let isSticker: Bool
    let numeric: Bool
    let maxLines: Int
    private let canvasWidth: Double

    init(layer: WallpaperLayer, style: WallpaperStyle = .standard, canvas: WallpaperCanvas = .standard) {
        let resolved = style.merged(over: .standard), base = WallpaperStyle.standard
        isSticker = layer.kind == .sticker
        let bold = resolved.boldFont ?? base.boldFont ?? "", medium = resolved.mediumFont ?? base.mediumFont ?? ""
        fontName = isSticker || layer.size > (resolved.boldThreshold ?? 0.035) ? bold : medium
        size = layer.size
        tracking = layer.size < (resolved.captionThreshold ?? 0.02) ? (resolved.captionTracking ?? 2) : (resolved.displayTracking ?? -1)
        numeric = layer.kind == .metric
        maxLines = layer.maxLines ?? 3
        canvasWidth = canvas.width
    }
    func font(scale: CGFloat) -> Font { .custom(fontName, size: size * canvasWidth * scale) }
}
