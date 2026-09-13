/// Public product identity, independent of persisted IDs and internal module names.
public enum AppIdentity {
    public static let name = "UnfoldMyMac"
    public static let bundleIdentifier = "com.unfoldmymac"

    /// Public destinations the app links to. Stored as strings so this type stays free of
    /// force-unwrapped URLs; `AppIdentityTests` proves each one parses and points where it claims.
    public static let website = "https://unfoldmymac.com"
    public static let repository = "https://github.com/satyajiit/UnfoldMyMac"
    public static let contributing = "https://github.com/satyajiit/UnfoldMyMac/blob/main/CONTRIBUTING.md"
    public static let newIssue = "https://github.com/satyajiit/UnfoldMyMac/issues/new/choose"

    /// The Apple Developer team that signs every release. The updater refuses to install a build
    /// signed by anyone else, so this constant is a security boundary rather than a label.
    public static let teamIdentifier = "WW382UC8JD"

    /// `owner/name`, derived from `repository` so a fork that edits one link cannot leave the
    /// updater pointed at the original project.
    public static var repositorySlug: String {
        String(repository.dropFirst("https://github.com/".count))
    }
    public static var latestReleaseAPI: String { "https://api.github.com/repos/\(repositorySlug)/releases/latest" }
    public static var latestReleasePage: String { repository + "/releases/latest" }
    /// The release manifest, at the permanent redirect GitHub keeps pointed at the newest release.
    /// Reading it costs no API quota, which matters because the wallpaper connector already spends
    /// the unauthenticated allowance and that allowance is counted per address, not per user.
    public static var latestReleaseManifest: String { repository + "/releases/latest/download/release.json" }
}
