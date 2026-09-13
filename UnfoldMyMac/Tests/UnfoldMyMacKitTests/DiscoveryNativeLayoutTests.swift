import AppKit
import SwiftUI
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

/// Renders the actual native galleries, details, and inspector with isolated preferences.
@Test(.requiresGPU, .requiresWindowServer, .tags(.gpu, .window), .serialized, arguments: [ColorScheme.light, .dark])
@MainActor func discoveryNativeLayoutsAndListSwitch(scheme: ColorScheme) async throws {
    _ = NSApplication.shared
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let suite = "discovery-review-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
    let model = WallpaperModel(preferences: UserDefaultsPreferencesStore(defaults: defaults), environment: FakeSystemEnvironment(), displays: FakeDisplay(),
                               surfaces: DesktopSurfaceRegistry(), gpu: try TestGPU.context(), coverDirectory: directory)
    let registry = EffectRegistry.builtIn()
    let session = EffectSession(registry: registry, host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: { FakeCapture() })
    let effects = makeModel(registry: registry, session: session)
    let shell = AppShellModel(effects: effects, wallpaper: model)
    model.start(); shell.windowDidShow()
    defer { model.shutdown(); effects.shutdown() }
    try await settle { model.thumbnails.count >= bundledTemplateCount() }
    let covers = CoverImageStore()
    UnfoldMyMacType.register()
    let view = UnfoldMyMacView(shell: shell, effects: effects, wallpaper: model)
        .environment(\.colorScheme, scheme).environment(\.coverImages, covers).defaultAppStorage(defaults)
    let host = NSHostingView(rootView: view)
    let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1120, height: 780),
                          styleMask: [.titled, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.titleVisibility = .hidden; window.toolbarStyle = .unifiedCompact
    window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
    window.contentView = host
    NSApplication.shared.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    defer { window.contentView = nil; window.close() }
    for route in AppRoute.features {
        shell.show(route)
        for width in [1120.0, 900.0] {
            window.setContentSize(NSSize(width: width, height: 780))
            try await Task.sleep(for: .milliseconds(300))
            host.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            #expect(host.fittingSize.width <= width + 1, "Navigation fits the supported window width")
            try saveDiscoveryImage(host, name: "\(route.rawValue)-\(Int(width))-\(scheme)")
        }
        if route == .wallpaper {
            let control = try #require(discoverySegment(in: host))
            #expect(control.segmentCount == 2)
            control.selectedSegment = 1
            #expect(control.sendAction(control.action, to: control.target))
            try await Task.sleep(for: .milliseconds(150))
            #expect(defaults.bool(forKey: "unfoldmymac.discovery.list"))
            try saveDiscoveryImage(host, name: "wallpaper-list-\(scheme)")
            control.selectedSegment = 0; _ = control.sendAction(control.action, to: control.target)
        }
    }
    for id in ["hinge-garden", "claude-current"] {
        let template = try #require(model.catalog.template(id))
        let detail = NavigationStack { WallpaperDetailPage(model: model, template: template) }
            .environment(\.colorScheme, scheme).environment(\.coverImages, covers)
        try await captureDiscoveryView(detail, size: CGSize(width: 840, height: 1000), name: "detail-\(id)-\(scheme)",
                                       styleMask: [.titled, .resizable, .fullSizeContentView])
        #expect(!model.enabled && model.previewFPS == 0, "Opening details leaves the desktop and live inputs unchanged")
    }
    let inspector = EffectInspector(model: effects, preview: { _ in }).environment(\.colorScheme, scheme)
    try await captureDiscoveryView(inspector, size: CGSize(width: 640, height: 620), name: "effect-inspector-\(scheme)")
}

@MainActor private func discoverySegment(in view: NSView) -> NSSegmentedControl? {
    if let control = view as? NSSegmentedControl { return control }
    for child in view.subviews { if let control = discoverySegment(in: child) { return control } }
    return nil
}

@MainActor private func captureDiscoveryView(_ view: some View, size: CGSize, name: String, styleMask: NSWindow.StyleMask = [.borderless]) async throws {
    let host = NSHostingView(rootView: view)
    let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: styleMask, backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    if styleMask.contains(.titled) {
        window.titleVisibility = .hidden; window.toolbarStyle = .unifiedCompact
        window.orderFront(nil)
    }
    defer { window.contentView = nil; window.close() }
    try await Task.sleep(for: .milliseconds(250))
    host.layoutSubtreeIfNeeded()
    #expect(host.bounds.width == size.width, "Detail content uses the proposed window width")
    try saveDiscoveryImage(host, name: name)
    guard styleMask.contains(.titled), ProcessInfo.processInfo.environment["UNFOLDMYMAC_DISCOVERY_ARTIFACTS"] != nil else { return }
    // Include the collapsed toolbar in the optional visual review artifacts.
    var remaining = host.subviews
    while let child = remaining.popLast() {
        if let scroll = child as? NSScrollView, let document = scroll.documentView,
           document.frame.height > scroll.contentSize.height {
            scroll.contentView.scroll(to: NSPoint(x: 0, y: 360))
            scroll.reflectScrolledClipView(scroll.contentView)
            try await Task.sleep(for: .milliseconds(250))
            host.layoutSubtreeIfNeeded()
            try saveDiscoveryImage(host, name: name + "-scrolled")
            break
        }
        remaining.append(contentsOf: child.subviews)
    }
}

@MainActor private func saveDiscoveryImage(_ host: NSView, name: String) throws {
    guard let path = ProcessInfo.processInfo.environment["UNFOLDMYMAC_DISCOVERY_ARTIFACTS"] else { return }
    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    if let window = host.window, window.styleMask.contains(.titled) {
        // Split-view content is hosted in sibling AppKit surfaces, outside the root's bitmap cache.
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), path + "/" + name + ".png"]
        try capture.run(); capture.waitUntilExit()
        #expect(capture.terminationStatus == 0)
        return
    }
    let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: bitmap)
    let png = try #require(bitmap.representation(using: .png, properties: [:]))
    try png.write(to: URL(fileURLWithPath: path).appendingPathComponent(name + ".png"))
}
