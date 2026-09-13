/// Whether a discovered update should open its sheet now, later, or not at all.
public enum UpdatePromptDecision: Equatable, Sendable {
    case present
    /// Wait for the user to open the window themselves.
    case waitForWindow
    case ignore
}

/// The app keeps running with its window closed, so a discovery can arrive while someone is working
/// in another application. Pulling a window forward to announce a download is the behaviour people
/// complain about; the sidebar badge is the notification, and the sheet waits to be opened.
public enum UpdatePromptPolicy {
    public static func decide(trigger: UpdateTrigger, windowVisible: Bool,
                              lastSeen: AppVersion?, release: UpdateRelease) -> UpdatePromptDecision {
        // A click is always answered, even for a version already seen.
        if trigger == .manual { return .present }
        if lastSeen == release.version { return .ignore }
        return windowVisible ? .present : .waitForWindow
    }
}
