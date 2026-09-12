# Living wallpapers

The wallpaper feature puts a Metal scene on every display, below the desktop icons, and feeds it live data from the Mac and from local developer tools. It is a separate feature beside the lid effects with its own preferences, desktop surfaces, connections and previews. This guide covers the engine, the template format and how to add scenes, shaders and data sources. See [DEVELOPING.md](DEVELOPING.md) for the package and [VALIDATION.md](VALIDATION.md) for measured results.

## Collection

| Template | Rendering | Data |
| --- | --- | --- |
| Pulse | Lit 3D chrome sphere and ring, orbiting particles | CPU drives motion; memory tints the material; live CPU, memory estimate and power label |
| Claude Current | Rotating ceramic sculpture, recessed groove, orbiting lights | Retained local sessions, token totals including cache, recent activity and optional working/waiting/finished hooks |
| Daydream | Artwork, glass refraction, drifting particles, typographic stickers | Mac activity modulates distortion; a tool connection supplies the live label and status |
| Codex Foundry | Twisting ceramic accelerator ribs, circuits, chips, light packets and a central beam | Local Codex sessions as "side quests", indexed tokens as "tokens snacked", recent activity, rotating jokes |
| Grok Event Horizon | Tilted volumetric accretion disk, lensed photon crown, starfield, jets and embers | Wallpaper-session "hot takes delivered" and "minutes unsupervised", rotating jokes |
| GitHub After Hours | Floating green city, illuminated towers, packet traffic and orbital halo | Public repositories, followers and push events from the latest 100 public events; profile setup |
| Codex Mission Control | Cobalt robot, blinking expression, status lights and orbiting cards | Codex lifecycle hooks: working, awaiting approval, completed, interrupted, idle; turn and tool counts |
| Lights Out | Procedural open-wheel car, moving track, spinning wheels and five-light start sequence | Simulated laps and elapsed wallpaper-session minutes; original F1 mark |
| GTA VI — Vice City Countdown | Official Jason and Lucia artwork, original logo, camera drift and foreground embers | Local calendar days until November 19, 2026; official release link |
| Aurora Observatory | Tilted textured Earth and layered polar auroral curtains | NOAA OVATION spatial forecast and planetary Kp, refreshed every five minutes |

Product marks (Codex, Grok, GitHub, F1, Rockstar) are drawn in a separate untinted pass from their original files. Codex reads local index metadata only; Grok's counters are labelled *wallpaper session · just for fun*. Neither binds CPU or memory. Codex and Grok accept the optional tool feed for live `tool.status` text and `tool.value` intensity (0–100) and return to their own captions when it is missing or stale.

**Using it.** Select a card to preview it. **Use wallpaper** applies the selected scene to every connected display and hands macOS a matching still for its menu-bar sampler. Previewing another scene leaves the applied one running. **Stop**, also in the menu bar, closes the desktop surfaces and restores the previous system wallpaper. **Set up / Configure** on a card holds that template's connections; required setup opens from **Use wallpaper** before applying. **Playback settings** holds the 30/60 fps choice and the personal background image (downsampled to at most 2560 px and copied into app storage). Imported templates get **Rename…** and **Remove** on their card.

## Architecture

```text
AppDependencies.live() → WallpaperFeature.make
  WallpaperModel                 façade: the state views read and the commands they send
    WallpaperCatalog             templates, lint warnings, imports, rename/remove
      WallpaperTemplateRegistry  bundled folders (WallpaperTemplateLoader) + the user's library (WallpaperTemplateLibrary),
                                 Collection.json and Style.json
      WallpaperTemplateSchema    Core: size cap → version gate → migration → open-enum normalisation → decode → rules → lint
      WallpaperAssetResolver     the template folder first, then the shared Artwork and WallpaperMarks folders
    WallpaperCoverStore          gallery covers: memory → the folder's cover.png → disk cache → one offscreen render at a time
    WallpaperPipelineFactory     the only place that turns a template into a GPU pipeline
    WallpaperPreferencesController  unfoldmymac.wallpaper.v1
    WallpaperPlaybackPolicy      user choices + SystemState → WallpaperPlayback (fps, sampling, stillness)
    WallpaperConnectorRegistry   one WallpaperConnectorDescriptor per connector
      WallpaperProviderAssembly  template + saved connections → providers
    WallpaperDataCoordinator     the desktop and preview WallpaperDataHubs
      MacWallpaperProvider, ClaudeWallpaperProvider, CodexWallpaperProvider, CodexActivityProvider,
      GitHubWallpaperProvider, CountdownWallpaperProvider, AuroraWallpaperProvider, WallpaperSessionProvider,
      WallpaperJSONProvider, WallpaperHTTPProvider
    WallpaperDesktopCoordinator  one WallpaperDesktopWindowController per display
      WallpaperSurfaceModel      template, style sheet, snapshot and per-display RenderStats the windows observe
      WallpaperDesktopWindowController  AppKit window + WallpaperSurfaceRenderer + NSHostingView(WallpaperLayersRoot)
        WallpaperSurfaceRenderer DisplayLinkFrameDriver + WallpaperFrameSmoother + presentation stats
        WallpaperPipeline        scene pipeline state, textures and the emblem pass
        WallpaperLayers          bound text, counters and stickers
    WallpaperSystemBackdrop      the matching system still and the journal that restores the original image
    WallpaperBackgroundImporter  the personal background image
    WallpaperScene               the in-window preview: WallpaperMetalView + WallpaperLayers
    WallpaperSetupController     per-template configuration drafts and apply readiness
      WallpaperTemplateSetupSheet  one WallpaperConnectorFormView per requirement
```

`UnfoldMyMacCore/Wallpaper` holds Foundation-only value types, the schema, validation, JSON framing, usage accounting and the playback policy. Providers live under `Features/Wallpaper/Data`; rendering, runtime and presentation have their own folders. No provider reads SwiftUI state. No template creates a window, reads a file, starts a timer or performs a network request. Views take files from `@Environment(\.filePicker)`, the pasteboard from `@Environment(\.workspace)` and the bundled style sheet from `catalog.style`; every wallpaper control has an accessibility label and identifier (`wallpaper.settings`, `wallpaper.import`, `wallpaper.apply`, `wallpaper.stop`, `wallpaper.template.<id>`, `wallpaper.configure.<id>`, `wallpaper.more.<id>`).

### Rendering and pacing

`DisplayLinkFrameDriver` drives each desktop window through `CAMetalDisplayLink` with a triple drawable pool and a preferred frame latency of two. It renders the supplied drawable at its target timestamp, so there is no synchronous drawable acquisition and no per-frame concurrency hop, and it pauses while the window is fully occluded. The shader canvas is capped at 1920 px on its longest edge; text is composited at native resolution. Scene shaders are compile units of the shared `ShaderLibraryCache`, so a scene compiles once per process and the emblem pass is one cached pipeline state. The performance label reports presented frames, their 95th-percentile interval and mean GPU time; GPU completions alone do not count as displayed frames.

### Data flow

Sources are sampled independently (Mac and session every second, Claude and Codex every two seconds) and interpolated on the GPU with animated number transitions in the text layers. A snapshot becomes a `WallpaperPose` (energy, four clamped channels, optional grid) once per change, never per frame. Only namespaces bound by the applied and previewed templates run. The applied desktop and a different preview have separate data hubs, so their values never mix; previewing the applied template reuses its snapshot. Switching previews cancels the previous preview's providers.

### System backdrop

`WallpaperSystemBackdrop` renders an aspect-correct still with the scene's shader and hands it to `NSWorkspace.setDesktopImageURL`, so the menu bar samples a matching image. Before changing anything it journals the original image URL and options per display under `Wallpaper/SystemBackdrop/`. Stop and Quit restore the original; a wallpaper the user chooses later in System Settings is left alone. Records survive restarts and are kept for disconnected displays and other Spaces, so their originals are restored when they reappear. A record remembers template, image, size and time, so a later launch reuses the still instead of rendering it again; each display keeps its six newest companions and the rest are pruned with their files.

### Playback policy

Low Power Mode or serious thermal pressure limits animation to 30 fps. Reduce Motion shows a still pose with live data at 1 Hz. Display sleep and an inactive user session pause rendering and sampling. An activity assertion prevents App Nap while a desktop scene animates. Closing or minimising the app window stops its preview; an applied desktop continues. Display changes rebuild the desktop surfaces.

Frost's ScreenCaptureKit filter excludes this process but re-admits the applied wallpaper windows by ID, so the wallpaper stays visible under Frost while the app's own controls and overlays stay out of the capture.

## Template reference

Every bundled scene is one folder under `Sources/UnfoldMyMacKit/Resources/Wallpapers/<id>/`:

```text
<id>/
  template.json     the template (version 2)
  Scene.metal       the scene's fragment shader, declared by the template's "scene" block
  cover.png         optional gallery cover; without it the app renders one from the shader
  marks/<Name>.png  optional product marks; <Image>.png artwork; both override the shared folders
```

`Collection.json` lists the gallery sections (`mac`, `ai`, `code`, `art`, `play`, `space`); a template with an unknown category lands in "More scenes". `Style.json` holds the typography every template starts from. Flat `<name>.json` files beside the folders are still read.

### `template.json`

Version 1 documents still load; they are migrated in memory to the same template. Colours are decimal RGB integers (`0xRRGGBB` in Swift).

| Field | Type | Notes |
| --- | --- | --- |
| `version` | 1 or 2 | |
| `id`, `title`, `subtitle`, `author`, `tags` | strings | `id` is persisted; never reuse or rename a published one |
| `category`, `order`, `credit` | string, int, string | gallery section, sort order (0–10000), attribution shown under the preview |
| `shader` | string | an installed scene id; defaults to `id` when the template declares its own `scene` |
| `scene` | object | `source` (`Scene.metal`), `fragment`, optional `dependencies`, `mathMode` (`fast`, `relaxed`, `safe`), `params` (up to eight `{key, default, min, max}`) |
| `accent`, `background` | colour | theme colours passed to the shader |
| `image`, `allowsCustomBackground` | string, bool | bundled artwork for texture 0; whether the personal background may replace it |
| `reactiveMetric`, `reactiveScale`, `idleEnergy` | `ns.key`, number, 0–1 | the primary GPU signal, its scale, and the energy shown before the first sample |
| `channels` | up to 4 `{metric, scale, smoothing}` | four more smoothed signals for the shader |
| `reactiveSmoothing` | 0.5–20 | easing rate of the primary signal in 1/s (default 4) |
| `params` | `{key: value}` | values for the scene's declared parameters, delivered as `u.params[0..1]` |
| `layers` | 1–32 | see below |
| `emblem` | `{asset, x, y, width}` | an original product mark on the fitted canvas |
| `setup` | up to 5 `{kind, required}` | connections the template needs; `kind` is an open connector id |
| `canvas` | `{width, height}` | design canvas, 1600×1000 by default (200–8000, aspect 0.5–4) |
| `style` | object | overrides for `Style.json`: `boldFont`, `mediumFont`, `boldThreshold`, `captionThreshold`, `captionTracking`, `displayTracking` |
| `cover`, `reduceMotionPose` | `{time, energy, channels}` | the pose covers and system stills render at; the frozen time under Reduce Motion |
| `fpsCeiling` | 1–120 | caps preview and desktop playback |
| `countdown`, `informationURL`, `gridBinding` | | see the data sources below |

**Layers.** Each layer is `text`, `metric` or `sticker` with `content`, an optional `binding` to any provider key, a `format` (`text`, `integer`, `compact`, `percent`, `gigabytes`), position and `width` as fractions of the canvas, `size` as a fraction of canvas width, `color`, `rotation`, and optional `height`, `maxLines` (1–6), `phrases` (1–12 lines of at most 160 characters) with `cycleSeconds` (4–60). Missing or stale numbers show an em dash; text falls back to `content`. Phrases rotate on the one-second data cadence and hold the first phrase under Reduce Motion. A kind or format this version does not know renders as text with a warning.

```json
{
  "id": "build-count", "kind": "metric", "content": "—",
  "binding": "build.jobs", "format": "integer",
  "x": 0.08, "y": 0.70, "width": 0.25, "size": 0.05,
  "color": 16774117, "rotation": 0
}
```

**Validation.** `WallpaperTemplateSchema.decode` caps files at 128 KB and rejects, naming the field: versions outside 1–2, ids with path separators, colours above `0xFFFFFF`, a `reactiveMetric` without a namespace (`cpu` instead of `mac.cpu`), layers that leave the canvas (`x + width > 1`), duplicate ids, layers or setup kinds, more than four channels or eight params, invalid scene blocks, unknown math modes and every non-finite or out-of-range number. A *required* connector this version does not have rejects the template. Warnings, shown on the card with a tooltip: an optional unknown connector, an unknown category, a namespace no connector feeds, a `params` key the scene does not declare, and text below a 3.0 contrast ratio against the background.

**Emblem.** `{"asset": "Codex", "x": 0.072, "y": 0.102, "width": 0.074}` places a mark on the same fitted canvas as text; height follows the file's aspect ratio. Files live in the template's `marks/` or the shared `Resources/WallpaperMarks/`. Invalid names, missing files and out-of-canvas placement are rejected. The pass is shared by every scene.

### Add a template

1. Copy a folder from `Resources/Wallpapers/`.
2. Give `template.json` a unique `id`, copy, a `category` from `Collection.json` and an `order`.
3. Keep an inline `scene` block with your own `Scene.metal`, or drop `scene` and name an installed scene in `shader` (the bundled ids equal the template ids). Choose colours, an optional artwork and the reactive binding.
4. Add layers. Keep important copy away from the menu bar, Dock and desktop icons.
5. Rebuild, or import the JSON from the Wallpaper page. Imports keep their original bytes under `~/Library/Application Support/UnfoldMyMac/Wallpaper/Templates/<uuid>.json`, indexed by `library.json`; they may name a bundled scene but may not ship shader source.

No Swift changes, registry entries or UI branches are needed.

### Scenes and shaders

A scene shader lives beside its template and is declared by the `scene` block:

```json
"scene": {
  "source": "Scene.metal", "fragment": "lightsOutFragment",
  "dependencies": ["RaceCar", "RaceMaterials"], "mathMode": "fast",
  "params": [{ "key": "spin", "default": 0.5, "min": 0, "max": 1 }]
}
```

The registry registers it in the GPU-free `WallpaperShaderCatalog` under the template's `shader` id; the `GPUContext` compiles and caches it and `script/compile_shaders.sh` precompiles it. Other templates reuse it by naming that id. `dependencies` names modules in `Sources/UnfoldMyMacKit/Shaders/Wallpaper/`; `Common` is always first and `Emblem`, `RaceCar` and `RaceMaterials` ship.

Shaders receive `WallpaperUniforms`: viewport size, time, primary energy, accent and background colours, the four channels and the eight declared parameters. Texture 0 is the template image or a one-pixel fallback; texture 1 is the bound scalar grid. Time freezes under Reduce Motion. Use a stable zero-time pose, bounded work, aspect-safe composition and alpha 1. Add tests for time and metric changes, deterministic frozen frames, resize and frame budget. Procedural and image shaders are supported; mesh import and executable plugins are not.

## Connectors and providers

Every data source is one `WallpaperConnectorDescriptor` in `WallpaperConnectorRegistry.standard`: its id (the `setup` kind), title, the namespaces it feeds, whether it is implicit (`mac-metrics`, `session` and `aurora` attach whenever a template binds their namespace), its form (`toggle`, `file`, `url`, or a bespoke `githubProfile`, `codexHooks`, `claudeCode`), `validate` and `makeProvider`. `WallpaperProviderAssembly` builds a template's providers from that table; the setup sheet renders one form per requirement; `WallpaperSetupController` stores configurations per template in `unfoldmymac.wallpaper.connections.v1`, stages edits in a draft, and commits or cancels them. Apply checks readiness in the model, so hiding a button cannot bypass setup.

Bundled kinds: `github-profile`, `codex-activity`, `codex-history`, `claude-code`, `tool-file`, `http`. A template may name a connector a later version adds: required → rejected, optional → a warning.

```json
"setup": [
  { "kind": "github-profile", "required": true },
  { "kind": "tool-file", "required": false }
]
```

### Add a provider

Implement `WallpaperDataProvider` as an actor with a stable namespace, a polling interval and `sample(at:)` returning immutable `WallpaperDataSample` values; then add one descriptor. Templates bind to keys such as `build.jobs` without knowing the source. Slow or remote sources keep their last good sample and retry through `RefreshSchedule`; folders of small hook records go through `ActivityFileCache`, which decodes a file only when its modification date changes. A connector with a plain form is one descriptor and no other Swift; only a bespoke form adds a view.

```swift
actor BuildProvider: WallpaperDataProvider {
    nonisolated let id = "build"
    nonisolated let interval: TimeInterval = 5
    func sample(at date: Date) async throws -> WallpaperDataSample {
        let jobs = try await readBuildService()
        return .init(timestamp: date, numbers: ["build.jobs": Double(jobs)],
                     text: ["build.status": "BUILDING"], status: "Live")
    }
}
```

`WallpaperHTTPProvider` takes a `URLRequest`, namespace, interval and `URLSession` for APIs that return the snapshot format. It requires HTTPS (HTTP only for loopback), a five-second timeout, a successful status, freshness, and a 64 KB body. Credentials belong to the connector, never to template JSON.

### Tool file

For scripts and existing tools, connect a JSON file and replace it atomically:

```json
{
  "timestamp": "2026-09-12T05:00:00Z",
  "numbers": {"tool.value": 42},
  "text": {"tool.label": "BUILD STATUS", "tool.status": "ALL SYSTEMS GO."},
  "status": "Live"
}
```

Write the current UTC timestamp on every update (ISO 8601, with or without fractions). A snapshot older than 15 seconds is stale and stops supplying live values. At most 128 values, finite numbers, strings of at most 256 characters, and no keys outside the provider's namespace. A working example: `python3 Examples/Wallpaper/live_load.py --output /tmp/mac-load.json`, then connect that file.

## Data sources

**Mac and session.** Mach and IOKit metrics every second; the session provider supplies monotonic elapsed time and playful counters that reset when it starts again.

**Claude Code.** The default source is `~/.claude/projects`; a project folder can be chosen. The reader takes only the usage fields from retained JSONL logs; prompts, responses and tool content are neither displayed nor stored. A session counts once it has an assistant usage record; subagent usage joins its parent session. Tokens include input, output, cache read and cache creation, as local retained history, not billing or quota. A response's message id deduplicates streaming revisions. New files are discovered every 10 seconds in one directory walk; recently modified files are checked every cycle; reads are limited to 32 MB per cycle with a cancellation check per file. Appended records join the ledger incrementally; a rotated, truncated or deleted file rebuilds it. A large history indexes progressively and the scene labels its counters as *counts so far*. A property-list cache under `Wallpaper/ClaudeCache-v1/` keeps usage metadata and committed line offsets only, flushed at most every five seconds per growing file. Bounds: 50,000 files, one million records, 4 MB per line. For exact **Working / Needs you / All yours** states, **Claude Current → Configure → Live work states** copies a hooks block for `~/.claude/settings.json` that calls this executable with `--wallpaper-claude-hook`; it records session id, event and timestamp only, never blocks Claude, and expires after five minutes without an event.

**Codex history.** The provider finds the highest numbered `~/.codex/state_N.sqlite`, opens it read-only with a short busy timeout and keeps one connection and one prepared statement, reset after each row so no read lock outlives a poll. It aggregates the count, non-negative `tokens_used` and recent `updated_at` of top-level sessions from the `cli`, `vscode` and `exec` sources, excluding serialized subagent rows; it never selects titles, messages, prompts or rollout content. "Side quests" are indexed sessions; "tokens snacked" is the sum of retained token metadata: local history, not billing. Recent means an index update within five minutes. The connection can be disabled from Codex Foundry's Configure sheet.

**Codex lifecycle hooks.** **Codex Mission Control → Set up → Install hooks** merges observational commands into `~/.codex/hooks.json`, preserving other handlers and saving `hooks.before-unfold-<UUID>.json` first; installation is idempotent and leaves malformed or symlinked files alone. Review and trust the hooks in Codex `/hooks`; the installer does not bypass that step. The `--wallpaper-codex-hook` endpoint reads stdin JSON, discards prompts, commands and responses, and writes session, turn and tool identifiers, timestamps and counters to `Wallpaper/CodexActivity/` with per-session locks and atomic replacement. It always returns `{}` and never steers a turn. Waiting takes priority over working, then the newest terminal state; work state expires after five minutes; duplicate ids count once within a 128-id window; late tool callbacks cannot reactivate a finished turn.

**GitHub.** **GitHub After Hours → Set up** takes a username, `@handle` or profile URL and finds the public profile without a token; **Save changes** configures without applying, **Disconnect profile** removes the connection. `GitHubProfileClient` calls the public users and events endpoints at most once per five minutes per scene, two requests per refresh (24 per hour), with a five-second local heartbeat. `If-None-Match` from `HTTPConditionalCache` turns an unchanged response into a 304 that does not count against the rate limit. A failed refresh keeps the last profile on screen and retries after one minute; a failed events request keeps the profile counts and omits the push value. "Public push-ups" counts distinct `PushEvent` ids among the latest 100 public events, which GitHub may delay by 30 seconds to six hours. No default username ships. References: [users](https://docs.github.com/en/rest/users/users), [events](https://docs.github.com/en/rest/activity/events), [rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api).

**NOAA space weather (Aurora Observatory).** `NOAAWeatherClient` owns HTTPS and bounded decoding, `NOAAWeatherStore` shares in-flight requests and five-minute results, and the provider owns the five-second heartbeat, labels and remarks. Each feed fails independently; the last valid data stays visible with a stale label; a first-use failure shows "Waiting for NOAA". Forecast age is measured from NOAA's observation timestamp (stale after two hours), Kp after six. The forecast grid arrives as a `WallpaperScalarGrid` (immutable revision, up to 512×512 finite values in 0–1, at most two per sample); `gridBinding` selects it for texture slot 1 and `WallpaperGridTexture` uploads only on a new revision. The scene is an artistic interpretation, not a visibility forecast; no location permission is requested.

**Countdown (GTA VI).** `countdown` gives a year, month, day and HTTPS `sourceURL`. The provider computes local calendar days, updates after sleep and time-zone changes, and switches to "Release day" and "Scheduled release date reached". The date is bundled and editable in the template, not scraped. `allowsCustomBackground: false` keeps the official art.

**Lights Out.** `scene.laps` counts completed 18-second animation cycles and minutes use the session timer; the scene labels itself as an animated fan simulation. Geometry, materials and composition are separate Metal sources (`RaceCar`, `RaceMaterials`, the template's `Scene.metal`).

## Verification

```sh
swift test
./script/build_and_run.sh --build
./script/build_and_run.sh --shader-check
./dist/UnfoldMyMac.app/Contents/MacOS/UnfoldMyMac --wallpaper-benchmark
UNFOLDMYMAC_WALLPAPER_ARTIFACTS=/tmp/wallpaper-frames swift test --filter wallpaper
```

The benchmark presents each complete scene on the desktop for eight seconds and reports presented frame rate, worst p95 frame interval and full-surface coverage without changing saved settings. Run it with the normal app closed. Tests cover schema validation and migration, rotating copy and Reduce Motion, Codex aggregate metadata, presentation timing, duplicate streaming usage, partial and oversized lines, append/truncate/rotate/delete, cache resume, provider cancellation, HTTP status/body/freshness, real Mac metrics, preview/apply separation, desktop level and teardown, deterministic rendering, reactivity and GPU budget. Results are in [VALIDATION.md](VALIDATION.md).

## References

Desktop hosting uses public [CoreGraphics window levels](https://developer.apple.com/documentation/coregraphics/cgwindowlevelkey), [CAMetalDisplayLink](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink) and [NSHostingView safe-area control](https://developer.apple.com/documentation/swiftui/nshostingview/safearearegions); Apple's [Metal display-link sample](https://developer.apple.com/documentation/metal/achieving-smooth-frame-rates-with-a-metal-display-link) describes the pacing model. The [LiveWallpaperMacOS](https://github.com/thusvill/LiveWallpaperMacOS) project (GPL-3.0-or-later) was reviewed for hosting concepts; no code was copied. Claude integration follows the official [hooks reference](https://code.claude.com/docs/en/hooks) and [usage monitoring](https://code.claude.com/docs/en/monitoring-usage) documentation.
