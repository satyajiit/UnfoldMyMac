# Developing UnfoldMyMac

How the app is put together and how to extend it. The living-wallpaper feature has its own guide in [WALLPAPER_ENGINE.md](WALLPAPER_ENGINE.md). Product behaviour is specified in [SPEC.md](../SPEC.md); measured results and the limits of the verification are in [VALIDATION.md](VALIDATION.md).

## Build and test

Requirements: macOS 26 and Xcode 26 with the Metal Toolchain component (`xcodebuild -downloadComponent MetalToolchain`). The package uses Swift tools 6.2 and the Swift 6 language mode; it has no third-party dependencies.

| Command | What it does |
| --- | --- |
| `swift test` | The full suite: Core value types, Kit behaviour on fakes, GPU renders and golden frames |
| `./script/build_and_run.sh` | Release build, packages `dist/UnfoldMyMac.app`, precompiles shaders, signs and launches |
| `./script/build_and_run.sh --build` | The same without launching |
| `./script/build_and_run.sh --shader-check` | Renders every pipeline from shader source and from the precompiled units and requires identical pixels |
| `./script/build_and_run.sh --probe` | Read-only lid-sensor probe |
| `./script/build_and_run.sh --self-test` | `swift test` through the script |
| `./script/check_update_trust.sh` | Runs the real updater requirements against `dist/release` and `dist`: the release app and DMG must be accepted, a dev build rejected |

The packaged executable also understands `--wallpaper-benchmark` (presents every wallpaper scene for eight seconds and reports presented frame rate, worst p95 interval and coverage), `--shader-units` (lists the shader compile units for the precompile step) and the two hook endpoints `--wallpaper-claude-hook` and `--wallpaper-codex-hook`.

Environment variables used by tests and diagnostics:

| Variable | Effect |
| --- | --- |
| `UNFOLDMYMAC_LAUNCH_TIMING=1` | Prints launch-to-window time and per-stage timings |
| `UNFOLDMYMAC_RECORD_GOLDENS=1` | Re-records the golden frame hashes after an intended shader change |
| `UNFOLDMYMAC_ART_ARTIFACTS`, `_CURTAIN_`, `_CURRENT_`, `_PEEKABOO_`, `_WALLPAPER_ARTIFACTS=<dir>` | Tests write rendered frames to that directory for inspection |
| `UNFOLDMYMAC_GARDEN_ARTIFACTS=<dir>` | Writes Hinge Garden's native reference states and aspect variants; add `UNFOLDMYMAC_GARDEN_MOTION=1` for an 22-second 60 fps recording (ffmpeg required) |
| `UNFOLDMYMAC_WORKSHOP_ARTIFACTS=<dir>` | `swift test --filter workshopReferenceFrames` exports day, night, count, lid, power, mirror, still, Retina, portrait, ultrawide and cover fixtures |
| `UNFOLDMYMAC_BENCHMARK_FOREGROUND=1` | Temporarily raises the diagnostic surface above other apps; use when desktop occlusion pauses measurements. Closing the benchmark removes the window |
| `UNFOLDMYMAC_BENCHMARK_TEMPLATE=hinge-garden`, `UNFOLDMYMAC_BENCHMARK_SECONDS=60`, `UNFOLDMYMAC_BENCHMARK_STRESS=1` | Selects a scene, enables the 59 fps / 20 ms performance gate, and optionally supplies scripted physical inputs |
| `UNFOLDMYMAC_SIGN_IDENTITY` | Code-signing identity for the build script (`-` for ad hoc) |

Continuous integration (`.github/workflows/ci.yml`) builds every test target, runs `swift test --skip-build`, packages the app and verifies its signature. Tests that need a Metal device or a window server carry `.requiresGPU` or `.requiresWindowServer` and skip themselves when `CI=true`; the workflow prints what it skipped.

## Package layout

Five SwiftPM targets. `UnfoldMyMacCore` imports Foundation only; `UnfoldMyMacKit` depends on it and holds AppKit, SwiftUI and Metal; the `UnfoldMyMac` executable's `main.swift` only calls `UnfoldMyMacApp.main`. Keep that direction.

`UnfoldMyMacWallpaperExtension` is the macOS 26 wallpaper provider, packaged as a `.appex` inside the app, and its `main.swift` is the same kind of shim: it calls `UnfoldMyMacWallpaperProvider`. Everything it does lives in `Features/WallpaperProvider/` inside the Kit, where it can reach the whole render stack at `internal` visibility, so the desktop and the lock screen run the same code rather than two copies of it. `UnfoldMyMacWallpaperBridge` is a header-only ObjC target holding the reconstructed private protocols, so the Swift side sees them without a bridging header.

The bridge between the two is one-way by construction. `WallpaperHostProxy` has no push channel, so the
extension learns nothing except when the app writes its container file and posts a Darwin notification —
and the extension stamps its heartbeat only while handling one of those. The app therefore keeps talking
to it every four seconds even when it has nothing to send and its own wallpaper switch is off, because
that is the only way it can tell a provider that is rendering from one that stopped. Drop that and the
silence latches: the app reads the old stamp as a dead provider, stops writing, and the stamp stays old —
the lock screen falls back to dashes and the app decides the system wallpaper is free to overwrite.
`WallpaperProviderLinkTests` pins the whole loop.

macOS keeps **two** wallpaper selections per display, and conflating them is the mistake this code is
shaped to prevent. `Index.plist` holds a `Desktop` slot and an `Idle` slot per display; the lock screen and
the screen saver are the same `Idle` slot, chosen in the Screen Saver pane rather than the Wallpaper pane.
A provider selected as the desktop wallpaper therefore fills only the first, and the lock screen goes on
painting an exported still of whatever is in the second. So the heartbeat reports the *roles* the host
actually holds — never a surface count, which cannot tell the two apart — and `WallpaperLockScreenCard`
says which of the two it has and links to the matching pane.

Nothing in the framework names that role. `WallpaperCreationRequestXPC`, dumped on macOS 26.6, is exactly
`size`, `colorSpace`, `scaleFactor`, `directDisplayID`, `isPreview`, `presentationMode`, `systemAppearance`,
`debugBackgrounds`, a cache directory and the choice's payload blob — there is no content type. So
`presentationMode` is the discriminator: `default` is the desktop, `idle` is the screen saver and `locked`
is the lock screen, and the host sets it per surface at acquire (three acquires arriving in the same
millisecond carry `default`, `default` and `idle`). `WallpaperProviderRequest.Role` maps it, an unknown
mode maps to `desktop` because claiming the lock screen wrongly is the failure being prevented, and a
request with no presentation mode at all sets `identifiesDestination` false so the store never reuses a
`CAContext` across two surfaces it cannot tell apart. `WallpaperProviderMirror.describeOnce` dumps the
whole request shape to the log the first time that field goes missing, which is how the above was found.

The heartbeat still cannot answer the question on its own, because a lock-screen surface exists only while
the lock screen is being shown: between unlocking and the next lock there is nothing to report, and
reading that silence as "not chosen for the lock screen" is the same wrong answer in a different place.
`WallpaperSlotIndex` closes that gap by **reading** — never writing — the `Idle` slot out of
`~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`. macOS exposes no public API for the
screen-saver selection, the file is a private format, so every failure to read or understand it returns
nil and the live surfaces decide instead. Writing that file stays forbidden: `WallpaperAgent` owns it in
memory with scheduled flushes, a lost update can drop wallpaper configuration for every display and Space
at once, and `wallpaperexportd` mirrors the damage to the Preboot volume.

The heartbeat also carries the rate the display link was asked for *and* the rate frames actually reached
the screen (`WallpaperProviderSurface` feeds `DisplayLinkFrameDriver.onStats`, and the extension logs
`frames … presented=<n>fps configured=<n>`). Those are different facts. A surface draws one frame in its
initialiser, before the link exists, so a link that never ticks leaves a still on screen that is
indistinguishable from a live scene to anything that only counts surfaces or reads back a configured rate
— and once the link is attached, `nextDrawable` raises, so nothing else can put a frame up. The app reads
the measured rate and calls the difference `.stalled` rather than reporting it as live.

Two things about that target are load-bearing and invisible. It links with `-Xlinker -e -Xlinker _NSExtensionMain`: ExtensionKit requires that Mach-O entry point, and with Swift's `@main` alone the process initialises, logs and exits in milliseconds without ever accepting a connection, while the host reports only `NSCocoaErrorDomain 4099`. And the appex carries its own copy of the Kit resource bundle, because inside it `Bundle.main` is the appex and `BundleResources` resolves shaders and templates relative to that. `script/sign_release.sh` asserts both.

```text
UnfoldMyMac/
  Package.swift
  script/                        build_and_run.sh, compile_shaders.sh, make_icon.sh
  Sources/UnfoldMyMac/main.swift → UnfoldMyMacApp.main
  Sources/UnfoldMyMacWallpaperExtension/main.swift → UnfoldMyMacWallpaperProvider
  Sources/UnfoldMyMacWallpaperBridge/  header-only ObjC: the private wallpaper XPC protocols and CAContext
  WallpaperExtension.plist / .entitlements   the appex's reviewed Info.plist and sandbox entitlement
  Sources/UnfoldMyMacCore/       Identity, Effects, Settings, Design, Wallpaper: value types, contracts, rules
  Sources/UnfoldMyMacKit/
    App/                         UnfoldMyMacApp (CLI modes + launch), AppDependencies, AppController, AppShellModel,
                                 window / menu / status-item / preview-panel / appearance controllers, AppDiagnostics
    Platform/                    system seams and their live implementations: environment, displays, lid sensor,
                                 desktop capture, preferences, file picker, workspace, permission, paths, BundleResources,
                                 HTTP primitives, subprocess runner, update-environment probe
    Rendering/                   the GPU kernel shared by both features
    Shaders/                     Effects/*.metal, Wallpaper/{Common,Emblem,RaceCar,RaceMaterials,GardenGeometry,GardenMaterials}.metal
    DesignSystem/                palette, typography, icons, cards, buttons, NativeSwitch, environment keys
    Features/Effects/            Catalog, Pipelines, Library, Runtime, Presentation
    Features/Wallpaper/          Catalog, Connections, Data, Rendering, Runtime, Presentation
    Features/WallpaperProvider/  the macOS 26 wallpaper provider: runtime bridging to WallpaperExtensionKit,
                                 XPC service and configuration, remote-context surface, readout renderer,
                                 settings view models, and the app↔extension data bridge and its app-side link
    Features/Updates/            Data (feed, download), Verify (signature, SHA-256), Install (mount, stage, swap),
                                 Runtime, Presentation
    Resources/                   Effects/Effects.json, Library/Artworks.json, Artwork, Covers, Fonts, Brand,
                                 WallpaperMarks, Wallpapers/<id>/{template.json, Scene.metal, cover.png?, marks/},
                                 Wallpapers/{Collection,Style}.json
  Tests/UnfoldMyMacCoreTests/
  Tests/UnfoldMyMacKitTests/     + Support/ (fakes, traits, settle helper), Fixtures/ (goldens, v1 templates)
```

Conventions: one type per file, files under 200 lines, `internal` by default with `private(set)` state, `public` only on `UnfoldMyMacApp` and `UnfoldMyMacWallpaperProvider`. Every class is `final`. Owners of system resources implement `isolated deinit`. Blocking I/O lives in actors. Errors are typed (`GPUError`, `EffectSessionError`, `WallpaperError`, `LibraryError`, `BundleResourcesError`, `UpdateError`); tuning numbers are named constants (`EffectTuning`, `GPUTuning`, `WallpaperCanvas`). `BundleResources` is the only place that reads the resource bundle.

## Architecture

Each feature follows the same shape: a **composition root** builds it, a **façade model** exposes the state views read and the commands they send, and single-purpose **collaborators** do the work.

- `AppDependencies.live()` builds the platform services once: preferences store, `SystemEnvironment`, displays, `DesktopSurfaceRegistry`, file picker, workspace, screen-capture permission, `GPUContext` (nil on a Mac without Metal) and a clock.
- `EffectsFeature.make` and `WallpaperFeature.make` build each feature from those services and return `EffectsModel` and `WallpaperModel`.
- `AppController` is a thin `NSApplicationDelegate` over `AppShellModel` (route, effects path, window visibility) and the AppKit controllers: `MainWindowController`, `MainMenuController`, `StatusMenuController` with the pure `QuickMenuBuilder`, `PreviewPanelController`, `AppearanceController`.
- SwiftUI receives the feature models by constructor. Cross-cutting services arrive through `@Environment`: `\.filePicker` (open panels), `\.workspace` (URLs and the pasteboard), `\.coverImages` (decoded cover thumbnails), `\.appInfo` (version, executable path). Views never build panels, never touch `Bundle.main`, `NSWorkspace.shared` or `NSPasteboard`, and never construct capture, sensor or renderer services. Colours come from `@Palette private var palette`, a dynamic property that resolves the palette for the current colour scheme.

Seams with one live implementation and one fake (`Tests/UnfoldMyMacKitTests/Support/EffectsFakes.swift`):

| Protocol | Live | Purpose |
| --- | --- | --- |
| `PreferencesStore` | `UserDefaultsPreferencesStore` | Raw bytes per `PreferenceKey`, with legacy names and one-shot migration |
| `SystemEnvironmentObserving` | `SystemEnvironment` | One `SystemState`: sleep, screen sleep, session, accessibility, power, thermal, display and Space generations |
| `DisplayProviding` | `DisplayEnvironment` | Built-in display, clamshell, display IDs |
| `LidReading` | `LidSensor` | Read-only IOKit lid angle |
| `DesktopCapturing` | `DesktopCapture` | ScreenCaptureKit frames for Frost |
| `EffectHosting` | `EffectHost` | The click-through overlay panel |
| `FilePicking` | `OpenPanelFilePicker` | Open panels |
| `WorkspaceOpening` | `SystemWorkspace` | URLs, System Settings, pasteboard |
| `ScreenCapturePermissionChecking` | `SystemScreenCapturePermission` | Screen Recording state |
| `WallpaperDataProvider`, `WallpaperDesktopImageAccess` | providers, `SystemWallpaperDesktopImages` | Wallpaper data and the system desktop image |
| `WallpaperAudioCapturing` | `WallpaperAudioCapture` | Input-only AVAudioEngine, permission state, scalar amplitude and device changes |
| `ReleaseFeedReading` | `ReleaseFeed` | The published release: `release.json` first, the GitHub API as fallback and notes source |
| `ArtifactDownloading` | `URLSessionArtifactDownloader` | One resumable `URLSessionDownloadTask` per download, as a stream of `DownloadEvent`s |
| `CodeSignatureValidating` | `SecurityCodeSignatureValidator` | Developer ID + notarization + same-identity checks, in process |
| `DiskImageMounting` | `HDIUtilMounter` | Read-only `nobrowse` attach scoped to one closure, with detach escalation |
| `BundleInstalling` | `RenameSwapInstaller` | Writes the handoff and spawns the staged bundle's own signed binary |
| `UpdateEnvironmentProbing` | `BundleUpdateEnvironment` | Where this copy runs, whether it may update itself, free space |
| `ProcessRunning` | `SystemProcessRunner` | The only subprocess seam; three absolute paths, never a shell |

Models are `@Observable`; controllers and models consume each other's state through `Observations {}` rather than callbacks. `SystemEnvironment` debounces display reconfiguration by 150 ms into one generation.

`WallpaperModel` also owns one `WallpaperInputService`. Native scenes opt in with `scene.liveInputs`; visible desktop and preview renderers lease its lid sampler, physical motion sensors, and optional microphone session. Input dynamics are pure Core values; the platform audio callback retains only scalar RMS, and the frame smoother interpolates at display cadence. See the wallpaper engine guide for lifetimes, neutral defaults and the appended uniform layout. `scene.resolution: "native"` removes the default 1920-pixel shader cap for Hinge Garden only.

Persisted keys: `unfoldmymac.settings.v1` (migrates from `luma.settings.v1`), `unfoldmymac.wallpaper.v1`, `unfoldmymac.wallpaper.connections.v1`, `unfoldmymac.updates.v1`. Golden JSON fixtures pin all four payloads; legacy names are removed after adoption.

## Effects catalog

Every native and procedural effect is a row in `Resources/Effects/Effects.json`:

```json
{
  "version": 1,
  "default": "frost",
  "fallback": "veil",
  "reduceTransparencyFallback": "fade",
  "effects": [
    {
      "id": "current", "title": "Current", "subtitle": "…", "detail": "…",
      "symbol": "water.waves", "category": "motion", "tags": ["Calm"],
      "author": "…", "credit": "…", "cover": "Covers/Current",
      "renderer": "metal-pipeline:current", "renderingLabel": "Procedural",
      "capabilities": { "requiresCapture": false, "continuousMotion": true },
      "parameters": [
        { "key": "strength", "title": "Flow energy", "kind": "slider", "range": [0, 1], "step": 0.01, "format": "percent", "default": 1 }
      ]
    }
  ]
}
```

`Resources/Library/Artworks.json` describes the image reveals with nine fields; `EffectAssets` adapts each row to the same entry shape. An image is content, not a renderer subclass.

The only Swift-side registration is `EffectRendererFactories.table`, a map from renderer key (`native:veil`, `native:fade`, `metal-capture:frost`, `metal-pipeline:curtains`, `metal-pipeline:current`, `metal-pipeline:peekaboo`, `art-reveal`) to the code that builds the renderer. `EffectRegistry.builtIn()` binds every manifest entry to its factory, then adds the user's imports. An entry whose renderer this build lacks, a duplicate id or an empty catalog become `diagnostics`, never a crash. `resolve(_:)` returns the entry or the manifest's `fallback` with `substituted` set; the model shows a notice when a saved effect is no longer installed. Reduce Transparency renders `reduceTransparencyFallback`.

Parameters are declarations. `EffectParameters` is a flat key→value blob (`{"strength": 0.42, "reveal": "straight"}`) whose unknown keys survive a save; `strength` and `reveal` are accessors over it. `EffectPreferences.setParameter` clamps through the declaration and coalesces slider writes (250 ms after the last change); choices persist at once. The inspector draws one control per declared parameter (`slider`, `choice`, `toggle`) and never switches on an effect id.

Collections describe the medium: **Glass & Light**, **Image Art**, **Motion & 3D**. Genre, mood and subject are tags; authors are a searchable credit.

### Add an artwork (no Swift)

1. Put an original PNG in `Sources/UnfoldMyMacKit/Resources/Artwork/`. Use a landscape composition with the important content near the centre; displays use aspect fill. Keep a record of its origin, permission and, where applicable, generation prompt.
2. Add an entry to `Sources/UnfoldMyMacKit/Resources/Library/Artworks.json`:

```json
{
  "id": "your-unique-style",
  "title": "Your Style",
  "asset": "YourStyle",
  "reveal": "curved",
  "subtitle": "A short introduction.",
  "detail": "Describe the artwork and how it feels when it opens.",
  "author": "Your name",
  "credit": "Original illustration",
  "tags": ["Illustration", "Calm"]
}
```

`asset` omits the extension. IDs are persisted; never reuse or rename a published id. Reveal keys are `curved`, `diagonal`, `straight` and `burst` (Sculpted, Diagonal, Slide and Burst in the inspector); users may choose any reveal for any image. The artwork supplies its own cover.

3. Run `swift test` and `./script/build_and_run.sh --shader-check`. The catalog tests find every image through the manifest and check covers, complete assembly, transparency, first-frame onset, reversibility, colour and capture capability.

### Add a procedural or native effect

`LidImpactPipeline` provides Glass Fracture and Ink Vortex through one fullscreen encoder and two distinct radial shaders in `LidImpact.metal`. Their factories are `metal-pipeline:fracture` and `metal-pipeline:vortex`; neither requires desktop capture. See [Game wallpapers and radial lid effects](GAME_WALLPAPERS.md) for their behavior and checks.

1. Add an entry to `Effects.json`. An effect that reuses an existing renderer key stops here.
2. For a new Metal renderer, implement `EffectPipeline`: keep the injected `GPUContext`, declare a `SurfaceConfiguration` (pixel format, opacity, clear colour) and encode one frame in `encode(command:pass:size:frame:)`. Ask the context for pipeline states with `gpu.pipeline(.effect("Name"), vertex:fragment:color:)`; units compile once per process and states are cached by every input. `CurrentPipeline` is a small example, `CurtainsPipeline` a mesh. Read extra parameters from `context.parameters["key"]`.
3. Add one line to `EffectRendererFactories.table`: `"metal-pipeline:yours": .metal { _, gpu in try YourPipeline(gpu: gpu) }`, or `.native { _ in YourRenderer() }` for an `NSView`-based renderer. `--shader-check` and the catalog test fail on an entry without a factory and on a factory no entry uses.
4. Only effects that need desktop pixels implement `DesktopFrameSink.receive` and declare `requiresCapture: true`. Follow Frost's ownership path: `CaptureTextureCache`, a completed-handler lifetime per buffer, one mip chain.
5. Add GPU tests: transparent zero, inclusive onset, full coverage, reversible input, resizing, premultiplied edges, frame budget; time-change and Reduce Motion checks for animated effects.

All pipelines receive calibrated closure: 0 is completely clear, 1 complete. Static effects reproduce the same pose for the same input. Animated pipelines use `context.time`, never a private timer; the runtime freezes time while a preview is paused and honours Reduce Motion. Do not create windows, read the lid or start a display link inside a renderer.

## Rendering kernel

`Rendering/` is shared by both features.

- `GPUContext`: one `MTLDevice` and command queue per process, a `ShaderLibraryCache`, a `RenderPipelineCache` and a texture loader.
- `ShaderModule`: a compile unit, an ordered list of `.metal` sources plus a math mode. Effect units come from `Shaders/Effects`; wallpaper units are `Common` + declared modules + the scene's own file.
- `ShaderLibraryCache`: a unit compiles once per process, keyed by the SHA-256 of the exact source and math mode. `script/compile_shaders.sh` asks the built executable for its units and precompiles each into `Shaders/Compiled/<digest>.metallib` when the Metal toolchain is present; at runtime a matching digest loads the library, otherwise the source compiles. Every unit pins `MTLMathMode.fast`, which is also Metal's default.
- `MetalPipeline` / `SurfaceConfiguration`: what a pipeline declares and encodes. `EffectPipeline` fixes the frame type to `EffectContext`; `WallpaperPipeline` uses `WallpaperFrame`.
- `MetalSurfaceRenderer` on a `MetalSurfaceView`: the `CAMetalLayer` surface, bounded in-flight submissions, one cached pass descriptor, identical-frame skipping, a cleared frame on encode failure, occlusion reporting and GPU timing. `DisplayLinkFrameDriver` paces the wallpaper through `CAMetalDisplayLink`; lid effects render on demand.
- `OffscreenRenderer`: stills for covers, the system backdrop, `--shader-check` and tests.

## Runtime behaviour

**Lid input.** `LidMonitor` reads the sensor immediately before each live frame (up to 60 Hz) with no temporal filter. `LidPollingPolicy` sets the idle cadence: 30 Hz while effects are on or a preview runs, 4 Hz while the angle is shown in the menu bar or the window is open, otherwise no timer. Only the poll tick creates the display link. A sensor that stops reading is reopened after two seconds, doubling to one minute; a reading or a wake resets the delay.

**Safety.** `DisplayGate` requires the built-in display, no clamshell and a present sensor; `DisplaySafetyGate` waits 0.5 s of stable availability after an interruption. System or screen sleep suspends the effect; a session switch does not. Capture must target the built-in display and exclude this process; failure is surfaced rather than capturing another screen.

**Calibration.** Physical closure maps activation angle → 0 and 5° → 1. `calibratedClosure` remaps it by `min(raw / completionFraction, 1)`; the default 0.8 finishes the effect at 80 % of travel. Live progress is zero above the activation angle and adds a 0.4 % first pose at the inclusive trigger. Activation is stored in whole degrees (60–180); completion is 0.4–1.

**Preview.** `PreviewController` is a pure state machine (`begin`, `play`, `pause`, `scrub`, `advance`, `end(restoring:)`). A preview uses a temporary effect id and its own parameters without changing the selection, remembers the enabled state from before the first preview, and ends on selection, opening effect settings, leaving Effects, Stop, physical closure, display sleep or display removal. A failed card preview ends the preview and leaves the chosen effect running; a failure of the chosen effect turns effects off.

**Session and capture.** `EffectSession` installs renderers and, only for capture effects, a `DesktopCapturing` service. A new capture waits for the previous teardown; generation tokens reject stale callbacks; `suspend()` keeps the running renderer across a preview so ending it does not rebuild the pipeline. Capture frames arrive on a private queue and only the newest one crosses to the main actor per hop.

**Status.** `EffectRuntime` publishes every observable property only on change and names the *rendered* effect, so Reduce Transparency reports the fallback it actually shows.

## Updating

**What it is.** The app checks GitHub Releases, badges the sidebar, offers a sheet, and on one click downloads, verifies, installs and relaunches. No third-party framework: the package still has zero dependencies. Nothing is fetched until the user asks, and no update path is entered without the user clicking Update Now.

**The feed.** `ReleaseFeed` reads `release.json`, published as a third release asset alongside the DMG and `SHA256SUMS`. It is the primary manifest because it costs no API quota — `/releases/latest/download/` is a redirect, not an API call — and because it carries `minimumMacOS`, which the GitHub API cannot report. The API is the fallback and the source of release notes. Both share `HTTPConditionalCache`, so a 304 is free against the 60-per-hour unauthenticated limit that `GitHubProfileClient` also spends.

**Cadence.** `UpdateModel.run()` waits 8 s after launch, then wakes every 15 minutes to ask whether a check is due: 6 h after a success, 15 min after a failure, jittered ±30 min, never more than once an hour. The wait is sliced rather than one long sleep, because a sleep deadline is not extended across system sleep and a single six-hour wait fires late after a night with the lid closed.

**Quiet in the background, always answers a click.** Every result passes through `UpdatePolicy.next(after:trigger:…)`, which takes the trigger as an argument. A failed automatic check returns `.idle` and leaves its message only in the retry schedule; a failed manual check returns `.failed`. `.failed(.download/.verify/.stage)` is therefore unreachable except from a path the user started. `UpdateModel` is the only writer of `state`.

**The kill switch.** `BundleUpdateEnvironment.eligibility()` runs cheapest-first, first match wins, and any verdict other than `.eligible` ends in `.unsupported` before a single request: an unparseable `CFBundleShortVersionString`, a parent directory named `dist`, a read-only volume, an `/AppTranslocation/` path, a build that fails our own requirement, or an install root we cannot create a directory in. A `dist/` build reports `developmentTree`; a copy of one elsewhere reports `developmentBuild`. Neither ever touches the network.

**Verification.** `SecurityCodeSignatureValidator` pins the Developer ID Application leaf OID, the Developer ID CA, team `WW382UC8JD` and `notarized`, and additionally requires the candidate to satisfy the running app's own designated requirement. Team OU alone is not enough: an Apple Development certificate carries the same OU, so the obvious requirement string accepts a dev build. The DMG's requirement omits the `identifier` clause, because a disk image's signing identifier is derived from its filename. `script/check_update_trust.sh` asserts all of this against the real signed artifacts.

The order is load-bearing: SHA-256 against `SHA256SUMS`, then the **DMG's signature before `hdiutil attach`** — so the kernel is never asked to parse an image we did not sign — then the app on the read-only mount, reading its `Info.plist` through `kSecCodeInfoPList` so version and `LSMinimumSystemVersion` come from bytes the signature covers, then the staged copy after `ditto`, then the installed bundle after the swap.

**Install.** In-place replacement is rejected because `ShaderLibraryCache`, `Effects.json`, templates and fonts all load lazily by bundle path; a swap under a live process breaks a resource twenty minutes later with nothing pointing at the updater. Instead the staged bundle's own signed binary is re-executed as `--install-update`, staging in `<installRoot>/.UnfoldMyMac-update-<uuid>/` on the target's volume. The helper `setsid()`s, re-verifies, waits for the old PID (confirming the path via `proc_pidpath` against PID recycling), and exchanges the two paths with `renamex_np(…, RENAME_SWAP)` — one syscall, no instant at which the app is missing, and rollback is the same call again. It relaunches with `open <path>`, never by bundle identifier. Same path plus same designated requirement means the Screen Recording and Microphone grants survive; an update must never relocate the app.

**Failure reporting across a process death.** `handoff.json` is the state: `pending`, `installed` or `rolledBack` with a reason. The next launch reads it, and `UpdateSweeper` removes stale downloads, mount points and staging directories.

**Diagnostics.** `--update-requirements` prints both requirement strings plus this copy's eligibility verdict and bundle path; `script/check_update_trust.sh` runs it against `.build`. Storage is `~/Library/Application Support/UnfoldMyMac/Updates/` — at most one version directory at a time, ~1 KB between sessions.

## Imported images

**Add image** asks the injected `FilePicking` service for a file. `ImageFiles` validates a regular image up to 50 MB and 200 megapixels, applies orientation, downsamples to at most 4096 px on the longest side, flattens transparency over a dark matte and writes an opaque sRGB PNG without the original metadata; animated formats use their first frame. Decoding runs off the main actor.

`ArtworkLibrary` keeps the copies and an atomic `library.json` in `~/Library/Application Support/UnfoldMyMac/Artwork/` under UUID filenames. A failed import rolls back its copy; a corrupt index is reported, never overwritten; a missing copy keeps its entry and reports a renderer error so the user can remove it. Removing a design deletes only the app's copy and settings, and selects the catalog fallback if it was the chosen effect. Title and author are editable in Customize → Artwork.

Cover thumbnails decode off the main actor at 720 px into an 80-item `CoverImageStore` provided through `\.coverImages`. Generated covers are labelled as cover art; Preview renders the real effect.

## Design system and navigation

Use `ContentCard`, `EffectTile`, `NativeSwitch` (an `NSSwitch` at its native small size with an explicit accessibility identifier), `ParameterRow`, `StatusIndicator`, `SecondaryTextStyle` and `UnfoldMyMacButtonStyle`. The button style paints its label explicitly: white on opaque blue for primary actions, primary text on glass for secondary ones, secondary text on an opaque card when disabled; secondary glass falls back to an opaque surface under Reduce Transparency. `UnfoldMyMacType` registers and vends Space Grotesk; `UnfoldMyMacIcon` is the SF Symbols vocabulary. Branding lives in `Resources/Brand`; `make_icon.sh` derives the `.icns` sizes and the 256 px sidebar mark from the logo. The packaged app's Dock tile is its `.icns`; only an unbundled run sets `applicationIconImage`, after the window is up.

`AppShellModel` owns `route` and `effectsPath`. Routes are Lid Effects, Dynamic Wallpapers, Creative Scenes, and Settings; both desktop-content routes share the wallpaper engine. `EffectsFeatureView` holds a `NavigationStack` whose only destination is Effect settings (lid timing, menu-bar angle, permissions, diagnostics); global Settings holds appearance, accessibility status and app information. Preview is an action on each `EffectTile` with a floating `PreviewControls` panel; there is no preview route. `FeaturePage` puts the heading and content in one scroll area and shows a compact title in the toolbar once the heading scrolls away; Lid-effect and wallpaper categories pin under it. Wallpaper and scene cards open a `WallpaperDetailPage`; data feeds and live rendering begin only when its preview is visible or a design is applied. Closing the window keeps the process alive; the Dock icon reopens it.

## Tests

- `Tests/UnfoldMyMacCoreTests`: value types, schema, rules, migrations. Runs anywhere.
- `Tests/UnfoldMyMacKitTests`: models on fakes, providers behind `URLProtocol`, GPU renders, golden frames (62 SHA-256 hashes over every effect and wallpaper at fixed poses in `Fixtures/golden-frames.json`), input/capture lifecycle, window and panel behaviour.
- `Support/`: `EffectsFakes.swift` and `makeModel(...)`, `UpdateFakes.swift` (feed, downloader, validator, mounter, installer, environment), `TestTraits.swift` (`.requiresGPU`, `.requiresWindowServer`, tags `.gpu`, `.window`), `settle(timeout:until:)` for queued main-actor work, `TestGPU.context()`.
- Updater tests are pure: `UpdatePlan`, `UpdatePolicy`, `AppVersion`, `ChecksumManifest` and the `UpdateError` copy meta-test need no fakes; the Kit side drives the install flow on `UpdatePaths(root:)` pointed at a temporary directory, never the real Application Support. The highest-value assertion is that an ineligible environment makes no network request at all.
- Tag any new test that touches Metal, `NSWindow`, `NSScreen`, `ImageRenderer` or `NSHostingView`, otherwise it will fail on the CI runner.

## Product identity

`AppIdentity` owns the visible name, UnfoldMyMac, and the bundle identifier `com.unfoldmymac`; the executable, bundle, icon, Info.plist and code-signing identifier follow it. Window autosave uses `UnfoldMyMacMainWindow` (migrated from `LumaMainWindow`); artwork storage migrates from `~/Library/Application Support/Luma/Artwork/`. macOS may ask for Screen Recording again after an identifier change.

## Discovery metadata

Discovery metadata is shared by the native collection pages and design details. Internal research, generation prompts, and review screenshots stay in ignored local directories.

Templates and effect manifests can add an optional `metadata` object, shared through Core's `ContentMetadata`. Existing IDs, template schema versions, settings, and connections do not migrate. Example:

```json
{
  "metadata": {
    "version": 1,
    "collection": "scenes",
    "overview": "A **tiny world** that responds to your MacBook.",
    "sections": [{ "title": "Make it yours", "body": "Choose your atmosphere in Customize." }],
    "authors": [{ "name": "Creator", "role": "Design", "url": "https://example.com", "logo": "CreatorMark" }],
    "relatedBrands": ["Codex"],
    "banner": "EditorialBanner",
    "badge": "New"
  }
}
```

`collection` is `wallpapers` by default or `scenes`. Keep the original `category` for subcategories, declared in `Collection.json`. Creator logos and related-product marks resolve from the template's `marks/` folder, then shared marks; banners resolve from the template's PNG assets. Missing artwork uses the collection banner, and missing creator logos use a person symbol. All bundle access stays in `BundleResources`.

Capabilities come from runtime declarations through `WallpaperDiscovery`, not from promotional tags or related brands. A new host feature extends `ContentCapability` and its mapping. The metadata is size-bounded and validated. Description bodies support inline Markdown and paragraphs under structured headings; links only open HTTPS destinations through the injected workspace. Cover-cache identity excludes editorial metadata.

Effect parameters can declare an optional `group` string for inspector sections. Legacy parameters use Appearance, with reveal choices under Motion & reveal. Rendering still reads the original parameter keys.

Run native discovery review with `UNFOLDMYMAC_DISCOVERY_ARTIFACTS=/tmp/discovery swift test --filter discoveryNativeLayoutsAndListSwitch`. Window captures use the macOS screenshot utility because split-view content is hosted in sibling AppKit surfaces. Without the export variable, the test still exercises geometry and the native grid/list control.
