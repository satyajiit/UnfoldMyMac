import { createHash } from "node:crypto";
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import path from "node:path";
import { load } from "cheerio";
import sharp from "sharp";
import { pages, site, release, type Release } from "../src/lib/site";
import { catalog, gameWallpapers } from "../src/lib/catalog";
import { getArticles } from "../src/lib/content";
import { releaseProblems } from "../src/lib/release-validation";
import { libraryRoutes } from "../src/lib/design-content";
import { designPath } from "../src/lib/catalog-routes";
const routes = [...[...pages, ...libraryRoutes].map(page => page.path), ...getArticles().map(article => `/blog/${article.slug}/`)];
for (const route of routes) test(`static export, metadata, and local resources: ${route}`, () => {
  const $ = load(readFileSync(path.join("out", route, "index.html"), "utf8"));
  assert.equal($("main h1").length, 1);
  assert.ok($("title").text().includes("UnfoldMyMac"));
  assert.equal($("link[rel=canonical]").attr("href"), `${site.url}${route}`);
  assert.ok($("meta[name=description]").attr("content"));
  assert.equal($("link[rel=canonical]").length, 1);
  assert.equal($("html").attr("lang"), "en");
  assert.ok($("meta[name=viewport]").attr("content")?.includes("width=device-width"));
  assert.equal($("meta[property='og:url']").attr("content"), `${site.url}${route}`);
  assert.ok($("meta[property='og:title']").attr("content"));
  assert.equal($("meta[property='og:description']").attr("content"), $("meta[name=description]").attr("content"));
  assert.equal($("meta[property='og:locale']").attr("content"), "en_US");
  const design = catalog.find(item => designPath(item) === route);
  const imageURL = `${site.url}${design?.poster ?? "/media/featured.png"}`;
  assert.equal($("meta[property='og:image']").attr("content"), imageURL);
  if (!design) {
    assert.equal($("meta[property='og:image:width']").attr("content"), "1200");
    assert.equal($("meta[property='og:image:height']").attr("content"), "630");
  }
  assert.equal($("meta[property='og:image:type']").attr("content"), design ? "image/webp" : "image/png");
  assert.ok($("meta[property='og:image:alt']").attr("content"));
  assert.equal($("meta[name='twitter:card']").attr("content"), "summary_large_image");
  assert.equal($("meta[name='twitter:image']").attr("content"), imageURL);
  assert.ok($("meta[name='twitter:image:alt']").attr("content"));
  assert.equal($("meta[name=robots]").attr("content"), "index, follow");
  assert.ok($("meta[name=googlebot]").attr("content")?.includes("max-image-preview:large"));
  assert.equal($("link[rel=describedby]").attr("href"), "/llms.txt");
  assert.ok(existsSync(path.join("out", route, "index.md")));
  for (const element of $("a[href],img[src],link[rel=stylesheet],script[src]").toArray()) {
    const url = $(element).attr("href") ?? $(element).attr("src")!;
    if (!url.startsWith("/") || url.startsWith("//")) continue;
    const pathname = new URL(url, site.url).pathname;
    const file = path.join("out", pathname, pathname.endsWith("/") ? "index.html" : "");
    assert.ok(existsSync(file), `Missing ${url} linked from ${route}`);
  }
  for (const script of $("script[type='application/ld+json']").toArray()) assert.doesNotThrow(() => JSON.parse($(script).text()));
});
test("search snippets are unique and the featured social image is export-ready", async () => {
  const documents = routes.map(route => load(readFileSync(path.join("out", route, "index.html"), "utf8")));
  assert.equal(new Set(documents.map($ => $("title").text())).size, routes.length);
  assert.equal(new Set(documents.map($ => $("meta[name=description]").attr("content"))).size, routes.length);
  const image = await sharp("out/media/featured.png").metadata();
  assert.equal(image.width, 1200);
  assert.equal(image.height, 630);
  assert.equal(image.format, "png");
  assert.ok(readFileSync("out/media/featured.png").length < 2 * 1024 * 1024);
  const missing = load(readFileSync("out/404.html", "utf8"));
  assert.ok(missing("meta[name=robots]").toArray().some(element => missing(element).attr("content")?.includes("noindex")));
});
test("catalog assets and search discovery are complete", () => {
  assert.equal(catalog.length, 35);
  assert.equal(new Set(catalog.map(item => item.id)).size, catalog.length);
  const sitemap = readFileSync("out/sitemap.xml", "utf8");
  const llms = readFileSync("out/llms.txt", "utf8");
  for (const route of routes) { assert.ok(sitemap.includes(`${site.url}${route}`)); assert.ok(llms.includes(`${site.url}${route}index.md`)); }
  for (const item of catalog) { assert.ok(existsSync(path.join("out", item.poster)), item.poster); if (item.video) assert.ok(existsSync(path.join("out", item.video)), item.video); }
  assert.ok(existsSync("out/404.html"));
  assert.ok(existsSync("out/.nojekyll"));
});
test("pending release cannot pass the public launch gate", () => {
  if (release.status === "pending") assert.ok(releaseProblems(release).length > 0);
});
test("release gate rejects mismatched assets, unknown signing, and future attestations", () => {
  const valid: Release = { status: "available", version: "1.0.0", tag: "v1.0.0", assetUrl: "https://github.com/satyajiit/UnfoldMyMac/releases/download/v1.0.0/UnfoldMyMac.dmg", sha256: "a".repeat(64), architectures: ["arm64"], minimumMacOS: "26", signing: "developer-id-notarized", verifiedAt: "2026-01-01" };
  assert.deepEqual(releaseProblems(valid), []);
  assert.ok(releaseProblems({ ...valid, assetUrl: "https://example.com/download.dmg" }).length);
  assert.ok(releaseProblems({ ...valid, tag: "v2.0.0" }).length);
  assert.ok(releaseProblems({ ...valid, signing: "unverified" }).length);
  assert.ok(releaseProblems({ ...valid, verifiedAt: "2099-01-01" }).length);
});

test("native previews have consistent 60 fps provenance", () => {
  const manifest = JSON.parse(readFileSync("scripts/media-manifest.json", "utf8")) as { file: string; width: number; height: number; avg_frame_rate: string; nb_frames: string; sha256: string }[];
  assert.equal(manifest.length, catalog.filter(item => item.video).length);
  for (const item of manifest) {
    assert.equal(item.avg_frame_rate, "60/1");
    if (gameWallpapers.some(game => `${game.id}.mp4` === item.file)) assert.deepEqual([item.width, item.height], [1920, 1200]);
    assert.equal(item.nb_frames, item.file === "hinge-garden.mp4" ? "1320" : item.file === "the-workshop.mp4" ? "1080" : "240");
    assert.equal(createHash("sha256").update(readFileSync(path.join("public/media", item.file))).digest("hex"), item.sha256);
  }
});
