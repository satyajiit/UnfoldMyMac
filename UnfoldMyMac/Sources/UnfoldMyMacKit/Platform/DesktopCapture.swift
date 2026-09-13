import AppKit
import UnfoldMyMacCore
import CoreMedia
import ScreenCaptureKit

enum CaptureFailure: LocalizedError {
    case displayUnavailable, exclusionUnavailable
    var errorDescription: String? {
        switch self {
        case .displayUnavailable: "The built-in display is not available for capture."
        case .exclusionUnavailable: "\(AppIdentity.name) could not exclude itself from capture. Try enabling Frost again."
        }
    }
}

/// Captures the built-in display through ScreenCaptureKit, excluding the app's own desktop windows. Frames are
/// delivered on a private queue and only the newest one crosses to the main actor per hop (P3).
@MainActor final class DesktopCapture: NSObject, DesktopCapturing, SCStreamOutput, SCStreamDelegate {
    private static let filterRetryDelay: Duration = .seconds(1)
    private nonisolated let queue = DispatchQueue(label: "\(AppIdentity.bundleIdentifier).capture", qos: .userInteractive)
    private nonisolated let latest = LatestFrameBox()
    private var stream: SCStream?
    private var cancelled = false
    private let includedWindows: () -> Set<CGWindowID>
    private var filteredWindows: Set<CGWindowID> = []
    private var displayID: CGDirectDisplayID?
    private var windowObserver: NSObjectProtocol?
    private var refreshPending = false
    private var refreshTask: Task<Void, Never>?
    var onFrame: ((DesktopFrame) -> Void)?
    var onError: ((Error) -> Void)?

    init(includingWindows: @escaping () -> Set<CGWindowID> = { [] }) {
        includedWindows = includingWindows
        super.init()
    }
    /// Excludes the app's own desktop surfaces, refreshing the filter when the registry changes.
    convenience init(surfaces: DesktopSurfaceRegistry) {
        self.init(includingWindows: { surfaces.windowIDs })
    }

    func start(displayID: CGDirectDisplayID) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        try Task.checkCancellation()
        guard !cancelled else { throw CancellationError() }
        self.displayID = displayID
        filteredWindows = includedWindows()
        let filter = try DesktopCaptureFilter.make(content: content, displayID: displayID, including: filteredWindows)
        let config = SCStreamConfiguration()
        config.width = CGDisplayPixelsWide(displayID)
        config.height = CGDisplayPixelsHigh(displayID)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 3
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = false
        config.colorSpaceName = CGColorSpace.sRGB
        let next = SCStream(filter: filter, configuration: config, delegate: self)
        try next.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        stream = next
        // Registered before capture starts so a registry change during startup is not missed (L13).
        windowObserver = NotificationCenter.default.addObserver(forName: .desktopContentWindowsChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshFilter() }
        }
        try await next.startCapture()
        if cancelled || Task.isCancelled {
            try? await next.stopCapture()
            throw CancellationError()
        }
        refreshFilter()
    }

    func stop() async {
        cancelled = true
        onFrame = nil; onError = nil
        refreshTask?.cancel(); refreshTask = nil; refreshPending = false
        if let windowObserver { NotificationCenter.default.removeObserver(windowObserver); self.windowObserver = nil }
        let old = stream
        stream = nil
        latest.clear()
        guard let old else { return }
        try? old.removeStreamOutput(self, type: .screen)
        try? await old.stopCapture()
    }

    /// Reapplies the window filter after a registry change. Overlapping requests fold into one pass that runs
    /// again if the wanted set moved meanwhile; a failure gets one retry a second later before it is reported.
    private func refreshFilter() {
        refreshPending = true
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            await self?.applyPendingFilters()
            self?.refreshTask = nil
        }
    }
    private func applyPendingFilters() async {
        var retried = false
        while refreshPending, !cancelled, let stream, let displayID {
            refreshPending = false
            let wanted = includedWindows()
            guard wanted != filteredWindows else { continue }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                try Task.checkCancellation()
                guard self.stream === stream, !cancelled else { return }
                try await stream.updateContentFilter(try DesktopCaptureFilter.make(content: content, displayID: displayID, including: wanted))
                filteredWindows = wanted; retried = false
            } catch is CancellationError {
                return
            } catch {
                guard !cancelled else { return }
                if retried { onError?(error); return }
                retried = true; refreshPending = true
                try? await Task.sleep(for: Self.filterRetryDelay)
                if Task.isCancelled { return }
            }
        }
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let info = (CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]])?.first,
              let status = info[.status] as? Int, status == SCFrameStatus.complete.rawValue,
              let buffer = sampleBuffer.imageBuffer else { return }
        guard latest.offer(DesktopFrame(buffer)) else { return }
        let streamID = ObjectIdentifier(stream)
        DispatchQueue.main.async { [weak self] in
            guard let self, let frame = latest.take() else { return }
            MainActor.assumeIsolated {
                guard self.stream.map(ObjectIdentifier.init) == streamID, !cancelled else { return }
                onFrame?(frame)
            }
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        let streamID = ObjectIdentifier(stream)
        Task { @MainActor [weak self] in
            guard let self, self.stream.map(ObjectIdentifier.init) == streamID, !cancelled else { return }
            onError?(error)
        }
    }
}
