import Foundation
import UnfoldMyMacCore
import UnfoldMyMacWallpaperBridge

/// The provider's side of the wallpaper XPC contract.
///
/// `WallpaperAgent` owns the lifecycle: it acquires a surface per destination, updates it when the display
/// or the presentation mode changes, asks for a still to export, and invalidates it when the user picks
/// something else. Every call must reply — a call left hanging stalls the agent for every wallpaper
/// provider on the system, Apple's included — so each method here answers exactly once on every path.
///
/// NSXPC invokes these on its own queue while all rendering is main-actor bound, so each method parses its
/// arguments where it stands and then hops.
final class WallpaperProviderService: NSObject, UnfoldMyMacWallpaperExtensionXPC {
    /// Carries a non-`Sendable` XPC reply block to the main actor. The block is called exactly once, on
    /// the main actor, which is what makes the unchecked conformance sound.
    private struct Reply<Value>: @unchecked Sendable {
        let call: Value
        init(_ call: Value) { self.call = call }
    }
    private enum Failure: Int {
        case unsupportedRuntime = 1, surfaceUnavailable = 2, snapshotUnavailable = 3, settingsUnavailable = 4
        var error: NSError {
            NSError(domain: AppIdentity.wallpaperExtensionIdentifier, code: rawValue,
                    userInfo: [NSLocalizedDescriptionKey: String(describing: self)])
        }
    }

    // MARK: Lifecycle

    func acquire(withId anId: Any?, request: Any?, reply: @escaping (Any?, (any Error)?) -> Void) {
        let identity = WallpaperProviderRuntime.identity(of: anId)
        let parsed = WallpaperProviderRequest(request)
        WallpaperProviderLog.note("acquire \(identity) \(parsed.destinationKey) \(Int(parsed.size.width))x\(Int(parsed.size.height))@\(parsed.scale)x choice=\(parsed.choice ?? "-")")
        let reply = Reply(reply)
        Task { @MainActor in
            guard WallpaperProviderRuntime.isSupported else { reply.call(nil, Failure.unsupportedRuntime.error); return }
            guard let contextID = WallpaperProviderStore.shared.acquire(id: identity, request: parsed),
                  let boxed = WallpaperProviderRuntime.remoteContextReply(contextID: contextID) else {
                reply.call(nil, Failure.surfaceUnavailable.error); return
            }
            reply.call(boxed, nil)
        }
    }

    func update(withId anId: Any?, request: Any?, reply: @escaping ((any Error)?) -> Void) {
        let identity = WallpaperProviderRuntime.identity(of: anId)
        let parsed = WallpaperProviderRequest(request)
        let reply = Reply(reply)
        Task { @MainActor in
            WallpaperProviderStore.shared.update(id: identity, request: parsed)
            reply.call(nil)
        }
    }

    func invalidate(withId anId: Any?, reply: @escaping ((any Error)?) -> Void) {
        let identity = WallpaperProviderRuntime.identity(of: anId)
        let reply = Reply(reply)
        Task { @MainActor in
            WallpaperProviderStore.shared.invalidate(id: identity)
            reply.call(nil)
        }
    }

    /// The still the host exports to `/var/db/Wallpapers`, which is what the login window and the System
    /// Settings tile show. Returning nothing here is not cosmetic — it renders as a grey lock screen.
    func snapshot(withId anId: Any?, reply: @escaping (Any?, (any Error)?) -> Void) {
        let identity = WallpaperProviderRuntime.identity(of: anId)
        let reply = Reply(reply)
        Task { @MainActor in
            guard let surface = WallpaperProviderStore.shared.snapshot(id: identity),
                  let boxed = WallpaperProviderRuntime.snapshotReply(surface: surface) else {
                WallpaperProviderLog.fault("snapshot unavailable for \(identity)")
                reply.call(nil, Failure.snapshotUnavailable.error); return
            }
            WallpaperProviderLog.note("snapshot delivered for \(identity)")
            reply.call(boxed, nil)
        }
    }

    // MARK: Settings

    func provideSettingsViewModels(withContentTypes types: Any?, reply: @escaping (Any?, (any Error)?) -> Void) {
        let reply = Reply(reply)
        Task { @MainActor in
            guard let models = WallpaperProviderSettings.viewModels() else {
                reply.call(nil, Failure.settingsUnavailable.error); return
            }
            WallpaperProviderLog.note("settings view models delivered")
            reply.call(models, nil)
        }
    }

    /// The user picked a different scene in System Settings. That is a decision made just now, so it
    /// outranks whatever the app's own picker last selected.
    func selectedChoicesDidChange(for anId: Any?, reply: @escaping ((any Error)?) -> Void) {
        let reply = Reply(reply)
        Task { @MainActor in
            WallpaperProviderStore.shared.hostChoiceChanged()
            reply.call(nil)
        }
    }

    // MARK: Choices this provider does not offer
    //
    // Every bundled scene ships inside the app, so there is nothing to add, download, resume or migrate.
    // These still reply: an unanswered XPC call blocks the agent, not just this extension.

    func addChoiceRequest(withChoiceRequest request: Any?, onBehalfOfProcess process: Any?, reply: @escaping (Any?, (any Error)?) -> Void) { reply(nil, nil) }
    func removeChoiceRequest(withChoiceRequest request: Any?, reply: @escaping ((any Error)?) -> Void) { reply(nil) }
    func invokeContextMenuAction(withMenuItemID menuItemID: Any?, groupItemID: Any?, reply: @escaping ((any Error)?) -> Void) { reply(nil) }
    func isChoiceDownloaded(with choiceID: Any?, reply: @escaping (Bool, (any Error)?) -> Void) { reply(true, nil) }
    func download(withChoiceID choiceID: Any?, reply: @escaping ((any Error)?) -> Void) -> Any? { reply(nil); return nil }
    func pauseDownload(for choiceID: Any?, reply: @escaping ((any Error)?) -> Void) { reply(nil) }
    func cancelDownload(for choiceID: Any?, reply: @escaping ((any Error)?) -> Void) { reply(nil) }
    func resumeDownload(for choiceID: Any?, reply: @escaping ((any Error)?) -> Void) { reply(nil) }
    func removeDownload(for choiceID: Any?, reply: @escaping ((any Error)?) -> Void) { reply(nil) }
    func migrateSelectedChoice(for anId: Any?, reply: @escaping (Any?, (any Error)?) -> Void) { reply(nil, nil) }
    func migrate(from: Any?, to: Any?, reply: @escaping ((any Error)?) -> Void) { reply(nil) }
    func skipShuffledContent(withId anId: Any?, reply: @escaping ((any Error)?) -> Void) { reply(nil) }
    func canSkipShuffledContent(withId anId: Any?, reply: @escaping (Bool, (any Error)?) -> Void) { reply(false, nil) }
    func handleDebugRequest(for request: Any?, reply: @escaping (Any?, (any Error)?) -> Void) { reply(nil, nil) }

    /// The host relays system notifications the provider may care about; a data refresh is the only one
    /// that changes what we draw, and it is cheap enough to do unconditionally.
    func handleNotification(withNamed name: Any?, reply: @escaping ((any Error)?) -> Void) {
        let reply = Reply(reply)
        Task { @MainActor in
            WallpaperProviderStore.shared.refresh()
            reply.call(nil)
        }
    }
}
