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
}
