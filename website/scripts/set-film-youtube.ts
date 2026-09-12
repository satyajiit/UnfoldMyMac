import { readFileSync, writeFileSync } from "node:fs";
import { youtubeId } from "../src/lib/youtube";

const file = new URL("../src/lib/youtube-videos.json", import.meta.url);
const videos = JSON.parse(readFileSync(file, "utf8")) as Record<string, string | null>;
const [film, link, ...extra] = process.argv.slice(2);
if (!film || !Object.hasOwn(videos, film) || !link || extra.length) {
  throw new Error(`Usage: npm run films:youtube -- <${Object.keys(videos).join("|")}> <YouTube URL or ID | --clear>`);
}
const id = link === "--clear" ? null : youtubeId(link);
if (link !== "--clear" && !id) throw new Error("Supply a valid HTTPS YouTube link or 11-character video ID.");
videos[film] = id ? `https://www.youtube.com/watch?v=${id}` : null;
writeFileSync(file, JSON.stringify(videos, null, 2) + "\n");
console.log(`${film}: ${videos[film] || "local video fallback"}. Run npm run build to refresh the local website.`);
