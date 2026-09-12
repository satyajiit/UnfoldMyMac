import UnfoldMyMacCore

@MainActor struct EffectRegistration {
    let descriptor: EffectDescriptor
    /// Builds the renderer; the GPU context is nil only on a Mac without Metal.
    let makeRenderer: @MainActor (GPUContext?) throws -> any EffectRenderer

    /// A GPU pipeline on the shared surface renderer.
    static func metal<Pipeline: EffectPipeline>(_ make: @escaping @MainActor (GPUContext) throws -> Pipeline) -> @MainActor (GPUContext?) throws -> any EffectRenderer {
        { gpu in
            guard let gpu else { throw GPUError.metalUnavailable }
            return MetalSurfaceRenderer(pipeline: try make(gpu))
        }
    }
}

extension EffectRegistration {
    static func artwork(_ artwork: ArtworkDefinition) -> EffectRegistration {
        .init(descriptor: artwork.descriptor, makeRenderer: metal { try ArtRevealPipeline(artwork: artwork, gpu: $0) })
    }
}
