@MainActor protocol WallpaperAudioCapturing: AnyObject {
    var permission: WallpaperMicrophonePermission { get }
    var isRunning: Bool { get }
    var onDeviceChange: (() -> Void)? { get set }
    func requestPermission() async
    func start() throws
    func stop()
    func amplitude(now: Double) -> Double
}
