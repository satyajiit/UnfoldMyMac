import AppKit
import UnfoldMyMacCore

/// Supplies the system wallpaper sampler with scene colors, outside the animation loop.
/// A durable journal retains originals across Apply, Spaces, display changes and restart; a still rendered
/// on an earlier launch is reused, and each display keeps only its newest few companions on disk.
@MainActor final class WallpaperSystemBackdrop {
    private struct Record: Codable {
        let display: String
        let original: WallpaperDesktopImage
        let installed: WallpaperDesktopImage
        var templateID: String? = nil
        var imageURL: URL? = nil
        var width: Double? = nil
        var height: Double? = nil
        var installedAt: Date? = nil
        var backdropKey: String? = nil
        func matches(_ pipeline: WallpaperPipeline, display: String, original: WallpaperDesktopImage, size: CGSize) -> Bool {
            self.display == display && templateID == pipeline.template.id && imageURL == pipeline.imageURL
                && self.original == original && width == size.width && height == size.height && backdropKey == pipeline.backdropKey
        }
    }
    private struct Journal: Codable {
        var version = 1
        var records: [String: Record] = [:]
    }
    static let retainedRecordsPerDisplay = 6
    private let access: any WallpaperDesktopImageAccess
    private let directory: URL
    private var journal: Journal?
    private struct Applied { let templateID: String; let backdropKey: String; let imageURL: URL?; let size: CGSize; let url: URL; let previous: URL }
    /// Identity only: holding the pipeline itself would keep its GPU resources alive after a template switch.
    private var applied: [String: Applied] = [:]
    /// Stills rendered so far; a journalled still is reused instead.
    private(set) var renders = 0

    init(access: any WallpaperDesktopImageAccess = SystemWallpaperDesktopImages(),
         directory: URL = WallpaperPaths.root.appendingPathComponent("SystemBackdrop", isDirectory: true)) {
        self.access = access; self.directory = directory
    }
    func apply(_ pipeline: WallpaperPipeline) throws {
        try loadJournal()
        var changed = false
        for display in access.screens {
            let screen = WallpaperBackdropScreen(id: display.id, size: pipeline.surface.maximumDimension == nil ? display.nativeSize ?? display.size : display.size)
            guard let current = access.current(on: screen.id) else {
                throw WallpaperError.unavailable("The current system wallpaper could not be saved for restoration.")
            }
            if let cached = applied[screen.id], cached.templateID == pipeline.template.id, cached.imageURL == pipeline.imageURL,
               cached.size == screen.size, cached.url == current.url, cached.backdropKey == pipeline.backdropKey { continue }
            let previous = journal?.records[current.url.path]
            let original = previous.flatMap { $0.display == screen.id ? $0.original : nil } ?? current
            var record = try journal?.records.values.first { $0.matches(pipeline, display: screen.id, original: original, size: screen.size)
                && FileManager.default.fileExists(atPath: $0.installed.url.path) } ?? render(pipeline, for: screen, original: original)
            record.installedAt = .now
            journal?.records[record.installed.url.path] = record
            // Save the restoration record BEFORE changing any system preference.
            try saveJournal()
            try access.set(record.installed, on: screen.id)
            applied[screen.id] = Applied(templateID: pipeline.template.id, backdropKey: pipeline.backdropKey, imageURL: pipeline.imageURL, size: screen.size, url: record.installed.url, previous: current.url)
            changed = true
        }
        if changed, prune(keeping: Set(access.screens.compactMap { access.current(on: $0.id)?.url.path })) { try saveJournal() }
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
        // Records survive Stop: a disconnected display or another Space can still show a companion.
    }
    private func render(_ pipeline: WallpaperPipeline, for screen: WallpaperBackdropScreen, original: WallpaperDesktopImage) throws -> Record {
        let image = try WallpaperCoverRenderer.image(pipeline: pipeline, size: screen.size)
        renders += 1
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { throw WallpaperError.unavailable("The desktop still could not be encoded.") }
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        var signature = png
        signature.append(try encoder.encode(original)); signature.append(Data(screen.id.utf8))
        let url = directory.appendingPathComponent(RecordStore.digest(signature) + ".png")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) { try png.write(to: url, options: .atomic) }
        let installed = WallpaperDesktopImage(url: url, options: [.imageScaling: NSImageScaling.scaleAxesIndependently.rawValue, .allowClipping: true])
        return Record(display: screen.id, original: original, installed: installed, templateID: pipeline.template.id,
                      imageURL: pipeline.imageURL, width: screen.size.width, height: screen.size.height, backdropKey: pipeline.backdropKey)
    }
    /// Keeps the newest companions per display and whatever any screen shows right now; the rest go with their files.
    private func prune(keeping current: Set<String>) -> Bool {
        guard var journal else { return false }
        var removed = false
        for display in Set(journal.records.values.map(\.display)) {
            let mine = journal.records.filter { $0.value.display == display }
                .sorted { ($0.value.installedAt ?? .distantPast) > ($1.value.installedAt ?? .distantPast) }
            for (path, _) in mine.dropFirst(Self.retainedRecordsPerDisplay) where !current.contains(path) {
                journal.records[path] = nil; removed = true
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        self.journal = journal
        return removed
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
