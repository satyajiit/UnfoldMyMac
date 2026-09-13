# Changelog

All notable changes to UnfoldMyMac are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-09-13

### Added

- **Creative Scenes**, beginning with Hinge Garden: a glass snail and greenhouse that respond to lid movement, charger connection, battery, time of day, and system activity. Optional sound, pointer, motion-sensor, and one-liner controls are available in Customize.
- A redesigned library with **Lid Effects**, **Dynamic Wallpapers**, and **Creative Scenes**, category tabs, tag filters, grid/list browsing, brand and capability badges, and linked creator credits.
- Full wallpaper and scene detail pages with the design preview, formatted descriptions, and actions below the preview. Titles stay in the toolbar while scrolling.
- Updated website collection browsing, native interface screenshots in both themes, and a 22-second Hinge Garden video preview.

### Changed

- Grouped lid-effect appearance and credit controls, and refreshed collection artwork for light and dark appearances.
- Renamed the app source directory to `UnfoldMyMac/`, including build, CI, release, and documentation references.
- Kept internal planning, AI instructions, artwork prompts, and review artifacts out of the public source tree.

### Fixed

- Creative Scenes’ New badge remains visible on the selected light-mode sidebar row.
- Showcase collection tabs have space below the preceding divider on desktop and mobile.

## [1.0.0] - 2026-09-12

First public release.

### Added

- **13 lid effects.** Frost, Curtains, Current and Peekaboo are drawn procedurally in Metal. Veil
  and Fade are native AppKit effects. Reverie, Neon Coast, Rise, Tab Goblin, FCUK It. Ship It., Codex After Dark and Claude Has Notes are
  built from bundled artwork, each with its own reveal.
- **Your own artwork.** Import an image, choose a Sculpted, Diagonal, Slide or Burst reveal, and
  adjust its depth and edge light. The app keeps its own copy in
  `~/Library/Application Support/UnfoldMyMac/Artwork/`.
- **10 live wallpapers.** Pulse, Daydream, Lights Out, Aurora Observatory, GTA VI — Vice City
  Countdown, GitHub After Hours, Codex Foundry, Codex Mission Control, Claude Current and Grok
  Event Horizon. They run independently of the lid, at 30 or 60 fps, across displays.
- **Optional data connections.** Local Mac metrics, local Claude or Codex activity metadata, a
  public GitHub profile, public NOAA aurora forecasts, or your own JSON over HTTP. Every
  connection is off until you turn it on, and none of them read prompts or responses.
- **Lid timing controls.** Set the angle where an effect begins and how far into closing it
  finishes. Preview, pause and scrub any effect before enabling it.
- **A menu-bar item** for turning an effect on or off, switching between them by category,
  starting or stopping a wallpaper, opening the app, and starring the repository.
- **Accessibility.** Reduce Motion stills continuous animation while manual and lid control stay
  available. Reduce Transparency uses a dim-only effect with no desktop capture.
- **A signed, notarized, stapled disk image** with a branded drag-to-Applications window.

### Requirements

- macOS 26 or later, Apple silicon. There is no Intel build.
- Automatic lid effects need a MacBook with a readable lid angle sensor. The app reads an
  undocumented Apple HID report, so support varies by model.

### Privacy

- Screen Recording is requested only by Frost, only while it is running or previewing. Frames stay
  in memory, are never written to disk, and never leave the Mac.
- No telemetry, no analytics, no crash reporting and no accounts.

[1.0.0]: https://github.com/satyajiit/UnfoldMyMac/releases/tag/v1.0.0

[1.0.1]: https://github.com/satyajiit/UnfoldMyMac/releases/tag/v1.0.1
