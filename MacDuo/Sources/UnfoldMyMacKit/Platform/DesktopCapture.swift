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

@MainActor final class DesktopCapture: NSObject, DesktopCapturing, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private var cancelled = false
    private let includedWindows: () -> Set<CGWindowID>
    private var filteredWindows: Set<CGWindowID> = []
    private var displayID: CGDirectDisplayID?
    private var windowObserver: NSObjectProtocol?
    private var filterTask: Task<Void, Never>?
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
        try next.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        stream = next
        try await next.startCapture()
        if cancelled || Task.isCancelled {
            try? await next.stopCapture()
            throw CancellationError()
        }
        windowObserver = NotificationCenter.default.addObserver(forName: .desktopContentWindowsChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshFilter() }
        }
        refreshFilter()
    }

    func stop() async {
        cancelled = true
        onFrame = nil; onError = nil
        filterTask?.cancel(); filterTask = nil
        if let windowObserver { NotificationCenter.default.removeObserver(windowObserver); self.windowObserver = nil }
        let old = stream
        stream = nil
        try? await old?.stopCapture()
    }

    private func refreshFilter() {
        let wanted = includedWindows()
        guard !cancelled, wanted != filteredWindows, filterTask == nil, let stream, let displayID else { return }
        filterTask = Task { [weak self] in
            guard let self else { return }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                try Task.checkCancellation()
                guard self.stream === stream, !cancelled else { return }
                let filter = try DesktopCaptureFilter.make(content: content, displayID: displayID, including: wanted)
                try await stream.updateContentFilter(filter)
                filteredWindows = wanted
            } catch {
                if !Task.isCancelled && !cancelled { onError?(error) }
            }
            filterTask = nil
            if !cancelled && filteredWindows == wanted { refreshFilter() }
        }
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let info = (CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]])?.first,
              let status = info[.status] as? Int, status == SCFrameStatus.complete.rawValue,
              let buffer = sampleBuffer.imageBuffer else { return }
        let frame = DesktopFrame(buffer)
        let streamID = ObjectIdentifier(stream)
        // This callback is explicitly delivered on .main by addStreamOutput.
        MainActor.assumeIsolated {
            guard self.stream.map(ObjectIdentifier.init) == streamID, !cancelled else { return }
            onFrame?(frame)
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
