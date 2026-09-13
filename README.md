<div align="center">

<img src=".github/media/banner.png" width="1000" alt="UnfoldMyMac: Lid down. Drama up. A laptop theatre with curtains, curious characters, and little wallpaper worlds.">

# UnfoldMyMac

Desktop effects that follow your lid. Live wallpapers with something going on.

<p>
  <a href="#get-started"><img src="https://img.shields.io/badge/macOS-26%2B-111827?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="macOS 26 or later"></a>
  <a href="MacDuo/Package.swift"><img src="https://img.shields.io/badge/Swift-6.2%2B-F05138?style=for-the-badge&amp;logo=swift&amp;logoColor=white" alt="Swift 6.2 or later"></a>
  <a href="#the-effects"><img src="https://img.shields.io/badge/Rendered_with-Metal-334155?style=for-the-badge" alt="Rendered with Metal"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache_2.0-2563EB?style=for-the-badge" alt="Apache 2.0 license"></a>
</p>
<p>
  <a href="https://forthebadge.com"><img src=".github/media/badges/fuck-it-ship-it.svg" height="28" alt="Fuck it, ship it"></a>
  <a href="https://forthebadge.com"><img src=".github/media/badges/works-on-my-machine.svg" height="28" alt="Works on my machine"></a>
  <a href="https://forthebadge.com"><img src=".github/media/badges/powered-by-coffee.svg" height="28" alt="Powered by coffee"></a>
  <a href="https://forthebadge.com"><img src=".github/media/badges/it-works-why.svg" height="28" alt="It works. Why?"></a>
</p>
<p>
  <a href="#how-it-started"><img src="https://img.shields.io/badge/Scope-out_of_control-F97316?style=for-the-badge&amp;labelColor=172554" alt="Scope: out of control"></a>
  <a href="#the-effects"><img src="https://img.shields.io/badge/Lid-closed_for_dramatic_effect-7C3AED?style=for-the-badge&amp;labelColor=172554" alt="Lid: closed for dramatic effect"></a>
</p>
<p>
  <a href="MacDuo/Package.swift"><img src="https://img.shields.io/badge/Package_dependencies-0-22C55E?style=flat-square" alt="Zero third-party package dependencies"></a>
  <a href="#contributing"><img src="https://img.shields.io/badge/Contributions-welcome-2563EB?style=flat-square" alt="Contributions welcome"></a>
  <a href="https://github.com/satyajiit/UnfoldMyMac"><img src="https://img.shields.io/badge/GitHub-UnfoldMyMac-181717?style=flat-square&amp;logo=github&amp;logoColor=white" alt="UnfoldMyMac on GitHub"></a>
  <a href="https://matterwardlabs.com"><img src="https://img.shields.io/badge/Matterward-Labs-111827?style=flat-square" alt="Matterward Labs"></a>
</p>

[Real-life films](#filmed-on-a-real-macbook) · [Effects](#the-effects) · [Live wallpapers](#living-wallpapers) · [The story](#how-it-started) · [Native stack](#native-down-to-the-pixels) · [Get started](#get-started)

From [Matterward Labs](https://matterwardlabs.com).

</div>

Close your MacBook and curtains meet across the desktop. Open it and they pull apart. Or choose blur, glowing ribbons, blinking characters, and artwork that opens with the lid.

Leave the laptop open and the wallpapers take over: a chrome sculpture reacts to system load, a robot follows coding activity, and your public GitHub profile becomes a small city. All native SwiftUI, AppKit, and Metal.

## Filmed on a real MacBook

A café table. A moving lid. A desktop with a little character. These real-life films sit alongside the full rendered preview collection below.

<p align="center">
  <a href="https://youtu.be/3wAaLwu-msc"><img src=".github/media/real-life/reel.jpg" width="1000" alt="UnfoldMyMac — an app for your MacBook. Move the lid and your desktop reacts."></a><br>
  <strong>Give Your Mac a New Look.</strong> · 2 min 30 sec · 4K / 60 fps · HDR on YouTube<br>
  <a href="https://youtu.be/3wAaLwu-msc">Watch on YouTube ↗</a> · <a href="https://unfoldmymac.com/showcase/#real-reel">View on the website</a>
</p>

<table>
  <tr>
    <td width="50%" align="center"><a href="https://www.youtube.com/watch?v=uXgEo_o9gIg"><img src=".github/media/real-life/lights-out.jpg" width="480" alt="Lights Out filmed on a MacBook — A race circuit on the desktop."></a><br><strong>Lights Out</strong><br><sub>A race circuit on the desktop.</sub><br><a href="https://www.youtube.com/watch?v=uXgEo_o9gIg">Watch on YouTube · 14.7s</a> · <a href="https://unfoldmymac.com/showcase/#real-lights-out">Website</a></td>
    <td width="50%" align="center"><a href="https://www.youtube.com/watch?v=K8EdaVhhuBc"><img src=".github/media/real-life/codex-foundry.jpg" width="480" alt="Codex Foundry filmed on a MacBook — Local Codex activity powers a tiny factory."></a><br><strong>Codex Foundry</strong><br><sub>Local Codex activity powers a tiny factory.</sub><br><a href="https://www.youtube.com/watch?v=K8EdaVhhuBc">Watch on YouTube · 21.9s</a> · <a href="https://unfoldmymac.com/showcase/#real-codex-foundry">Website</a></td>
  </tr>
  <tr>
    <td width="50%" align="center"><a href="https://www.youtube.com/watch?v=nDbIJivsbAc"><img src=".github/media/real-life/claude-has-notes.jpg" width="480" alt="Claude Has Notes follows the physical MacBook lid — Claude takes over as the lid closes."></a><br><strong>Claude Has Notes</strong><br><sub>Claude takes over as the lid closes.</sub><br><a href="https://www.youtube.com/watch?v=nDbIJivsbAc">Watch on YouTube · 10.5s</a> · <a href="https://unfoldmymac.com/showcase/#real-claude-has-notes">Website</a></td>
    <td width="50%" align="center"><a href="https://www.youtube.com/watch?v=23SEy6OLJyg"><img src=".github/media/real-life/frost.jpg" width="480" alt="Frost blurs the screen as the real MacBook lid moves — Lid angle controls the blur."></a><br><strong>Frost</strong><br><sub>Lid angle controls the blur.</sub><br><a href="https://www.youtube.com/watch?v=23SEy6OLJyg">Watch on YouTube · 18.3s</a> · <a href="https://unfoldmymac.com/showcase/#real-frost">Website</a></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><a href="https://www.youtube.com/watch?v=RdcjgygF0Vg"><img src=".github/media/real-life/neon-coast.jpg" width="480" alt="Neon Coast artwork reveals with the MacBook lid — Artwork revealed by the lid."></a><br><strong>Neon Coast</strong><br><sub>Artwork revealed by the lid.</sub><br><a href="https://www.youtube.com/watch?v=RdcjgygF0Vg">Watch on YouTube · 20.5s</a> · <a href="https://unfoldmymac.com/showcase/#real-neon-coast">Website</a></td>
  </tr>
</table>

UnfoldMyMac makes your desktop react when you move your MacBook’s lid, and adds live wallpapers behind your windows. Start with the **00:00 origin and app introduction**, explore the **00:44 collection**, then watch the **01:22 café recordings at 1.5×**. All 23 templates appear in three scenes: an overview mosaic, a moving grid of 13 effects, and a moving grid of 10 wallpapers. [Browse every scene in the interactive carousel ↗](https://unfoldmymac.com/showcase/#every-preview)

All five recordings play from beginning to end: **1.5× in the full film**, **original speed in the individual clips**. Each has a one-second transition before and after. All six films include a spoken voiceover, an original funk score, and a 4K 60 fps HDR upload on YouTube. The playful coffee bubbles, icon stickers, and UnfoldMyMac badge are back; large caption panels stay off the footage. Press play on the website to watch with sound. The complete effects and wallpaper collection follows.

## The effects

All 13 effects, shown over a macOS demo desktop with a menu bar, Dock, and sample windows. The animations use the app's actual Metal and AppKit renderers.

### Glass & Light

<table>
  <tr>
    <td width="50%" align="center">
      <a href=".github/media/effects/frost.gif"><img src=".github/media/effects/frost.gif" width="480" alt="Frost: the Mac desktop progressively blurs and darkens as the lid closes"></a><br>
      <strong>Frost</strong><br><sub>The original iPhone Duo-inspired effect. A soft blur deepens toward the top of your desktop.</sub>
    </td>
    <td width="50%" align="center">
      <a href=".github/media/effects/veil.gif"><img src=".github/media/effects/veil.gif" width="480" alt="Veil: native translucent glass settles over the Mac desktop"></a><br>
      <strong>Veil</strong><br><sub>Native translucent glass with a quiet tint. No Screen Recording needed.</sub>
    </td>
  </tr>
  <tr>
    <td colspan="2" align="center">
      <a href=".github/media/effects/fade.gif"><img src=".github/media/effects/fade.gif" width="480" alt="Fade: the Mac desktop dims to black and returns as the lid opens"></a><br>
      <strong>Fade</strong><br><sub>A smooth shade follows the lid into darkness. Your tabs can rest now.</sub>
    </td>
  </tr>
</table>

### Motion & image reveals

<table>
  <tr>
    <td width="50%" align="center">
      <a href=".github/media/effects/curtains.gif"><img src=".github/media/effects/curtains.gif" width="480" alt="Curtains: animated preview from the app"></a><br>
      <strong>Curtains</strong><br><sub>Velvet folds, stage lighting, and a curtain call for your tabs.</sub>
    </td>
    <td width="50%" align="center">
      <a href=".github/media/effects/current.gif"><img src=".github/media/effects/current.gif" width="480" alt="Current: animated preview from the app"></a><br>
      <strong>Current</strong><br><sub>Mint and coral ribbons that keep moving while the lid holds still.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <a href=".github/media/effects/peekaboo.gif"><img src=".github/media/effects/peekaboo.gif" width="480" alt="Peekaboo: animated preview from the app"></a><br>
      <strong>Peekaboo</strong><br><sub>Blinking characters. Your desktop has acquired witnesses.</sub>
    </td>
    <td width="50%" align="center">
      <a href=".github/media/effects/reverie.gif"><img src=".github/media/effects/reverie.gif" width="480" alt="Reverie: animated preview from the app"></a><br>
      <strong>Reverie</strong><br><sub>Celestial paper art opens along a curved, moonlit seam.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <a href=".github/media/effects/neon-coast.gif"><img src=".github/media/effects/neon-coast.gif" width="480" alt="Neon Coast: animated preview from the app"></a><br>
      <strong>Neon Coast</strong><br><sub>A neon coastline separates into angled panels.</sub>
    </td>
    <td width="50%" align="center">
      <a href=".github/media/effects/tab-goblin.gif"><img src=".github/media/effects/tab-goblin.gif" width="480" alt="Tab Goblin: animated preview from the app"></a><br>
      <strong>Tab Goblin</strong><br><sub>Bro. Close a tab. The laptop has a point.</sub>
    </td>
  </tr>
</table>

<details>
<summary><strong>Four more image reveals, including FCUK It. Ship It.</strong></summary>

<table>
  <tr>
    <td width="50%" align="center">
      <a href=".github/media/effects/rise.gif"><img src=".github/media/effects/rise.gif" width="480" alt="Rise: animated preview from the app"></a><br>
      <strong>Rise</strong><br><sub>MAKE IT HAPPEN. With cobalt steps and a sunburst.</sub>
    </td>
    <td width="50%" align="center">
      <a href=".github/media/effects/fcuk-it.gif"><img src=".github/media/effects/fcuk-it.gif" width="480" alt="FCUK It. Ship It.: animated preview from the app"></a><br>
      <strong>FCUK It. Ship It.</strong><br><sub>An orange-and-cobalt answer to one more round of tweaking.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <a href=".github/media/effects/codex-after-dark.gif"><img src=".github/media/effects/codex-after-dark.gif" width="480" alt="Codex After Dark: animated preview from the app"></a><br>
      <strong>Codex After Dark</strong><br><sub>One more fix. A midnight pixel-art bug chase.</sub>
    </td>
    <td width="50%" align="center">
      <a href=".github/media/effects/claude-has-notes.gif"><img src=".github/media/effects/claude-has-notes.gif" width="480" alt="Claude Has Notes: animated preview from the app"></a><br>
      <strong>Claude Has Notes</strong><br><sub>Just one small change. The revision pile disagrees.</sub>
    </td>
  </tr>
</table>

</details>

- **Add your own image.** Choose Sculpted, Diagonal, Slide, or Burst, then adjust depth and edge light. The app keeps a local copy.
- **Set the timing.** Pick the starting lid angle and how far into closing the effect should finish. Preview supports play, pause, and scrubbing.
- **Keep control.** Effects start disabled. Overlays let clicks through; the Dock and menu-bar controls stay available.
- **Use your system preferences.** Reduce Motion stills continuous animation. Reduce Transparency uses dimming without screen capture.

## Living wallpapers

Ten scenes, optional personal data connections, and 30 or 60 fps playback across your displays. Choose a scene, try its preview, then select **Use wallpaper**.

The GIFs below use the app's Metal shaders and SwiftUI text layers with **sample data**. They are exported at 12 fps to keep the README lighter.

<table>
  <tr>
    <td width="50%" align="center">
      <a href=".github/media/wallpapers/pulse.gif"><img src=".github/media/wallpapers/pulse.gif" width="480" alt="Pulse: animated preview from the app"></a><br>
      <strong>Pulse</strong><br><sub>CPU load, memory, and battery feed a moving chrome sculpture.</sub>
    </td>
    <td width="50%" align="center">
      <a href=".github/media/wallpapers/daydream.gif"><img src=".github/media/wallpapers/daydream.gif" width="480" alt="Daydream: animated preview from the app"></a><br>
      <strong>Daydream</strong><br><sub>Your image, floating glass, and a sticker with opinions.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <a href=".github/media/wallpapers/claude-current.gif"><img src=".github/media/wallpapers/claude-current.gif" width="480" alt="Claude Current: animated preview from the app"></a><br>
      <strong>Claude Current</strong><br><sub>Local Claude sessions and token counts bring the scene to life.</sub>
    </td>
    <td width="50%" align="center">
      <a href=".github/media/wallpapers/codex-foundry.gif"><img src=".github/media/wallpapers/codex-foundry.gif" width="480" alt="Codex Foundry: animated preview from the app"></a><br>
      <strong>Codex Foundry</strong><br><sub>A 3D accelerator assembles around local Codex activity.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <a href=".github/media/wallpapers/codex-mission-control.gif"><img src=".github/media/wallpapers/codex-mission-control.gif" width="480" alt="Codex Mission Control: animated preview from the app"></a><br>
      <strong>Codex Mission Control</strong><br><sub>A little robot responds to working, waiting, and completed hook states.</sub>
    </td>
    <td width="50%" align="center">
      <a href=".github/media/wallpapers/grok-horizon.gif"><img src=".github/media/wallpapers/grok-horizon.gif" width="480" alt="Grok Event Horizon: animated preview from the app"></a><br>
      <strong>Grok Event Horizon</strong><br><sub>A black hole with playful session counters. No chill detected.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <a href=".github/media/wallpapers/github-after-hours.gif"><img src=".github/media/wallpapers/github-after-hours.gif" width="480" alt="GitHub After Hours: animated preview from the app"></a><br>
      <strong>GitHub After Hours</strong><br><sub>Public repositories, followers, and push events become a floating city.</sub>
    </td>
    <td width="50%" align="center">
      <a href=".github/media/wallpapers/lights-out.gif"><img src=".github/media/wallpapers/lights-out.gif" width="480" alt="Lights Out: animated preview from the app"></a><br>
      <strong>Lights Out</strong><br><sub>An open-wheel car, a flowing circuit, and a five-light countdown.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <a href=".github/media/wallpapers/gta-vi-countdown.gif"><img src=".github/media/wallpapers/gta-vi-countdown.gif" width="480" alt="GTA VI — Vice City Countdown: native animated preview with a sample day count"></a><br>
      <strong>GTA VI — Vice City Countdown</strong><br><sub>Rockstar's own promotional artwork and a calendar-day countdown to the announced console release. Artwork © Rockstar Games, excluded from this project's licence; not affiliated with or endorsed by Rockstar Games or Take-Two. Rights holders: <a href="mailto:admin@matterwardlabs.com">admin@matterwardlabs.com</a>. See <a href="NOTICE">NOTICE</a>.</sub>
    </td>
    <td width="50%" align="center">
      <a href=".github/media/wallpapers/aurora-observatory.gif"><img src=".github/media/wallpapers/aurora-observatory.gif" width="480" alt="Aurora Observatory: a rotating 3D Earth with auroral curtains and sample space-weather data"></a><br>
      <strong>Aurora Observatory</strong><br><sub>NOAA space weather shapes auroral curtains around a 3D Earth. NASA Earth Observatory imagery; an artistic interpretation.</sub>
    </td>
  </tr>
</table>

- **A date to look forward to:** GTA VI counts calendar days in your time zone toward the console release date stored in its template. See [Rockstar's announcement](https://www.rockstargames.com/VI) for the current date.
- **Public space weather:** Aurora Observatory fetches [NOAA's OVATION forecast](https://www.swpc.noaa.gov/products/aurora-30-minute-forecast) and planetary Kp readings without account setup. Earth imagery comes from [NASA Earth Observatory](https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/).
- **Mac data:** CPU load, memory estimates, and battery information can drive a scene.
- **Local activity:** optional Claude and Codex connections show session metadata; lifecycle hooks let a wallpaper react to work and approval states.
- **Public GitHub data:** connect a username to bring repositories, followers, and recent public events into the scene.
- **Your own input:** import a background or connect local JSON/JSONL snapshots. Developers can extend the data providers and wallpaper templates.

Connections live in **Data & settings**. Grok's hot takes and the racing scene's laps are playful wallpaper-session counters, not service usage or live race telemetry.

## How it started

I started by trying to bring the iPhone Duo effects to the Mac. I wanted that same sense of movement, but tied to something you could physically do with the laptop. Playing with the MacBook's sensors led to using the lid angle to drive the transition.

Then I added more effects. A blur became curtains, image reveals, flowing ribbons, and little characters peeking at the desktop. Apparently, closing a laptop needed art direction.

Once the rendering was there, I wanted to build a live wallpaper engine with real data behind it. CPU load could move a sculpture. Local coding activity could animate a robot. A public GitHub profile could become a city. That grew into the wallpaper collection, with separate templates and data sources so the next idea wouldn't require rebuilding everything.

<img src=".github/media/origin-comic.png" width="1000" alt="A three-panel comic about scope creep: one lid effect becomes a collection of effects, then a desktop full of live-data scenes.">

## Native, down to the pixels

Swift 6, SwiftUI, AppKit, and Apple's Metal APIs do the work. The curtains are lit cloth meshes; the ribbons, characters, and wallpaper worlds run through GPU shaders. The GIFs above come from those same renderers.

| Apple stack | What it does here |
| --- | --- |
| **Swift 6.2+ & SwiftUI** | App state, settings, the effect library, and wallpaper typography. |
| **AppKit** | Native windows, Dock and menu-bar controls, and desktop surfaces across displays. |
| **Metal & MetalKit** | Custom GPU pipelines for blur, cloth, image reveals, characters, and procedural wallpapers. |
| **IOKit** | Read-only access to the MacBook's lid-angle HID report. |
| **ScreenCaptureKit** | In-memory desktop frames for Frost's live blur. |

The Swift package has **zero third-party package dependencies**. Your GPU does get a slightly more theatrical job description.

## Get started

### Drag, drop, done

The release is a **Developer ID-signed, Apple-notarized DMG**, with an UnfoldMyMac-branded installation window and an Applications shortcut. It needs an **Apple silicon** Mac running **macOS 26 or later**; there is no Intel build.

1. Download the DMG from [GitHub Releases](https://github.com/satyajiit/UnfoldMyMac/releases/latest).
2. Open it and drag **UnfoldMyMac** onto **Applications**.
3. Launch UnfoldMyMac from Applications.

Releases are packaged, notarized, and published **manually**. GitHub Actions checks builds and tests; publishing stays behind a human-operated button.

### Build from source

You need **macOS 26 or later** and **Xcode 26 or later** with Swift 6.2+. Select Xcode's command-line tools in Xcode → Settings → Locations.

```sh
git clone https://github.com/satyajiit/UnfoldMyMac.git
cd UnfoldMyMac/MacDuo
./script/build_and_run.sh
```

The script builds and opens `MacDuo/dist/UnfoldMyMac.app`. It uses an available Apple Development signing identity or falls back to ad-hoc signing. You can copy the app to `/Applications` after building.

1. Open **Effects** and choose a design.
2. Try **Preview** to play or scrub it on your desktop.
3. Turn on lid effects. Use **Effect settings** to adjust the activation angle and completion point.

Lid control needs a MacBook with a readable lid-angle sensor. The app uses an undocumented Apple HID report, so support varies by model. Run `cd MacDuo && ./script/build_and_run.sh --probe` from a clone to check your Mac. Manual preview remains available when the sensor is missing, subject to built-in display safety checks.

Lid effects target the built-in display and pause when it is closed, asleep, unavailable, or mirrored. Wallpapers can use external displays.

<details>
<summary><strong>Permissions and data</strong></summary>

Frost needs **Screen Recording** to blur your desktop. Capture starts when you enable Frost or preview it, and stops when you switch away. Frames stay in memory; Frost does not save or transmit them. Other lid effects do not need Screen Recording.

Personal data connections are optional. Local activity sources read metadata from the files you select; lifecycle connections require their setup step. GitHub wallpapers fetch public profile data and avatars over the network. Aurora Observatory fetches public NOAA forecasts and geomagnetic readings when previewed or active, without account setup. Its cache refreshes every five minutes. The GTA VI countdown uses your local calendar and a bundled release date. Custom HTTP providers contact their configured endpoint.

Artwork imports are stored in `~/Library/Application Support/UnfoldMyMac/Artwork/`. Removing an import deletes the app's copy and leaves your original file alone.

</details>

## Contributing

[Bug reports](https://github.com/satyajiit/UnfoldMyMac/issues/new/choose), hardware compatibility reports, new effects, wallpapers, artwork, and fixes are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) has the four checks to run before a pull request, the file map, and the rules on dependencies and artwork rights. [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) applies here. Security problems go through [SECURITY.md](SECURITY.md) rather than the issue tracker.

## Contributors

Everyone who helps build UnfoldMyMac is credited through their [commits](https://github.com/satyajiit/UnfoldMyMac/graphs/contributors) and [pull requests](https://github.com/satyajiit/UnfoldMyMac/pulls).

## License

Licensed under [Apache 2.0](LICENSE).

Space Grotesk retains its SIL Open Font License. Third-party product marks retain their owners' rights. See [NOTICE](NOTICE) for credits and sources.
