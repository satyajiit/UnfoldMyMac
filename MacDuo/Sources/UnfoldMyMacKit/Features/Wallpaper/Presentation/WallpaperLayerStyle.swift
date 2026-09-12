import SwiftUI
import UnfoldMyMacCore

/// The typography rules for one layer, in one place instead of inline in the layer view (P20).
struct WallpaperLayerStyle: Equatable {
    static let boldFont = "SpaceGrotesk-Bold"
    static let mediumFont = "SpaceGrotesk-Medium"
    let fontName: String
    /// Font size as a fraction of the canvas width.
    let size: Double
    /// Letter spacing in canvas points; multiplied by the fitted scale at render time.
    let tracking: CGFloat
    let isSticker: Bool
    let numeric: Bool
    let maxLines: Int

    init(layer: WallpaperLayer) {
        isSticker = layer.kind == .sticker
        fontName = isSticker || layer.size > 0.035 ? Self.boldFont : Self.mediumFont
        size = layer.size
        tracking = layer.size < 0.02 ? 2 : -1
        numeric = layer.kind == .metric
        maxLines = layer.maxLines ?? 3
    }
    func font(scale: CGFloat) -> Font { .custom(fontName, size: size * WallpaperCanvas.width * scale) }
}
