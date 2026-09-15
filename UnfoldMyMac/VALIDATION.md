# Validation

Run these checks from `UnfoldMyMac/` on macOS 26 or later with Xcode 26 and the Metal toolchain.

## Build and runtime checks

| Command | Coverage |
| --- | --- |
| `swift test` | Core models, schema compatibility and migrations, provider and input lifecycles, native UI, and GPU reference renders. Hardware-dependent cases require Metal or a WindowServer session. |
| `./script/build_and_run.sh --build` | Builds the app bundle, copies resources and notices, compiles shaders, and verifies its development signature. |
| `./script/build_and_run.sh --shader-check` | Renders every pipeline from source and precompiled shader libraries; the pixels must match. |
| `./script/build_and_run.sh --probe` | Reports local lid-sensor and display availability without starting an effect. |

### The wallpaper provider

`swift test` covers the bridge round trip, the handover between the provider and the app's own desktop
windows, the selection precedence between the app's picker and System Settings, request parsing, the
readout renderer, and that the app keeps feeding a provider it never applied itself. What it cannot cover
is the system itself, so the provider needs these on hardware:

| Check | What it proves | How |
| --- | --- | --- |
| Registration | macOS sees the extension | `pluginkit -mv -p com.apple.wallpaper` lists `com.unfoldmymac.wallpaper` beside Apple's eleven |
| Gallery | The scenes are offered | System Settings › Wallpaper shows “UnfoldMyMac — Dynamic Wallpapers” with rendered thumbnails |
| Desktop | The scene composites | Pick a scene; `log show --predicate 'subsystem == "com.unfoldmymac.wallpaper"'` shows `surface up` with a non-zero context, and the scene is on the desktop |
| Live data | The bridge works | With the app running, the readouts show real numbers rather than dashes; `~/Library/Containers/com.unfoldmymac.wallpaper/Data/Documents/Snapshot.json` carries the namespace the scene reads |
| Two selections | The lock screen is its own choice | System Settings › Wallpaper *and* › Screen Saver both list the group. `plutil -p ~/Library/Application\ Support/com.apple.wallpaper/Store/Index.plist` names `com.unfoldmymac.wallpaper` under `Idle`, not only under `Desktop` |
| Frames | The surface is moving, not merely up | The log shows `frames … presented=<n>fps configured=60` with a non-zero measured rate. `mode=locked` and `fps=60` are the rate asked for and prove nothing on their own — that pair was logged throughout the period the lock screen was in fact a still |
| Lock screen | The point of all this | With the `Idle` slot ours, lock with ⌃⌘Q; a second `acquire` appears keyed `<display>:lockScreen:false`, with its own context id and a non-zero `presented=` while the display is awake. The scene visibly moves |
| Reach is reported honestly | The card cannot promise what it lacks | With only the desktop selected, the card reads “On your desktop · not the lock screen yet” and its button opens Screen Saver settings. It reads “desktop and lock screen” only once `Heartbeat.json` lists `lockScreen` in `roles` — previews excluded, since a Screen Saver tile in System Settings is not a lock screen |
| Screen saver | The Idle slot | Start the screen saver; the log shows `mode=idle` and the surface is not invalidated |
| Display sleep | It costs nothing when unseen | Leave the Mac locked; the log shows `activity=suspended` and the process drops to ~0% CPU |
| App wallpaper off | The bridge does not hang on the app's own switch | With the provider selected and UnfoldMyMac's wallpaper turned off, `Heartbeat.json` and `Snapshot.json` stay under ~4 s old and the readouts keep their numbers |
| No double render | The app stands down | With the provider live, `WallpaperModel` shows no desktop windows and never calls `setDesktopImageURL` |
| Primary display only | The app draws where it says it does | With a second display attached and the provider not selected, the app puts one window on the built-in display, the Display row names it, and the second display keeps its own wallpaper — including having a still this app installed on it handed back |
| Snapshot export | The login window | `/var/db/Wallpapers/<uuid>/Metadata.plist` records `Provider = com.unfoldmymac.wallpaper` |
| Reversibility | Nothing is left behind | Pick an Apple wallpaper, quit the app, delete the app: the wallpaper returns and `Index.plist` was never written by us |

Measured on an M5 Max at 1512×982@2x: ~4–6% of a core while visible, ~0% while the display sleeps.

Two deployment traps, neither of them code: deleting the app bundle while its extension is the current
wallpaper leaves a stale pluginkit record and the next launch fails with `extensionKit error 2` — reinstall
over the bundle instead of replacing it, and recover with `pluginkit -a <appex>` then `killall
WallpaperAgent`. And an extension only reloads when `WallpaperAgent` restarts, so a rebuilt provider needs
that `killall` to be picked up.

Golden-frame fixtures live in `Tests/UnfoldMyMacKitTests/Fixtures/golden-frames.json`. Update them only after reviewing an intended rendering change. Offscreen GPU timings exclude compositor work and vary with hardware and power state; use the wallpaper benchmark for presentation measurements.

The native discovery test covers both appearances, supported window widths, grid/list switching, design details, and the effect inspector. Set `UNFOLDMYMAC_DISCOVERY_ARTIFACTS` to an ignored local directory to export window screenshots. Without that variable, the test still exercises the interface.

For the website, run `npm run verify` from `website/`. It runs lint, type checking, the static export, content/media checks, and browser tests across Chromium, Firefox, WebKit, and a mobile viewport. Browser coverage includes collection filters, video playback, theme changes, keyboard input, narrow layouts, and automated WCAG 2.2 AA checks.

## Distribution checks

Use [SIGNING.md](SIGNING.md) and `script/release_macos.sh` for a release. The release path verifies the Developer ID signature, hardened runtime, reviewed entitlements, bundled notices, architecture, and precompiled shaders. It checks the wallpaper provider separately, because each of its failures is silent: the extension point identifier, the `XPC!` package type, a version matching the app's, its own copy of the precompiled shaders, its sandbox entitlement, and that its binary imports `_NSExtensionMain` — without which the process exits before serving a single call and the host reports only `NSCocoaErrorDomain 4099`. The provider is sealed before the app, with its own identifier and its own reviewed entitlement set. It notarizes and staples both the app and the DMG, then verifies the mounted app matches the signed original and writes a checksum of the final DMG.

## Contrast

Calculated with the WCAG relative-luminance formula on the fixed, opaque sRGB surfaces:

| Pair | Ratio |
| --- | --- |
| Light primary / canvas | 15.44:1 |
| Light secondary / canvas | 6.35:1 |
| Light secondary / card | 6.92:1 |
| White / light blue action | 6.34:1 |
| Dark primary / canvas | 15.98:1 |
| Dark secondary / canvas | 8.94:1 |
| Dark secondary / card | 7.98:1 |
| Dark accent / card | 8.18:1 |
| White / dark blue action | 4.81:1 |
| Dark blue action / card boundary | 3.23:1 |

Text tokens meet AA (4.5:1) and primary text meets AAA. Native glass varies with system settings; these ratios do not certify every composited native control.

## Manual checks and limits

- Exercise sleep, wake, clamshell transitions, external and mirrored displays, and permission revocation on hardware. Model tests do not cover every physical configuration.
- Review VoiceOver navigation and the system Increase Contrast, Reduce Motion, and Reduce Transparency settings in the running app.
- Check Frost with Screen Recording granted and denied. Check Hinge Garden with optional sound and motion sensing enabled and disabled.
- Install the notarized DMG on a clean Mac or fresh account. Development signing and distribution signing have different privacy grants.
- Lid and motion sensors use undocumented, model-dependent hardware reports. Manual preview remains subject to display safety checks; Hinge Garden uses an open pose when lid data is unavailable.
- Local Claude/Codex formats and public API responses can change. Fixtures record supported formats and need maintenance alongside their adapters.

Internal investigation notes, generated artwork prompts, screenshots, and benchmark logs belong in ignored review/artifact directories, not in the public testing guide.
