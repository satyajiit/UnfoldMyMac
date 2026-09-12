import SwiftUI

struct WallpaperPreviewCard: View {
    @Bindable var model: WallpaperModel
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = UnfoldMyMacPalette(dark: scheme == .dark)
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if let pipeline = model.previewPipeline {
                    WallpaperScene(pipeline: pipeline, snapshot: model.previewSnapshot, fps: model.previewFPS,
                        onStats: { stats in if !model.enabled { model.receiveStats(stats) } })
                        .id(ObjectIdentifier(pipeline))
                } else { Color(hex: 0x101C20) }
                Text(model.playback.reducedMotion ? "REDUCED MOTION" : "LIVE PREVIEW")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1)
                    .foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: .capsule).padding(14)
            }
            .aspectRatio(1.6, contentMode: .fit).clipped()
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.selected?.title ?? "Loading scene…").font(UnfoldMyMacType.title3)
                        Text(model.selected?.subtitle ?? "").font(UnfoldMyMacType.caption).foregroundStyle(p.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if let selected = model.selected, !(selected.setup ?? []).isEmpty, model.setup.isReady(selected) {
                        Button("Configure") { model.setup.open(selected) }.modifier(UnfoldMyMacButtonStyle()).fixedSize()
                    }
                    Button(action: model.apply) {
                        Label(model.isSelectedApplied ? "On your desktop" : (model.selected.map { model.setup.isReady($0) } == true ? "Use wallpaper" : "Set up wallpaper"), icon: model.isSelectedApplied ? .selected : .display)
                    }
                    .modifier(UnfoldMyMacButtonStyle(prominent: !model.isSelectedApplied))
                    .disabled(model.previewPipeline == nil || model.isSelectedApplied)
                    .fixedSize().accessibilityIdentifier("wallpaper.apply")
                }
                HStack {
                    Label(model.enabled ? "\(model.activeTitle) · All displays" : "Preview only", icon: model.enabled ? .selected : .play)
                    Spacer(minLength: 0)
                    if model.stats.fps > 0 {
                        Text(String(format: "%.0f fps · %.1f ms GPU", model.stats.fps, model.stats.gpuMilliseconds)).monospacedDigit()
                            .help(String(format: "Measured displayed frames. 95th-percentile frame interval: %.1f ms. Target: %d fps.", model.stats.p95FrameMilliseconds, model.playback.framesPerSecond))
                    }
                    if model.enabled {
                        Button("Stop", action: model.stopWallpaper).buttonStyle(.plain).foregroundStyle(p.ink)
                            .accessibilityIdentifier("wallpaper.stop")
                    }
                }.font(UnfoldMyMacType.caption).foregroundStyle(p.secondary)
                WallpaperConnectionPrompt(model: model)
            }.padding(18)
        }
        .background { RoundedRectangle(cornerRadius: 18).fill(p.card) }
        .clipShape(.rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(p.ink.opacity(0.10), lineWidth: 1) }
        .onAppear { model.setPreviewVisible(true) }
        .onDisappear { model.setPreviewVisible(false) }
    }
}
