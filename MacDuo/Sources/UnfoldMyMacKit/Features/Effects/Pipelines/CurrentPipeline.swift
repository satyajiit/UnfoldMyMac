import Metal
import UnfoldMyMacCore

private struct CurrentUniforms {
    var closure: Float
    var strength: Float
    var aspect: Float
    var time: Float
    var pixel: SIMD2<Float>
}

/// Analytic ribbons and drifting particles; no captures, textures, or private clock.
@MainActor final class CurrentPipeline: EffectPipeline {
    let gpu: GPUContext
    let surface = SurfaceConfiguration()
    let animatesWithTime = true
    private let pipeline: MTLRenderPipelineState

    init(gpu: GPUContext) throws {
        self.gpu = gpu
        pipeline = try gpu.pipeline(.effect("Current"), vertex: "currentVertex", fragment: "currentFragment", color: .bgra8Unorm)
    }
    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, size: CGSize, frame context: EffectContext) -> Bool {
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return false }
        if context.closure > 0 {
            var uniforms = CurrentUniforms(closure: Float(context.closure), strength: Float(context.strength),
                aspect: Float(size.width / max(1, size.height)), time: context.reduceMotion ? 0 : Float(context.time.truncatingRemainder(dividingBy: 3600)),
                pixel: SIMD2(1 / Float(max(1, size.width)), 1 / Float(max(1, size.height))))
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CurrentUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }
        encoder.endEncoding()
        return true
    }
}
