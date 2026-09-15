import Foundation
import IOSurface
import QuartzCore
import UnfoldMyMacWallpaperBridge

/// Resolves the private `WallpaperExtensionKit` payload classes the host exchanges over XPC.
///
/// The framework is dyld-cache-only and ships no headers, so the classes are looked up by name after
/// `dlopen` and every use is guarded. A macOS release that renames or reshapes them makes `isSupported`
/// false and the provider declines to render rather than writing through a wrong ivar offset.
enum WallpaperProviderRuntime {
    /// Classes the provider genuinely needs. Anything absent means the contract moved.
    private static let requiredClasses = [
        "WallpaperRemoteContextXPC",
        "WallpaperSnapshotXPC",
        "WallpaperCreationRequestXPC",
        "WallpaperSettingsViewModelsXPC",
        "WallpaperIDXPC",
    ]
    /// Every class named in the XPC interface allow-list, including the optional ones.
    static let interfaceClasses = requiredClasses + [
        "WallpaperUpdateRequestXPC",
        "WallpaperContentTypeSetXPC",
        "WallpaperChoiceIDXPC",
        "WallpaperChoiceIDsXPC",
        "WallpaperExtensionChoiceRequestXPC",
        "WallpaperChoiceRequestAdditionResultXPC",
        "WallpaperDebugRequestXPC",
        "WallpaperDebugResponseXPC",
        "WallpaperMigrationVersionXPC",
        "AuditTokenXPC",
    ]
    private nonisolated(unsafe) static var loaded = false
    private nonisolated(unsafe) static var supported = false
    private static let lock = NSLock()

    /// Loads the framework once. Safe to call from any thread; the first caller does the work.
    @discardableResult static func bootstrap() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !loaded else { return supported }
        loaded = true
        let path = "/System/Library/PrivateFrameworks/WallpaperExtensionKit.framework/WallpaperExtensionKit"
        guard dlopen(path, RTLD_LAZY) != nil else {
            WallpaperProviderLog.fault("WallpaperExtensionKit could not be loaded: \(String(cString: dlerror()))")
            return false
        }
        let missing = requiredClasses.filter { objc_getClass($0) == nil }
        supported = missing.isEmpty
        if supported {
            WallpaperProviderLog.note("provider ready — WallpaperExtensionKit loaded, runtime layout matches")
        } else {
            WallpaperProviderLog.fault("unsupported runtime: missing \(missing.joined(separator: ", "))")
        }
        return supported
    }
    static var isSupported: Bool { bootstrap() }

    /// Wraps a remote `CAContext` id in the reply type the host expects.
    ///
    /// `WallpaperRemoteContextXPC` holds a boxed struct whose first field is the `UInt32` context id. The
    /// ivar is located by name and the write is bounds-checked against the instance size, so a changed
    /// layout returns nil instead of corrupting the heap.
    static func remoteContextReply(contextID: UInt32) -> AnyObject? {
        guard let cls = objc_getClass("WallpaperRemoteContextXPC") as? AnyClass,
              let instance = class_createInstance(cls, 0) else {
            WallpaperProviderLog.fault("could not allocate WallpaperRemoteContextXPC")
            return nil
        }
        let object = instance as AnyObject
        let offset = class_getInstanceVariable(cls, "box").map { ivar_getOffset($0) } ?? 8
        guard offset >= 0, offset + MemoryLayout<UInt32>.size <= class_getInstanceSize(cls) else {
            WallpaperProviderLog.fault("WallpaperRemoteContextXPC layout changed — declining to write")
            return nil
        }
        Unmanaged.passUnretained(object).toOpaque()
            .advanced(by: offset)
            .storeBytes(of: contextID, as: UInt32.self)
        return object
    }

    /// A remote `CAContext` the WindowServer composites as a real wallpaper surface.
    ///
    /// `remoteContextWithOptions:` pins the context to one display, which keeps a multi-display setup from
    /// compositing the same surface twice; the option-less form is the single-display fallback. The
    /// selector is dispatched by name because `CAContext` is CoreAnimation SPI with no header.
    static func makeRemoteContext(displayID: UInt32?) -> CAContext? {
        var created: CAContext?
        if let displayID, CAContext.responds(to: NSSelectorFromString("remoteContextWithOptions:")) {
            created = CAContext.remoteContext(options: ["displayId": displayID])
        }
        let context = created ?? CAContext.remoteContext()
        guard let context, context.contextId != 0 else {
            WallpaperProviderLog.fault("remote CAContext unavailable")
            return nil
        }
        return context
    }

    /// Boxes an IOSurface in `WallpaperSnapshotXPC`, the only shape the snapshot reply accepts.
    ///
    /// The class has no public initialiser and its single ivar holds the surface. The box takes a retain:
    /// the reply outlives this call, and the surface is mapped in the host after we return.
    static func snapshotReply(surface: IOSurfaceRef) -> AnyObject? {
        guard let cls = objc_getClass("WallpaperSnapshotXPC") as? AnyClass,
              let instance = class_createInstance(cls, 0) else {
            WallpaperProviderLog.fault("could not allocate WallpaperSnapshotXPC")
            return nil
        }
        let object = instance as AnyObject
        let offset = class_getInstanceVariable(cls, "rawValue").map { ivar_getOffset($0) } ?? 8
        guard offset >= 0, offset + MemoryLayout<UnsafeRawPointer>.size <= class_getInstanceSize(cls) else {
            WallpaperProviderLog.fault("WallpaperSnapshotXPC layout changed — declining to write")
            return nil
        }
        let retained = Unmanaged.passRetained(surface as AnyObject).toOpaque()
        Unmanaged.passUnretained(object).toOpaque()
            .advanced(by: offset)
            .storeBytes(of: UnsafeRawPointer(retained), as: UnsafeRawPointer.self)
        return object
    }

    /// A stable key for a `WallpaperIDXPC`, which is how the host addresses one hosted surface across
    /// acquire, update, snapshot and invalidate.
    ///
    /// The class wraps a 16-byte value in an ivar named `box` and exposes nothing else, so the bytes
    /// themselves are the identity: equal ids hash equal, different ids do not. What they *mean* is the
    /// framework's business, and reading them as a UUID would be a claim this cannot check. The read is
    /// bounds-checked against the instance size, and a changed layout falls back to the object's own
    /// description rather than reading past the allocation.
    static func identity(of value: Any?) -> String {
        guard let value else { return "none" }
        let object = value as AnyObject
        guard let cls = object_getClass(object), let ivar = class_getInstanceVariable(cls, "box") else {
            return String(describing: value)
        }
        let offset = ivar_getOffset(ivar)
        let width = 16
        guard offset >= 8, offset + width <= class_getInstanceSize(cls) else { return String(describing: value) }
        let base = Unmanaged.passUnretained(object).toOpaque().advanced(by: offset)
        return (0..<width).map { String(format: "%02x", base.load(fromByteOffset: $0, as: UInt8.self)) }.joined()
    }
}
