import SwiftUI

@MainActor enum BrandAssets {
    /// The full 1254-pixel logo; decoded lazily and only where that size is needed.
    static let logo: NSImage? = BundleResources.brandLogo.flatMap(NSImage.init(contentsOf:))
    /// The 256-pixel copy `script/make_icon.sh` derives from the logo, for the sidebar and menus.
    static let mark: NSImage? = BundleResources.brandMark.flatMap(NSImage.init(contentsOf:))

    /// A packaged app carries its `.icns`; a build run from the package directory sets the Dock tile from the logo,
    /// after launch so the decode never sits between `applicationDidFinishLaunching` and the window.
    static func installDockIconIfUnbundled() {
        guard Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") == nil else { return }
        Task(priority: .utility) { @MainActor in if let logo { NSApp.applicationIconImage = logo } }
    }
}
