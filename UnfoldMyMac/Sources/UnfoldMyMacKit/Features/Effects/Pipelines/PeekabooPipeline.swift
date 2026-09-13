import Metal
import UnfoldMyMacCore

private struct PeekabooUniforms {
    var closure: Float
    var strength: Float
    var aspect: Float
    var time: Float
}

/// Two deforming vinyl surfaces and four independently posed sphere meshes.
/// All movement uses the session clock; no capture, image texture, or private timer.
@MainActor final class PeekabooPipeline: EffectPipeline {
    let gpu: GPUContext
    let surface = SurfaceConfiguration(pixelFormat: .bgra8Unorm_srgb)
    let animatesWithTime = true
    private let body: MTLRenderPipelineState
    private let eyes: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private var depth: MTLTexture?
    private let vertices: MTLBuffer
    private let indices: MTLBuffer
    private let indexCount: Int

    init(gpu: GPUContext) throws {
        self.gpu = gpu
        let module = ShaderModule.effect("Peekaboo")
        body = try gpu.pipeline(module, vertex: "peekabooBodyVertex", fragment: "peekabooBodyFragment", color: .bgra8Unorm_srgb, depth: .depth32Float)
        eyes = try gpu.pipeline(module, vertex: "peekabooEyeVertex", fragment: "peekabooEyeFragment", color: .bgra8Unorm_srgb, depth: .depth32Float)
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        guard let depthState = gpu.device.makeDepthStencilState(descriptor: depthDescriptor) else { throw GPUError.allocationFailed("the depth state") }
        self.depthState = depthState
        // One reusable UV grid is instanced as both pillow surfaces and spheres.
        let mesh = GridMesh(columns: 96, rows: 64)
        guard let vertices = gpu.device.makeBuffer(bytes: mesh.points, length: mesh.points.count * MemoryLayout<SIMD2<Float>>.stride),
              let indices = gpu.device.makeBuffer(bytes: mesh.triangles, length: mesh.triangles.count * MemoryLayout<UInt32>.stride) else {
            throw GPUError.allocationFailed("the Peekaboo geometry")
        }
        self.vertices = vertices; self.indices = indices; indexCount = mesh.triangles.count
    }
    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, size: CGSize, frame context: EffectContext) -> Bool {
        let width = max(1, Int(size.width)), height = max(1, Int(size.height))
        if depth?.width != width || depth?.height != height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
            descriptor.storageMode = .private; descriptor.usage = .renderTarget
            depth = gpu.device.makeTexture(descriptor: descriptor)
        }
        guard let depth else { return false }
        pass.depthAttachment.texture = depth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare
        pass.depthAttachment.clearDepth = 1
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return false }
        // Always encode the clear, including when reopening to exactly zero.
        if context.closure > 0 {
            var uniforms = PeekabooUniforms(closure: Float(context.closure), strength: Float(context.strength),
                aspect: Float(width) / Float(height), time: context.reduceMotion ? 0 : Float(context.time.truncatingRemainder(dividingBy: 3600)))
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<PeekabooUniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<PeekabooUniforms>.stride, index: 1)
            encoder.setVertexBuffer(vertices, offset: 0, index: 0)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.none)
            encoder.setRenderPipelineState(body)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: indexCount, indexType: .uint32, indexBuffer: indices, indexBufferOffset: 0, instanceCount: 2)
            encoder.setRenderPipelineState(eyes)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: indexCount, indexType: .uint32, indexBuffer: indices, indexBufferOffset: 0, instanceCount: 4)
        }
        encoder.endEncoding()
        return true
    }
}
