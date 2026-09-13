import AppKit
import Observation
import UnfoldMyMacCore

/// Shared across preview and desktop. Visibility leases own the 30 Hz lid poll and single audio engine.
@MainActor @Observable final class WallpaperInputService {
    private(set) var permission: WallpaperMicrophonePermission
    private(set) var audioStatus = "Sound reactions are off."
    private(set) var motionStatus = "Motion sensors respond while the garden is playing."
    private(set) var gardenQuote: GardenQuotePresentation?
    private(set) var showsWorkshopCounts = true
    private(set) var workshopQuote: GardenQuotePresentation?
    @ObservationIgnored private let audio: any WallpaperAudioCapturing
    @ObservationIgnored private let makeSensor: () -> any LidReading
    @ObservationIgnored private let clock: () -> Double
    @ObservationIgnored private let makeMotion: () -> any GardenMotionReading
    @ObservationIgnored private var motion: (any GardenMotionReading)?
    @ObservationIgnored private var motionDynamics = GardenMotionDynamics()
    @ObservationIgnored private var breath = GardenBreathDetector()
    @ObservationIgnored private var quoteCycle = GardenQuoteCycle()
    @ObservationIgnored private var workshopQuoteCycle = GardenQuoteCycle(lines: WorkshopQuoteDeck.lines)
    @ObservationIgnored private var pointer = CGPoint.zero
    @ObservationIgnored private var lastSampleTime: Double?
    @ObservationIgnored private var lastMotionSignal = 0.0
    @ObservationIgnored private var lid: LidMonitor?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var metricsTask: Task<Void, Never>?
    @ObservationIgnored private var dynamics = WallpaperInputDynamics()
    @ObservationIgnored private var consumers: [UUID: (template: String, animated: Bool)] = [:]
    @ObservationIgnored private var connections: [String: [String: WallpaperConnectionSettings]] = [:]
    @ObservationIgnored private var suspended = false
    @ObservationIgnored private var reducedMotion = false
    @ObservationIgnored private var battery: Double?
    @ObservationIgnored private var pluggedIn: Bool?
    @ObservationIgnored private var lastAudioAttempt = -Double.infinity
    @ObservationIgnored private var permissionTask: Task<Void, Never>?
    var isSampling: Bool { task != nil }
    var consumerCount: Int { consumers.count }

    init(audio: any WallpaperAudioCapturing = WallpaperAudioCapture(),
         makeSensor: @escaping () -> any LidReading = { LidSensor() },
         makeMotion: @escaping () -> any GardenMotionReading = { GardenMotionSensor() },
         clock: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.audio = audio; self.makeSensor = makeSensor; self.makeMotion = makeMotion; self.clock = clock; permission = audio.permission
        audio.onDeviceChange = { [weak self] in self?.deviceChanged() }
    }
    func requestMicrophonePermission() {
        guard permissionTask == nil else { return }
        permissionTask = Task { [weak self, audio] in
            await audio.requestPermission()
            guard let self else { return }
            permissionTask = nil; permission = audio.permission; lastAudioAttempt = -.infinity
            reconcileAudio(now: clock())
        }
    }
    func configure(connections: [String: [String: WallpaperConnectionSettings]], suspended: Bool, reducedMotion: Bool) {
        self.connections = connections; self.suspended = suspended; self.reducedMotion = reducedMotion
        updateSampling()
    }
    func setConnections(_ connections: [String: [String: WallpaperConnectionSettings]]) {
        self.connections = connections; updateSampling()
    }
    func setConsumer(_ id: UUID, template: String, visible: Bool, animated: Bool) {
        if visible { consumers[id] = (template, animated) } else { consumers[id] = nil }
        updateSampling()
    }
    func removeConsumer(_ id: UUID) { consumers[id] = nil; updateSampling() }
    func inputs(for template: String, screenFrame: CGRect? = nil) -> WallpaperLiveInputs {
        var value = dynamics.value
        if connections[template]?["microphone"]?.enabled != true { value.sound = 0; value.pollen = -1 }
        let isGarden = template == "hinge-garden"
        let settings = connections[template]?[isGarden ? "garden" : "workshop"] ?? .init()
        value.mirrored = !isGarden && settings.mirrorsComposition
        if !reducedMotion {
            if isGarden && settings.sensorMotion { value.parallax = motionDynamics.tilt; value.motionStir = motionDynamics.stir }
            if settings.pointerParallax, let frame = screenFrame, frame.contains(pointer), frame.width > 0, frame.height > 0 {
                value.parallax += SIMD2((pointer.x-frame.midX)/frame.width, (pointer.y-frame.midY)/frame.height) * 1.2
            }
        }
        return value
    }
    func stop() { consumers.removeAll(); stopSampling(); permissionTask?.cancel(); permissionTask = nil }
    isolated deinit { task?.cancel(); metricsTask?.cancel(); permissionTask?.cancel(); audio.stop(); motion?.stop() }

    private var soundSettings: [WallpaperConnectionSettings] {
        guard !suspended, !reducedMotion else { return [] }
        return consumers.values.filter(\.animated).compactMap { connections[$0.template]?["microphone"] }.filter(\.enabled)
    }
    private func updateSampling() {
        showsWorkshopCounts = (connections["the-workshop"]?["workshop"] ?? .init()).showsLiveCounts
        sampleWorkshopQuote(delta: 0)
        guard !suspended, !consumers.isEmpty else { stopSampling(); return }
        if task == nil {
            lid = LidMonitor(makeSensor: makeSensor)
            task = Task { [weak self] in
                while !Task.isCancelled {
                    self?.sample()
                    try? await Task.sleep(for: .nanoseconds(33_333_334))
                }
            }
            metricsTask = Task { [weak self] in
                let provider = MacWallpaperProvider()
                while !Task.isCancelled {
                    let sample = try? await provider.sample(at: .now)
                    guard !Task.isCancelled else { return }
                    self?.battery = sample?.numbers["mac.battery"].map { $0 / 100 }
                    self?.pluggedIn = sample?.numbers["mac.pluggedIn"].map { $0 > 0.5 }
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
        reconcileAudio(now: clock())
        reconcileMotion(now: clock())
        if connections["hinge-garden"]?["garden"]?.showsOneLiners != true { gardenQuote = nil }
    }
    private func stopSampling() {
        task?.cancel(); task = nil; metricsTask?.cancel(); metricsTask = nil
        audio.stop(); lid = nil; battery = nil; pluggedIn = nil; dynamics.suspend()
        motion?.stop(); motion = nil; motionDynamics.reset(); breath = .init(); quoteCycle.pause()
        workshopQuoteCycle.pause()
        lastSampleTime = nil; motionStatus = "Motion sensors are paused."
        lastAudioAttempt = -.infinity; audioStatus = "Sound reactions are paused."
    }
    private func reconcileAudio(now: Double) {
        permission = audio.permission
        guard !soundSettings.isEmpty, isSampling, permission == .authorized else {
            if audio.isRunning { audio.stop() }
            audioStatus = soundSettings.isEmpty ? "Sound reactions are off or paused." : permission.rawValue
            return
        }
        guard !audio.isRunning, now - lastAudioAttempt >= 2 else { return }
        lastAudioAttempt = now
        do { try audio.start(); audioStatus = "Listening locally. Audio is never recorded or saved." }
        catch { audioStatus = "No microphone available. The garden continues quietly; reconnect a microphone to resume." }
    }
    private func deviceChanged() {
        audio.stop(); breath = .init(); lastAudioAttempt = -.infinity; reconcileAudio(now: clock())
    }
    private func sample() {
        let now = clock()
        let delta = min(0.1, max(0, now-(lastSampleTime ?? now)))
        lastSampleTime = now; pointer = NSEvent.mouseLocation
        lid?.read(now: now)
        reconcileAudio(now: now)
        dynamics.sample(now: now, lidAngle: lid?.angle, rms: audio.amplitude(now: now),
                        sensitivity: soundSettings.map(\.soundSensitivity).max() ?? 1,
                        battery: battery, pluggedIn: pluggedIn, daylight: WallpaperLiveInputs.daylight(at: .now),
                        soundEnabled: audio.isRunning && !soundSettings.isEmpty, reducedMotion: reducedMotion)
        sampleMotion(now: now, delta: delta)
        sampleQuote(delta: delta)
        sampleWorkshopQuote(delta: delta)
    }

    private func reconcileMotion(now: Double) {
        let eligible = !suspended && !reducedMotion && consumers.values.contains {
            $0.template == "hinge-garden" && $0.animated && (connections[$0.template]?["garden"] ?? .init()).sensorMotion
        }
        guard eligible, isSampling else {
            motion?.stop(); motion = nil; motionDynamics.reset(); motionStatus = "Motion sensors are off or paused."
            return
        }
        if motion == nil { motion = makeMotion(); motion?.start(); lastMotionSignal = now }
    }
    private func sampleMotion(now: Double, delta: Double) {
        let sample = motion?.read(now: now)
        motionDynamics.sample(acceleration: sample?.acceleration, rotation: sample?.rotation, delta: delta)
        if let motion { motionStatus = motion.diagnostic }
        if sample?.acceleration != nil || sample?.rotation != nil { lastMotionSignal = now }
        if motion != nil && now-lastMotionSignal > 5 {
            motion?.stop(); motion = nil; motionDynamics.reset(); reconcileMotion(now: now)
        }
    }
    private func sampleWorkshopQuote(delta: Double) {
        let settings = connections["the-workshop"]?["workshop"] ?? .init()
        guard settings.showsWorkshopLines else { workshopQuote = nil; workshopQuoteCycle.pause(); return }
        let animated = !suspended && !reducedMotion && consumers.values.contains { $0.template == "the-workshop" && $0.animated }
        let quote = workshopQuoteCycle.advance(delta: delta, next: false, animated: animated, interval: settings.rotationInterval)
        if workshopQuote != quote { workshopQuote = quote }
    }

    private func sampleQuote(delta: Double) {
        let settings = connections["hinge-garden"]?["garden"] ?? .init()
        let animated = !reducedMotion && consumers.values.contains { $0.template == "hinge-garden" && $0.animated }
        let soundEnabled = connections["hinge-garden"]?["microphone"]?.enabled == true
        let next = breath.sample(amplitude: dynamics.value.sound, delta: delta,
                                 enabled: animated && settings.showsOneLiners && settings.changesLineOnBlow && soundEnabled && audio.isRunning)
        guard settings.showsOneLiners else { gardenQuote = nil; quoteCycle.pause(); return }
        let quote = quoteCycle.advance(delta: delta, next: next, animated: animated, interval: settings.rotationInterval)
        if gardenQuote != quote { gardenQuote = quote }
    }
}
