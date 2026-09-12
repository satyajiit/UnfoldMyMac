import { test, expect, type Page } from "@playwright/test";
import { build } from "esbuild";
import path from "node:path";
import timings from "../../src/lib/film-timings.json" with { type: "json" };
import { realLifeReel, realLifeClips } from "../../src/lib/real-footage";

// Exercise the production component with a configured ID without putting a
// placeholder upload into the real website. All YouTube traffic is intercepted.
let fixture: string;
test.beforeAll(async () => {
  const result = await build({
    stdin: { contents: `
      import React from 'react';
      import { createRoot } from 'react-dom/client';
      import { RealFootagePlayer } from './src/components/real-footage-player';
      import { realLifeReel } from './src/lib/real-footage';
      import { pauseOtherFilms } from './src/components/use-film-playback';
      createRoot(document.getElementById('root')).render(<>
        <RealFootagePlayer featured item={{...realLifeReel, youtubeId:'AbCd_123-xy'}} />
        <button onClick={() => pauseOtherFilms('another-film')}>Play another film</button>
        <div style={{height:1800}} /><footer>End</footer>
      </>);
    `, resolveDir: process.cwd(), loader: "tsx" },
    absWorkingDir: process.cwd(), bundle: true, write: false, format: "iife",
    tsconfig: path.resolve("tsconfig.json"), define: { "process.env.NODE_ENV": '"production"' },
    plugins: [{ name: "fixture-image", setup(builder) {
      builder.onResolve({ filter: /^next\/image$/ }, () => ({ path: "image", namespace: "fixture" }));
      builder.onLoad({ filter: /.*/, namespace: "fixture" }, () => ({ contents: `import React from 'react'; export default function Image({fill,...props}) { return <img {...props} /> }`, loader: "tsx", resolveDir: process.cwd() }));
    } }],
  });
  fixture = result.outputFiles[0].text;
});

const fakeAPI = `
  window.__youtubeEvents = window.__youtubeEvents || [];
  window.YT = { Player: class {
    constructor(frame, options) {
      this.options = options;
      this.captions = true;
      window.__youtubeCaptions = () => this.captions;
      window.__youtubeEnableCaptions = () => { this.captions = true; };
      window.__youtubeEvents.push(['create', frame.src]);
      window.__youtubeFail = () => options.events.onError();
      queueMicrotask(() => options.events.onReady());
    }
    seekTo(time) { window.__youtubeEvents.push(['seek', time]); }
    playVideo() { window.__youtubeEvents.push(['play']); this.options.events.onStateChange({data:1}); }
    pauseVideo() { window.__youtubeEvents.push(['pause']); }
    destroy() { window.__youtubeEvents.push(['destroy']); }
    unloadModule(module) { this.captions = false; window.__youtubeEvents.push(['unload', module]); }
  } };
  window.onYouTubeIframeAPIReady();
`;

async function openFixture(page: Page) {
  await page.route("**/__youtube-fixture/", route => route.fulfill({ contentType: "text/html", body: `<!doctype html><html lang="en"><head><title>Film player test</title><style>body{margin:16px;font-family:system-ui}.real-film-frame{position:relative;width:100%;max-width:800px;aspect-ratio:16/9;min-height:200px}.real-film-frame img,.real-film-video,iframe{position:absolute;inset:0;width:100%;height:100%;border:0}.real-film-play{position:absolute;left:40%;top:40%;z-index:3}.real-film-duration{position:absolute;bottom:0}.real-film-video:not(.is-loaded){visibility:hidden}</style></head><body><div id="root"></div><script src="/__youtube-fixture.js"></script></body></html>` }));
  await page.route("**/__youtube-fixture.js", route => route.fulfill({ contentType: "application/javascript", body: fixture }));
  await page.route("https://www.youtube-nocookie.com/**", route => route.fulfill({ contentType: "text/html", body: "<!doctype html><title>Stub player</title>" }));
  await page.goto("/__youtube-fixture/");
}

async function eventCount(page: Page, name: string) {
  return page.evaluate(name => ((window as unknown as { __youtubeEvents?: unknown[][] }).__youtubeEvents || []).filter(event => event[0] === name).length, name);
}

test("YouTube loads only on Play, seeks chapters, and pauses with other films or offscreen", async ({ page }) => {
  const requests: string[] = [];
  page.on("request", request => { if (/youtube|real-life.*mp4/.test(request.url()) && !request.url().includes("__youtube-fixture")) requests.push(request.url()); });
  await page.route("https://www.youtube.com/iframe_api", route => route.fulfill({ contentType: "application/javascript", body: fakeAPI }));
  await openFixture(page);
  await expect(page.locator("iframe, video, track")).toHaveCount(0);
  expect(requests).toEqual([]);
  await page.getByRole("button", { name: "Play Watch the lid. real-life video" }).click();
  const frame = page.locator("iframe");
  await expect(frame).toHaveAttribute("src", /^https:\/\/www.youtube-nocookie.com\/embed\/AbCd_123-xy\?/);
  await expect(frame).toHaveAttribute("referrerpolicy", "strict-origin-when-cross-origin");
  expect(new URL((await frame.getAttribute("src"))!).searchParams.get("cc_load_policy")).toBe("0");
  await expect.poll(() => eventCount(page, "play")).toBe(1);
  expect(await page.evaluate(() => (window as unknown as { __youtubeCaptions(): boolean }).__youtubeCaptions())).toBe(false);
  const captionDefaults = await eventCount(page, "unload");
  expect(captionDefaults).toBeGreaterThan(0);
  await page.evaluate(() => (window as unknown as { __youtubeEnableCaptions(): void }).__youtubeEnableCaptions());
  await page.getByRole("button", { name: /The collection/ }).click();
  expect(await page.evaluate(() => (window as unknown as { __youtubeCaptions(): boolean }).__youtubeCaptions())).toBe(true);
  expect(await eventCount(page, "unload")).toBe(captionDefaults);
  await expect.poll(() => page.evaluate(() => (window as unknown as { __youtubeEvents: unknown[][] }).__youtubeEvents.filter(event => event[0] === "seek").at(-1)?.[1])).toBeCloseTo(timings.reel.chapters.find(chapter => chapter.label === "The collection")!.start, 2);
  const before = await eventCount(page, "pause");
  await page.getByRole("button", { name: "Play another film" }).click();
  await expect.poll(() => eventCount(page, "pause")).toBeGreaterThan(before);
  await page.getByRole("button", { name: /How it started/ }).click();
  const beforeScroll = await eventCount(page, "pause");
  await page.locator("footer").scrollIntoViewIfNeeded();
  await expect.poll(() => eventCount(page, "pause")).toBeGreaterThan(beforeScroll);
  expect(requests.filter(url => url.includes("iframe_api"))).toHaveLength(1);
  expect(requests.some(url => url.endsWith(".mp4"))).toBe(false);
});

test("each uploaded film plays its assigned YouTube video and preserves the original previews", async ({ page }) => {
  const requests: string[] = [];
  page.on("request", request => { if (/youtube|real-life.*mp4/.test(request.url())) requests.push(request.url()); });
  await page.route("https://www.youtube.com/iframe_api", route => route.fulfill({ contentType: "application/javascript", body: fakeAPI }));
  await page.route("https://www.youtube-nocookie.com/**", route => route.fulfill({ contentType: "text/html", body: "<!doctype html><title>Stub player</title>" }));
  await page.goto("/showcase/");
  await expect(page.locator(".real-film")).toHaveCount(6);
  await expect(page.locator(".showcase-grid article")).toHaveCount(23);
  await expect(page.locator(".real-film iframe")).toHaveCount(0);
  expect(requests).toEqual([]);
  for (const item of [realLifeReel, ...realLifeClips].filter(item => item.youtubeId)) {
    const film = page.locator(`#${item.id}`);
    await expect(film).toHaveAttribute("data-provider", "youtube");
    await film.getByRole("button", { name: `Play ${item.title} real-life video` }).click();
    const frame = film.locator("iframe");
    await expect(frame).toHaveAttribute("src", new RegExp(`/embed/${item.youtubeId}\\?`));
    await expect(film.locator(".real-film-youtube")).toHaveClass(/is-loaded/);
    await expect(film.getByRole("link", { name: "Watch on YouTube" })).toHaveAttribute("href", `https://www.youtube.com/watch?v=${item.youtubeId}`);
  }
  expect(requests.some(url => url.endsWith(".mp4"))).toBe(false);
});

test("YouTube API and player failures keep a retryable poster", async ({ page }) => {
  let failAPI = true;
  await page.route("https://www.youtube.com/iframe_api", route => failAPI ? route.abort() : route.fulfill({ contentType: "application/javascript", body: fakeAPI }));
  await openFixture(page);
  await page.getByRole("button", { name: "Play Watch the lid. real-life video" }).click();
  await expect(page.getByRole("status")).toContainText("couldn’t load");
  await expect(page.locator(".real-film-frame img")).toBeVisible();
  failAPI = false;
  await page.getByRole("button", { name: "Retry Watch the lid. real-life video" }).click();
  await expect.poll(() => eventCount(page, "play")).toBe(1);
  await page.evaluate(() => (window as unknown as { __youtubeFail(): void }).__youtubeFail());
  await expect(page.getByRole("status")).toContainText("couldn’t load");
  await expect(page.locator("iframe")).toHaveCount(0);
  expect(await eventCount(page, "destroy")).toBe(1);
  await page.getByRole("button", { name: "Retry Watch the lid. real-life video" }).click();
  await expect.poll(() => eventCount(page, "play")).toBe(2);
  await expect(page.getByRole("status")).toHaveCount(0);
});
