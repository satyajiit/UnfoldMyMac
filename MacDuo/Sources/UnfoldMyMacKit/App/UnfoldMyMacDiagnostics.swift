import AppKit
import SwiftUI
import UnfoldMyMacCore

@MainActor enum UnfoldMyMacDiagnostics {
    static func probe() -> Bool {
        let sensor = LidSensor(); print(sensor.diagnostic)
        return sensor.read() != nil
    }
    static func checkShader() -> Bool {
        do {
            _ = try FrostPipeline()
            _ = try CurtainsPipeline()
            for artwork in try LibraryAssets.artworks() { _ = try ArtRevealPipeline(artwork: artwork) }
            _ = try CurrentPipeline()
            _ = try PeekabooPipeline()
            print("Frost, Curtains, Current, Peekaboo, and Art Reveal shaders compiled; all catalog artwork textures loaded")
            return true
        }
        catch { print(error.localizedDescription); return false }
    }
}
