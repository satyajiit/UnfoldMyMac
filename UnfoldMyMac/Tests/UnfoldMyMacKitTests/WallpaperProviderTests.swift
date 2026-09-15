import AppKit
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

/// The extension's side: the requests the host sends, the surfaces they map to, and the settings payload
/// System Settings decodes. The app's side is in `WallpaperProviderLinkTests`.

@Test func creationRequestsAreReadByLabelAndDegenerateGeometryIsRefused() {
    // The host's payload types are private Swift structs read reflectively, so the parser is exercised
    // against the same shape rather than against the framework.
    struct Destination { let size: CGSize; let scaleFactor: CGFloat; let directDisplayID: UInt32? }
    struct Descriptor { let configuration: Data? }
    struct Request { let destination: Destination; let descriptor: Descriptor; let isPreview: Bool }
    struct Boxed { let rawValue: Request }

    let parsed = WallpaperProviderRequest(Boxed(rawValue: Request(
        destination: Destination(size: CGSize(width: 3456, height: 2234), scaleFactor: 2, directDisplayID: 7),
        descriptor: Descriptor(configuration: Data("hinge-garden".utf8)), isPreview: true)))
    #expect(parsed.size == CGSize(width: 3456, height: 2234))
    #expect(parsed.scale == 2 && parsed.displayID == 7 && parsed.isPreview)
    #expect(parsed.choice == "hinge-garden")

    let degenerate = WallpaperProviderRequest(Boxed(rawValue: Request(
        destination: Destination(size: CGSize(width: 0, height: CGFloat.nan), scaleFactor: 0, directDisplayID: nil),
        descriptor: Descriptor(configuration: nil), isPreview: false)))
    #expect(degenerate.size.width > 0 && degenerate.size.height > 0 && degenerate.scale >= 1,
            "A size that would divide through the render path never reaches it")
    #expect(degenerate.displayID == nil && degenerate.choice == nil)
}

@Test func everyHostedSurfaceGetsItsOwnKeyBecauseAContextCanOnlyBeHostedOnce() {
    struct Destination { let size: CGSize; let scaleFactor: CGFloat; let directDisplayID: UInt32? }
    struct Request { let destination: Destination; let isPreview: Bool; let presentationMode: String? }
    func request(display: UInt32?, preview: Bool, mode: String?) -> WallpaperProviderRequest {
        WallpaperProviderRequest(Request(destination: Destination(size: CGSize(width: 100, height: 100), scaleFactor: 1, directDisplayID: display),
                                         isPreview: preview, presentationMode: mode))
    }
    let keys = [request(display: 1, preview: false, mode: "default"), request(display: 1, preview: true, mode: "default"),
                request(display: 2, preview: false, mode: "default"), request(display: 1, preview: false, mode: "locked")]
        .map(\.destinationKey)
    #expect(Set(keys).count == keys.count, "A CAContext lives in one CALayerHost at a time; every destination needs its own")

    // Without a presentation mode the desktop and the lock screen collapse onto one key. The store must
    // then never reuse a context across them: one CAContext in two CALayerHosts is live in one and frozen
    // on its last composited frame in the other, which is precisely a static lock screen.
    let blind = request(display: 1, preview: false, mode: nil)
    #expect(blind.destinationKey == request(display: 1, preview: false, mode: "locked").destinationKey.replacingOccurrences(of: "lockScreen", with: "desktop"))
    #expect(!blind.identifiesDestination, "A key that cannot separate them must not be trusted to reuse a context")
    #expect(request(display: 1, preview: false, mode: "locked").identifiesDestination)
}

@Test @MainActor func theProviderOffersEveryBundledSceneToBothWallpaperSlots() throws {
    // The desktop and the lock screen are filled from the same list, which is what makes every dynamic
    // wallpaper eligible for the lock screen without a second choice.
    let offered = WallpaperProviderEnvironment.shared.offeredTemplates
    let bundled = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false).templates
    #expect(offered.count == bundled.count && !offered.isEmpty)
    #expect(Set(offered.map(\.id)) == Set(bundled.map(\.id)))
    for id in offered.map(\.id) { #expect(WallpaperProviderEnvironment.shared.template(id) != nil) }
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func readoutsRenderInTheExtensionAndRedrawOnlyWhenAValueChanges() throws {
    // The readouts are most of what these scenes say. In the extension there is no window to drive an
    // NSHostingView, so they are rendered explicitly — and re-rendered only when a displayed value moves,
    // because every sample carries a new timestamp whether or not anything it reports has changed.
    let templates = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false).templates
    let withLayers = try #require(templates.first { !$0.layers.isEmpty })
    let layers = try #require(WallpaperProviderLayers(template: withLayers, styleSheet: .standard,
                                                      size: CGSize(width: 640, height: 400), scale: 2))
    #expect(layers.layer.contents != nil, "A scene with readouts must have drawn them before it is hosted")

    // `contents` identity says whether a new image was produced; `===` is kept out of the #expect macro
    // because reabstracting it there crashes the 6.3 compiler.
    func contents() -> AnyObject? { layers.layer.contents as AnyObject? }
    func same(_ a: AnyObject?, _ b: AnyObject?) -> Bool { a === b }
    let first = contents()
    var snapshot = WallpaperSnapshot()
    snapshot.sources["mac"] = WallpaperDataSample(timestamp: .now, numbers: ["mac.cpu": 42], text: ["mac.status": "BUSY."])
    layers.update(snapshot: snapshot, animated: true)
    let afterData = contents()
    #expect(!same(afterData, first), "New values must reach the screen")

    // Same values, later sample: nothing the user can see has changed.
    snapshot.sources["mac"] = WallpaperDataSample(timestamp: .now.addingTimeInterval(1), numbers: ["mac.cpu": 42], text: ["mac.status": "BUSY."])
    layers.update(snapshot: snapshot, animated: true)
    #expect(same(contents(), afterData), "A fresh timestamp alone must not cost a full-resolution render")

    snapshot.sources["mac"] = WallpaperDataSample(timestamp: .now, numbers: ["mac.cpu": 43], text: ["mac.status": "BUSY."])
    layers.update(snapshot: snapshot, animated: true)
    #expect(!same(contents(), afterData), "A changed value must redraw")

    // A scene with no readouts builds no layer at all rather than an empty one over the Metal surface.
    if let plain = templates.first(where: { $0.layers.isEmpty }) {
        #expect(WallpaperProviderLayers(template: plain, styleSheet: .standard, size: CGSize(width: 640, height: 400), scale: 2) == nil)
    }
}

@Test @MainActor func onlyAStateThatMeansNobodyIsLookingPausesTheScene() {
    // The lock screen and the screen saver are surfaces the user is looking at; pausing there is exactly
    // the bug that makes a live wallpaper look broken. Only a suspended session stops the frames.
    // `inactive` and `displaySleep` belong here: they are plausible names for a surface that is still on
    // screen, no release has ever sent either, and guessing that they mean "hidden" freezes a wallpaper
    // the user is looking at. An unrecognised state costs battery; it must never cost the animation.
    for visible in ["active", "Active", nil, "someFutureState", "inactive", "displaySleep"] {
        #expect(!WallpaperProviderSurface.isSuspended(visible), Comment(rawValue: visible ?? "nil"))
    }
    for hidden in ["suspended", "Suspended", "suspending"] {
        #expect(WallpaperProviderSurface.isSuspended(hidden), Comment(rawValue: hidden))
    }
    // The playback policy the extension shares with the app: locked and idle still animate.
    var playback = WallpaperPlayback()
    playback.enabled = true
    #expect(playback.framesPerSecond == 60 && playback.animates)
    playback.sleeping = true
    #expect(playback.framesPerSecond == 0, "A suspended session must cost nothing")
}

@Test @MainActor func theSettingsViewModelsEncodeIntoTheHostsOwnPayloadType() throws {
    // The host does not accept a hand-built object: it decodes a keyed archive, and the wire types are
    // Codable mirrors of Apple's private ones whose field names and enum payload shapes are the contract.
    // Nothing checks that at compile time, so this exercises the real path — archive, class substitution,
    // decode — against the framework actually installed on this Mac.
    try #require(WallpaperProviderRuntime.isSupported, "WallpaperExtensionKit is unavailable on this system")
    let models = try #require(WallpaperProviderSettings.viewModels(), "The settings payload failed to encode")
    #expect(String(describing: type(of: models)) == "WallpaperSettingsViewModelsXPC",
            "The archive must decode as the host's type, not as our shim")

    // Every bundled scene must be offered, and to both slots: that is what makes each one eligible for the
    // lock screen without the user choosing twice. Checked on the model, because the encoded payload is an
    // opaque instance of a class with no accessors.
    let model = try #require(WallpaperProviderSettings.model())
    let offered = WallpaperProviderEnvironment.shared.offeredTemplates
    #expect(!offered.isEmpty)
    for slot in [model.desktop, model.screenSaver] {
        let view = try #require(slot, "Both pickers must be offered a group")
        let group = try #require(view.groups.first)
        #expect(group.items.count == offered.count, "A template whose thumbnail fails to render is dropped from the group")
        #expect(Set(group.items.map(\.id.id)) == Set(offered.map(\.id)))
        for item in group.items {
            guard case let .image(url) = item.thumbnail else {
                Issue.record(Comment(rawValue: "\(item.id.id) offers no rendered thumbnail")); continue
            }
            // A missing file is the grey-tile failure: System Settings shows the row and no picture.
            #expect(FileManager.default.fileExists(atPath: url.path), Comment(rawValue: "\(item.id.id): \(url.path)"))
        }
    }
}
