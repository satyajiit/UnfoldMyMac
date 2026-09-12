import AppKit
import UnfoldMyMacCore

/// Supplies the system wallpaper sampler with scene colors, outside the animation loop.
/// A durable journal retains originals across Apply, Spaces, display changes and restart.
@MainActor final class WallpaperSystemBackdrop {
    private struct Record: Codable {
        let display: String
        let original: WallpaperDesktopImage
        let installed: WallpaperDesktopImage
    }
    private struct Journal: Codable {
        var version = 1
        var records: [String: Record] = [:]
    }
    private let access: any WallpaperDesktopImageAccess
    private let directory: URL
    private var journal: Journal?
    private struct Applied { let templateID: String; let imageURL: URL?; let size: CGSize; let url: URL; let previous: URL }
    /// Identity only: holding the pipeline itself would keep its GPU resources alive after a template switch.
    private var applied: [String: Applied] = [:]

    init(access: any WallpaperDesktopImageAccess = SystemWallpaperDesktopImages(),
         directory: URL = WallpaperPaths.root.appendingPathComponent("SystemBackdrop", isDirectory: true)) {
        self.access = access; self.directory = directory
    }
    func apply(_ pipeline: WallpaperPipeline) throws {
        try loadJournal()
        for screen in access.screens {
            guard let current = access.current(on: screen.id) else {
                throw WallpaperError.unavailable("The current system wallpaper could not be saved for restoration.")
            }
            if let cached = applied[screen.id], cached.templateID == pipeline.template.id, cached.imageURL == pipeline.imageURL,
               cached.size == screen.size, cached.url == current.url { continue }
            let previous = journal?.records[current.url.path]
            let original = previous.flatMap { $0.display == screen.id ? $0.original : nil } ?? current
            let image = try WallpaperThumbnailRenderer.image(pipeline: pipeline, size: screen.size)
            guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else { throw WallpaperError.unavailable("The desktop still could not be encoded.") }
            let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
            var signature = png
            signature.append(try encoder.encode(original)); signature.append(Data(screen.id.utf8))
            let filename = RecordStore.digest(signature) + ".png"
            let url = directory.appendingPathComponent(filename)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) { try png.write(to: url, options: .atomic) }
            let installed = WallpaperDesktopImage(url: url, options: [.imageScaling: NSImageScaling.scaleAxesIndependently.rawValue, .allowClipping: true])
            journal?.records[url.path] = Record(display: screen.id, original: original, installed: installed)
            // Save the restoration record BEFORE changing any system preference.
            try saveJournal()
            try access.set(installed, on: screen.id)
            applied[screen.id] = Applied(templateID: pipeline.template.id, imageURL: pipeline.imageURL, size: screen.size, url: url, previous: current.url)
        }
    }
    func restore() throws {
        try loadJournal()
        for screen in access.screens {
            guard let current = access.current(on: screen.id) else { continue }
            var record = journal?.records[current.url.path]
            if record == nil, let pending = applied[screen.id], let queued = journal?.records[pending.url.path],
               current.url == pending.previous || current.url == queued.original.url {
                // NSWorkspace may return before WallpaperAgent publishes its new image URL.
                // Queue restoration even when Stop arrives during that propagation interval.
                record = queued
            }
            guard let record, record.display == screen.id else { continue }
            // A wallpaper chosen later in System Settings belongs to the user; leave it alone.
            try access.set(record.original, on: screen.id)
        }
        applied.removeAll()
        // Retain records/files: a disconnected display or another Space can still reference them.
    }
    private func loadJournal() throws {
        guard journal == nil else { return }
        let url = directory.appendingPathComponent("restoration.json")
        guard FileManager.default.fileExists(atPath: url.path) else { journal = Journal(); return }
        let decoded = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: url))
        guard decoded.version == 1 else { throw WallpaperError.invalidData }
        journal = decoded
    }
    private func saveJournal() throws {
        guard let journal else { return }
        try JSONEncoder().encode(journal).write(to: directory.appendingPathComponent("restoration.json"), options: .atomic)
    }
}
