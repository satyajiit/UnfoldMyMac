import Foundation

/// When the host refreshes a choice and what its context menu offers. Split from `WallpaperSettingsWire`
/// only for size; the encoding contract is described there.

extension WallpaperSettingsWire {
    enum RefreshPolicy: Codable {
        case `default`

        private enum CodingKeys: String, CodingKey {
            case `default`
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .default:
                _ = container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .default)
            }
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if container.contains(.default) {
                self = .default
            } else {
                self = .default
            }
        }
    }

    /// Real type: WallpaperTypes.ContextMenu { items: [ContextMenuItem] }
    struct ContextMenu: Codable {
        var items: [ContextMenuItem]
    }

    /// Real type: WallpaperTypes.ContextMenuItem { id: ContextMenuItem.ID, localizedTitle: String, isDestructive: Bool }
    struct ContextMenuItem: Codable {
        var id: ContextMenuItemID
        var localizedTitle: String
        var isDestructive: Bool
    }

    struct ContextMenuItemID: Codable {
        var id: String
    }

    enum EmptyCodingKeys: CodingKey {}
}
