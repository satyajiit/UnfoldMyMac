import AppKit
import Observation
import UnfoldMyMacCore

/// Gallery covers resolved off the launch path (P17): memory, then the template folder's `cover.png`, then the disk
/// cache, then one offscreen render at a time with a yield between renders so the window and its events come first.
@MainActor @Observable final class WallpaperCoverStore {
    static let cacheVersion = "cover-v1"
    static let defaultDirectory = URL.cachesDirectory.appendingPathComponent(AppIdentity.bundleIdentifier + "/WallpaperCovers", isDirectory: true)
    private(set) var images: [String: NSImage] = [:]
    /// Offscreen renders performed so far; a warm cache keeps this at zero.
    @ObservationIgnored private(set) var rendered = 0
    @ObservationIgnored private let factory: WallpaperPipelineFactory?
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private var queue: [(template: WallpaperTemplate, assets: WallpaperAssetResolver)] = []
    @ObservationIgnored private var worker: Task<Void, Never>?
    @ObservationIgnored private var workerGeneration = 0

    init(factory: WallpaperPipelineFactory?, directory: URL = WallpaperCoverStore.defaultDirectory) {
        self.factory = factory; self.directory = directory
    }
    /// Stable for identical template content; any change to what the cover shows produces a new key.
    static func cacheKey(for template: WallpaperTemplate) -> String {
        var rendering = template
        rendering.metadata = nil
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return RecordStore.digest(((try? encoder.encode(rendering)) ?? Data()) + Data(cacheVersion.utf8))
    }
    func cacheURL(for template: WallpaperTemplate) -> URL { directory.appendingPathComponent(Self.cacheKey(for: template) + ".png") }

    /// Queues every template whose cover is not in memory; nothing is read or rendered before the caller returns.
    func request(_ templates: [WallpaperTemplate], assets: (String) -> WallpaperAssetResolver = { _ in .shared }) {
        for template in templates where images[template.id] == nil && !queue.contains(where: { $0.template.id == template.id }) {
            queue.append((template, assets(template.id)))
        }
        guard worker == nil, !queue.isEmpty else { return }
        workerGeneration &+= 1
        let generation = workerGeneration
        worker = Task { [weak self] in
            await self?.drain()
            if self?.workerGeneration == generation { self?.worker = nil }
        }
    }
    func invalidate(_ id: String) { images[id] = nil; queue.removeAll { $0.template.id == id } }
    func cancel() { workerGeneration &+= 1; worker?.cancel(); worker = nil; queue.removeAll() }

    private func drain() async {
        while !queue.isEmpty, !Task.isCancelled {
            await Task.yield()
            // Cancellation or invalidation can empty the queue across this suspension.
            guard !Task.isCancelled, !queue.isEmpty else { return }
            let (template, assets) = queue.removeFirst()
            guard images[template.id] == nil else { continue }
            if let url = assets.cover(for: template), let image = NSImage(contentsOf: url) { images[template.id] = image; continue }
            let cached = cacheURL(for: template)
            if let image = NSImage(contentsOf: cached) { images[template.id] = image; continue }
            guard let factory, let image = try? WallpaperCoverRenderer.image(pipeline: factory.make(template, assets: assets)) else { continue }
            rendered += 1
            images[template.id] = image
            try? write(image, to: cached)
        }
    }
    private func write(_ image: NSImage, to url: URL) throws {
        guard let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: url, options: .atomic)
    }
}
