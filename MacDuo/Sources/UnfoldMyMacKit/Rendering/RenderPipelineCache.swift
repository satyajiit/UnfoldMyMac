import Metal

enum PipelineBlend: Hashable, Sendable {
    case opaque
    /// Source-over with premultiplied alpha, so cleared regions stay genuinely transparent.
    case premultiplied
}

/// Pipeline states keyed by everything that shapes them; two pipelines asking for the same state share it.
@MainActor final class RenderPipelineCache {
    private struct Key: Hashable {
        let unit: String, vertex: String, fragment: String
        let color: MTLPixelFormat, depth: MTLPixelFormat, blend: PipelineBlend
    }
    private var states: [Key: MTLRenderPipelineState] = [:]
    private(set) var builtCount = 0

    func pipeline(library: MTLLibrary, unit: String, vertex: String, fragment: String, color: MTLPixelFormat,
                  depth: MTLPixelFormat = .invalid, blend: PipelineBlend = .opaque) throws -> MTLRenderPipelineState {
        let key = Key(unit: unit, vertex: vertex, fragment: fragment, color: color, depth: depth, blend: blend)
        if let cached = states[key] { return cached }
        guard let vertexFunction = library.makeFunction(name: vertex) else { throw GPUError.missingFunction(vertex) }
        guard let fragmentFunction = library.makeFunction(name: fragment) else { throw GPUError.missingFunction(fragment) }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        guard let attachment = descriptor.colorAttachments[0] else { throw GPUError.allocationFailed("the color attachment") }
        attachment.pixelFormat = color
        if blend == .premultiplied {
            attachment.isBlendingEnabled = true
            attachment.sourceRGBBlendFactor = .one; attachment.sourceAlphaBlendFactor = .one
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha; attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }
        descriptor.depthAttachmentPixelFormat = depth
        let state = try library.device.makeRenderPipelineState(descriptor: descriptor)
        states[key] = state; builtCount += 1
        return state
    }
}
