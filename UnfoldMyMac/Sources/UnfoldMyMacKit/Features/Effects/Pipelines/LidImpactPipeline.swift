import Metal
import UnfoldMyMacCore

/// Two radial lid gestures share only their fullscreen encoder and uniform layout.
@MainActor final class LidImpactPipeline: EffectPipeline {
    enum Style: String, CaseIterable {
        case fracture, vortex
    }

    private struct Uniforms {
        var closure: Float
        var strength: Float
        var aspect: Float
        var time: Float
        var pixel: SIMD2<Float>
    }

    let gpu: GPUContext
    let surface = SurfaceConfiguration()
    let animatesWithTime: Bool
    private let pipeline: MTLRenderPipelineState

    init(style: Style, gpu: GPUContext) throws {
        self.gpu = gpu
        animatesWithTime = style == .vortex
        pipeline = try gpu.pipeline(.effect("LidImpact"), vertex: "impactVertex",
                                    fragment: "\(style.rawValue)Fragment", color: .bgra8Unorm)
    }

    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, size: CGSize, frame: EffectContext) -> Bool {
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return false }
        if frame.closure > 0 {
            var uniforms = Uniforms(closure: Float(frame.closure), strength: Float(frame.strength),
                aspect: Float(size.width / max(1, size.height)),
                time: frame.reduceMotion ? 0 : Float(frame.time.truncatingRemainder(dividingBy: 3600)),
                pixel: SIMD2(1 / Float(max(1, size.width)), 1 / Float(max(1, size.height))))
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }
        encoder.endEncoding()
        return true
    }
}
