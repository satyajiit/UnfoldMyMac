# Changelog

All notable changes to UnfoldMyMac are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-09-12

First public release.

### Added

- **13 lid effects.** Frost, Veil, Fade, Curtains, Current and Peekaboo are drawn procedurally in
  Metal. Reverie, Neon Coast, Rise, Tab Goblin, FCUK It. Ship It., Codex After Dark and Claude Has Notes are
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
