import Foundation

extension WallpaperProviderLink {
    /// What the app knows about the provider right now.
    ///
    /// Every case answers two separate questions the app used to conflate: whether macOS is compositing
    /// our scene at all, and *where*. The desktop and the lock screen are different slots in the system's
    /// wallpaper store — `Desktop` and `Idle`, per display — and a provider can hold one without the
    /// other. Reading "some surface exists" as "the lock screen is ours" is how the app came to promise a
    /// lock screen it did not have.
    enum Status: Equatable {
        /// Nothing has been heard from the provider yet, and not enough time has passed to conclude it is
        /// absent. The app must not touch the system wallpaper in this state: if macOS is already showing
        /// our provider, replacing the desktop image would throw the user's own choice away, and at launch
        /// this is always the state we start in.
        case unknown
        /// No heartbeat, or one too old to trust: the extension is not rendering and the app must.
        case idle
        /// Rendering, with the scene it reports and whether the lock screen is one of the surfaces.
        case live(templateID: String?, onLockScreen: Bool)
        /// Holding surfaces, asked for motion, and presenting no frames. The wallpaper is on screen and
        /// frozen — which looks like a still to the user and like success to everything that only counts
        /// surfaces. Separate from `failed` because the scene *is* up; it simply is not moving.
        case stalled(templateID: String?)
        /// The extension ran and could not render. The reason is shown to the user, never swallowed.
        case failed(String)

        var isLive: Bool { if case .live = self { return true }; return false }
        /// Whether the scene is on the lock screen, or nil while that is still being established. Callers
        /// that have nothing to show for "not yet" use this rather than reading `isLive` as a no.
        var lockScreenState: Bool? {
            switch self {
            case .unknown: nil
            case .live(_, let onLockScreen): onLockScreen
            case .idle, .stalled, .failed: false
            }
        }
        /// Whether the app may change the system wallpaper. False until the question is settled, because
        /// the only irreversible mistake here is overwriting a choice that was ours to begin with, and
        /// false while the provider is stalled, because a stalled surface is still the system's wallpaper.
        var allowsSystemWallpaperChanges: Bool { self == .idle }
    }
}
