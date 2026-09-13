import AVFoundation

/// One input-only engine for every wallpaper consumer. Creation and teardown happen outside rendering.
@MainActor final class WallpaperAudioCapture: WallpaperAudioCapturing {
    private enum Failure: Error { case noInput }
    private var engine: AVAudioEngine?
    private let meter = WallpaperAudioMeter()
    private var observer: NSObjectProtocol?
    var onDeviceChange: (() -> Void)?
    var isRunning: Bool { engine?.isRunning == true }
    var permission: WallpaperMicrophonePermission {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .undetermined
        @unknown default: .restricted
        }
    }
    func requestPermission() async {
        guard permission == .undetermined else { return }
        _ = await AVCaptureDevice.requestAccess(for: .audio)
    }
    func start() throws {
        guard permission == .authorized, !isRunning else { return }
        stop()
        let engine = AVAudioEngine()
        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            throw Failure.noInput
        }
        node.installTap(onBus: 0, bufferSize: 1024, format: nil, block: meter.makeTap())
        do { try engine.start() }
        catch { node.removeTap(onBus: 0); throw error }
        self.engine = engine
        observer = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
            // Defer teardown beyond AVAudioEngine's internal notification callback.
            Task { @MainActor [weak self] in self?.onDeviceChange?() }
        }
    }
    func amplitude(now: Double) -> Double { meter.read(now: now) }
    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }; observer = nil
        if let engine { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        engine = nil; meter.reset()
    }
    isolated deinit { stop() }
}
