import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("the illustrated story has working chapter links and previews that play only on request", async ({ page }) => {
  const mediaRequests: string[] = [];
  page.on("request", request => { if (/\.mp4(?:\?|$)|youtube/.test(request.url())) mediaRequests.push(request.url()); });
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/story/");
  await expect(page.locator("main h1")).toHaveCount(1);
  await expect(page.locator("main figure")).toHaveCount(3);
  await expect(page.locator(".media-card")).toHaveCount(3);
  await expect(page.locator("#real-reel")).toHaveAttribute("data-provider", "youtube");
  expect(mediaRequests).toEqual([]);
  await expect(page.locator("#real-reel iframe")).toHaveCount(0);
  for (const anchor of await page.getByRole("navigation", { name: "Story chapters" }).getByRole("link").all()) {
    const target = (await anchor.getAttribute("href"))!;
    await anchor.click();
    await expect(page.locator(target)).toBeInViewport();
  }
  await expect(page.locator("#real-reel img")).toBeVisible();
  await expect.poll(() => page.locator("#real-reel img").evaluate((image: HTMLImageElement) => image.complete && image.naturalWidth > 0)).toBe(true);
  await page.getByRole("button", { name: "Play Lights Out preview" }).click();
  const preview = page.locator("#lights-out video");
  await expect.poll(() => preview.evaluate((video: HTMLVideoElement) => video.currentTime)).toBeGreaterThan(0);
  await page.getByRole("button", { name: "Pause Lights Out preview" }).click();
  expect(await preview.evaluate((video: HTMLVideoElement) => video.paused)).toBe(true);
  await expect(page.getByRole("link", { name: "Get the Mac app", exact: true })).toHaveAttribute("href", "/download/");
});

test("the story reflows and remains accessible in both themes", async ({ page }) => {
  await page.goto("/story/");
  for (const width of [1280, 390, 320]) {
    await page.setViewportSize({ width, height: 850 });
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    const frame = page.locator("#real-reel .real-film-frame");
    await frame.scrollIntoViewIfNeeded();
    const bounds = (await frame.boundingBox())!;
    const play = (await frame.getByRole("button").boundingBox())!;
    expect(play.x).toBeGreaterThanOrEqual(bounds.x);
    expect(play.y).toBeGreaterThanOrEqual(bounds.y);
    expect(play.x + play.width).toBeLessThanOrEqual(bounds.x + bounds.width);
    expect(play.y + play.height).toBeLessThanOrEqual(bounds.y + bounds.height);
    const duration = frame.locator(".real-film-duration");
    if (await duration.isVisible()) {
      const badge = (await duration.boundingBox())!;
      expect(play.x + play.width <= badge.x || play.y + play.height <= badge.y).toBe(true);
    }
    for (const theme of ["Light", "Dark"]) {
      await page.getByRole("button", { name: `${theme} appearance` }).click();
      const result = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"]).analyze();
      expect(result.violations, `${theme} at ${width}px`).toEqual([]);
    }
  }
});
