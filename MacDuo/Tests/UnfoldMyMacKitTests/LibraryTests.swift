import AppKit
import ImageIO
import UniformTypeIdentifiers
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test @MainActor func catalogHasCoversCreditsAndSearchableUnifiedImageCategory() throws {
    let registry = EffectRegistry.builtIn()
    #expect(registry.catalogError == nil)
    #expect(registry.descriptors.count == 13)
    for descriptor in registry.descriptors {
        #expect(!descriptor.author.isEmpty && !descriptor.tags.isEmpty)
        let url = try #require(descriptor.coverURL)
        #expect(ImageFiles.thumbnail(at: url) != nil)
    }
    let art = registry.descriptors.filter { $0.category == .image }
    #expect(Set(art.map(\.id)) == Set([.reverie, .neonCoast, .rise, EffectID(rawValue: "tab-goblin"), EffectID(rawValue: "fcuk-it"), EffectID(rawValue: "codex-after-dark"), EffectID(rawValue: "claude-has-notes")]))
    #expect(art.filter { $0.matches(query: "unfoldmymac game", category: .image, tag: "Game Art") }.map(\.id) == [.neonCoast])
    #expect(art.filter { $0.matches(query: "MOTIVATION") }.map(\.id) == [.rise])
    #expect(Set(art.filter { $0.matches(query: "mac", tag: "Humor") }.map(\.id.rawValue)) == ["tab-goblin", "fcuk-it", "codex-after-dark", "claude-has-notes"])
    #expect(Set(art.filter { $0.matches(query: "", tag: "Coding") }.map(\.id.rawValue)) == ["codex-after-dark", "claude-has-notes"])
    #expect(art.first { $0.id.rawValue == "codex-after-dark" }?.defaultReveal == .diagonal)
    #expect(art.first { $0.id.rawValue == "claude-has-notes" }?.defaultReveal == .curved)
    #expect(art.first { $0.id.rawValue == "tab-goblin" }?.defaultReveal == .straight)
    #expect(art.first { $0.id.rawValue == "fcuk-it" }?.defaultReveal == .diagonal)
    #expect(art.filter { $0.matches(query: "  ", category: .motion) }.isEmpty)
    #expect(art.filter { $0.matches(query: "unrelated") }.isEmpty)
    #expect(throws: LibraryError.self) { try registry.register(registry.entries[0]) }
}

private func imageFixture(in directory: URL) throws -> URL {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("My test art.png")
    let context = try #require(CGContext(data: nil, width: 6, height: 4, bitsPerComponent: 8, bytesPerRow: 24,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    for y in 0..<4 { for x in 0..<6 {
        context.setFillColor(CGColor(red: CGFloat(x)/6, green: CGFloat(y)/4, blue: 0.4, alpha: 0.5))
        context.fill(CGRect(x: x, y: y, width: 1, height: 1))
    } }
    let image = try #require(context.makeImage())
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: 6] as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    return url
}

@Test @MainActor func importedImagesSurviveOriginalRemovalAndPersistCreditsAndReveal() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = try imageFixture(in: root)
    let library = ArtworkLibrary(directory: root.appendingPathComponent("library"))
    let artwork = try await library.importImage(at: source)
    #expect(artwork.descriptor.title == "My test art")
    #expect(artwork.descriptor.category == .image && artwork.descriptor.isImported)
    #expect(artwork.imageURL != source)
    let image = try #require(ImageFiles.thumbnail(at: artwork.imageURL))
    #expect(image.width == 4 && image.height == 6) // EXIF orientation has been baked in.
    #expect(image.alphaInfo == .none || image.alphaInfo == .noneSkipLast || image.alphaInfo == .noneSkipFirst)
    try FileManager.default.removeItem(at: source)
    let updated = try #require(try library.update(id: artwork.id, title: "  My World  ", author: "  Test Artist  "))
    #expect(updated.descriptor.title == "My World" && updated.descriptor.author == "Test Artist")
    let reloaded = ArtworkLibrary(directory: library.directory)
    #expect(reloaded.definitions.map(\.id) == [artwork.id])
    #expect(reloaded.definitions[0].descriptor.matches(query: "Test Artist", tag: "Imported"))
    let registry = EffectRegistry.builtIn()
    try registry.register(.artwork(reloaded.definitions[0]))
    let renderer = try registry.entry(for: artwork.id).makeRenderer(try TestGPU.context())
    #expect(!(renderer is any DesktopFrameSink)); renderer.stop()
    var settings = UnfoldMyMacSettings(); settings.effect = artwork.id
    settings.parameters[artwork.id.rawValue] = .init(strength: 0.42, reveal: .straight)
    settings.sanitize()
    let decoded = try JSONDecoder().decode(UnfoldMyMacSettings.self, from: JSONEncoder().encode(settings))
    #expect(decoded.parameters(for: artwork.id).reveal == .straight)
    #expect(registry.entry(for: decoded.effect).descriptor.id == artwork.id)
    try reloaded.remove(artwork.id); registry.removeImported(artwork.id)
    #expect(ArtworkLibrary(directory: library.directory).records.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: artwork.imageURL.path))
    #expect(registry.entry(for: artwork.id).descriptor.id == .frost)
}

@Test @MainActor func importsRejectInvalidAndOversizedFilesWithoutChangingTheLibrary() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let invalid = root.appendingPathComponent("fake.png")
    try Data("not an image".utf8).write(to: invalid)
    let library = ArtworkLibrary(directory: root.appendingPathComponent("library"))
    await #expect(throws: LibraryError.self) { try await library.importImage(at: invalid) }
    let handle = try FileHandle(forWritingTo: invalid)
    try handle.truncate(atOffset: 51 * 1024 * 1024); try handle.close()
    await #expect(throws: LibraryError.self) { try await library.importImage(at: invalid) }
    #expect(library.records.isEmpty)
}

@Test @MainActor func corruptIndexIsReportedAndNeverOverwrittenByImport() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = try imageFixture(in: root)
    let index = root.appendingPathComponent("library.json")
    let original = Data("broken index".utf8); try original.write(to: index)
    let library = ArtworkLibrary(directory: root)
    #expect(library.loadError != nil)
    await #expect(throws: LibraryError.self) { try await library.importImage(at: source) }
    #expect(try Data(contentsOf: index) == original)
    #expect(FileManager.default.fileExists(atPath: source.path))
}
