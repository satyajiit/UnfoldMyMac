import SwiftUI
import UnfoldMyMacCore

/// Says where this scene is actually being shown, and offers the one control that changes it.
///
/// macOS 26 keeps **two** wallpaper selections per display, not one: `Desktop` and `Idle` in the system's
/// wallpaper store. A provider chosen as the desktop wallpaper fills only the first. The lock screen and
/// the screen saver are the same `Idle` slot, chosen in a different System Settings pane, and until this
/// scene is picked there too the lock screen paints an exported still of whatever is — which is what makes
/// a live wallpaper look frozen the moment the Mac locks.
///
/// So the card reports two facts rather than one: whether macOS is compositing our scene at all, and
/// whether the lock screen is one of the places it does. Selecting a wallpaper provider belongs to the
/// user and macOS offers apps no way to do it for them, so the button opens the pane that holds the
/// setting rather than writing the system's wallpaper state behind its back.
struct WallpaperLockScreenCard: View {
    let status: WallpaperProviderLink.Status
    let applied: Bool
    @Palette private var palette
    private var copy: Copy { Copy(status: status, applied: applied) }

    var body: some View {
        ContentCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: copy.symbol).foregroundStyle(tint).frame(width: 22)
                    Text(copy.title).font(UnfoldMyMacType.title3)
                }
                Text(copy.detail).font(UnfoldMyMacType.callout).foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let pane = copy.pane {
                    Button { WallpaperProviderLink.openSystemSettings(pane) } label: {
                        Label(copy.buttonTitle, systemImage: "arrow.up.forward.app")
                    }
                    .modifier(UnfoldMyMacButtonStyle())
                    .accessibilityIdentifier("wallpaper.lockScreen.settings")
                }
            }
        }
        .accessibilityIdentifier("wallpaper.lockScreen")
    }

    private var tint: Color {
        switch status {
        case .live(_, onLockScreen: true): palette.accent
        case .live(_, onLockScreen: false): palette.secondary
        case .failed, .stalled: .orange
        case .idle, .unknown: palette.secondary
        }
    }
}
