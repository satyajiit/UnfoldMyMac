import Foundation
import UnfoldMyMacCore

@MainActor struct EffectRegistration {
    let descriptor: EffectDescriptor
    /// Builds the renderer; the GPU context is nil only on a Mac without Metal.
    let makeRenderer: @MainActor (GPUContext?) throws -> any EffectRenderer
    /// The bare GPU pipeline for offscreen checks; nil for native renderers.
    let makePipeline: (@MainActor (GPUContext) throws -> any EffectPipeline)?

    init(descriptor: EffectDescriptor, makeRenderer: @escaping @MainActor (GPUContext?) throws -> any EffectRenderer,
         makePipeline: (@MainActor (GPUContext) throws -> any EffectPipeline)? = nil) {
        self.descriptor = descriptor; self.makeRenderer = makeRenderer; self.makePipeline = makePipeline
    }
    /// A catalog entry bound to the factory its renderer key names.
    init(entry: EffectManifestEntry, factory: EffectRendererFactory, coverURL: URL?) {
        var makePipeline: (@MainActor (GPUContext) throws -> any EffectPipeline)?
        if factory.isMetal {
            makePipeline = { gpu in
                guard let pipeline = try factory.makePipeline(entry, gpu: gpu) else { throw GPUError.metalUnavailable }
                return pipeline
            }
        }
        self.init(descriptor: entry.descriptor(coverURL: coverURL), makeRenderer: { gpu in try factory.makeRenderer(entry, gpu: gpu) }, makePipeline: makePipeline)
    }
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
        .init(descriptor: artwork.descriptor, makeRenderer: metal { try ArtRevealPipeline(artwork: artwork, gpu: $0) },
              makePipeline: { try ArtRevealPipeline(artwork: artwork, gpu: $0) })
    }
}
