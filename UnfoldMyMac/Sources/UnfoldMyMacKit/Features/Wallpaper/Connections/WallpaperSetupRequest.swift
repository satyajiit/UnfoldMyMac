import Foundation
import Observation
import UnfoldMyMacCore

struct WallpaperSetupRequest: Identifiable {
    let id = UUID()
    let template: WallpaperTemplate
    let applyAfterSetup: Bool
}
