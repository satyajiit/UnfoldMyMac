import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { load } from "cheerio";
import { interactiveScenes, scenePosterURL } from "../src/lib/scene-preview";

test("interactive responses are native 60 fps renders with every required still pose", () => {
  const clips = JSON.parse(readFileSync("scripts/scene-media-manifest.json", "utf8")) as { file: string; width: number; height: number; avg_frame_rate: string; nb_frames: string; sha256: string }[];
  assert.equal(clips.length, 12);
  for (const clip of clips) {
    assert.equal(clip.avg_frame_rate, "60/1");
    assert.deepEqual([clip.width, clip.height], [960, 600]);
    assert.equal(Number(clip.nb_frames), clip.file.includes("-lid-") ? 103 : clip.file.endsWith("-connect.mp4") ? 600 : 360);
    assert.equal(createHash("sha256").update(readFileSync(`public${clip.file}`)).digest("hex"), clip.sha256);
  }
  for (const scene of interactiveScenes) for (const charging of [false, true]) for (const closed of [false, true]) assert.ok(existsSync(`out${scenePosterURL(scene, charging, closed)}`));
});

test("Creative Scene cards and detail pages contain a Mac and accessible event controls", () => {
  for (const route of ["/", "/features/", "/creative-scenes/", ...interactiveScenes.map(id => `/creative-scenes/${id}/`)]) {
    const $ = load(readFileSync(`out${route}index.html`, "utf8"));
    for (const scene of interactiveScenes) {
      const preview = $(`[data-scene-preview='${scene}']`);
      assert.equal(preview.length, 1, `${route} ${scene}`);
      assert.equal(preview.find("[data-mac-lid]").length, 1);
      assert.equal(preview.find("[data-mac-base]").length, 1);
      assert.ok(preview.text().includes("Connect charger"));
      assert.ok(preview.text().includes("Your device isn’t read"));
      assert.equal(preview.find("video[src]").length, 0, "Responses load only on interaction");
    }
  }
});
