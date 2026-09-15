import AppKit
import ImageIO
import UniformTypeIdentifiers
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
    /// A still younger than this is never pruned, whatever the count says. `NSWorkspace` reports the
    /// wallpaper of the current Space only, so a companion another Space is showing right now looks
    /// unused from here — deleting it would blank that Space's desktop until the user switched back.
    static let defaultRetentionWindow: TimeInterval = 24 * 60 * 60
    private let access: any WallpaperDesktopImageAccess
    private let directory: URL
    private let retentionWindow: TimeInterval
    private var journal: Journal?
    private struct Applied { let templateID: String; let backdropKey: String; let imageURL: URL?; let size: CGSize; let url: URL; let previous: URL }
    /// Identity only: holding the pipeline itself would keep its GPU resources alive after a template switch.
    private var applied: [String: Applied] = [:]
    /// Stills rendered so far; a journalled still is reused instead.
    private(set) var renders = 0

    init(access: any WallpaperDesktopImageAccess = SystemWallpaperDesktopImages(),
         directory: URL = WallpaperPaths.root.appendingPathComponent("SystemBackdrop", isDirectory: true),
         retentionWindow: TimeInterval = WallpaperSystemBackdrop.defaultRetentionWindow) {
        self.access = access; self.directory = directory; self.retentionWindow = retentionWindow
    }
    func apply(_ pipeline: WallpaperPipeline) throws {
        try loadJournal()
        var changed = try retireSecondaryScreens()
        for display in access.screens where display.isPrimary {
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
    /// Hands back every display the app is no longer responsible for.
    ///
    /// The scene used to be installed on all of them. A build that has since scoped itself to the primary
    /// display would otherwise leave its still frozen on the others forever — the user's own wallpaper
    /// replaced by a picture of a scene that stopped being drawn. The journal holds each original, so this
    /// is exact: only a screen currently showing something this app installed is touched at all.
    private func retireSecondaryScreens() throws -> Bool {
        var changed = false
        for screen in access.screens where !screen.isPrimary {
            guard let current = access.current(on: screen.id), let record = journal?.records[current.url.path],
                  record.display == screen.id else { continue }
            try access.set(record.original, on: screen.id)
            applied[screen.id] = nil
            changed = true
        }
        return changed
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
        // The GPU pass stays on the main actor because the pipeline is main-actor isolated, but the
        // encode no longer does two full rasters on the way out.
        let size = MetalSurfaceRenderer<WallpaperPipeline>.drawableSize(points: screen.size, scale: 1, cap: pipeline.surface.maximumDimension)
        let rendered = try OffscreenRenderer.render(pipeline, frame: WallpaperFrame(pose: pipeline.template.coverPose),
                                                    width: Int(size.width), height: Int(size.height))
        renders += 1
        let png = try Self.png(from: try OffscreenRenderer.cgImage(rendered))
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
            for (path, record) in mine.dropFirst(Self.retainedRecordsPerDisplay) where !current.contains(path) {
                guard Date.now.timeIntervalSince(record.installedAt ?? .distantPast) > retentionWindow else { continue }
                journal.records[path] = nil; removed = true
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        self.journal = journal
        return removed
    }
    /// PNG straight from the CGImage. The old route went `NSImage` → `tiffRepresentation` →
    /// `NSBitmapImageRep` → PNG, which re-encoded the full raster twice: at desktop resolution that was
    /// long enough on the main actor to drop frames from the very scene the still was made from.
    private static func png(from image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw WallpaperError.unavailable("The desktop still could not be encoded.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw WallpaperError.unavailable("The desktop still could not be encoded.")
        }
        return data as Data
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
