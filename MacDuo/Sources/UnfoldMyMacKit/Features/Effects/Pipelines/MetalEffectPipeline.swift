import AppKit
import MetalKit
import UnfoldMyMacCore

/// The only contract a procedural GPU effect implements. Encoding must clear at
/// zero and use premultiplied alpha. The shared renderer owns the drawable lifecycle.
@MainActor protocol MetalEffectPipeline {
    var gpu: MTLDevice { get }
    var queue: MTLCommandQueue { get }
    var pixelFormat: MTLPixelFormat { get }
    var animatesWithTime: Bool { get }
    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, size: CGSize, context: EffectContext) -> Bool
}

extension MetalEffectPipeline {
    var pixelFormat: MTLPixelFormat { .bgra8Unorm }
    var animatesWithTime: Bool { false }
}
