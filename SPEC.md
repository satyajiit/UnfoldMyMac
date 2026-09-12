# UnfoldMyMac specification

What the app does and the rules it keeps. Implementation notes are in [MacDuo/DEVELOPING.md](MacDuo/DEVELOPING.md) and [MacDuo/WALLPAPER_ENGINE.md](MacDuo/WALLPAPER_ENGINE.md); measured results are in [MacDuo/VALIDATION.md](MacDuo/VALIDATION.md).

## Platform

- macOS 26 or later on Apple silicon. Swift 6, SwiftUI and AppKit for the interface, Metal for every effect and wallpaper scene. No third-party dependencies.
- Product name UnfoldMyMac, bundle identifier `com.unfoldmymac`. A regular Dock and app-switcher application with menu-bar controls; closing the window leaves it running and the Dock icon reopens it.
- Settings persist under `unfoldmymac.settings.v1` (migrated from the earlier `luma.settings.v1`), `unfoldmymac.wallpaper.v1` and `unfoldmymac.wallpaper.connections.v1`. Imported artwork lives in `~/Library/Application Support/UnfoldMyMac/`.

## Interface

- One resizable window with a native sidebar: **Effects**, **Wallpaper**, and **Settings** at the bottom. Large page headings scroll away and a compact title appears in the toolbar.
- Effects is a searchable library of cover cards in three collections, **Glass & Light**, **Image Art** and **Motion & 3D**, with tag filtering and author credits. Each card selects, previews or adjusts its design. The page header owns the enable switch, the selected design's status and an **Effect settings** page for lid timing, the menu-bar angle, Screen Recording and diagnostics. Global Settings holds appearance, accessibility status and app information.
- Preview plays directly on the desktop with floating play, pause, scrub and stop controls; there is no separate preview screen. Escape stops it.
- The menu-bar item offers turning the effect on or off, stopping a preview or the wallpaper, opening the Wallpaper page and Settings, opening the window, and quitting.
- Typography is bundled Space Grotesk; symbols are SF Symbols. Text sits on opaque surfaces; Liquid Glass is limited to navigation and key actions. Contrast targets are WCAG AA for text (AAA for primary text) with calculated ratios for the custom tokens.

## Lid effects

**Input.** A read-only IOKit report of the lid angle is read immediately before each live frame, up to 60 Hz, without smoothing. When effects are off the app polls at 4 Hz only while the angle is shown, otherwise not at all. A sensor that stops reading is reopened with a backoff from two seconds to one minute. Without input, live effects pause; manual preview still works when the display is safe.

**Activation and calibration.** The activation angle defaults to 125° and is adjustable from 60° to 180° in whole degrees. Closure is 0 at the activation angle and 1 at 5°. Completion defaults to 80 % of that travel and is adjustable from 40 % to 100 %; the effect holds at 100 % beyond it. Above the activation angle the desktop is clear; at the inclusive trigger a 0.4 % first pose appears. Preview starts fully clear and uses the same calibration.

**Safety.** Effects need the built-in display, an open clamshell and a working sensor, and wait half a second of stable availability after an interruption. Physical closure, system or screen sleep, and display changes always take precedence over a preview. The overlay covers only the usable built-in display, never becomes key and ignores mouse events.

**Preview.** Previewing uses a temporary effect id and its own parameters without changing the chosen design. Stopping, selecting a design, opening effect settings or leaving Effects restores the previous enabled state. With Reduce Motion, preview starts in manual mode.

**Capture.** Only Frost captures the desktop, through ScreenCaptureKit, targeting the built-in display with this process excluded; the applied wallpaper windows are re-admitted so they stay visible. Frames stay in memory; nothing is recorded, stored or sent. Capture that cannot meet those conditions fails visibly instead of capturing another screen.

**Fallbacks.** Frost is the default. Reduce Transparency renders Fade, a capture-free dim, in place of any effect. A saved design that is no longer installed is replaced by Veil with a visible notice; removing the chosen imported image also falls back to Veil. Nothing falls back to Frost silently.

## Designs

| Design | Technique | Capture | Parameters |
| --- | --- | --- | --- |
| Frost | Metal blur of the live desktop: up to 72 source pixels, blended linear/smoothstep progression, 1.35 spatial exponent, 0.2 darkening dead zone, 2× darken, coverage-aware 5×5 binomial taps, sRGB sampling, whole-frame fade after half closure. Identity UV coordinates; source pixels are never replaced | yes | Intensity |
| Veil | `NSVisualEffectView` behind-window material with a graduated alpha mask; the system sets the blur radius | no | Intensity |
| Fade | Native black gradient | no | Intensity |
| Curtains | Two deforming garnet-velvet meshes drawn inward with pleat normals, warm lighting, brass edging and soft shadows; opaque at full closure | no | Fold depth |
| Image reveals (Reverie, Neon Coast, Rise, Tab Goblin, FCUK It. Ship It., Codex After Dark, Claude Has Notes, and imported images) | One shared reveal pipeline splits the artwork into panels that reassemble at calibrated completion; four reveal motions | no | Depth & edge light, reveal |
| Current | Six procedural luminous ribbons and a bounded particle field driven by session time | no | Flow energy |
| Peekaboo | Two deforming vinyl meshes and four eye spheres with depth-tested lighting, breathing, blinks and moving pupils | no | Playfulness |

All designs share calibration, scrubbing, playback and safety. Static designs reproduce the same pose for the same input; animated ones freeze while a preview is paused and under Reduce Motion. Bundled artwork is registered through a JSON manifest; imported images keep app-owned copies, editable credits, and can be removed without touching the original file.

## Living wallpapers

One Metal window per display below the desktop icons, paced by `CAMetalDisplayLink` at 30 or 60 fps, with text layers composited at native resolution. Ten bundled scenes are template folders (`template.json` plus `Scene.metal`) validated by a versioned schema; data comes from local providers (Mac metrics, Claude Code logs, Codex history and hooks, GitHub's public API, NOAA space weather, a calendar countdown, session timers, a JSON file, an HTTPS adapter), declared per template. A matching still is handed to macOS so the menu bar samples correctly and the original wallpaper is journaled and restored. Low Power Mode and thermal pressure drop to 30 fps; Reduce Motion shows a still pose with live data; display sleep and inactive sessions pause everything. Details, limits and privacy boundaries of every source: [MacDuo/WALLPAPER_ENGINE.md](MacDuo/WALLPAPER_ENGINE.md).

## Privacy

- Lid input is read-only. Desktop capture exists only while Frost runs and never leaves memory.
- Wallpaper sources read local files and public endpoints only: Claude usage fields, Codex index metadata and hook events, a public GitHub profile, NOAA forecasts. Prompts, responses, tool output, private repositories and credentials are never read, stored or displayed. Counters are local history, not billing.
- The only network requests are GitHub's public API while a profile is configured, NOAA while Aurora Observatory is shown, and an HTTPS adapter a contributor points at a snapshot endpoint. Nothing else leaves the Mac.

## Accessibility

Reduce Transparency substitutes dimming for capture; Reduce Motion disables auto-play and stills animated scenes while keeping manual and lid control; system contrast settings are followed; keyboard focus stays visible and controls carry accessibility labels and identifiers. The desktop effects intentionally obscure content and are not reading surfaces.

## Architecture

Three targets: `UnfoldMyMacCore` (Foundation only) → `UnfoldMyMacKit` (AppKit, SwiftUI, Metal) → `UnfoldMyMac`. Platform services are built once by `AppDependencies.live()` and injected; each feature has a composition root and a façade model over single-purpose collaborators; views take services from the SwiftUI environment. Effects are declared in `Effects.json` and bound to one renderer-factory table; wallpapers are declared in template folders and bound to connector descriptors. One `GPUContext` per process compiles each shader unit once and loads precompiled units when the build had the Metal toolchain.
