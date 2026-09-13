import UnfoldMyMacCore

/// How one renderer key becomes code: a native AppKit renderer, or a GPU pipeline on the shared surface renderer.
enum EffectRendererFactory {
    case native(@MainActor (EffectManifestEntry) -> any EffectRenderer)
    case metal(@MainActor (EffectManifestEntry, GPUContext) throws -> any EffectPipeline)

    @MainActor func makeRenderer(_ entry: EffectManifestEntry, gpu: GPUContext?) throws -> any EffectRenderer {
        switch self {
        case .native(let make): return make(entry)
        case .metal(let make):
            guard let gpu else { throw GPUError.metalUnavailable }
            return Self.surface(try make(entry, gpu))
        }
    }
    var isMetal: Bool { if case .metal = self { true } else { false } }
    @MainActor func makePipeline(_ entry: EffectManifestEntry, gpu: GPUContext) throws -> (any EffectPipeline)? {
        if case .metal(let make) = self { try make(entry, gpu) } else { nil }
    }
    @MainActor private static func surface(_ pipeline: some EffectPipeline) -> any EffectRenderer { MetalSurfaceRenderer(pipeline: pipeline) }
}

/// The only Swift-side effect registration: renderer keys named by `Effects.json` (and the artwork adapter) and
/// the code that builds them. A new pipeline is one line here plus a manifest entry.
@MainActor enum EffectRendererFactories {
    static let table: [String: EffectRendererFactory] = [
        "native:veil": .native { _ in NativeEffectRenderer(kind: .veil) },
        "native:fade": .native { _ in NativeEffectRenderer(kind: .fade) },
        "metal-capture:frost": .metal { _, gpu in try FrostPipeline(gpu: gpu) },
        "metal-pipeline:curtains": .metal { _, gpu in try CurtainsPipeline(gpu: gpu) },
        "metal-pipeline:current": .metal { _, gpu in try CurrentPipeline(gpu: gpu) },
        "metal-pipeline:peekaboo": .metal { _, gpu in try PeekabooPipeline(gpu: gpu) },
        EffectAssets.artworkRenderer: .metal { entry, gpu in try ArtRevealPipeline(artwork: try EffectAssets.artwork(for: entry), gpu: gpu) },
    ]
    static func factory(for entry: EffectManifestEntry) -> EffectRendererFactory? { table[entry.renderer] }
}
