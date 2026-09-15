import Foundation
import IOSurface
import UnfoldMyMacCore

/// Every surface the host currently holds, and the live data they are posed from.
///
/// The host addresses surfaces by an opaque id it also uses for update, snapshot and invalidate, while a
/// surface's *identity* is its destination — a display, a content type and whether it is a preview. Both
/// are tracked: the id resolves a call, the destination decides whether an acquire can reuse the context
/// it already built. Reusing matters because a `CAContext` can live in only one `CALayerHost` at a time.
@MainActor final class WallpaperProviderStore {
    static let shared = WallpaperProviderStore()
    private var surfaces: [String: WallpaperProviderSurface] = [:]
    private var destinations: [String: String] = [:]
    /// The request each live id was acquired with, so a scene change can rebuild the surface exactly as
    /// the host asked for it instead of reconstructing geometry from the destination key.
    private var requests: [String: WallpaperProviderRequest] = [:]
    private var payload: WallpaperProviderBridge.Payload?
    private var observing = false
    /// When the user last chose a scene in System Settings. The app's picker and the system's picker are
    /// both real choices; whichever the user made more recently is the one to honour.
    private var hostChoiceAt: Date?
    private var lastHostChoice: String?

    /// The scene to render for a request: the app's picker while it is running, the choice macOS
    /// persisted otherwise, and the first bundled template if neither named one.
    func templateID(for request: WallpaperProviderRequest) -> String? {
        if let payload, payload.selectionIsCurrent(), let id = payload.templateID,
           payload.selectedAt ?? .distantPast > hostChoiceAt ?? .distantPast,
           WallpaperProviderEnvironment.shared.template(id) != nil { return id }
        if let choice = request.choice, WallpaperProviderEnvironment.shared.template(choice) != nil { return choice }
        return WallpaperProviderEnvironment.shared.offeredTemplates.first?.id
    }

    /// Builds or reuses the surface for `request` and returns its remote context id.
    func acquire(id: String, request: WallpaperProviderRequest) -> UInt32? {
        startObserving()
        // The host sends its persisted choice on every acquire, so a change here is a change the user
        // made in System Settings — the same signal as `selectedChoicesDidChange`, which does not always
        // arrive. The first one seen is not a change: at login there is nothing for it to outrank.
        if let choice = request.choice {
            if let last = lastHostChoice, last != choice { hostChoiceAt = .now }
            lastHostChoice = choice
        }
        guard let templateID = templateID(for: request) else {
            WallpaperProviderLog.fault("no scenes available to render")
            heartbeat(failure: "no scenes available")
            return nil
        }
        let destination = request.destinationKey
        if request.identifiesDestination, let existingID = destinations[destination], let existing = surfaces[existingID] {
            if existing.templateID == templateID {
                // Same destination, same scene: keep the context so the wallpaper never blinks.
                existing.resize(to: request.size, scale: request.scale)
                surfaces[id] = existing
                destinations[destination] = id
                requests[id] = request
                if existingID != id { surfaces[existingID] = nil; requests[existingID] = nil }
                pose(existing)
                existing.apply(presentationMode: request.presentationMode, activityState: request.activityState)
                WallpaperProviderLog.note("acquire reused ctx=\(existing.contextID) for \(destination)")
                return existing.contextID
            }
            existing.invalidate()
            surfaces[existingID] = nil
        }
        guard let surface = WallpaperProviderSurface(templateID: templateID, size: request.size, scale: request.scale,
                                                     displayID: request.displayID, isPreview: request.isPreview,
                                                     role: request.role) else {
            heartbeat(failure: "surface creation failed for \(templateID)")
            return nil
        }
        surfaces[id] = surface
        destinations[destination] = id
        requests[id] = request
        pose(surface)
        surface.apply(presentationMode: request.presentationMode, activityState: request.activityState)
        heartbeat()
        return surface.contextID
    }

    /// The user picked a different scene in System Settings; that choice now outranks the app's.
    func hostChoiceChanged() {
        hostChoiceAt = .now
        refresh()
    }

    func update(id: String, request: WallpaperProviderRequest) {
        requests[id] = request
        guard let surface = surfaces[id] else { return }
        surface.resize(to: request.size, scale: request.scale)
        surface.apply(presentationMode: request.presentationMode, activityState: request.activityState)
        pose(surface)
    }
    /// The still for one surface, and only that surface.
    ///
    /// This used to fall back to `surfaces.values.first` for an id it did not know, which answers with
    /// another destination's scene at another destination's geometry — on a Mac with a built-in display
    /// and an ultrawide, a 3200x900 frame offered as the still for a 3024x1964 screen. An id we do not
    /// hold is a question we cannot answer, and the host handles that; a wrong answer it cannot.
    func snapshot(id: String) -> IOSurfaceRef? {
        guard let surface = surfaces[id] else {
            WallpaperProviderLog.fault("snapshot asked for \(id), which this provider does not hold")
            return nil
        }
        return surface.snapshotSurface()
    }
    func invalidate(id: String) {
        guard let surface = surfaces.removeValue(forKey: id) else { return }
        requests[id] = nil
        for (destination, owner) in destinations where owner == id { destinations[destination] = nil }
        // The same surface can be registered under an earlier id after a reuse; drop those too.
        for (key, value) in surfaces where value === surface { surfaces[key] = nil; requests[key] = nil }
        surface.invalidate()
        heartbeat()
    }

    /// Re-reads the bridge and re-poses every live surface. Called on each Darwin notification from the
    /// app, and once at acquire so a surface is never posed from nothing.
    func refresh() {
        payload = WallpaperProviderBridge.shared.readPayload()
        for (id, surface) in surfaces {
            // A scene change from the app's picker needs a new pipeline, not a new pose.
            if let payload, payload.selectionIsCurrent(), let wanted = payload.templateID, wanted != surface.templateID,
               let request = requests[id] {
                _ = acquire(id: id, request: request)
            } else {
                pose(surface)
            }
        }
        // Stamped on every refresh, not only on acquire: it is how the app tells a provider that is
        // rendering from one that stopped, and the app must not wait for the next lifecycle event to know.
        heartbeat()
    }
    private func pose(_ surface: WallpaperProviderSurface) {
        guard let template = WallpaperProviderEnvironment.shared.template(surface.templateID) else { return }
        guard let payload else {
            // No app running and nothing on disk: the scene's declared idle pose still animates, and the
            // readouts fall back to whatever each layer declares for missing data.
            surface.apply(pose: WallpaperPose(energy: template.idleEnergy ?? 0), snapshot: WallpaperSnapshot())
            return
        }
        let snapshot = payload.snapshot
        var pose = WallpaperPose(template: template, snapshot: snapshot)
        pose.liveInputs = payload.inputs
        surface.apply(pose: pose, snapshot: snapshot)
    }
    private func startObserving() {
        guard !observing else { return }
        observing = true
        payload = WallpaperProviderBridge.shared.readPayload()
        WallpaperProviderBridge.observe { WallpaperProviderStore.shared.refresh() }
    }
    /// Tells the app what the host is showing: which scene, on which content types, and — the part that
    /// cannot be inferred — whether frames are actually reaching the screen.
    private func heartbeat(failure: String? = nil) {
        let live = Dictionary(surfaces.map { (ObjectIdentifier($0.value), $0.value) }, uniquingKeysWith: { first, _ in first }).values
        let shown = live.filter { !$0.isPreview }
        let surface = shown.first ?? live.first
        WallpaperProviderBridge.shared.write(WallpaperProviderBridge.Heartbeat(
            templateID: surface?.templateID, contextID: surface?.contextID ?? 0,
            surfaces: shown.count,
            // Previews are excluded: a scene rendering in the Screen Saver tile of System Settings is not
            // a scene on the lock screen, and counting it as one is the same class of mistake as counting
            // a desktop surface as one.
            roles: Set(shown.map(\.role.rawValue)).sorted(),
            framesPerSecond: shown.map(\.framesPerSecond).max() ?? 0,
            presentedFPS: shown.map(\.presentedFPS).max() ?? 0,
            failure: failure))
    }
}
