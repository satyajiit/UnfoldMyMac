import UnfoldMyMacCore

/// Any effect pipeline on the shared surface renderer is an effect renderer.
extension MetalSurfaceRenderer: EffectRenderer where Pipeline: EffectPipeline {
    var ready: Bool { pipeline.isReady }
    var animatesWithTime: Bool { pipeline.animatesWithTime }
    func update(_ context: EffectContext) { render(context) }
}

/// Capture frames go straight to the pipeline; the renderer only redraws because the content generation moved.
extension MetalSurfaceRenderer: DesktopFrameSink where Pipeline: DesktopFrameSink {
    func receive(_ frame: DesktopFrame) { pipeline.receive(frame) }
}
