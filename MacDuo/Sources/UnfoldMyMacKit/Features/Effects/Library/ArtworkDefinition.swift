import Foundation
import UnfoldMyMacCore

/// Content owns metadata and a file; the shared reveal pipeline owns all motion.
struct ArtworkDefinition: Identifiable, Sendable {
    let descriptor: EffectDescriptor
    let imageURL: URL
    var id: EffectID { descriptor.id }
}
