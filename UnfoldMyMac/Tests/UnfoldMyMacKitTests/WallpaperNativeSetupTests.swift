import AppKit
import SwiftUI
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

/// Exercise the native category control and asynchronous permission/status updates in the same host.
@Test(.requiresWindowServer, .tags(.window), arguments: [ColorScheme.light, .dark],
      [WallpaperMicrophonePermission.undetermined, .denied, .authorized])
@MainActor func gardenSetupKeepsItsSizeAcrossCategoriesAndRepeatedEdits(scheme: ColorScheme, permission: WallpaperMicrophonePermission) async throws {
    let suite = "garden-sheet-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let audio = GardenTestAudio()
    let service = WallpaperInputService(audio: audio, makeSensor: { GardenTestLid() }, makeMotion: { GardenTestMotion() })
    let setup = WallpaperSetupController(preferences: UserDefaultsPreferencesStore(defaults: defaults), inputs: service)
    let templates = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false).templates
    let template = try #require(templates.first { $0.id == "hinge-garden" })
    service.setConsumer(UUID(), template: template.id, visible: true, animated: true)
    setup.open(template)
    let host = NSHostingView(rootView: WallpaperTemplateSetupSheet(setup: setup, request: try #require(setup.request))
        .environment(\.colorScheme, scheme))
    let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 640, height: 580), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
    window.contentView = host
    defer { window.contentView = nil; window.close(); setup.cancel(); service.stop() }
    host.layoutSubtreeIfNeeded()
    window.setContentSize(host.fittingSize)
    try await Task.sleep(for: .milliseconds(100))
    let originalSize = host.fittingSize
    let originalFrame = window.frame
    let categories = try #require(setupCategoryControl(in: host))
    #expect(categories.segmentCount == 3)
    #expect(originalSize.width == 640)
    let edits = [(0, false), (0, true), (1, false), (1, true), (2, false), (2, true), (0, false), (2, true)]
    for (category, enabled) in edits {
        categories.selectedSegment = category
        #expect(categories.sendAction(categories.action, to: categories.target))
        audio.permission = permission
        audio.missing = permission == .authorized
        setup.setDraft(.init(enabled: enabled, sensitivity: enabled ? 4 : 0.25), for: "microphone")
        setup.setDraft(.init(parallax: enabled, motionSensors: enabled, oneLiners: enabled,
                             lineInterval: enabled ? 120 : 15, blowToChange: enabled), for: "garden")
        audio.onDeviceChange?()
        try await Task.sleep(for: .milliseconds(50))
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize == originalSize)
        #expect(window.frame == originalFrame)
        #expect(permission == .undetermined || service.permission == permission)
        if permission == .denied {
            let name = "hinge-setup-\(category)-\(enabled ? "on" : "off")-\(scheme == .dark ? "dark" : "light")"
            try await saveSetupImage(host, name: name)
        }
    }
    // Preview edits remain reversible after navigating away from the edited pane.
    setup.cancel()
    #expect(service.gardenQuote == nil && !audio.isRunning)
    #expect(setup.configuration("garden", for: template.id).showsOneLiners == false)
}

@MainActor private func setupCategoryControl(in view: NSView) -> NSSegmentedControl? {
    if let control = view as? NSSegmentedControl { return control }
    for child in view.subviews {
        if let control = setupCategoryControl(in: child) { return control }
    }
    return nil
}

@MainActor private func saveSetupImage(_ host: NSView, name: String) async throws {
    guard let path = ProcessInfo.processInfo.environment["UNFOLDMYMAC_WALLPAPER_ARTIFACTS"] else { return }
    // Let AppKit's switch and slider animations settle before capturing their pixels.
    try await Task.sleep(for: .milliseconds(300))
    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: bitmap)
    let png = try #require(bitmap.representation(using: .png, properties: [:]))
    try png.write(to: URL(fileURLWithPath: path).appendingPathComponent(name + ".png"))
}

/// Render native controls through AppKit; ImageRenderer substitutes placeholders for them.
@Test(.requiresWindowServer, .tags(.window)) @MainActor func templateSetupNativeControlsRenderWithoutImageRendererPlaceholders() async throws {
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
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 640, height: 580), styleMask: [.borderless], backing: .buffered, defer: false)
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
