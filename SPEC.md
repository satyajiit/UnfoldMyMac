# UnfoldMyMac specification

What the app does and the rules it keeps. Implementation notes are in [UnfoldMyMac/DEVELOPING.md](UnfoldMyMac/DEVELOPING.md) and [UnfoldMyMac/WALLPAPER_ENGINE.md](UnfoldMyMac/WALLPAPER_ENGINE.md); measured results are in [UnfoldMyMac/VALIDATION.md](UnfoldMyMac/VALIDATION.md).

## Platform

- macOS 26 or later on Apple silicon. Swift 6, SwiftUI and AppKit for the interface, Metal for every effect and wallpaper scene. No third-party dependencies.
- Product name UnfoldMyMac, bundle identifier `com.unfoldmymac`. A regular Dock and app-switcher application with menu-bar controls; closing the window leaves it running and the Dock icon reopens it.
- Settings persist under `unfoldmymac.settings.v1` (migrated from the earlier `luma.settings.v1`), `unfoldmymac.wallpaper.v1` and `unfoldmymac.wallpaper.connections.v1`. Imported artwork lives in `~/Library/Application Support/UnfoldMyMac/`.

## Interface

- One resizable window with a native sidebar: **Lid Effects**, **Dynamic Wallpapers**, **Creative Scenes** (with a New badge), and **Settings** at the bottom. Large page headings scroll away and a compact title appears in the toolbar.
- Lid Effects is a searchable library of cover cards in three collections, **Glass & Light**, **Image Art** and **Motion & 3D**, with visible tag chips and author credits. Each card selects, previews or customizes its design. Customization groups declared parameters and separates About and imported Artwork management. The page header owns the enable switch, the selected design's status and an **Effect settings** page for lid timing, the menu-bar angle, Screen Recording and diagnostics. Global Settings holds appearance, accessibility status and app information.
- Wallpaper and Creative Scenes galleries have category tabs, search, tag chips, and grid/list layouts. Each design opens a detail page with a labeled editorial banner, actual preview, formatted description, creator links, original credits, related-product marks, and capability badges. Browsing does not apply a design or start its data feeds. Hinge Garden is a Creative Scene under Nature & atmosphere; its stable template ID and settings are preserved.
- Lid-effect preview plays directly on the desktop with floating play, pause, scrub and stop controls; there is no separate preview screen. Escape stops it.
- The menu-bar item offers turning the effect on or off, stopping a preview or the wallpaper, opening the Wallpaper page and Settings, opening the window, and quitting.
- Typography uses bundled Space Grotesk with system type for editorial display headings; symbols are SF Symbols. Text sits on opaque surfaces; Liquid Glass is limited to navigation and key actions. Contrast targets are WCAG AA for text (AAA for primary text) with calculated ratios for the custom tokens.

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

Twenty-two bundled designs are template folders (`template.json` plus `Scene.metal`) validated by a versioned schema; data comes from local providers (Mac metrics, Claude Code logs, Codex history and hooks, GitHub's public API, NOAA space weather, a calendar countdown, session timers, a JSON file, an HTTPS adapter), declared per template. Metal is paced by `CAMetalDisplayLink` at 30 or 60 fps with text layers composited at native resolution. Low Power Mode and thermal pressure drop to 30 fps; Reduce Motion shows a still pose with live data; display sleep and suspended sessions pause everything. Details, limits and privacy boundaries of every source: [UnfoldMyMac/WALLPAPER_ENGINE.md](UnfoldMyMac/WALLPAPER_ENGINE.md).

Every design can be drawn two ways, from the same pipeline and the same views.

**As a system wallpaper.** `UnfoldMyMacWallpaperExtension.appex` is a macOS 26 wallpaper provider: it registers at the `com.apple.wallpaper` extension point, and every bundled design appears in System Settings › Wallpaper under “UnfoldMyMac — Dynamic Wallpapers”. macOS keeps two wallpaper selections per display: `Desktop`, and the `Idle` slot that the lock screen and the screen saver share. Choosing a design under Wallpaper fills the first; choosing it under Screen Saver fills the second, and the lock screen shows an exported still of whatever is in the `Idle` slot until it does. Both are live once selected — macOS composites the scene itself, so it keeps running with the app closed and with the Mac locked. The app reports which of the two it actually holds — macOS names no content type, so the surface's role comes from the presentation mode it was created with — and links to the matching pane; it never claims the lock screen on the strength of holding the desktop. The extension is sandboxed and cannot read `~/.claude`, `~/.codex`, the lid angle or the microphone, so the app writes a snapshot of those into the extension's container every few seconds and posts a Darwin notification; the scene poses from it, and falls back to its declared idle pose when the app is not running. Selecting a wallpaper provider is the user's decision and macOS gives apps no way to make it, so the app links to the setting rather than writing the system's wallpaper state.

**As desktop windows.** One Metal window on the primary display below the desktop icons, with the text layers in a hosting view above the surface, plus a matching still handed to macOS so the menu bar samples correctly; the original wallpaper is journaled and restored. Other displays are left alone, and a still this app installed on one is handed back the next time the scene is applied. This is what runs when the provider is not the current wallpaper, and it cannot reach the lock screen — a desktop window is invisible there. The two never run at once: while macOS is showing the provider, the app draws nothing and never changes the system wallpaper, because the wallpaper it would replace is its own.

Note that the still handed to macOS *is* the system wallpaper, so the desktop-window path already repaints the user's lock screen with a frozen frame of the scene. The provider path replaces that frozen frame with the live one.

## Privacy

- Lid input is read-only. Desktop capture exists only while Frost runs and never leaves memory.
- Wallpaper sources read local files and public endpoints only: Claude usage fields, Codex index metadata and hook events, a public GitHub profile, NOAA forecasts. Prompts, responses, tool output, private repositories and credentials are never read, stored or displayed. Counters are local history, not billing.
- The only network requests are GitHub's public API while a profile is configured, NOAA while Aurora Observatory is shown, and an HTTPS adapter a contributor points at a snapshot endpoint. Nothing else leaves the Mac.

## Accessibility

Reduce Transparency substitutes dimming for capture; Reduce Motion disables auto-play and stills animated scenes while keeping manual and lid control; system contrast settings are followed; keyboard focus stays visible and controls carry accessibility labels and identifiers. The desktop effects intentionally obscure content and are not reading surfaces.

## Architecture

Four targets: `UnfoldMyMacCore` (Foundation only) → `UnfoldMyMacKit` (AppKit, SwiftUI, Metal) → `UnfoldMyMac`, plus `UnfoldMyMacWallpaperExtension`, a thin `.appex` shim whose renderer, XPC contract and data bridge all live in the Kit so the desktop and the lock screen run the same code. (`UnfoldMyMacWallpaperBridge` is a header-only ObjC target carrying the reconstructed private wallpaper protocols.) Platform services are built once by `AppDependencies.live()` and injected; each feature has a composition root and a façade model over single-purpose collaborators; views take services from the SwiftUI environment. Effects are declared in `Effects.json` and bound to one renderer-factory table; wallpapers are declared in template folders and bound to connector descriptors. One `GPUContext` per process compiles each shader unit once and loads precompiled units when the build had the Metal toolchain.
