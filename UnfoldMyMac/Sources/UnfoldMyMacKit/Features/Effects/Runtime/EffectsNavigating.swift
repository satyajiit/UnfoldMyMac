/// Navigation the effects feature can request from the app shell; the shell owns the route.
@MainActor protocol EffectsNavigating: AnyObject {
    /// Brings the effects library forward, for example when a preview starts from the menu bar.
    func showEffectsLibrary()
}
