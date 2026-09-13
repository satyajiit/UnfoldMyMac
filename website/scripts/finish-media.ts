import { execFileSync } from "node:child_process";
import { readFileSync, readdirSync, writeFileSync, existsSync, unlinkSync } from "node:fs";
import { createHash } from "node:crypto";
import sharp from "sharp";
import { catalog, gameWallpapers } from "../src/lib/catalog";
const selected = process.argv.slice(2).flatMap(id => id === "games" ? gameWallpapers.map(item => item.id) : [id]);
for (const item of catalog.filter(item => item.video && (!selected.length || selected.includes(item.id)))) {
  const png = execFileSync("ffmpeg", ["-v", "error", "-ss", item.id === "the-workshop" ? "12" : "1", "-i", `public/media/${item.id}.mp4`, "-frames:v", "1", "-f", "image2pipe", "-vcodec", "png", "pipe:1"], { maxBuffer: 8 * 1024 * 1024 });
  await sharp(png).webp({ quality: 85 }).toFile(`public/media/${item.id}.webp`);
}
if (existsSync("public/media/demo-desktop.png")) {
  await sharp("public/media/demo-desktop.png").webp({ quality: 90 }).toFile("public/media/demo-desktop.webp");
  unlinkSync("public/media/demo-desktop.png");
}
const manifest = readdirSync("public/media").filter(file => file.endsWith(".mp4")).map(file => {
  const bytes = readFileSync(`public/media/${file}`);
  const info = JSON.parse(execFileSync("ffprobe", ["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height,avg_frame_rate,nb_frames", "-of", "json", `public/media/${file}`], { encoding: "utf8" })).streams[0];
  const item = catalog.find(item => `${item.id}.mp4` === file)!;
  const isGame = gameWallpapers.some(game => game.id === item.id);
  return { file, source: isGame ? "Native Metal wallpaper and SwiftUI readouts, 4K artwork with illustrative device and public data, rendered at 60 fps" : item.kind === "scene" ? "Native Metal scene with deterministic local input dynamics, rendered at 60 fps" : "Updated README preview exporter, rendered at 60 fps", readmePreview: item.kind === "scene" || isGame ? null : `.github/media/${item.kind === "effect" ? "effects" : "wallpapers"}/${item.id}.gif`, sampleData: item.kind !== "effect", demoDesktop: item.kind === "effect", ...info, bytes: bytes.length, sha256: createHash("sha256").update(bytes).digest("hex") };
});
writeFileSync("scripts/media-manifest.json", JSON.stringify(manifest, null, 2) + "\n");
console.log(`Prepared preview posters. Verified ${manifest.length} native 60 fps videos.`);
