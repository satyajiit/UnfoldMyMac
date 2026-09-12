import SwiftUI
import UnfoldMyMacCore

struct WallpaperLayers: View {
    let template: WallpaperTemplate
    let snapshot: WallpaperSnapshot
    let animated: Bool
    var body: some View {
        GeometryReader { geometry in
            let fit = template.canvasSize.fit(width: geometry.size.width, height: geometry.size.height)
            let scale = fit.scale, size = CGSize(width: fit.width, height: fit.height)
            let style = template.styled(over: WallpaperStyleSheet.bundled)
            let resolved = resolvedSnapshot
            ZStack(alignment: .topLeading) {
                ForEach(template.layers) { layer in
                    layerView(layer, value: layer.value(in: resolved, cycles: animated), scale: scale, style: style)
                        .frame(width: size.width*layer.width, height: layer.height.map { size.height * $0 }, alignment: .topLeading)
                        .rotationEffect(.degrees(layer.rotation))
                        .offset(x: size.width*layer.x, y: size.height*layer.y)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .position(x: geometry.size.width/2, y: geometry.size.height/2)
        }
        .accessibilityElement(children: .combine)
    }
    private var resolvedSnapshot: WallpaperSnapshot {
        var resolved = snapshot
        if let countdown = template.countdown { resolved.sources["countdown"] = countdown.sample(at: .now) }
        return resolved
    }
    @ViewBuilder private func layerView(_ layer: WallpaperLayer, value: String, scale: CGFloat, style sheet: WallpaperStyle) -> some View {
        let style = WallpaperLayerStyle(layer: layer, style: sheet, canvas: template.canvasSize)
        if style.isSticker {
            Text(value)
                .font(style.font(scale: scale))
                .foregroundStyle(Color(hex: template.background))
                .padding(.horizontal, 22*scale).padding(.vertical, 14*scale)
                .background(Color(hex: layer.color), in: .rect(cornerRadius: 12*scale))
                .overlay { RoundedRectangle(cornerRadius: 12*scale).strokeBorder(.white.opacity(0.6), lineWidth: 2*scale) }
                .shadow(color: .black.opacity(0.3), radius: 12*scale, y: 8*scale)
        } else {
            Text(value)
                .font(style.font(scale: scale))
                .tracking(style.tracking * scale)
                .foregroundStyle(Color(hex: layer.color))
                .monospacedDigit().lineLimit(style.maxLines).minimumScaleFactor(0.5)
                .contentTransition(style.numeric ? .numericText() : .opacity)
                .animation(animated ? .easeOut(duration: 0.6) : nil, value: value)
                .shadow(color: .black.opacity(0.25), radius: 2*scale, y: scale)
        }
    }
}
