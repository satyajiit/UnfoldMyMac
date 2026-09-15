import AppKit
import Foundation
import UnfoldMyMacCore

/// Builds the group System Settings shows under Wallpaper, one item per bundled scene.
///
/// Thumbnails are the real thing: each scene is rendered offscreen at its cover pose through the same
/// `WallpaperCoverRenderer` the in-app gallery uses, so the tile in System Settings is the scene itself
/// rather than a stand-in. Renders are cached in the extension's container and reused until the template's
/// content key changes.
@MainActor enum WallpaperProviderSettings {
    /// Identifies our group among Apple's. Sorting next to the aerials group puts us near the top.
    private static let groupID = "com.unfoldmymac.wallpaper.scenes"
    private static let thumbnailSize = CGSize(width: 356, height: 356)

    /// The encoded `WallpaperSettingsViewModelsXPC` for the host, or nil if nothing could be offered.
    static func viewModels() -> AnyObject? {
        guard let model = model() else { return nil }
        return encodeViewModels(model)
    }

    /// What the host is offered, before it is archived. Separate from the encoding so the contents can be
    /// checked directly: once encoded, the payload is an opaque instance of a class with no accessors.
    static func model() -> WallpaperSettingsWire.SettingsViewModels? {
        let environment = WallpaperProviderEnvironment.shared
        let templates = environment.offeredTemplates
        guard !templates.isEmpty else {
            WallpaperProviderLog.fault("no templates to offer")
            return nil
        }
        let provider = Bundle.main.bundleIdentifier ?? "com.unfoldmymac.wallpaper.extension"
        var items: [WallpaperSettingsWire.SettingsItem] = []
        for (index, template) in templates.enumerated() {
            guard let thumbnail = thumbnailURL(for: template) else { continue }
            items.append(item(for: template, provider: provider, thumbnail: thumbnail, sortOrder: index))
        }
        guard !items.isEmpty else {
            WallpaperProviderLog.fault("every template failed to produce a thumbnail")
            return nil
        }
        let group = WallpaperSettingsWire.SettingsGroup(
            id: .init(id: groupID),
            items: items,
            localizedName: "\(AppIdentity.name) — Dynamic Wallpapers",
            disposability: .none,
            sortOrder: -100,
            // Sorting against the aerials group lands us beside Apple's own moving wallpapers.
            sortID: .init(id: "com.apple.wallpaper.aerials"),
            allChoiceID: nil,
            shouldHideItemLabels: false,
            contextMenu: nil,
            thumbnail: nil,
        )
        let viewModel = WallpaperSettingsWire.SettingsViewModel(groups: [group], refreshPolicy: .default, isModificationDisabled: false)
        // The same group serves both pickers. Since the Sonoma unified model the screen saver is simply the
        // wallpaper surface entering idle presentation, and that surface is what the lock screen shows, so
        // every scene we offer for the desktop is offered for the lock screen too.
        return .init(desktop: viewModel, screenSaver: viewModel)
    }

    private static func item(
        for template: WallpaperTemplate,
        provider: String,
        thumbnail: URL,
        sortOrder: Int,
    ) -> WallpaperSettingsWire.SettingsItem {
        let choiceID = WallpaperSettingsWire.ChoiceID(
            id: template.id,
            descriptor: .init(
                provider: .init(rawValue: provider),
                identifier: template.id,
                files: [],
                // The configuration blob is how the template id comes back to us on acquire.
                configuration: Data(template.id.utf8),
            ),
        )
        return .init(
            id: choiceID,
            localizedName: template.title,
            thumbnail: .image(url: thumbnail),
            choice: .init(
                id: choiceID,
                provider: .init(rawValue: provider),
                identifier: template.id,
                name: template.title,
                localizedDescription: template.metadata?.overview ?? "A live \(AppIdentity.name) scene.",
                thumbnail: .image(url: thumbnail),
                isDownloaded: true,
                options: [],
            ),
            contentBadge: .video,
            showInTopLevel: true,
            sortOrder: sortOrder,
            disposability: .none,
            contextMenu: nil,
        )
    }

    // MARK: - Thumbnails

    private static var thumbnailDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("SceneThumbnails", isDirectory: true)
    }

    /// A rendered cover for `template`, reused when one already exists for this content key.
    private static func thumbnailURL(for template: WallpaperTemplate) -> URL? {
        let directory = thumbnailDirectory
        let url = directory.appendingPathComponent("\(template.id)-\(WallpaperCoverStore.cacheKey(for: template)).png")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        do {
            let pipeline = try WallpaperProviderEnvironment.shared.makePipeline(templateID: template.id)
            let image = try WallpaperCoverRenderer.image(pipeline: pipeline, size: thumbnailSize)
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try png.write(to: url, options: .atomic)
            return url
        } catch {
            WallpaperProviderLog.fault("thumbnail failed for \(template.id): \(String(describing: error))")
            return nil
        }
    }

    // MARK: - Encoding

    /// Archives our Codable mirror and decodes it back as the private XPC class.
    ///
    /// Secure coding must be off: substituting a class on unarchive is exactly what it forbids. That is safe
    /// here because the archive is produced and consumed inside this function from values we just built, so
    /// there is no untrusted input — the decoded object goes straight back to WallpaperAgent.
    private static func encodeViewModels(_ models: WallpaperSettingsWire.SettingsViewModels) -> AnyObject? {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: ShimViewModelsXPC(value: models), requiringSecureCoding: false),
              let target = objc_getClass("WallpaperSettingsViewModelsXPC") as? AnyClass,
              let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else {
            WallpaperProviderLog.fault("could not archive settings view models")
            return nil
        }
        unarchiver.requiresSecureCoding = false
        unarchiver.decodingFailurePolicy = .setErrorAndReturn
        unarchiver.setClass(target, forClassName: "ShimViewModelsXPC")
        let decoded = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
        if let error = unarchiver.error { WallpaperProviderLog.fault("view model decode: \(String(describing: error))") }
        unarchiver.finishDecoding()
        return decoded as AnyObject?
    }
}
