import Foundation

/// How a choice looks in System Settings: its badge, its thumbnail, its buttons, and whether the user may
/// remove it. Split from `WallpaperSettingsWire` only for size; the encoding contract is described there.

extension WallpaperSettingsWire {
    /// Real type: WallpaperTypes.WallpaperDisposability, with cases none, removable and purgeable.
    enum Disposability: Codable {
        case none
        case removable
        case purgeable

        private enum CodingKeys: String, CodingKey {
            case none
            case removable
            case purgeable
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .none:
                _ = container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .none)
            case .removable:
                _ = container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .removable)
            case .purgeable:
                _ = container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .purgeable)
            }
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if container.contains(.none) { self = .none } else if container.contains(.removable) { self = .removable } else if container.contains(.purgeable) { self = .purgeable } else { self = .none }
        }
    }

    /// WallpaperSettingsItem.ContentBadge — cases: none, video, dynamic.
    enum ContentBadge: Codable {
        case none
        case video
        case dynamic

        private enum CodingKeys: String, CodingKey {
            case none
            case video
            case dynamic
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .none:
                _ = container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .none)
            case .video:
                _ = container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .video)
            case .dynamic:
                _ = container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .dynamic)
            }
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if container.contains(.none) { self = .none } else if container.contains(.video) { self = .video } else if container.contains(.dynamic) { self = .dynamic } else { self = .none }
        }
    }

    /// WallpaperThumbnail — enum with cases: image, solidColor, customButton, shuffleColors, shuffleImages, currentColorOption.
    /// shuffleImages renders the composite shuffle tile (stacked thumbnails + rotate badge).
    enum Thumbnail: Codable {
        case image(url: URL)
        case shuffleImages(urls: [URL])
        case customButton(CustomButton)

        private enum CodingKeys: String, CodingKey {
            case image
            case shuffleImages
            case customButton
        }

        private enum ImageCodingKeys: String, CodingKey {
            case url
        }

        private enum ShuffleImagesCodingKeys: String, CodingKey {
            case urls
        }

        /// Unlabeled associated values use `_0`, `_1`, etc. as keys in Swift's auto-synthesized Codable
        private enum CustomButtonCodingKeys: String, CodingKey {
            case _0
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .image(url):
                var nested = container.nestedContainer(keyedBy: ImageCodingKeys.self, forKey: .image)
                try nested.encode(url, forKey: .url)
            case let .shuffleImages(urls):
                var nested = container.nestedContainer(keyedBy: ShuffleImagesCodingKeys.self, forKey: .shuffleImages)
                try nested.encode(urls, forKey: .urls)
            case let .customButton(button):
                var nested = container.nestedContainer(keyedBy: CustomButtonCodingKeys.self, forKey: .customButton)
                try nested.encode(button, forKey: ._0)
            }
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if container.contains(.image) {
                let nested = try container.nestedContainer(keyedBy: ImageCodingKeys.self, forKey: .image)
                let url = try nested.decode(URL.self, forKey: .url)
                self = .image(url: url)
            } else if container.contains(.shuffleImages) {
                let nested = try container.nestedContainer(keyedBy: ShuffleImagesCodingKeys.self, forKey: .shuffleImages)
                let urls = try nested.decode([URL].self, forKey: .urls)
                self = .shuffleImages(urls: urls)
            } else if container.contains(.customButton) {
                let nested = try container.nestedContainer(keyedBy: CustomButtonCodingKeys.self, forKey: .customButton)
                let button = try nested.decode(CustomButton.self, forKey: ._0)
                self = .customButton(button)
            } else {
                self = .image(url: URL(fileURLWithPath: "/"))
            }
        }
    }

    /// WallpaperTypes.CustomButton — enum with cases: addPhotoButton, addColorButton, shuffleColorsButton
    enum CustomButton: Codable {
        case addPhotoButton
        case addColorButton
        case shuffleColorsButton

        private enum CodingKeys: String, CodingKey {
            case addPhotoButton
            case addColorButton
            case shuffleColorsButton
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .addPhotoButton:
                _ = container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .addPhotoButton)
            case .addColorButton:
                _ = container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .addColorButton)
            case .shuffleColorsButton:
                _ = container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .shuffleColorsButton)
            }
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if container.contains(.addPhotoButton) { self = .addPhotoButton } else if container.contains(.addColorButton) { self = .addColorButton } else if container.contains(.shuffleColorsButton) { self = .shuffleColorsButton } else { self = .addPhotoButton }
        }
    }
}
