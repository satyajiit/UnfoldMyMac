import timings from "./film-timings.json" with { type: "json" };
import uploads from "./youtube-videos.json" with { type: "json" };
import { youtubeId } from "./youtube";

// HEVC Main 10, Level 4.1, as encoded in every delivered HDR file's hvcC box.
// A bare "hvc1" is rejected by Chrome's canPlayType even when HEVC decoding works.
export const HDR_MEDIA_TYPE = 'video/mp4; codecs="hvc1.2.4.L123.90"';

export interface RealFootage {
  id: string;
  title: string;
  description: string;
  category: string;
  duration: number;
  video: string;
  hdrVideo: string;
  poster: string;
  posterAlt?: string;
  youtubeId?: string | null;
  chapters?: { label: string; start: number }[];
}

export const formatFilmTime = (seconds: number) => `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(Math.floor(seconds % 60)).padStart(2, "0")}`;

const footage = (id: keyof typeof timings.clips, title: string, category: string, description: string): RealFootage => ({
  ...timings.clips[id], id: `real-${id}`, title, category, description,
  video: `/media/real-life/${id}.mp4`, hdrVideo: `/media/real-life/${id}-hdr.mp4`, poster: `/media/real-life/${id}.webp`,
  youtubeId: youtubeId(uploads[id]),
});

export const realLifeReel: RealFootage = {
  ...timings.reel, id: "real-reel", title: "Watch the lid.", category: "The full story",
  description: "A Mac app with animations that follow your lid and live wallpapers for your desktop. See where it started, choose a look, then watch it on a real MacBook.",
  video: "/media/real-life/reel.mp4", hdrVideo: "/media/real-life/reel-hdr.mp4", poster: "/media/real-life/reel.webp", youtubeId: youtubeId(uploads.reel),
};

export const realLifeClips: RealFootage[] = [
  footage("lights-out", "Lights Out", "Live wallpaper", "Race cars run on the desktop while the lid moves. The complete café recording."),
  footage("codex-foundry", "Codex Foundry", "Live wallpaper", "Local Codex sessions and token counts feed a tiny factory on the desktop."),
  footage("claude-has-notes", "Claude Has Notes", "Lid effect", "Claude takes over as the lid closes. Open it to bring your windows back."),
  footage("frost", "Frost", "Lid effect", "The desktop blurs as the lid closes. Stop halfway and the blur stops there too."),
  footage("neon-coast", "Neon Coast", "Lid effect", "Lower the lid to reveal the artwork. Lift it to return to your desktop."),
];
