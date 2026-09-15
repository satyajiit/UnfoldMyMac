import ExtensionFoundation
import Foundation
import UnfoldMyMacWallpaperBridge

/// Process entry point for the wallpaper provider extension, mirroring `UnfoldMyMacApp` for the app.
///
/// The `.appex` target is a shim around this: everything the provider does lives in the Kit, where it has
/// the whole render stack at internal visibility, and only what `ExtensionFoundation` must name is public.
public enum UnfoldMyMacWallpaperProvider {
    /// Called from the principal object's initialiser, before any connection arrives.
    ///
    /// `WallpaperExtensionKit` has to be loaded before the XPC interface is built, because the interface
    /// allow-lists payload classes by name. Logging here also separates "the process never started" from
    /// "the process started and was never connected" — the failure that has no other symptom.
    public static func start() {
        WallpaperProviderLog.note("provider process \(ProcessInfo.processInfo.processIdentifier) starting")
        WallpaperProviderRuntime.bootstrap()
    }
    public static func configuration() -> some AppExtensionConfiguration { WallpaperProviderConfiguration() }
}

/// Accepts the host's connection and describes both directions of the wallpaper XPC contract.
struct WallpaperProviderConfiguration: AppExtensionConfiguration {
    /// Arguments and replies the host marshals. NSXPC refuses any class not named for the exact selector
    /// and argument position, so every payload type is allow-listed for every position it can appear in.
    /// Computed rather than stored: `Selector` is not `Sendable`, and a stored static would be inferred
    /// main-actor isolated while `accept(connection:)` is called from wherever ExtensionKit stands.
    private nonisolated static var selectors: [(Selector, Int, Bool)] { [
        (#selector(WallpaperProviderService.acquire(withId:request:reply:)), 0, false),
        (#selector(WallpaperProviderService.acquire(withId:request:reply:)), 1, false),
        (#selector(WallpaperProviderService.acquire(withId:request:reply:)), 0, true),
        (#selector(WallpaperProviderService.update(withId:request:reply:)), 0, false),
        (#selector(WallpaperProviderService.update(withId:request:reply:)), 1, false),
        (#selector(WallpaperProviderService.invalidate(withId:reply:)), 0, false),
        (#selector(WallpaperProviderService.snapshot(withId:reply:)), 0, false),
        (#selector(WallpaperProviderService.snapshot(withId:reply:)), 0, true),
        (#selector(WallpaperProviderService.provideSettingsViewModels(withContentTypes:reply:)), 0, false),
        (#selector(WallpaperProviderService.provideSettingsViewModels(withContentTypes:reply:)), 0, true),
        (#selector(WallpaperProviderService.selectedChoicesDidChange(for:reply:)), 0, false),
        (#selector(WallpaperProviderService.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 0, false),
        (#selector(WallpaperProviderService.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 1, false),
        (#selector(WallpaperProviderService.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 0, true),
        (#selector(WallpaperProviderService.removeChoiceRequest(withChoiceRequest:reply:)), 0, false),
        (#selector(WallpaperProviderService.invokeContextMenuAction(withMenuItemID:groupItemID:reply:)), 0, false),
        (#selector(WallpaperProviderService.invokeContextMenuAction(withMenuItemID:groupItemID:reply:)), 1, false),
        (#selector(WallpaperProviderService.isChoiceDownloaded(with:reply:)), 0, false),
        (#selector(WallpaperProviderService.migrateSelectedChoice(for:reply:)), 0, false),
        (#selector(WallpaperProviderService.migrateSelectedChoice(for:reply:)), 0, true),
        (#selector(WallpaperProviderService.migrate(from:to:reply:)), 0, false),
        (#selector(WallpaperProviderService.migrate(from:to:reply:)), 1, false),
        (#selector(WallpaperProviderService.skipShuffledContent(withId:reply:)), 0, false),
        (#selector(WallpaperProviderService.canSkipShuffledContent(withId:reply:)), 0, false),
        (#selector(WallpaperProviderService.handleDebugRequest(for:reply:)), 0, false),
        (#selector(WallpaperProviderService.handleDebugRequest(for:reply:)), 0, true),
        (#selector(WallpaperProviderService.handleNotification(withNamed:reply:)), 0, false),
    ] }

    func accept(connection: NSXPCConnection) -> Bool {
        WallpaperProviderLog.note("XPC connection from pid \(connection.processIdentifier)")
        guard WallpaperProviderRuntime.isSupported else {
            WallpaperProviderLog.fault("declining the connection: the wallpaper runtime is not supported here")
            return false
        }
        let interface = NSXPCInterface(with: (any UnfoldMyMacWallpaperExtensionXPC).self)
        let allowed = NSMutableSet()
        var missing: [String] = []
        for name in WallpaperProviderRuntime.interfaceClasses {
            if let type = objc_getClass(name) { allowed.add(type) } else { missing.append(name) }
        }
        if !missing.isEmpty { WallpaperProviderLog.note("optional payload classes absent: \(missing.joined(separator: ", "))") }
        for type in [NSString.self, NSNumber.self, NSData.self, NSArray.self, NSDictionary.self,
                     NSURL.self, NSUUID.self, NSError.self] as [AnyClass] { allowed.add(type) }
        guard let classes = allowed as? Set<AnyHashable> else { return false }
        for (selector, index, isReply) in Self.selectors {
            interface.setClasses(classes, for: selector, argumentIndex: index, ofReply: isReply)
        }
        connection.exportedInterface = interface
        connection.exportedObject = WallpaperProviderService()
        connection.remoteObjectInterface = NSXPCInterface(with: (any UnfoldMyMacWallpaperHostProxy).self)
        connection.invalidationHandler = { WallpaperProviderLog.note("XPC invalidated") }
        connection.interruptionHandler = { WallpaperProviderLog.note("XPC interrupted") }
        connection.resume()
        WallpaperProviderLog.note("XPC accepted")
        return true
    }
}
