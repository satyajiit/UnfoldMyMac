# Validation

How UnfoldMyMac is verified, what the current build measures, and what is not covered by automation. Numbers come from one MacBook (Apple silicon, built-in 1512×982-point display, macOS 26, the Xcode 26 toolchain) and describe that host, not every Mac.

## How it is verified

| Check | What it proves |
| --- | --- |
| `swift test` | 175 tests: Core value types, schema and migrations; models and providers on fakes; GPU renders of every effect and wallpaper; window and panel behaviour |
| Golden frames | 60 SHA-256 hashes of rendered frames (every effect at three lid poses, every image reveal in every motion, every wallpaper at two poses) must match `Tests/UnfoldMyMacKitTests/Fixtures/golden-frames.json`; re-recorded only after an intended shader change |
| `--shader-check` | Every pipeline renders once from shader source and once from the precompiled `.metallib` units; the pixels must be identical |
| `--wallpaper-benchmark` | Each wallpaper scene is presented on the real desktop for eight seconds; reports presented frames per second, worst p95 frame interval and whether the surface covers the display |
| Packaging | Release build, precompiled shaders, `codesign --verify --strict`, Info.plist and bundled-notice checks |
| Launch timing | `UNFOLDMYMAC_LAUNCH_TIMING=1` prints the time from `applicationDidFinishLaunching` to the window and a per-stage breakdown |
| Leaks | `leaks` against the packaged app after launch and after apply/stop cycles |
| Continuous integration | Builds all test targets, runs the suite with GPU and window tests skipping themselves, packages and verifies the signature on a macOS 26 runner |

GPU timings inside `swift test` are medians of offscreen renders and exclude the compositor; sub-millisecond kernels swing two to three times between runs with identical pixels, so they are recorded rather than gated.

## Current results

Build `5e820d5`, 12 September 2026, measured on battery power.

| Measurement | Result |
| --- | --- |
| Test suite | 175 passed; 42 GPU/window tests skip on CI |
| Golden frames | unchanged since the baseline |
| Shader check | 16 units precompiled and loaded, 21 pipelines rendered, all identical |
| Wallpaper benchmark, all ten scenes | 60.0 fps, worst p95 16.67 ms, full coverage (one scene read 59.9 fps in one of two runs) |
| Launch to window, wallpaper applied | 0.40–0.43 s over three launches; 0 shader units compiled from source, 1 precompiled, 1 pipeline state |
| Leaks after launch | 0 leaks; 329 MB physical footprint with a 60 fps desktop scene running |
| Idle CPU, effects off, window open | 0.0–0.2 % |
| Frost live | ≈2 ms GPU per frame at 3024×1964 |

GPU medians at 3024×1964: Frost 1.2 ms, Curtains 0.65 ms, Peekaboo 0.83 ms, Current 2.6 ms. Wallpapers at 1920×1200, best of two runs: Aurora 0.18, Pulse 0.35, Claude Current 0.82, Daydream 0.93, GTA VI 0.94, GitHub After Hours 1.36, Lights Out 1.69, Codex Mission Control 1.75, Grok 1.88, Codex Foundry 1.95 ms. All are far inside the 16.67 ms budget of a 60 Hz frame.

Launch stages on this host: process start to `applicationDidFinishLaunching` 85–97 ms, wallpaper start (preview pipeline, desktop windows and the reused system still) 106–116 ms, first window layout 276–297 ms. The first layout is the floor of the current view tree.

### Contrast

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

## What automation does not cover

- Physical sleep, wake and clamshell transitions, mirrored and external display changes, permission revocation, VoiceOver navigation, and the system Increase Contrast, Reduce Motion and Reduce Transparency switches are modelled in tests but were not all exercised on hardware. They remain a manual release checklist.
- Screenshots capture app windows, not the whole desktop; the physical look of an effect under a closing lid needs a person.
- The lid-angle sensor is undocumented and hardware dependent. Without it, live effects pause and preview stays manual.
- Frame-rate and launch numbers depend on GPU clocks, which halve on battery power. Numbers here were taken on battery.
- Wallpaper data sources are compatibility adapters over local files and public APIs (Claude JSONL logs, the Codex SQLite index, GitHub REST, NOAA feeds) and need maintenance when those formats change. Fixtures pin the formats observed at the time of writing.

## History

Each milestone was verified with the full suite, a release build and a strict signature check before it was kept. Tests counts are the suite size at that point.

### Architecture hardening, September 2026

A nine-step refactor of the whole app with one commit per step. Every step kept the golden frames byte-identical.

| Step | What changed | Verified |
| --- | --- | --- |
| Baseline | Golden-frame test, GPU test traits, launch timing probe | 94 tests; launch 0.62–0.65 s; steady state with a 60 fps scene 5–12 % CPU, 287 MB |
| Tree and fixes | One type per file under `App`, `Platform`, `Rendering`, `DesignSystem`, `Features`; typed errors; named constants; twelve bug and leak fixes each with a regression test (preview enable state, sensor backoff, capture-cache release, duplicate registrations, orphaned settings, per-frame `orderOut`, bounded HTTP bodies, failed-preview recovery, backdrop retention, GitHub retry, provider identity, hook file locking) | 112 tests |
| Platform seams | `PreferencesStore` with typed keys and golden fixtures, one `SystemEnvironment`, file-picker, workspace and permission seams, composition roots, `AppController` reduced to a delegate | 123 tests; launch 0.49 s |
| GPU kernel | One `GPUContext` instead of up to six devices; shader units cached per process and precompiled into the bundle; one surface renderer for every pipeline; Frost's capture memory reduced from about 95 MB to 32 MB; a packaging bug that loaded resources from the build directory fixed | 123 tests; shader check identical through both paths; benchmark 60.0 fps on all ten scenes; runtime shader compilations at launch 12 → 0 |
| Effects decomposition | `EffectsModel` façade over runtime, pacing, lid monitor, display gate, preview state machine, preferences, import and permissions; capture frames on a private queue; observable state written only on change | 141 tests; 100 identical ticks produce 0 observer invalidations; idle CPU 0.0–0.2 % |
| Wallpaper decomposition | `WallpaperModel` façade over catalog, covers, playback policy, connector registry, data and desktop coordinators; covers rendered after launch; incremental Claude log reader; one Codex connection; GitHub ETags; backdrop reuse and pruning | 155 tests; apply/stop ×10 and preview switching ×20 release every pipeline and window; 0 leaks; pipeline states at launch 11 → 1 |
| Content model | `Effects.json` manifest and one renderer-factory table; wallpaper template schema v2 with field-level rejections and lint warnings; one folder per scene with its own shader; imported template library | 173 tests; every v1 template decodes to its v2 folder; launch 0.39–0.45 s |
| Polish | Views take services from the environment; CI runs the whole suite with GPU and window tests self-skipping; Dock-icon decode and backdrop round trips off the launch path; accessibility labels on the wallpaper page | 175 tests; launch 0.40–0.43 s; 0 leaks |

### Earlier milestones

| Milestone | Verified |
| --- | --- |
| GTA VI countdown and Aurora Observatory | 94 tests: date, DST and time-zone boundaries, invalid grid and Kp data, cache dedup/offline/stale/recovery, grid uploads; both scenes 60.0 fps with full coverage; NOAA data fetched live |
| Template setup and Lights Out rework | 89 tests: required setup checked in the model, draft cancel/save, per-template isolation, no default GitHub username; native renders of the setup sheets; 60.0 fps |
| GitHub, Codex lifecycle and the F1 scene | 84 tests: GitHub validation, caching, push dedup, failure fallback; hook state ordering, expiry, bounded ids, config preservation, 24 concurrent writers; every rotating headline measured inside its reserved area at three sizes; live GitHub profile fetched; eight scenes at 60.0 fps |
| System menu-bar backdrop and Codex count fix | 74 tests plus an opt-in native check of `NSWorkspace` apply/restore and the real Codex index |
| Wallpaper pacing and coverage | 70 tests; `CAMetalDisplayLink` pacing with presented-frame measurement; five scenes at 60.0 fps and exact display coverage |
| Codex and Grok scenes | 67 tests; product marks pinned by hash; Codex 2.1 ms and Grok 2.5 ms GPU at 1920×1200 |
| Wallpaper engine | 65 tests; Pulse, Claude Current and Daydream at about 1 ms GPU; a multi-gigabyte Claude history indexed incrementally and resumed from cache |
| Effects library, imports and new designs | 40 tests; eight designs in three collections; import normalisation, rollback and corrupt-index protection; Current at 1.4 ms GPU |
| Peekaboo, Tab Goblin and FCUK It. Ship It. | 43 tests; Peekaboo at 0.84 ms GPU |
| Curtains | 22 tests; 0.77 ms GPU across moving poses |
| UnfoldMyMac identity | 40 tests; preference, window-frame and artwork-folder migrations from the earlier Luma name |
| First automated baseline | 17 tests: angle mapping, calibration, preferences migration, safety recovery, capture ownership, Frost identity at every pixel of a multicolour fixture, blur progression, sRGB wrapping; Frost 1.39 ms GPU |

References: [Apple Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass), [AppKit visual effects](https://developer.apple.com/documentation/AppKit/NSVisualEffectView), [WCAG contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).
