import Foundation

/// The parts of the host's creation and update requests the provider acts on.
///
/// `WallpaperCreationRequestXPC` and `WallpaperUpdateRequestXPC` wrap Swift structs that the framework
/// never exposes, so the fields are read reflectively by label. The walk is depth-tolerant rather than
/// positional: a macOS release that adds or reorders a wrapper layer keeps working, and a field that
/// disappears leaves its default rather than shifting every other value by one.
struct WallpaperProviderRequest: Sendable {
    var size = CGSize(width: 1920, height: 1080)
    var scale: CGFloat = 2
    var displayID: UInt32?
    var isPreview = false
    var presentationMode: String?
    var activityState: String?
    /// The scene the user picked, carried as the choice descriptor's opaque configuration payload.
    var choice: String?

    /// What a surface is for. The desktop is one slot in the system's wallpaper store; the lock screen and
    /// the screen saver are the other, and they share a surface.
    enum Role: String, Sendable {
        case desktop, lockScreen
        /// The presentation modes the host has been observed to use: `default` for the desktop, `idle` for
        /// the screen saver, `locked` for the lock screen. An unrecognised mode is the desktop, because
        /// claiming the lock screen wrongly is the failure this whole type exists to prevent.
        init(presentationMode: String?) {
            switch presentationMode?.lowercased() {
            case "idle", "locked": self = .lockScreen
            default: self = .desktop
            }
        }
    }
    /// This surface's role, from the presentation mode the host created it with.
    ///
    /// There is no content type anywhere in `WallpaperCreationRequestXPC` — the whole struct is size,
    /// scale factor, display id, colour space, preview flag, presentation mode, system appearance, a cache
    /// directory and the choice's payload blob. `presentationMode` is therefore the only thing separating
    /// the desktop surface from the one the lock screen shows, and the host does set it per surface: three
    /// acquires arriving in the same millisecond carry `default`, `default` and `idle`.
    var role: Role { Role(presentationMode: presentationMode) }

    /// Identifies one hosted surface. A context can live in only one `CALayerHost` at a time, so the
    /// desktop, the lock screen, the Settings preview and each additional display must never share one.
    var destinationKey: String { "\(displayID.map(String.init) ?? "main"):\(role.rawValue):\(isPreview)" }

    /// Whether the key above actually distinguishes this surface from the host's other ones.
    ///
    /// False when the host reported no presentation mode, which would collapse the desktop and the lock
    /// screen onto one key. Reusing a context across them hosts one `CAContext` in two `CALayerHost`s —
    /// live in one, frozen on its last composited frame in the other. Building a redundant context costs
    /// a blink; sharing one costs the lock screen.
    var identifiesDestination: Bool { presentationMode != nil }

    init(_ request: Any?) {
        guard let request else { return }
        if let value = WallpaperProviderMirror.find("size", in: request) as? CGSize { size = value }
        if let value = WallpaperProviderMirror.find("scaleFactor", in: request) as? CGFloat { scale = value }
        if let value = WallpaperProviderMirror.find("directDisplayID", in: request) as? UInt32 { displayID = value }
        if let value = WallpaperProviderMirror.find("isPreview", in: request) as? Bool { isPreview = value }
        presentationMode = WallpaperProviderMirror.find("presentationMode", in: request).map { WallpaperProviderMirror.name(of: $0) }
        activityState = WallpaperProviderMirror.find("activityState", in: request).map { WallpaperProviderMirror.name(of: $0) }
        // The presentation mode is the only field that says what a surface is for, so losing it to a
        // rename would silently merge the desktop and the lock screen. Dump the shape rather than guess.
        if presentationMode == nil { WallpaperProviderMirror.describeOnce(request) }
        if let data = WallpaperProviderMirror.find("configuration", in: request) as? Data, !data.isEmpty {
            choice = String(data: data, encoding: .utf8)
        }
        // A size the host reports in a degenerate state would divide through the whole render path.
        if !(size.width.isFinite && size.height.isFinite) || size.width < 1 || size.height < 1 { size = CGSize(width: 1920, height: 1080) }
        if !scale.isFinite || scale < 1 { scale = 2 }
    }
}

/// Reads labelled fields out of the framework's private payload types.
enum WallpaperProviderMirror {
    /// Depth-first search for the first child labelled `label`, bounded so a cyclic or deep graph cannot
    /// spin. Optionals are unwrapped as they are met, so a `Bool?` field reads back as `Bool`.
    static func find(_ label: String, in value: Any, depth: Int = 6) -> Any? {
        guard depth > 0 else { return nil }
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let wrapped = mirror.children.first?.value else { return nil }
            return find(label, in: wrapped, depth: depth)
        }
        for child in mirror.children where child.label == label {
            let unwrapped = Mirror(reflecting: child.value)
            guard unwrapped.displayStyle == .optional else { return child.value }
            if let inner = unwrapped.children.first?.value { return inner }
            return nil
        }
        for child in mirror.children {
            if let found = find(label, in: child.value, depth: depth - 1) { return found }
        }
        return nil
    }
    /// Every labelled field in one of the host's payloads, as `path=value`, logged once per process.
    ///
    /// Called when a field the provider depends on cannot be found. These types ship no headers, so when a
    /// label moves the only way to learn where it went is to look at what the host actually handed over —
    /// and the only process that can look is this one, inside the sandbox, at the moment it arrives.
    static func describeOnce(_ value: Any) {
        guard !described else { return }
        described = true
        // One line per handful of fields. `os_log` truncates a long interpolated string, and the first
        // version of this lost every field after the payload blob — which is where the interesting ones
        // turned out to be. A dump that silently ends early is worse than no dump.
        let leaves = describe(value)
        for chunk in stride(from: 0, to: leaves.count, by: 8) {
            WallpaperProviderLog.note("request shape \(chunk / 8): \(leaves[chunk..<min(chunk + 8, leaves.count)].joined(separator: " "))")
        }
    }
    private nonisolated(unsafe) static var described = false
    static func describe(_ value: Any, path: String = "", depth: Int = 6) -> [String] {
        guard depth > 0, path.components(separatedBy: ".").count <= 8 else { return [] }
        // A `Data` is thousands of `_` children that say nothing and crowd out everything after them.
        if let data = value as? Data { return ["\(path)=<\(data.count) bytes>"] }
        let mirror = Mirror(reflecting: value)
        let kind = "\(type(of: value))"
        guard !mirror.children.isEmpty else { return path.isEmpty ? [] : ["\(path):\(kind)=\(name(of: value))"] }
        return mirror.children.prefix(24).flatMap { child -> [String] in
            let next = [path, child.label ?? "_"].filter { !$0.isEmpty }.joined(separator: ".")
            return describe(child.value, path: next, depth: depth - 1)
        }
    }
    /// The case name of an enum the framework does not export, or the value's description otherwise.
    /// Compared case-insensitively everywhere, so a capitalisation change upstream is harmless.
    static func name(of value: Any) -> String {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .enum, let label = mirror.children.first?.label { return label }
        return String(describing: value)
    }
}
