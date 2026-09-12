import MetalKit
import UnfoldMyMacCore

struct CurrentUniforms {
    var closure: Float
    var strength: Float
    var aspect: Float
    var time: Float
    var pixel: SIMD2<Float>
}

/// Analytic ribbons and drifting particles; no captures, textures, or private clock.
@MainActor final class CurrentPipeline: MetalEffectPipeline {
    let gpu: MTLDevice
    let queue: MTLCommandQueue
    let animatesWithTime = true
    private let pipeline: MTLRenderPipelineState
    init() throws {
        guard let gpu = MTLCreateSystemDefaultDevice(), let queue = gpu.makeCommandQueue() else {
            throw NSError(domain: AppIdentity.name, code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal is unavailable on this Mac."])
        }
        self.gpu = gpu; self.queue = queue
        guard let url = Bundle.module.url(forResource: "Current", withExtension: "metal", subdirectory: "Shaders") else { throw CocoaError(.fileNoSuchFile) }
        let library = try gpu.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "currentVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "currentFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try gpu.makeRenderPipelineState(descriptor: descriptor)
    }
    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, size: CGSize, context: EffectContext) -> Bool {
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
