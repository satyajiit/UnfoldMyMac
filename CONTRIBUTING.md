# Contributing to UnfoldMyMac

Bug reports, hardware compatibility reports, new effects, new wallpaper templates, artwork and
fixes are all welcome.

## Before you open a pull request

Run all four from `MacDuo/`:

```sh
swift test
./script/build_and_run.sh --build
./script/build_and_run.sh --shader-check
./script/build_and_run.sh --probe
```

`--shader-check` and `--probe` need a real Mac: the first compiles every shader and compares it
against the precompiled metallibs, the second reads the lid-angle sensor. CI runs the tests and
builds the app on macOS 26, and GPU and window-server tests skip themselves there, so hardware
checks are yours to run.

Say which of the four you ran, and paste the output. For a rendering change, attach a short
recording or before-and-after stills.

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
| Models, calibration, preferences | [`UnfoldMyMacCore`](MacDuo/Sources/UnfoldMyMacCore) |
| The effect list and its renderers | [`Effects.json`](MacDuo/Sources/UnfoldMyMacKit/Resources/Effects/Effects.json) and [`EffectRendererFactories.swift`](MacDuo/Sources/UnfoldMyMacKit/Features/Effects/Catalog/EffectRendererFactories.swift) |
| Effect render pipelines | [`Pipelines`](MacDuo/Sources/UnfoldMyMacKit/Features/Effects/Pipelines) |
| Metal shaders | [`Shaders`](MacDuo/Sources/UnfoldMyMacKit/Shaders) |
| Bundled image designs | [`Artworks.json`](MacDuo/Sources/UnfoldMyMacKit/Resources/Library/Artworks.json) and [`Artwork`](MacDuo/Sources/UnfoldMyMacKit/Resources/Artwork) |
| Wallpaper templates and rendering | [`Wallpapers`](MacDuo/Sources/UnfoldMyMacKit/Resources/Wallpapers) and [`Wallpaper`](MacDuo/Sources/UnfoldMyMacKit/Features/Wallpaper) |
| App entry point | [`main.swift`](MacDuo/Sources/UnfoldMyMac/main.swift) |

[`MacDuo/DEVELOPING.md`](MacDuo/DEVELOPING.md) is the extension guide: how to add an effect, a
shader, or a wallpaper template. [`MacDuo/WALLPAPER_ENGINE.md`](MacDuo/WALLPAPER_ENGINE.md)
covers the template schema and the data connectors.
[`MacDuo/SIGNING.md`](MacDuo/SIGNING.md) covers how releases are built, signed and notarized.

## Reporting a bug

Use the [bug report template](https://github.com/satyajiit/UnfoldMyMac/issues/new/choose) and
include your Mac model, your macOS version, which effect or wallpaper was running, what you
expected, and what happened. If you built from source, attach the output of
`./script/build_and_run.sh --probe`.

Security problems go through [SECURITY.md](SECURITY.md), not the issue tracker.
