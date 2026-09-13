import { catalog } from "../../src/lib/catalog";
import { test, expect } from "@playwright/test";
import { realLifeReel, formatFilmTime } from "../../src/lib/real-footage";

test("the reel can jump directly into the all-preview chapter", async ({ page }) => {
  await page.route("https://www.youtube-nocookie.com/**", route => route.fulfill({ contentType: "text/html", body: "<!doctype html><title>Stub player</title>" }));
  await page.route("https://www.youtube.com/iframe_api", route => route.fulfill({ contentType: "application/javascript", body: `
    window.YT = { Player: class {
      constructor(frame, options) { this.options = options; queueMicrotask(() => options.events.onReady()); }
      seekTo(time) { document.body.dataset.youtubeSeek = String(time); }
      playVideo() { this.options.events.onStateChange({data:1}); }
      pauseVideo() {}
      destroy() {}
    } };
    window.onYouTubeIframeAPIReady();
  ` }));
  await page.goto("/");
  const chapter = realLifeReel.chapters!.find(chapter => chapter.label === "The collection")!;
  await expect(page.locator("#real-reel iframe")).toHaveCount(0);
  await page.getByRole("button", { name: `${formatFilmTime(chapter.start)} · The collection` }).click();
  const frame = page.locator("#real-reel iframe");
  await expect(frame).toHaveAttribute("src", new RegExp(`/embed/${realLifeReel.youtubeId}\\?`));
  expect(new URL((await frame.getAttribute("src"))!).searchParams.get("start")).toBe(String(Math.floor(chapter.start)));
  await expect(page.locator("body")).toHaveAttribute("data-youtube-seek", String(chapter.start));
  await page.getByRole("button", { name: "00:00 · How it started" }).click();
  await expect(page.locator("body")).toHaveAttribute("data-youtube-seek", "0");
});

test("the collection carousel contains every scene, wraps, and only plays on request", async ({ page }) => {
  await page.goto("/showcase/");
  const carousel = page.locator("#every-preview");
  await expect(carousel.locator(".collection-rail button")).toHaveCount(catalog.length);
  await expect(carousel.locator("video")).not.toHaveAttribute("src");
  await carousel.getByRole("button", { name: "Show Aurora Observatory" }).click();
  await expect(carousel.getByRole("heading", { name: "Aurora Observatory" })).toBeVisible();
  await expect(carousel.locator("video")).not.toHaveAttribute("src");
  await carousel.getByRole("button", { name: "Show Hinge Garden" }).click();
  await expect(carousel.getByRole("heading", { name: "Hinge Garden" })).toBeVisible();
  await expect(carousel.locator("video")).not.toHaveAttribute("src");
  await carousel.getByRole("button", { name: "Play Hinge Garden collection preview" }).click();
  await expect.poll(() => carousel.locator("video").evaluate((video: HTMLVideoElement) => video.currentTime)).toBeGreaterThan(0);
  await carousel.getByRole("button", { name: "Next animation" }).click();
  await expect(carousel.getByRole("heading", { name: "The Workshop" })).toBeVisible();
  await expect(carousel.locator("video")).not.toHaveAttribute("src");
  await carousel.getByRole("button", { name: "Play The Workshop collection preview" }).click();
  await expect.poll(() => carousel.locator("video").evaluate((video: HTMLVideoElement) => video.currentTime)).toBeGreaterThan(0);
  await carousel.getByRole("button", { name: "Next animation" }).click();
  await expect(carousel.getByRole("heading", { name: "Curtains" })).toBeVisible();
  await carousel.getByRole("button", { name: "Play Curtains collection preview" }).click();
  await expect.poll(() => carousel.locator("video").evaluate((element: HTMLVideoElement) => element.paused)).toBe(false);
  await carousel.getByRole("button", { name: "Next animation" }).click();
  await expect(carousel.getByRole("heading", { name: "Peekaboo" })).toBeVisible();
  expect(await carousel.locator("video").evaluate((element: HTMLVideoElement) => element.paused)).toBe(true);
});
