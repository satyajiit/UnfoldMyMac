import AppKit
import UnfoldMyMacCore

/// Any effect pipeline on the shared surface renderer is an effect renderer.
extension MetalSurfaceRenderer: EffectRenderer where Pipeline: EffectPipeline {
    /// Effects always come from `init(pipeline:)`, which owns a `MetalSurfaceView` and installs it in the
    /// overlay window. The layer-backed initialiser exists for the wallpaper extension, whose surface is a
    /// remote `CAContext` layer with no AppKit view and never carries an effect pipeline.
    var view: NSView {
        guard let surfaceView else { preconditionFailure("An effect renderer is always view-backed") }
        return surfaceView
    }
    var ready: Bool { pipeline.isReady }
    var animatesWithTime: Bool { pipeline.animatesWithTime }
    func update(_ context: EffectContext) { render(context) }
}

/// Capture frames go straight to the pipeline; the renderer only redraws because the content generation moved.
extension MetalSurfaceRenderer: DesktopFrameSink where Pipeline: DesktopFrameSink {
    func receive(_ frame: DesktopFrame) { pipeline.receive(frame) }
}
