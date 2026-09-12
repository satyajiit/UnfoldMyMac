import MetalKit
import UnfoldMyMacCore

private struct PeekabooUniforms {
    var closure: Float
    var strength: Float
    var aspect: Float
    var time: Float
}

/// Two deforming vinyl surfaces and four independently posed sphere meshes.
/// All movement uses the session clock; no capture, image texture, or private timer.
@MainActor final class PeekabooPipeline: MetalEffectPipeline {
    let pixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
    let gpu: MTLDevice
    let queue: MTLCommandQueue
    let animatesWithTime = true
    private let body: MTLRenderPipelineState
    private let eyes: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private var depth: MTLTexture?
    private let vertices: MTLBuffer
    private let indices: MTLBuffer
    private let indexCount: Int

    init() throws {
        guard let gpu = MTLCreateSystemDefaultDevice(), let queue = gpu.makeCommandQueue() else {
            throw NSError(domain: AppIdentity.name, code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal is unavailable on this Mac."])
        }
        self.gpu = gpu; self.queue = queue
        guard let url = Bundle.module.url(forResource: "Peekaboo", withExtension: "metal", subdirectory: "Shaders") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let library = try gpu.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
        func pipeline(_ vertex: String, _ fragment: String) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: vertex)
            descriptor.fragmentFunction = library.makeFunction(name: fragment)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
            descriptor.depthAttachmentPixelFormat = .depth32Float
            return try gpu.makeRenderPipelineState(descriptor: descriptor)
        }
        body = try pipeline("peekabooBodyVertex", "peekabooBodyFragment")
        eyes = try pipeline("peekabooEyeVertex", "peekabooEyeFragment")
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        guard let depthState = gpu.makeDepthStencilState(descriptor: depthDescriptor) else { throw CocoaError(.coderInvalidValue) }
        self.depthState = depthState

        // One reusable UV grid is instanced as both pillow surfaces and spheres.
        let columns = 96, rows = 64
        var points: [SIMD2<Float>] = []
        var triangles: [UInt32] = []
        for row in 0...rows { for column in 0...columns {
            points.append(SIMD2(Float(column) / Float(columns), Float(row) / Float(rows)))
        } }
        for row in 0..<rows { for column in 0..<columns {
            let a = UInt32(row * (columns + 1) + column), b = a + 1
            let c = a + UInt32(columns + 1), d = c + 1
            triangles.append(contentsOf: [a, b, c, b, d, c])
        } }
        guard let vertices = gpu.makeBuffer(bytes: points, length: points.count * MemoryLayout<SIMD2<Float>>.stride),
              let indices = gpu.makeBuffer(bytes: triangles, length: triangles.count * MemoryLayout<UInt32>.stride) else {
            throw NSError(domain: AppIdentity.name, code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to create the Peekaboo geometry."])
        }
        self.vertices = vertices; self.indices = indices; indexCount = triangles.count
    }

    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, size: CGSize, context: EffectContext) -> Bool {
        let width = max(1, Int(size.width)), height = max(1, Int(size.height))
        if depth?.width != width || depth?.height != height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
            descriptor.storageMode = .private; descriptor.usage = .renderTarget
            depth = gpu.makeTexture(descriptor: descriptor)
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
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: indexCount, indexType: .uint32,
                indexBuffer: indices, indexBufferOffset: 0, instanceCount: 2)
            encoder.setRenderPipelineState(eyes)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: indexCount, indexType: .uint32,
                indexBuffer: indices, indexBufferOffset: 0, instanceCount: 4)
        }
        encoder.endEncoding()
        return true
    }
}
