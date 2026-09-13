# Validation

Run these checks from `UnfoldMyMac/` on macOS 26 or later with Xcode 26 and the Metal toolchain.

## Build and runtime checks

| Command | Coverage |
| --- | --- |
| `swift test` | Core models, schema compatibility and migrations, provider and input lifecycles, native UI, and GPU reference renders. Hardware-dependent cases require Metal or a WindowServer session. |
| `./script/build_and_run.sh --build` | Builds the app bundle, copies resources and notices, compiles shaders, and verifies its development signature. |
| `./script/build_and_run.sh --shader-check` | Renders every pipeline from source and precompiled shader libraries; the pixels must match. |
| `./script/build_and_run.sh --probe` | Reports local lid-sensor and display availability without starting an effect. |

Golden-frame fixtures live in `Tests/UnfoldMyMacKitTests/Fixtures/golden-frames.json`. Update them only after reviewing an intended rendering change. Offscreen GPU timings exclude compositor work and vary with hardware and power state; use the wallpaper benchmark for presentation measurements.

The native discovery test covers both appearances, supported window widths, grid/list switching, design details, and the effect inspector. Set `UNFOLDMYMAC_DISCOVERY_ARTIFACTS` to an ignored local directory to export window screenshots. Without that variable, the test still exercises the interface.

For the website, run `npm run verify` from `website/`. It runs lint, type checking, the static export, content/media checks, and browser tests across Chromium, Firefox, WebKit, and a mobile viewport. Browser coverage includes collection filters, video playback, theme changes, keyboard input, narrow layouts, and automated WCAG 2.2 AA checks.

## Distribution checks

Use [SIGNING.md](SIGNING.md) and `script/release_macos.sh` for a release. The release path verifies the Developer ID signature, hardened runtime, reviewed entitlements, bundled notices, architecture, and precompiled shaders. It notarizes and staples both the app and the DMG, then verifies the mounted app matches the signed original and writes a checksum of the final DMG.

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
