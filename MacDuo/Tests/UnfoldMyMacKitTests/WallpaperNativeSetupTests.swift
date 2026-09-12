import AppKit
import SwiftUI
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

/// Render native controls through AppKit; ImageRenderer substitutes placeholders for them.
@Test @MainActor func templateSetupNativeControlsRenderWithoutImageRendererPlaceholders() async throws {
    guard let path = ProcessInfo.processInfo.environment["UNFOLDMYMAC_WALLPAPER_ARTIFACTS"] else { return }
    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    UnfoldMyMacType.register()
    let suite = "native-setup-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let setup = WallpaperSetupController(preferences: UserDefaultsPreferencesStore(defaults: defaults))
    let templates = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false).templates
    for id in ["github-after-hours", "codex-mission-control"] {
        let template = try #require(templates.first { $0.id == id })
        setup.open(template, applyAfterSetup: true)
        let request = try #require(setup.request)
        let view = WallpaperTemplateSetupSheet(setup: setup, request: request)
            .environment(\.colorScheme, .dark).background(Color(hex: 0x16181D))
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 552, height: 720), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        window.setContentSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(150))
        window.setContentSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: path).appendingPathComponent(id + "-native-setup.png"))
        window.contentView = nil; window.close(); setup.cancel()
    }
}
