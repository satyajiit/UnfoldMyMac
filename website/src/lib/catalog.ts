export interface ShowcaseItem {
  id: string; name: string; kind: "effect" | "wallpaper"; category: string;
  description: string; poster: string; video?: string; sampleData?: boolean;
}
const effect = (id: string, name: string, category: string, description: string, video = true): ShowcaseItem => ({
  id, name, category, description, kind: "effect", poster: `/media/${id}.webp`, ...(video ? { video: `/media/${id}.mp4` } : {}),
});
const wallpaper = (id: string, name: string, description: string): ShowcaseItem => ({
  id, name, description, kind: "wallpaper", category: "Live wallpaper", poster: `/media/${id}.webp`, video: `/media/${id}.mp4`, sampleData: true,
});
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
];
export const featured = ["curtains", "peekaboo", "reverie"].map(id => catalog.find(item => item.id === id)!);
