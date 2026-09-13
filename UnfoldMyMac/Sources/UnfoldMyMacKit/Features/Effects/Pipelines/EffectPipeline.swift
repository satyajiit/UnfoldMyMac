import Metal
import UnfoldMyMacCore

/// A lid effect on the GPU: one `EffectContext` in, one premultiplied frame out. Encoding must clear at
/// zero closure so an old closed frame can never survive.
@MainActor protocol EffectPipeline: MetalPipeline where Frame == EffectContext {
    var animatesWithTime: Bool { get }
}

extension EffectPipeline {
    var animatesWithTime: Bool { false }
    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, size: CGSize, context: EffectContext) -> Bool {
        encode(command: command, pass: pass, size: size, frame: context)
    }
}
