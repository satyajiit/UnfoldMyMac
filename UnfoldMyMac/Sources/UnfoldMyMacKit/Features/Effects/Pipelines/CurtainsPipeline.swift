import Metal
import UnfoldMyMacCore

private struct CurtainsUniforms {
    var closure: Float
    var strength: Float
    var aspect: Float
    var pad: Float = 0
}

/// Two instanced cloth meshes, lit in 3D. No desktop textures or capture session.
/// Both the live effect and offscreen checks use this exact render path.
@MainActor final class CurtainsPipeline: EffectPipeline {
    let gpu: GPUContext
    let surface = SurfaceConfiguration(pixelFormat: .bgra8Unorm_srgb)
    private let cloth: MTLRenderPipelineState
    private let shadow: MTLRenderPipelineState
    private let vertices: MTLBuffer
    private let indices: MTLBuffer
    private let indexCount: Int

    init(gpu: GPUContext) throws {
        self.gpu = gpu
        let module = ShaderModule.effect("Curtains")
        // Premultiplied alpha leaves the opening genuinely transparent.
        cloth = try gpu.pipeline(module, vertex: "curtainVertex", fragment: "curtainFragment", color: .bgra8Unorm_srgb, blend: .premultiplied)
        shadow = try gpu.pipeline(module, vertex: "curtainShadowVertex", fragment: "curtainShadowFragment", color: .bgra8Unorm_srgb, blend: .premultiplied)
        let mesh = GridMesh(columns: 192, rows: 80)
        guard let vertices = gpu.device.makeBuffer(bytes: mesh.points, length: mesh.points.count * MemoryLayout<SIMD2<Float>>.stride),
              let indices = gpu.device.makeBuffer(bytes: mesh.triangles, length: mesh.triangles.count * MemoryLayout<UInt32>.stride) else {
            throw GPUError.allocationFailed("the curtain mesh")
        }
        self.vertices = vertices; self.indices = indices; indexCount = mesh.triangles.count
    }
    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, size: CGSize, frame context: EffectContext) -> Bool {
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return false }
        // Still encode the clear pass at zero so an old closed frame cannot survive.
        if context.closure > 0 {
            var uniforms = CurtainsUniforms(closure: Float(context.closure), strength: Float(context.strength), aspect: Float(size.width / max(1, size.height)))
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<CurtainsUniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CurtainsUniforms>.stride, index: 1)
            encoder.setRenderPipelineState(shadow)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.setRenderPipelineState(cloth)
            encoder.setCullMode(.none)
            encoder.setVertexBuffer(vertices, offset: 0, index: 0)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: indexCount, indexType: .uint32, indexBuffer: indices, indexBufferOffset: 0, instanceCount: 2)
        }
        encoder.endEncoding()
        return true
    }
}
