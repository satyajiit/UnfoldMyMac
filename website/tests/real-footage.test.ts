import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import path from "node:path";
import { load } from "cheerio";
import { catalog } from "../src/lib/catalog";
import { realLifeClips, realLifeReel } from "../src/lib/real-footage";
import timings from "../src/lib/film-timings.json" with { type: "json" };

const clips = [realLifeReel, ...realLifeClips];

test("every film plays from YouTube and no video file ships with the site", () => {
  assert.equal(clips.length, 6);
  const home = load(readFileSync("out/index.html", "utf8"));
  const showcase = load(readFileSync("out/showcase/index.html", "utf8"));
  assert.equal(home(".real-film").length, 1);
  assert.equal(showcase(".real-film").length, 6);
  assert.equal(showcase(".showcase-grid article").length, catalog.length);
  for (const item of catalog) assert.equal(showcase(`#${item.id}`).length, 1);
  for (const clip of clips) {
    assert.ok(clip.youtubeId, `${clip.id} needs a YouTube upload`);
    assert.equal(showcase(`#${clip.id}`).attr("data-provider"), "youtube");
    // The iframe is created on Play, so the exported page must not embed one.
    assert.equal(showcase(`#${clip.id} video, #${clip.id} iframe`).length, 0);
    assert.equal(showcase(`#${clip.id} a[href='https://www.youtube.com/watch?v=${clip.youtubeId}']`).length, 1);
    assert.equal(showcase(`#${clip.id} track`).length, 0);
    assert.ok(existsSync(path.join("out", clip.poster)), clip.poster);
    const slug = clip.id.replace(/^real-/, "");
    for (const file of [`${slug}.mp4`, `${slug}-hdr.mp4`, `${slug}.vtt`]) {
      assert.equal(existsSync(path.join("out/media/real-life", file)), false, `${file} must not ship`);
    }
  }
});

test("website carousel includes every current design alongside the original filmed collection", () => {
  const effects = catalog.filter(item => item.kind === "effect");
  const wallpapers = catalog.filter(item => item.kind === "wallpaper");
  assert.deepEqual([catalog.length, effects.length, wallpapers.length, catalog.filter(item => item.kind === "scene").length], [24, 13, 10, 1]);
  assert.equal(new Set(catalog.map(item => item.id)).size, catalog.length);
  for (const route of ["out/index.html", "out/showcase/index.html"]) {
    const $ = load(readFileSync(route, "utf8"));
    assert.equal($(".collection-rail button").length, catalog.length);
    for (const item of catalog) assert.equal($(`#collection-tab-${item.id}`).length, 1);
    const ids = $("[id]").map((_, element) => $(element).attr("id")).get();
    assert.equal(new Set(ids).size, ids.length, `Duplicate anchors in ${route}`);
  }
});

test("camera films cover the original recording and the story has three chapters without subtitles", () => {
  const recordings = Object.entries(timings.clips);
  assert.equal(realLifeClips.length, 5);
  assert.equal(recordings.length, 5);
  for (const [id, recording] of recordings) {
    const clip = realLifeClips.find(clip => clip.id === `real-${id}`)!;
    assert.ok(clip, id);
    assert.equal(clip.duration, recording.duration);
    // Each clip gets a one-second transition before and after the complete recording.
    assert.ok(Math.abs(recording.duration - recording.sourceDuration - 2) < 1 / 60, id);
  }
  const transcript = readFileSync("out/media/real-life/reel-transcript.txt", "utf8");
  assert.ok(transcript.includes("iPhone Duo"));
  assert.ok(transcript.includes("an app that makes your desktop react"));
  assert.ok(transcript.includes("twenty-three templates"));
  assert.deepEqual(realLifeReel.chapters?.map(chapter => chapter.label), ["How it started", "The collection", "Café recordings · 1.5×"]);
  assert.equal(realLifeReel.duration, 149.6);
  assert.deepEqual(realLifeReel.chapters?.map(chapter => chapter.start), [0, 44, 82]);
  assert.ok(transcript.includes("Download it at unfold my mac dot com."));
  assert.ok(!transcript.includes("Grab the source"));
});

test("README posters link to the uploads and to real showcase anchors", () => {
  const markdown = readFileSync("../README.md", "utf8");
  const showcase = load(readFileSync("out/showcase/index.html", "utf8"));
  assert.ok(markdown.includes("## Filmed on a real MacBook"));
  assert.ok(!/website\/public\/media\/real-life\/[\w-]+\.mp4/.test(markdown), "No links to deleted video files");
  for (const clip of clips) {
    const filename = `${clip.id.replace(/^real-/, "")}.jpg`;
    assert.ok(existsSync(`../.github/media/real-life/${filename}`), filename);
    assert.ok(markdown.includes(`.github/media/real-life/${filename}`), filename);
    assert.ok(markdown.includes(clip.youtubeId), clip.id);
    assert.ok(markdown.includes(`/showcase/#${clip.id}`), clip.id);
    assert.equal(showcase(`#${clip.id}`).length, 1);
  }
});
