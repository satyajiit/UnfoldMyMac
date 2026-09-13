# Game wallpapers and radial lid effects

The game collection adds ten wallpapers under Play. Each pairs an AI-generated fan-art environment with an unchanged official game logo. Official promotional artwork is used as the detail banner. Game artwork and marks retain the ownership credits shown in each template. These are independent tributes, without publisher affiliation or endorsement.

## Asset origins

Retrieved September 13, 2026. Publisher-uploaded Steam assets are served by Steam’s CDN; Wolverine assets and the Ghost of Tsushima logo come directly from PlayStation. Logos retain their downloaded PNG bytes. Steam promotional JPEGs are converted to PNG for the asset resolver. Generated artwork lives in `Sources/UnfoldMyMacKit/Resources/Artwork/Game*.png`; original marks in `Resources/WallpaperMarks/Game*.png`. Each template folder holds `Official.png`, `Scene.metal`, and the rendered `cover.png`.

The ten backgrounds are 3840×2402 PNGs, preserving the original 1586×992 compositions without cropping. They were enhanced locally with [Real-ESRGAN ncnn](https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan), `realesrgan-x4plus`, 4× scale and 128-pixel tiles, then reduced proportionally to 3840 pixels wide with macOS `sips`. This is super-resolution of the approved artwork; the separate official logos retain their original bytes. The upscaler is a build-time tool, not an app dependency. Each game template requests `scene.resolution: "native"` so Retina rendering is not limited to the default 1920-pixel surface.

| Wallpaper | Official logo | Official promotional artwork | Owner |
| --- | --- | --- | --- |
| wolverine-after-rain | [Source](https://gmedia.playstation.com/is/image/SIEPDC/wolverine-logo-02-en-30sept25?fmt=png-alpha&wid=1000) | [Source](https://gmedia.playstation.com/is/image/SIEPDC/marvels-wolverine-screenshot-06-en-08june26?fmt=png&wid=1600) | Marvel / Insomniac Games / Sony Interactive Entertainment |
| cyberpunk-night-city | [Source](https://cdn.akamai.steamstatic.com/steam/apps/1091500/logo.png) | [Source](https://cdn.akamai.steamstatic.com/steam/apps/1091500/library_hero.jpg) | CD PROJEKT RED |
| elden-ring-grace | [Source](https://cdn.akamai.steamstatic.com/steam/apps/1245620/logo.png) | [Source](https://cdn.akamai.steamstatic.com/steam/apps/1245620/library_hero.jpg) | FromSoftware / Bandai Namco Entertainment |
| doom-ember-citadel | [Source](https://cdn.akamai.steamstatic.com/steam/apps/782330/logo.png) | [Source](https://cdn.akamai.steamstatic.com/steam/apps/782330/library_hero.jpg) | id Software / Bethesda Softworks |
| forza-horizon-dusk | [Source](https://cdn.akamai.steamstatic.com/steam/apps/1551360/logo.png) | [Source](https://cdn.akamai.steamstatic.com/steam/apps/1551360/library_hero.jpg) | Playground Games / Xbox Game Studios |
| hollow-knight-greenpath | [Source](https://cdn.akamai.steamstatic.com/steam/apps/367520/logo.png) | [Source](https://cdn.akamai.steamstatic.com/steam/apps/367520/library_hero.jpg) | Team Cherry |
| wukong-cloud-temple | [Source](https://cdn.akamai.steamstatic.com/steam/apps/2358720/logo.png) | [Source](https://cdn.akamai.steamstatic.com/steam/apps/2358720/library_hero.jpg) | Game Science |
| red-dead-sunset | [Source](https://cdn.akamai.steamstatic.com/steam/apps/1174180/logo.png) | [Source](https://cdn.akamai.steamstatic.com/steam/apps/1174180/library_hero.jpg) | Rockstar Games |
| baldurs-gate-astral | [Source](https://cdn.akamai.steamstatic.com/steam/apps/1086940/logo.png) | [Source](https://cdn.akamai.steamstatic.com/steam/apps/1086940/library_hero.jpg) | Larian Studios / Wizards of the Coast |
| ghost-tsushima-maple | [Source](https://gmedia.playstation.com/is/image/SIEPDC/ghost-of-tsushima-directors-cut-logo-01-15jun21$en?fmt=png-alpha&wid=1000) | [Source](https://cdn.akamai.steamstatic.com/steam/apps/2215430/library_hero.jpg) | Sucker Punch Productions / Sony Interactive Entertainment |

## Useful live features

| Game | Useful feature | Scene response and source |
| --- | --- | --- |
| Wolverine | Battery percentage, charging state, macOS time estimate | Three recovery claws fill with reserve, pulse during charging, turn red below 20%; public IOKit power-source API |
| Cyberpunk | Download and upload traffic rates | Independent cyan and magenta lanes; `getifaddrs` physical `en*` counters, excluding loopback/tunnels; traffic rate, not a speed test |
| Elden Ring | Configurable 25-minute focus / 5-minute rest sessions | Grace ring fills during focus and turns blue during rest; public CoreGraphics idle time pauses focus after 60 seconds away |
| DOOM | System thermal state plus CPU and memory usage | Citadel heat and three armor cells follow `ProcessInfo.thermalState`; Mach host statistics supply CPU/memory, not fabricated temperature readings |
| Forza | City temperature, precipitation and conditions | Rain follows precipitation, clouds follow wind, night dims the scene; Open-Meteo forecast data |
| Hollow Knight | Configurable screen-break reminder, default 20 minutes | Five lights fill; 20 seconds without input resets the reminder; public CoreGraphics idle time |
| Wukong | Worldwide Steam player count and latest publisher announcement | Community constellation follows aggregate count on a logarithmic scale; public Steam Web API, app 2358720 |
| Red Dead Redemption 2 | Selected city's clock, sunrise, sunset and next-event countdown | Sun marker follows the daylight arc; timezone-aware solar instants from Open-Meteo, including day rollover |
| Baldur's Gate 3 | Free space on the Mac's home volume | Twelve inventory runes fill as storage fills; amber below 10% free; Foundation volume resource values |
| Ghost of Tsushima | Selected city's wind speed, direction and gusts | Compass points into the wind; leaves travel away from that bearing; Open-Meteo forecast data |

Every template binds its own namespace and up to four shader channels. `GameWallpaperConnectors` registers the providers without changing the provider assembly. Templates start only the providers they bind. Device readings stay local; no game account, game process, microphone or input contents are accessed. The idle API reads elapsed time, not keystrokes. Timers exist while their wallpaper provider is selected/applied and restart when it is recreated; sleep gaps do not advance them. Settings offer duration and restart, saved per wallpaper. Preview and desktop timer sessions are independent.

Forza, Red Dead and Ghost require a city selected in Settings. City search sends the typed query to Open-Meteo's geocoder; forecast requests send the selected city's coordinates, never device-derived location. The city is shown beside the readings. Weather uses °C and km/h. Open-Meteo provides forecast/model conditions, not an on-device weather sensor. Data attribution: Open-Meteo, CC BY 4.0; city data: GeoNames. The default endpoints are Open-Meteo's public non-commercial service; a commercial distribution should configure a licensed service according to its [API terms](https://open-meteo.com/en/terms).

`PublicWallpaperFeed` shares cached, validated responses between preview and desktop, caps bodies at 512 KiB and cache entries at 32, reserves fetch windows to prevent duplicate requests, and retries failures after 60 seconds. Normal refresh/maximum cache ages are weather 10 minutes/2 hours, Steam counts 2 minutes/10 minutes, and Steam news 15 minutes/24 hours. Weather also expires old upstream observation timestamps. Cached readings show timestamps; expired or absent values become unavailable. Publisher headlines are plain, bounded text. No account authentication is needed.

The original logo stays in a separate untinted pass. Lid closure lowers exposure and the pointer adds depth. Reduce Motion freezes decorative movement while live data remains readable. These scenes cap animation at 30 fps; providers run at 1–5 second intervals independently of rendering.

API references: [Open-Meteo forecast](https://open-meteo.com/en/docs), [city search](https://open-meteo.com/en/docs/geocoding-api), [Steam players](https://partner.steamgames.com/doc/webapi/ISteamUserStats#GetNumberOfCurrentPlayers), [Steam news](https://partner.steamgames.com/doc/webapi/isteamnews), [Apple idle time](https://developer.apple.com/documentation/coregraphics/cgeventsource/secondssincelasteventtype(_:eventtype:)), [Apple thermal state](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.property).

## Lid effects

**Glass Fracture** expands from a central impact into irregular spectral glass facets. The geometry and lighting retrace deterministically as the lid opens. It is a procedural overlay, so it does not capture or break apart desktop pixels.

**Ink Vortex** grows from a central pool in curled turquoise and violet arms. Its surface flows with the shared effect clock; Reduce Motion freezes that motion. Both effects are transparent at zero, visible at the inclusive onset, fully cover the display at completion, and use premultiplied alpha.

## Verification

`GameWallpaperTests.swift` exercises all ten scenes, their real artwork and marks, atmosphere/metric changes, lid and parallax inputs, still poses, portrait and ultrawide opacity, and a 3840×2400 GPU budget of 33.3 ms for their 30 fps animation. It verifies the 3840×2402 asset dimensions and uncapped native render surfaces. `LidImpactTests.swift` checks radial onset, reversible closure, strength, premultiplied alpha, full coverage at three aspect ratios, Reduce Motion, and native 3024×1964 frame time. The shared golden-frame and shader-check paths also include the additions.

`WallpaperRestClockTests`, `GameDeviceFeatureTests` and `GamePublicFeatureTests` cover sleep/idle boundaries, counter resets, missing estimates, thermal states, storage limits, city readiness, timezone/day rollover, polar missing events, caching, rate limits, invalid responses, expiry and recovery. `GameLivePresentationTests` renders the actual readout layers; the existing native setup snapshot suite includes city and timer controls. Its illustrative readings are test-only; exported gallery covers use missing-data placeholders.

Run live public endpoints and local device seams explicitly with `UNFOLDMYMAC_GAME_LIVE_CHECK=1 swift test --filter gamePublicEndpoints`. Generate review PNGs with `UNFOLDMYMAC_GAME_LIVE_ARTIFACTS=/tmp/game-previews swift test --filter gameLiveReadouts`. Each game also has a golden frame with nonzero data channels. Use `swift test` and `./script/build_and_run.sh --shader-check` for the complete checks.
