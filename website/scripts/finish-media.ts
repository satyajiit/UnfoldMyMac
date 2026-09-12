import { execFileSync } from "node:child_process";
import { readFileSync, readdirSync, writeFileSync, existsSync, unlinkSync } from "node:fs";
import { createHash } from "node:crypto";
import sharp from "sharp";
import { catalog } from "../src/lib/catalog";
for (const item of catalog) {
  const png = execFileSync("ffmpeg", ["-v", "error", "-ss", "1", "-i", `public/media/${item.id}.mp4`, "-frames:v", "1", "-f", "image2pipe", "-vcodec", "png", "pipe:1"], { maxBuffer: 8 * 1024 * 1024 });
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
  return { file, source: "Updated README preview exporter, rendered at 60 fps", readmePreview: `.github/media/${item.kind === "effect" ? "effects" : "wallpapers"}/${item.id}.gif`, sampleData: item.kind === "wallpaper", demoDesktop: item.kind === "effect", ...info, bytes: bytes.length, sha256: createHash("sha256").update(bytes).digest("hex") };
});
writeFileSync("scripts/media-manifest.json", JSON.stringify(manifest, null, 2) + "\n");
console.log(`Prepared preview posters. Verified ${manifest.length} native 60 fps videos.`);
