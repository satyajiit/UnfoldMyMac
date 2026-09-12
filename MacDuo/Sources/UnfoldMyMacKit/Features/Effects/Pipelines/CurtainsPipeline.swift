import AppKit
import MetalKit
import UnfoldMyMacCore

private struct CurtainsUniforms {
    var closure: Float
    var strength: Float
    var aspect: Float
    var pad: Float = 0
}

/// Two instanced cloth meshes, lit in 3D. No desktop textures or capture session.
/// Both the live effect and offscreen checks use this exact render path.
@MainActor final class CurtainsPipeline: MetalEffectPipeline {
    let pixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
    let gpu: MTLDevice
    let queue: MTLCommandQueue
    private let cloth: MTLRenderPipelineState
    private let shadow: MTLRenderPipelineState
    private let vertices: MTLBuffer
    private let indices: MTLBuffer
    private let indexCount: Int

    init() throws {
        guard let gpu = MTLCreateSystemDefaultDevice(), let queue = gpu.makeCommandQueue() else {
            throw GPUError.metalUnavailable
        }
        self.gpu = gpu; self.queue = queue
        let library = try gpu.makeLibrary(source: BundleResources.shaderSource("Curtains", family: .effects), options: nil)
        func pipeline(vertex: String, fragment: String) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: vertex)
            descriptor.fragmentFunction = library.makeFunction(name: fragment)
            let color = descriptor.colorAttachments[0]!
            color.pixelFormat = .bgra8Unorm_srgb
            // Premultiplied alpha leaves the opening genuinely transparent.
            color.isBlendingEnabled = true
            color.sourceRGBBlendFactor = .one
            color.sourceAlphaBlendFactor = .one
            color.destinationRGBBlendFactor = .oneMinusSourceAlpha
            color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try gpu.makeRenderPipelineState(descriptor: descriptor)
        }
        cloth = try pipeline(vertex: "curtainVertex", fragment: "curtainFragment")
        shadow = try pipeline(vertex: "curtainShadowVertex", fragment: "curtainShadowFragment")

        let columns = 192, rows = 80
        var points: [SIMD2<Float>] = []
        var triangles: [UInt32] = []
        for row in 0...rows {
            for column in 0...columns {
                points.append(SIMD2(Float(column) / Float(columns), Float(row) / Float(rows)))
            }
        }
        for row in 0..<rows {
            for column in 0..<columns {
                let a = UInt32(row * (columns + 1) + column)
                let b = a + 1, c = a + UInt32(columns + 1), d = c + 1
                triangles.append(contentsOf: [a, b, c, b, d, c])
            }
        }
        guard let vertices = gpu.makeBuffer(bytes: points, length: points.count * MemoryLayout<SIMD2<Float>>.stride),
              let indices = gpu.makeBuffer(bytes: triangles, length: triangles.count * MemoryLayout<UInt32>.stride) else {
            throw GPUError.allocationFailed("the curtain mesh")
        }
        self.vertices = vertices; self.indices = indices; indexCount = triangles.count
    }

    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, size: CGSize, context: EffectContext) -> Bool {
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return false }
        // Still encode the clear pass at zero so an old closed frame cannot survive.
        if context.closure > 0 {
            var uniforms = CurtainsUniforms(closure: Float(context.closure), strength: Float(context.strength),
                                             aspect: Float(size.width / max(1, size.height)))
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<CurtainsUniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CurtainsUniforms>.stride, index: 1)
            encoder.setRenderPipelineState(shadow)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.setRenderPipelineState(cloth)
            encoder.setCullMode(.none)
            encoder.setVertexBuffer(vertices, offset: 0, index: 0)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: indexCount, indexType: .uint32,
                                          indexBuffer: indices, indexBufferOffset: 0, instanceCount: 2)
        }
        encoder.endEncoding()
        return true
    }
}

typealias CurtainsRenderer = MetalEffectRenderer<CurtainsPipeline>
