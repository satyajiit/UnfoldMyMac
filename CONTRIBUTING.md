# Contributing to UnfoldMyMac

Bug reports, hardware compatibility reports, new effects, new wallpaper templates, artwork and
fixes are all welcome.

## Before you open a pull request

Run all four from `UnfoldMyMac/`:

```sh
swift test
./script/build_and_run.sh --build
./script/build_and_run.sh --shader-check
./script/build_and_run.sh --probe
```

`--shader-check` and `--probe` need a real Mac: the first compiles every shader and compares it
against the precompiled metallibs, the second reads the lid-angle sensor.

Say which of the four you ran, and paste the output. For a rendering change, attach a short
recording or before-and-after stills.

For a change under `website/`, run this from `website/` instead:

```sh
npm run verify
```

That is lint, typecheck, build, the Node tests and the Playwright suite across Chromium, Firefox
and WebKit. First time only, install the engines with
`node node_modules/@playwright/test/cli.js install chromium firefox webkit`.

## What CI does and does not cover

CI is deliberately small, because macOS runners bill at ten times the Linux rate and the browser
sweep costs about six minutes of runner time per push. It builds the Swift test targets and runs
the suite, and for the website it runs lint, typecheck, build and the Node tests.

It does **not** run the Playwright suite, the app bundle build, `--shader-check` or `--probe`.
Those are yours, locally, before you push. Both can be run on demand when a change warrants it:

```sh
gh workflow run website.yml -f browsers=true
gh workflow run ci.yml -f bundle=true
```

GPU and window-server tests carry `.requiresGPU` and `.requiresWindowServer` and skip themselves
when `CI=true`, so a green CI run is not a claim that rendering works. Your local `swift test` is.

## House rules

- **No third-party package dependencies.** The Swift package has zero, and that is a feature. If
  something needs a dependency, open an issue first so we can talk about it.
- **Artwork must be yours to contribute.** Original work, or work you hold a licence for. Say
  where it came from in the pull request. Anything bundled that is not covered by the project's
  Apache 2.0 grant has to be carved out in `NOTICE`, as the existing third-party entries are.
- **Keep changes focused.** One idea per pull request.
- **No generated attribution in commits.** No `Co-Authored-By` lines for tools, no "Generated
  with" trailers. Write commit messages in the imperative, and say what changed and why.
- Contributions are accepted under the project's Apache 2.0 licence.

## Where things live

| Area | Start here |
| --- | --- |
| Models, calibration, preferences | [`UnfoldMyMacCore`](UnfoldMyMac/Sources/UnfoldMyMacCore) |
| The effect list and its renderers | [`Effects.json`](UnfoldMyMac/Sources/UnfoldMyMacKit/Resources/Effects/Effects.json) and [`EffectRendererFactories.swift`](UnfoldMyMac/Sources/UnfoldMyMacKit/Features/Effects/Catalog/EffectRendererFactories.swift) |
| Effect render pipelines | [`Pipelines`](UnfoldMyMac/Sources/UnfoldMyMacKit/Features/Effects/Pipelines) |
| Metal shaders | [`Shaders`](UnfoldMyMac/Sources/UnfoldMyMacKit/Shaders) |
| Bundled image designs | [`Artworks.json`](UnfoldMyMac/Sources/UnfoldMyMacKit/Resources/Library/Artworks.json) and [`Artwork`](UnfoldMyMac/Sources/UnfoldMyMacKit/Resources/Artwork) |
| Wallpaper templates and rendering | [`Wallpapers`](UnfoldMyMac/Sources/UnfoldMyMacKit/Resources/Wallpapers) and [`Wallpaper`](UnfoldMyMac/Sources/UnfoldMyMacKit/Features/Wallpaper) |
| App entry point | [`main.swift`](UnfoldMyMac/Sources/UnfoldMyMac/main.swift) |

[`UnfoldMyMac/DEVELOPING.md`](UnfoldMyMac/DEVELOPING.md) is the extension guide: how to add an effect, a
shader, or a wallpaper template. [`UnfoldMyMac/WALLPAPER_ENGINE.md`](UnfoldMyMac/WALLPAPER_ENGINE.md)
covers the template schema and the data connectors.
[`UnfoldMyMac/SIGNING.md`](UnfoldMyMac/SIGNING.md) covers how releases are built, signed and notarized.

## Reporting a bug

Use the [bug report template](https://github.com/satyajiit/UnfoldMyMac/issues/new/choose) and
include your Mac model, your macOS version, which effect or wallpaper was running, what you
expected, and what happened. If you built from source, attach the output of
`./script/build_and_run.sh --probe`.

Security problems go through [SECURITY.md](SECURITY.md), not the issue tracker.
