import AppKit
import MetalKit
import UnfoldMyMacCore

struct ArtRevealUniforms {
    var closure: Float
    var strength: Float
    var aspect: Float
    var imageAspect: Float
    var style: UInt32
    var pad: UInt32 = 0
    var pixel: SIMD2<Float>
}

/// Bundled and imported artwork share one reversible reveal pipeline.
/// Image identity and selectable cut geometry are independent. No desktop capture.
@MainActor final class ArtRevealPipeline: MetalEffectPipeline {
    let gpu: MTLDevice
    let queue: MTLCommandQueue
    let artwork: MTLTexture
    let defaultReveal: ArtRevealMotion
    private let pipeline: MTLRenderPipelineState

    init(artwork definition: ArtworkDefinition) throws {
        guard let gpu = MTLCreateSystemDefaultDevice(), let queue = gpu.makeCommandQueue() else {
            throw NSError(domain: AppIdentity.name, code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal is unavailable on this Mac."])
        }
        self.gpu = gpu; self.queue = queue; self.defaultReveal = definition.descriptor.defaultReveal ?? .curved
        guard let shader = Bundle.module.url(forResource: "ArtReveal", withExtension: "metal", subdirectory: "Shaders") else {
            throw CocoaError(.fileNoSuchFile)
        }
        artwork = try MTKTextureLoader(device: gpu).newTexture(URL: definition.imageURL, options: [
            .SRGB: true,
            .origin: MTKTextureLoader.Origin.topLeft.rawValue,
            .generateMipmaps: true,
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            .textureStorageMode: NSNumber(value: MTLStorageMode.shared.rawValue),
        ])
        let library = try gpu.makeLibrary(source: String(contentsOf: shader, encoding: .utf8), options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "artRevealVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "artRevealFragment")
        // Shader encodes sRGB before premultiplication for Core Animation's
        // transparent surface, keeping bright antialiased edges halo-free.
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try gpu.makeRenderPipelineState(descriptor: descriptor)
    }

    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, size: CGSize, context: EffectContext) -> Bool {
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return false }
        if context.closure > 0 {
            var uniforms = ArtRevealUniforms(closure: Float(context.closure), strength: context.reduceMotion ? 0 : Float(context.strength),
                aspect: Float(size.width / max(1, size.height)), imageAspect: Float(artwork.width) / Float(artwork.height),
                style: (context.parameters.reveal ?? defaultReveal).shaderIndex, pixel: SIMD2(1 / Float(max(1, size.width)), 1 / Float(max(1, size.height))))
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentTexture(artwork, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ArtRevealUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }
        encoder.endEncoding()
        return true
    }
}

typealias ArtRevealRenderer = MetalEffectRenderer<ArtRevealPipeline>
