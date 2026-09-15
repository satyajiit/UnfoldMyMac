import Foundation

/// The wire shapes `WallpaperSettingsViewModelsXPC` decodes from.
///
/// The host does not accept a hand-built object: it decodes a keyed archive. We therefore encode these
/// Codable mirrors of Apple's `WallpaperTypes` values and, on unarchive, substitute the private class for
/// our shim (see `WallpaperProviderSettings.encodeViewModels`). Field names and enum payload shapes are the
/// contract — Apple's synthesized `Codable` uses a nested empty container per case and `_0` for payloads —
/// so nothing here may be renamed to read more nicely.
///
/// Namespaced because several of these names (`ContentBadge`, `ContextMenu`, `Thumbnail`) already mean
/// something else in the app's design system.
enum WallpaperSettingsWire {
    struct SettingsViewModels: Codable {
        var desktop: SettingsViewModel?
        var screenSaver: SettingsViewModel?
    }

    struct SettingsViewModel: Codable {
        var groups: [SettingsGroup]
        var refreshPolicy: RefreshPolicy
        var isModificationDisabled: Bool
    }

    struct SettingsGroup: Codable {
        var id: GroupID
        var items: [SettingsItem]
        var localizedName: String
        var disposability: Disposability
        var sortOrder: Int
        var sortID: GroupSortID?
        var allChoiceID: ChoiceID?
        var shouldHideItemLabels: Bool?
        var contextMenu: ContextMenu?
        var thumbnail: Data?
    }

    /// ID types use a keyed container with an "id" property.
    struct GroupID: Codable {
        var id: String
    }

    struct GroupSortID: Codable {
        var id: String
    }

    struct ChoiceID: Codable {
        var id: String
        var descriptor: ChoiceIDDescriptor
    }

    /// Nested descriptor inside WallpaperChoiceID — contains provider info
    struct ChoiceIDDescriptor: Codable {
        var provider: ChoiceProviderID
        var identifier: String
        var files: [URL]
        var configuration: Data
    }

    struct SettingsItem: Codable {
        var id: ChoiceID
        var localizedName: String
        var thumbnail: Thumbnail
        var choice: ChoiceDescriptor
        var contentBadge: ContentBadge
        var showInTopLevel: Bool
        var sortOrder: Int
        var disposability: Disposability
        var contextMenu: ContextMenu?
    }
}


@objc(ShimViewModelsXPC)
final class ShimViewModelsXPC: NSObject, NSSecureCoding {
    static let supportsSecureCoding = true
    let value: WallpaperSettingsWire.SettingsViewModels

    init(value: WallpaperSettingsWire.SettingsViewModels) {
        self.value = value
        super.init()
    }

    required init?(coder _: NSCoder) {
        fatalError("decode not needed")
    }

    func encode(with coder: NSCoder) {
        guard let archiver = coder as? NSKeyedArchiver else {
            WallpaperProviderLog.fault("  [ShimXPC] encode error: coder is not NSKeyedArchiver")
            return
        }
        do {
            try archiver.encodeEncodable(value, forKey: "WallpaperSettingsViewModels")
        } catch {
            WallpaperProviderLog.fault("  [ShimXPC] encode error: \(error)")
        }
    }
}
