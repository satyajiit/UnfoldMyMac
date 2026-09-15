import Foundation

/// What a choice *is* on the wire: its descriptor, its options, and the menu picker the host builds from
/// them. Split from `WallpaperSettingsWire` only for size; the encoding contract is described there.

extension WallpaperSettingsWire {
    struct ChoiceDescriptor: Codable {
        var id: ChoiceID
        var provider: ChoiceProviderID
        var identifier: String
        var name: String?
        var localizedDescription: String
        var thumbnail: Thumbnail
        var isDownloaded: Bool
        var options: [WallpaperOption]
    }

    /// Real type: WallpaperTypes.WallpaperOptionEnum — the per-choice settings controls
    /// shown in the wallpaper header when the choice is selected. Cases: picker, color,
    /// toggle, group, button; payloads use the synthesized `_0` key. Only picker is
    /// modeled here.
    enum WallpaperOption: Codable {
        case picker(MenuPickerOption)

        private enum CodingKeys: String, CodingKey {
            case picker
        }

        private enum PayloadCodingKeys: String, CodingKey {
            case _0
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .picker(option):
                var nested = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .picker)
                try nested.encode(option, forKey: ._0)
            }
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let nested = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .picker)
            self = try .picker(nested.decode(MenuPickerOption.self, forKey: ._0))
        }
    }

    /// Real type: WallpaperTypes.MenuPickerOption — a labeled popup in the choice's
    /// settings header. The system stores the selected item id per choice and hands it
    /// back to the extension; item ids and their meaning are the provider's own.
    struct MenuPickerOption: Codable {
        var id: String
        var localizedLabel: String
        var defaultValueID: String
        var accessibilityIdentifier: String?
        var localizedInformativeText: String?
        var items: [MenuPickerItemEnum]
    }

    /// Real type: WallpaperTypes.MenuPickerItemEnum — cases: item, divider (payload `_0`).
    enum MenuPickerItemEnum: Codable {
        case item(MenuPickerItem)
        case divider(MenuPickerDivider)

        private enum CodingKeys: String, CodingKey {
            case item
            case divider
        }

        private enum PayloadCodingKeys: String, CodingKey {
            case _0
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .item(item):
                var nested = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .item)
                try nested.encode(item, forKey: ._0)
            case let .divider(divider):
                var nested = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .divider)
                try nested.encode(divider, forKey: ._0)
            }
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if container.contains(.item) {
                let nested = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .item)
                self = try .item(nested.decode(MenuPickerItem.self, forKey: ._0))
            } else {
                let nested = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .divider)
                self = try .divider(nested.decode(MenuPickerDivider.self, forKey: ._0))
            }
        }
    }

    /// Real type: WallpaperTypes.MenuPickerItem. The macOS 27 decoder requires
    /// `isDownloaded`; the macOS 26 decoder ignores the extra key, so it is always
    /// encoded (#29).
    struct MenuPickerItem: Codable {
        var id: String
        var localizedName: String
        var accessibilityIdentifier: String?
        var localizedInformativeText: String?
        var isDownloaded: Bool
    }

    struct MenuPickerDivider: Codable {
        var id: String
    }

    /// Encodes as a plain string (singleValueContainer)
    struct ChoiceProviderID: Codable {
        var rawValue: String

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.rawValue = try container.decode(String.self)
        }
    }
}
