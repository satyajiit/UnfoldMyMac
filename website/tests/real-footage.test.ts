import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import path from "node:path";
import { load } from "cheerio";
import { catalog } from "../src/lib/catalog";
import { realLifeClips, realLifeReel } from "../src/lib/real-footage";

test("real footage exports retain the original collection and ship verified media", () => {
  const clips = [realLifeReel, ...realLifeClips];
  const manifest = JSON.parse(readFileSync("../videos/real-life/delivery.json", "utf8")) as {
    id: string; file: string; sha256: string; width: number; height: number;
    fps: string; frames: number; duration: number; bytes: number;
  }[];
  assert.equal(manifest.length, 6);
  const home = load(readFileSync("out/index.html", "utf8"));
  const showcase = load(readFileSync("out/showcase/index.html", "utf8"));
  assert.equal(home(".real-film").length, 1);
  assert.equal(showcase(".real-film").length, 6);
  assert.equal(showcase(".showcase-grid article").length, catalog.length);
  for (const item of catalog) assert.equal(showcase(`#${item.id}`).length, 1);
  for (const clip of clips) {
    const entry = manifest.find(entry => entry.file === clip.video)!;
    assert.ok(entry, clip.video);
    assert.equal(entry.width, 1920);
    assert.equal(entry.height, 1080);
    assert.equal(entry.fps, "60/1");
    assert.equal(entry.frames, clip.duration * 60);
    assert.ok(Math.abs(entry.duration - clip.duration) < 0.1);
    const bytes = readFileSync(path.join("out", clip.video));
    assert.equal(bytes.length, entry.bytes);
    assert.ok(bytes.length < (clip.duration === 24 ? 15_000_000 : 6_000_000));
    assert.equal(createHash("sha256").update(bytes).digest("hex"), entry.sha256);
    assert.ok(existsSync(path.join("out", clip.poster)));
    assert.equal(showcase(`#${clip.id} video`).attr("preload"), "none");
    assert.equal(showcase(`#${clip.id} video`).attr("src"), undefined);
    assert.equal(showcase(`#${clip.id} a[download]`).attr("href"), clip.video);
  }
});

test("README posters and MP4 fallbacks exist and point to real showcase anchors", () => {
  const markdown = readFileSync("../README.md", "utf8");
  const showcase = load(readFileSync("out/showcase/index.html", "utf8"));
  assert.ok(markdown.includes("## Filmed on a real MacBook"));
  for (const item of [realLifeReel, ...realLifeClips]) {
    const filename = item.video.split("/").at(-1)!.replace(".mp4", ".jpg");
    assert.ok(existsSync(`../.github/media/real-life/${filename}`));
    assert.ok(markdown.includes(`.github/media/real-life/${filename}`));
    assert.ok(markdown.includes(`website/public${item.video}`));
    assert.ok(markdown.includes(`/showcase/#${item.id}`));
    assert.equal(showcase(`#${item.id}`).length, 1);
  }
});
