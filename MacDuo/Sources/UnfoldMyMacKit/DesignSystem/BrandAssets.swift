import SwiftUI

@MainActor enum BrandAssets {
    static let logo: NSImage? = BundleResources.brandLogo.flatMap(NSImage.init(contentsOf:))
}
