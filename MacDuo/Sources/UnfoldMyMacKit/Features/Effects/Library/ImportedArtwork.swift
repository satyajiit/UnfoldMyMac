import AppKit
import ImageIO
import Observation
import UniformTypeIdentifiers
import UnfoldMyMacCore

struct ImportedArtwork: Codable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var author: String
    var effectID: EffectID { .init(rawValue: "import.\(id.uuidString.lowercased())") }
    var filename: String { "\(id.uuidString.lowercased()).png" }
    func definition(in directory: URL) -> ArtworkDefinition {
        let image = directory.appendingPathComponent(filename)
        return .init(descriptor: .init(id: effectID, title: title, subtitle: "Your art. A new way to open.",
            detail: "Your image parts to reveal the desktop and comes together as the lid closes. Choose a reveal and adjust its depth below. Images fill the display without stretching; edges may be cropped.",
            symbol: UnfoldMyMacIcon.image.rawValue, parameterTitle: "Depth & edge light", renderingLabel: "Your image",
            category: .image, tags: ["Imported", "Personal"], author: author, credit: "Imported from a local file",
            coverURL: image, isImported: true, defaultReveal: .curved), imageURL: image)
    }
}
