import SwiftUI
import UnfoldMyMacCore

struct WallpaperLayers: View {
    let template: WallpaperTemplate
    let snapshot: WallpaperSnapshot
    let animated: Bool
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / WallpaperCanvas.width, geometry.size.height / WallpaperCanvas.height)
            let size = CGSize(width: WallpaperCanvas.width * scale, height: WallpaperCanvas.height * scale)
            ZStack(alignment: .topLeading) {
                ForEach(template.layers) { layer in
                    layerView(layer, scale: scale)
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
    @ViewBuilder private func layerView(_ layer: WallpaperLayer, scale: CGFloat) -> some View {
        let value = layer.value(in: resolvedSnapshot, cycles: animated)
        if layer.kind == .sticker {
            Text(value)
                .font(.custom("SpaceGrotesk-Bold", size: layer.size * WallpaperCanvas.width * scale))
                .foregroundStyle(Color(hex: template.background))
                .padding(.horizontal, 22*scale).padding(.vertical, 14*scale)
                .background(Color(hex: layer.color), in: .rect(cornerRadius: 12*scale))
                .overlay { RoundedRectangle(cornerRadius: 12*scale).strokeBorder(.white.opacity(0.6), lineWidth: 2*scale) }
                .shadow(color: .black.opacity(0.3), radius: 12*scale, y: 8*scale)
        } else {
            Text(value)
                .font(.custom(layer.size > 0.035 ? "SpaceGrotesk-Bold" : "SpaceGrotesk-Medium", size: layer.size * WallpaperCanvas.width * scale))
                .tracking(layer.size < 0.02 ? 2*scale : -1*scale)
                .foregroundStyle(Color(hex: layer.color))
                .monospacedDigit().lineLimit(layer.maxLines ?? 3).minimumScaleFactor(0.5)
                .contentTransition(layer.kind == .metric ? .numericText() : .opacity)
                .animation(animated ? .easeOut(duration: 0.6) : nil, value: value)
                .shadow(color: .black.opacity(0.25), radius: 2*scale, y: scale)
        }
    }
}
