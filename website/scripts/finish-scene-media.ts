import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile, rm } from "node:fs/promises";
import sharp from "sharp";
import { interactiveScenes, scenePosterURL, sceneClipURL, type SceneClip } from "../src/lib/scene-preview";

const manifest = [];
for (const scene of interactiveScenes) {
  for (const charging of [false, true]) for (const closed of [false, true]) {
    const file = `public${scenePosterURL(scene, charging, closed)}`;
    const png = file.replace(/\.webp$/, ".png");
    await sharp(png).webp({ quality: 88 }).toFile(file);
    await rm(png);
  }
  const clips: [SceneClip, boolean][] = [["idle", false], ["idle", true], ["connect", true], ["disconnect", false], ["lid", false], ["lid", true]];
  for (const [clip, charging] of clips) {
    const file = sceneClipURL(scene, clip, charging);
    const probe = JSON.parse(execFileSync("ffprobe", ["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height,avg_frame_rate,nb_frames,duration", "-of", "json", `public${file}`], { encoding: "utf8" })).streams[0];
    manifest.push({ file, ...probe, sha256: createHash("sha256").update(await readFile(`public${file}`)).digest("hex") });
  }
}
await writeFile("scripts/scene-media-manifest.json", JSON.stringify(manifest, null, 2) + "\n");
console.log(`Prepared ${manifest.length} native response clips and 8 still poses.`);
