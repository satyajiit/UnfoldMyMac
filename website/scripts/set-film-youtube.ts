import { readFileSync, writeFileSync } from "node:fs";
import { youtubeId } from "../src/lib/youtube";

const file = new URL("../src/lib/youtube-videos.json", import.meta.url);
const videos = JSON.parse(readFileSync(file, "utf8")) as Record<string, string>;
const [film, link, ...extra] = process.argv.slice(2);
if (!film || !Object.hasOwn(videos, film) || !link || extra.length) {
  throw new Error(`Usage: npm run films:youtube -- <${Object.keys(videos).join("|")}> <YouTube URL or ID>`);
}
// There is no empty state to clear to. Every film plays from YouTube and no video file ships with
// the site, so real-footage.ts throws during the build on a missing or malformed link.
const id = youtubeId(link);
if (!id) throw new Error("Supply a valid HTTPS YouTube link or 11-character video ID.");
videos[film] = `https://www.youtube.com/watch?v=${id}`;
writeFileSync(file, JSON.stringify(videos, null, 2) + "\n");
console.log(`${film}: ${videos[film]}. Run npm run build to refresh the local website.`);
