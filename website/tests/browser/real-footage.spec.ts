import { test, expect } from "@playwright/test";

test("real films are additive, opt-in, keyboard playable, seekable, and pause offscreen", async ({ page }) => {
  const requests: string[] = [];
  page.on("request", request => { if (request.url().includes("/media/real-life/") && request.url().endsWith(".mp4")) requests.push(request.url()); });
  await page.goto("/showcase/");
  await expect(page.locator(".real-film")).toHaveCount(6);
  await expect(page.locator(".showcase-grid article")).toHaveCount(23);
  expect(requests).toEqual([]);
  const button = page.getByRole("button", { name: "Play Frost real-life video" });
  await button.focus();
  await button.press("Enter");
  const video = page.locator("#real-frost video");
  await expect.poll(() => video.evaluate((element: HTMLVideoElement) => element.currentTime)).toBeGreaterThan(0);
  expect(await video.evaluate((element: HTMLVideoElement) => element.muted && element.controls)).toBe(true);
  await video.evaluate((element: HTMLVideoElement) => { element.currentTime = 4; element.muted = false; });
  await expect.poll(() => video.evaluate((element: HTMLVideoElement) => element.currentTime)).toBeGreaterThanOrEqual(4);
  expect(await video.evaluate((element: HTMLVideoElement) => element.muted)).toBe(false);
  await page.locator("footer").scrollIntoViewIfNeeded();
  await expect.poll(() => video.evaluate((element: HTMLVideoElement) => element.paused)).toBe(true);
});

test("real films keep posters on failure and can retry", async ({ page }) => {
  await page.route("**/media/real-life/reel.mp4", route => route.abort());
  await page.goto("/");
  await page.getByRole("button", { name: "Play Lid down. Drama up. real-life video" }).click();
  await expect(page.locator("#real-reel [role=status]")).toContainText("couldn’t load");
  await expect(page.locator("#real-reel img")).toBeVisible();
  await page.unroute("**/media/real-life/reel.mp4");
  await page.getByRole("button", { name: "Retry Lid down. Drama up. real-life video" }).click();
  await expect.poll(() => page.locator("#real-reel video").evaluate((element: HTMLVideoElement) => element.currentTime)).toBeGreaterThan(0);
});

test("reduced motion keeps films still and changing the preference pauses playback", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");
  const video = page.locator("#real-reel video");
  expect(await video.getAttribute("src")).toBeNull();
  expect(await video.evaluate((element: HTMLVideoElement) => element.paused && !element.autoplay)).toBe(true);
  await page.emulateMedia({ reducedMotion: "no-preference" });
  await page.getByRole("button", { name: "Play Lid down. Drama up. real-life video" }).click();
  await expect.poll(() => video.evaluate((element: HTMLVideoElement) => element.paused)).toBe(false);
  await page.emulateMedia({ reducedMotion: "reduce" });
  await expect.poll(() => video.evaluate((element: HTMLVideoElement) => element.paused)).toBe(true);
});
