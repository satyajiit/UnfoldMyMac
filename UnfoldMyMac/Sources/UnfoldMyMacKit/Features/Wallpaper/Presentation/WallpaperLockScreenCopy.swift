import Foundation
import UnfoldMyMacCore

extension WallpaperLockScreenCard {
    /// What the card says, apart from how it looks. Separated from the view so the part that matters can
    /// be checked without rendering: that the app never claims a lock screen it does not have, never sends
    /// the user off to fix something before it knows there is anything wrong, and points at the pane that
    /// actually holds the setting being described.
    struct Copy: Equatable {
        let symbol: String
        let title: String
        let detail: String
        /// The System Settings pane this card's button opens, or nil when there is nothing to change.
        let pane: WallpaperProviderLink.SettingsPane?
        var buttonTitle: String {
            switch pane {
            case .screenSaver: "Open Screen Saver Settings"
            case .wallpaper: "Open Wallpaper Settings"
            case nil: ""
            }
        }
        private static let group = "“\(AppIdentity.name) — Dynamic Wallpapers”"

        init(status: WallpaperProviderLink.Status, applied: Bool) {
            switch status {
            case .live(_, onLockScreen: true):
                symbol = "lock.display"
                title = "On your desktop and lock screen"
                detail = "macOS is drawing this scene itself, on the desktop and on the lock screen. "
                    + "\(AppIdentity.name) keeps feeding it live data while the app is running; with the app closed the scene keeps moving on its own."
                pane = nil
            case .live(_, onLockScreen: false):
                symbol = "desktopcomputer"
                title = "On your desktop · not the lock screen yet"
                // The correction that matters. macOS keeps two selections per display — Desktop and Idle
                // — and choosing a wallpaper fills only the first. The lock screen keeps showing an
                // exported still of whatever is in the second until the user picks this scene there too.
                detail = "macOS is drawing this scene on your desktop. The lock screen and the screen saver are a separate "
                    + "choice, so it is still showing whatever you picked there. Choose this scene under \(Self.group) "
                    + "in Screen Saver settings and the lock screen becomes live too."
                pane = .screenSaver
            case .stalled:
                symbol = "pause.rectangle"
                title = "On screen, but not moving"
                detail = "macOS is showing this scene and no frames are reaching the screen, so it looks like a still image. "
                    + "Quitting and reopening \(AppIdentity.name) rebuilds the provider; if it keeps happening, this is worth reporting."
                pane = nil
            case .failed(let reason):
                symbol = "exclamationmark.triangle"
                title = "Lock screen unavailable"
                detail = "The \(AppIdentity.name) wallpaper provider could not render, so the desktop is being drawn by the app "
                    + "instead and the lock screen will show your previous wallpaper. \(reason)"
                pane = .wallpaper
            case .unknown:
                symbol = "clock.arrow.circlepath"
                title = "Checking the lock screen…"
                detail = "Asking macOS whether it is showing this scene itself."
                // Sending the user to System Settings to fix something that may not be wrong is worse
                // than a moment of saying nothing.
                pane = nil
            case .idle:
                symbol = "desktopcomputer"
                title = "Desktop only"
                detail = applied
                    ? "This scene is drawn by \(AppIdentity.name) in a desktop window, which the lock screen cannot see. "
                        + "Choose it under \(Self.group) in Wallpaper settings to hand the desktop to macOS, then in Screen Saver settings to reach the lock screen."
                    : "Choosing this scene under \(Self.group) in Wallpaper settings puts it on your desktop. "
                        + "The lock screen and the screen saver are a second choice, made under the same name in Screen Saver settings."
                pane = .wallpaper
            }
        }
    }
}
