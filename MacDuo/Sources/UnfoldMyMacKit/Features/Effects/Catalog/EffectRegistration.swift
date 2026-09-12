import AppKit
import Observation
import UnfoldMyMacCore

@MainActor struct EffectRegistration {
    let descriptor: EffectDescriptor
    let makeRenderer: () throws -> any EffectRenderer
}

extension EffectRegistration {
    static func artwork(_ artwork: ArtworkDefinition) -> EffectRegistration {
        .init(descriptor: artwork.descriptor, makeRenderer: { ArtRevealRenderer(pipeline: try ArtRevealPipeline(artwork: artwork)) })
    }
}
