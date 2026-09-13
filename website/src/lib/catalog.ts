export interface ShowcaseItem {
  id: string; name: string; kind: "effect" | "wallpaper" | "scene"; category: string;
  description: string; poster: string; video?: string; sampleData?: boolean; credit?: string;
}
const effect = (id: string, name: string, category: string, description: string, video = true): ShowcaseItem => ({
  id, name, category, description, kind: "effect", poster: `/media/${id}.webp`, ...(video ? { video: `/media/${id}.mp4` } : {}),
});
const wallpaper = (id: string, name: string, description: string): ShowcaseItem => ({
  id, name, description, kind: "wallpaper", category: "Dynamic Wallpapers", poster: `/media/${id}.webp`, video: `/media/${id}.mp4`, sampleData: true,
});
export const gameWallpapers: ShowcaseItem[] = [
  { ...wallpaper("wolverine-after-rain", "Wolverine — After the Rain", "Three glowing claws track your battery reserve. Charging brings recovery light; low power turns the marks red."), credit: "Official logo © Marvel / Insomniac Games / Sony Interactive Entertainment." },
  { ...wallpaper("cyberpunk-night-city", "Cyberpunk 2077 — Night City", "Neon lanes follow your Mac’s download and upload traffic, with both transfer rates visible."), credit: "Official logo © CD PROJEKT RED." },
  { ...wallpaper("elden-ring-grace", "Elden Ring — A Moment of Grace", "A golden grace ring fills during focus, then turns blue for a rest. The timer pauses when you step away."), credit: "Official logo © FromSoftware / Bandai Namco Entertainment." },
  { ...wallpaper("doom-ember-citadel", "DOOM Eternal — Ember Citadel", "Thermal armor responds to macOS heat pressure, with CPU and memory readings beneath the citadel."), credit: "Official logo © id Software / Bethesda Softworks." },
  { ...wallpaper("forza-horizon-dusk", "Forza Horizon 5 — Endless Dusk", "Your chosen city’s weather brings rain, clouds, and nightfall to the open road. Forecasts by Open-Meteo."), credit: "Official logo © Playground Games / Xbox Game Studios." },
  { ...wallpaper("hollow-knight-greenpath", "Hollow Knight — Greenpath", "Five quiet lights count toward your next screen break. Twenty seconds away resets the reminder."), credit: "Official logo © Team Cherry." },
  { ...wallpaper("wukong-cloud-temple", "Black Myth: Wukong — Cloud Temple", "Temple lights follow the worldwide Steam player count. Publisher announcements keep you connected to the game."), credit: "Official logo © Game Science." },
  { ...wallpaper("red-dead-sunset", "Red Dead Redemption 2 — Last Light", "A daylight companion with your chosen city’s clock, sunrise, sunset, and the time until the next solar event."), credit: "Official logo © Rockstar Games." },
  { ...wallpaper("baldurs-gate-astral", "Baldur’s Gate 3 — Astral Twilight", "Inventory runes track storage on your Mac’s home volume. Free space stays visible beside the astral skyline."), credit: "Official logo © Larian Studios / Wizards of the Coast." },
  { ...wallpaper("ghost-tsushima-maple", "Ghost of Tsushima — Scarlet Wind", "Leaves follow your chosen city’s wind. A compass, wind speed, and gust readings guide the scene."), credit: "Official logo © Sucker Punch Productions / Sony Interactive Entertainment." },
];
export const collections = [
  { id: "effect", name: "Lid Effects", anchor: "lid-effects", description: "13 effects that follow your lid. Browse by style, filter by tags, and arrange every detail in Adjust." },
  { id: "wallpaper", name: "Dynamic Wallpapers", anchor: "wallpapers", description: "20 moving desktops. Explore game worlds, useful Mac readings, and public data connections." },
  { id: "scene", name: "Creative Scenes", anchor: "creative-scenes", description: "Interactive worlds shaped by your Mac. Explore Hinge Garden and The Workshop." },
] as const;
export const catalog: ShowcaseItem[] = [
  effect("curtains", "Curtains", "Motion & 3D", "Velvet folds and stage lighting. A curtain call for your tabs."),
  effect("peekaboo", "Peekaboo", "Motion & 3D", "Blinking, curious characters. Your desktop has acquired witnesses."),
  effect("current", "Current", "Motion & 3D", "Mint and coral ribbons that keep moving while the lid holds still."),
  effect("frost", "Frost", "Glass & Light", "The original iPhone Duo-inspired effect. A live blur of your desktop, drawn in as you close the lid."),
  effect("veil", "Veil", "Glass & Light", "A soft, native translucent material over your desktop."),
  effect("fade", "Fade", "Glass & Light", "A quiet dimming effect. Sometimes less is plenty."),
  effect("reverie", "Reverie", "Image Art", "Celestial paper art opens along a curved, moonlit seam."),
  effect("neon-coast", "Neon Coast", "Image Art", "A neon coastline separates into angled panels."),
  effect("rise", "Rise", "Image Art", "MAKE IT HAPPEN. With cobalt steps and a sunburst."),
  effect("tab-goblin", "Tab Goblin", "Image Art", "Bro. Close a tab. The laptop has a point."),
  effect("fcuk-it", "FCUK It. Ship It.", "Image Art", "An orange-and-cobalt answer to one more round of tweaking."),
  effect("codex-after-dark", "Codex After Dark", "Image Art", "One more fix. A midnight pixel-art bug chase."),
  effect("claude-has-notes", "Claude Has Notes", "Image Art", "Just one small change. The revision pile disagrees."),
  wallpaper("pulse", "Pulse", "CPU load, memory, and battery feed a moving chrome sculpture."),
  wallpaper("daydream", "Daydream", "Your image, floating glass, and a sticker with opinions."),
  wallpaper("claude-current", "Claude Current", "Local Claude session metadata and token counts bring the scene to life."),
  wallpaper("codex-foundry", "Codex Foundry", "A 3D accelerator assembles around local Codex activity."),
  wallpaper("codex-mission-control", "Codex Mission Control", "A little robot responds to working, waiting, and completed hook states."),
  wallpaper("grok-horizon", "Grok Event Horizon", "A black hole with playful wallpaper-session counters."),
  wallpaper("github-after-hours", "GitHub After Hours", "Public repositories, followers, and push events become a floating city."),
  wallpaper("lights-out", "Lights Out", "An open-wheel car, a flowing circuit, and a five-light countdown. Session counters, not live race telemetry."),
  wallpaper("gta-vi-countdown", "GTA VI — Vice City Countdown", "Official Rockstar artwork and a calendar-day countdown to the announced console release. Artwork © Rockstar Games."),
  wallpaper("aurora-observatory", "Aurora Observatory", "NOAA space weather shapes auroral curtains around a 3D Earth. NASA Earth Observatory imagery; an artistic interpretation."),
  ...gameWallpapers,
  { id: "hinge-garden", name: "Hinge Garden", kind: "scene", category: "Creative Scenes", description: "A glass snail tends a tiny greenhouse. Lid movement, charger power, and optional sound bring the garden to life.", poster: "/media/hinge-garden.webp", video: "/media/hinge-garden.mp4", sampleData: true },
  { id: "the-workshop", name: "The Workshop", kind: "scene", category: "Creative Scenes", description: "A tiny maker’s studio opens with your Mac. Open apps light the benches; items in a folder you choose become parcels. Gentle motion and rotating lines keep you company.", poster: "/media/the-workshop.webp", video: "/media/the-workshop.mp4", sampleData: true },
];
export const featured = ["curtains", "peekaboo", "reverie"].map(id => catalog.find(item => item.id === id)!);
