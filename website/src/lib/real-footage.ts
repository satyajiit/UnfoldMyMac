export interface RealFootage {
  id: string;
  title: string;
  description: string;
  category: string;
  duration: number;
  video: string;
  poster: string;
}

const footage = (id: string, title: string, category: string, description: string, duration = 8): RealFootage => ({
  id: `real-${id}`, title, category, description, duration,
  video: `/media/real-life/${id}.mp4`, poster: `/media/real-life/${id}.webp`,
});

export const realLifeReel = footage("reel", "Lid down. Drama up.", "The highlight reel", "One MacBook, a café table, and a desktop with a little character. Five moments from the app, filmed in real life.", 24);

export const realLifeClips: RealFootage[] = [
  footage("lights-out", "Lights Out", "Live wallpaper", "Your desk. Pole position. A little race-day energy for your everyday desktop."),
  footage("codex-foundry", "Codex Foundry", "Live wallpaper", "Coffee in. Commits out. A small world with a coding habit."),
  footage("claude-has-notes", "Claude Has Notes", "Lid effect", "Just one small change. A lid reveal with a few revisions of its own."),
  footage("frost", "Frost", "Lid effect", "Close the lid. Lose the noise. Watch the desktop slip out of focus."),
  footage("neon-coast", "Neon Coast", "Lid effect", "Out of office. Into the neon. A little escape, right under your lid."),
];
