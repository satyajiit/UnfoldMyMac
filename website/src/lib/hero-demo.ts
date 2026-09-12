export const wallpaperInterval = 6_000;
export const lidAngles = { min: 30, max: 125, coverClosed: 30, coverOpen: 110 } as const;
export const heroWallpapers = [
  { id: "lights-out", label: "F1", name: "Lights Out", detail: "F1-inspired wallpaper · Sample session counters" },
  { id: "codex-mission-control", label: "Codex", name: "Codex Mission Control", detail: "A robot following your work · Sample hook states" },
  { id: "gta-vi-countdown", label: "GTA VI", name: "Vice City Countdown", detail: "Counting down the days · Recorded calendar preview" },
] as const;

export const heroCovers = [
  { id: "curtains", name: "Curtains", treatment: "split" },
  { id: "frost", name: "Frost", treatment: "frost" },
  { id: "peekaboo", name: "Peekaboo", treatment: "split" },
  { id: "reverie", name: "Reverie", treatment: "split" },
  { id: "neon-coast", name: "Neon Coast", treatment: "split" },
  { id: "fade", name: "Fade", treatment: "fade" },
] as const;
