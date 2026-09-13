import timings from "./film-timings.json" with { type: "json" };
import uploads from "./youtube-videos.json" with { type: "json" };
import { youtubeId } from "./youtube";

export interface RealFootage {
  id: string;
  title: string;
  description: string;
  category: string;
  duration: number;
  poster: string;
  posterAlt?: string;
  youtubeId: string;
  chapters?: { label: string; start: number }[];
}

export const formatFilmTime = (seconds: number) => `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(Math.floor(seconds % 60)).padStart(2, "0")}`;

// Every film plays from YouTube and no video file ships with the site, so a missing or
// malformed upload has nothing to fall back to. Fail the build here rather than render a
// play button that can never start.
const upload = (id: keyof typeof uploads): string => {
  const video = youtubeId(uploads[id]);
  if (!video) throw new Error(`youtube-videos.json needs a valid YouTube link for "${id}"`);
  return video;
};

const footage = (id: keyof typeof timings.clips, title: string, category: string, description: string): RealFootage => ({
  ...timings.clips[id], id: `real-${id}`, title, category, description,
  poster: `/media/real-life/${id}.webp`, youtubeId: upload(id),
});

export const realLifeReel: RealFootage = {
  ...timings.reel, id: "real-reel", title: "Watch the lid.", category: "The full story",
  description: "A Mac app with animations that follow your lid and live wallpapers for your desktop. See where it started, choose a look, then watch it on a real MacBook.",
  poster: "/media/real-life/reel.webp", youtubeId: upload("reel"),
};

export const realLifeClips: RealFootage[] = [
  footage("lights-out", "Lights Out", "Live wallpaper", "Race cars run on the desktop while the lid moves. The complete café recording."),
  footage("codex-foundry", "Codex Foundry", "Live wallpaper", "Local Codex sessions and token counts feed a tiny factory on the desktop."),
  footage("claude-has-notes", "Claude Has Notes", "Lid effect", "Claude takes over as the lid closes. Open it to bring your windows back."),
  footage("frost", "Frost", "Lid effect", "The desktop blurs as the lid closes. Stop halfway and the blur stops there too."),
  footage("neon-coast", "Neon Coast", "Lid effect", "Lower the lid to reveal the artwork. Lift it to return to your desktop."),
];
