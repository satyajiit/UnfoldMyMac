import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { youtubeEmbed, youtubeId } from "../src/lib/youtube";

test("YouTube uploads accept IDs and supported links, and reject unrelated URLs", () => {
  const id = "AbCd_123-xy";
  for (const value of [id, `https://youtu.be/${id}?si=share`, `https://www.youtube.com/watch?v=${id}&t=30`, `https://youtube.com/shorts/${id}`, `https://www.youtube-nocookie.com/embed/${id}`]) {
    assert.equal(youtubeId(value), id);
  }
  for (const value of [null, "", "too-short", `http://youtu.be/${id}`, `https://evil.test/watch?v=${id}`, `https://www.youtube.com.evil.test/watch?v=${id}`, `https://user@youtube.com/watch?v=${id}`, `https://youtu.be/${id}/extra`]) {
    assert.equal(youtubeId(value), null);
  }
  const uploads = JSON.parse(readFileSync("src/lib/youtube-videos.json", "utf8")) as Record<string, string | null>;
  assert.deepEqual(Object.keys(uploads).sort(), ["reel", "lights-out", "codex-foundry", "claude-has-notes", "frost", "neon-coast"].sort());
  for (const [name, value] of Object.entries(uploads)) if (value !== null) assert.ok(youtubeId(value), name);
});

test("the embed uses the privacy-enhanced host, correct origin, and chapter time", () => {
  const url = new URL(youtubeEmbed("AbCd_123-xy", "https://unfoldmymac.com", 105.2333));
  assert.equal(url.origin, "https://www.youtube-nocookie.com");
  assert.equal(url.searchParams.get("cc_load_policy"), "0");
  assert.equal(url.searchParams.get("origin"), "https://unfoldmymac.com");
  assert.equal(url.searchParams.get("start"), "105");
  assert.equal(url.searchParams.get("enablejsapi"), "1");
  assert.equal(url.searchParams.get("playsinline"), "1");
  assert.throws(() => youtubeEmbed("invalid", "https://unfoldmymac.com"));
});
