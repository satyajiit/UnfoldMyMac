import { test, expect } from "@playwright/test";

test("wallpapers cycle F1, Codex, GTA, then F1 with one active video", async ({ page }) => {
  test.setTimeout(35_000);
  await page.emulateMedia({ reducedMotion: "no-preference" });
  await page.goto("/");
  const demo = page.locator(".lid-demo");
  await page.getByRole("group", { name: "Preview wallpapers" }).scrollIntoViewIfNeeded();
  for (const id of ["lights-out", "codex-mission-control", "gta-vi-countdown", "lights-out"]) {
    await expect(demo).toHaveAttribute("data-wallpaper", id, { timeout: 8_000 });
    await expect.poll(() => demo.locator("[data-active=true] video").evaluate((video: HTMLVideoElement) => video.currentTime), { timeout: 4_000 }).toBeGreaterThan(0);
    expect(await demo.locator("video").evaluateAll(videos => videos.filter(video => video instanceof HTMLVideoElement && !video.paused).length)).toBe(1);
  }
});

test("pause and direct scene selection keep the selected wallpaper still", async ({ page }) => {
  await page.clock.install();
  await page.goto("/");
  await page.getByRole("group", { name: "Preview wallpapers" }).scrollIntoViewIfNeeded();
  await page.getByRole("button", { name: "Pause wallpaper loop" }).click();
  await page.getByRole("button", { name: "Show GTA VI wallpaper" }).click();
  const demo = page.locator(".lid-demo");
  await page.clock.fastForward(13_000);
  await expect(demo).toHaveAttribute("data-wallpaper", "gta-vi-countdown");
  expect(await demo.locator("video").evaluateAll(videos => videos.every(video => video instanceof HTMLVideoElement && video.paused))).toBe(true);
  await page.getByRole("button", { name: "Play wallpaper loop" }).click();
  await expect.poll(() => demo.locator("[data-active=true] video").evaluate((video: HTMLVideoElement) => video.paused)).toBe(false);
});

test("cover choices close over the current wallpaper and reset reopens it", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");
  await page.getByRole("button", { name: "Show Codex wallpaper" }).click();
  const demo = page.locator(".lid-demo");
  const slider = page.getByRole("slider", { name: "Lid angle" });
  for (const [name, id, treatment] of [["Curtains", "curtains", "split"], ["Frost", "frost", "frost"], ["Peekaboo", "peekaboo", "split"], ["Reverie", "reverie", "split"], ["Neon Coast", "neon-coast", "split"], ["Fade", "fade", "fade"]]) {
    const button = page.getByRole("group", { name: "Demo effect" }).getByRole("button", { name, exact: true });
    await button.click();
    await expect(button).toHaveAttribute("aria-pressed", "true");
    await expect(demo).toHaveAttribute("data-effect", id);
    await expect(demo).toHaveAttribute("data-wallpaper", "codex-mission-control");
    await expect(slider).toHaveValue("75");
    await expect(demo.locator(`[data-treatment=${treatment}]`)).toBeVisible();
  }
  await slider.focus(); await slider.press("Home");
  await expect(slider).toHaveValue("30");
  await expect(slider).toHaveAttribute("aria-valuetext", "30 degrees");
  await page.getByRole("button", { name: "Reset lid angle" }).click();
  await expect(slider).toHaveValue("125");
  await expect(demo.locator("output")).toHaveText("125°");
});

test("offscreen and hidden previews pause decoding and scene changes", async ({ page }) => {
  await page.clock.install();
  await page.goto("/");
  const demo = page.locator(".lid-demo");
  await page.getByRole("group", { name: "Preview wallpapers" }).scrollIntoViewIfNeeded();
  await expect(demo).toHaveAttribute("data-playing", "true");
  await page.locator("footer").scrollIntoViewIfNeeded();
  await expect(demo).toHaveAttribute("data-playing", "false");
  const selected = await demo.getAttribute("data-wallpaper");
  await page.clock.fastForward(13_000);
  await expect(demo).toHaveAttribute("data-wallpaper", selected!);
  expect(await demo.locator("video").evaluateAll(videos => videos.every(video => video instanceof HTMLVideoElement && video.paused))).toBe(true);
  await page.getByRole("group", { name: "Preview wallpapers" }).scrollIntoViewIfNeeded();
  await expect(demo).toHaveAttribute("data-playing", "true");
  await page.evaluate(() => { Object.defineProperty(document, "hidden", { configurable: true, value: true }); document.dispatchEvent(new Event("visibilitychange")); });
  await expect(demo).toHaveAttribute("data-playing", "false");
});

test("reduced motion stays still until play and a preference change pauses it", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");
  const demo = page.locator(".lid-demo");
  await page.getByRole("group", { name: "Preview wallpapers" }).scrollIntoViewIfNeeded();
  await expect(demo).toHaveAttribute("data-playing", "false");
  expect(await demo.locator("video").evaluateAll(videos => videos.every(video => !video.getAttribute("src")))).toBe(true);
  await page.getByRole("button", { name: "Play wallpaper loop" }).click();
  await expect(demo).toHaveAttribute("data-playing", "true");
  await page.emulateMedia({ reducedMotion: "no-preference" });
  // Allow the media-query change event to dispatch before changing it again.
  // Firefox and WebKit can coalesce two changes within one rendering frame.
  await page.evaluate(() => new Promise<void>(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
  await page.emulateMedia({ reducedMotion: "reduce" });
  await expect(demo).toHaveAttribute("data-playing", "false");
});

test("a failed recording retains its poster and another scene remains usable", async ({ page }) => {
  await page.route("**/media/lights-out.mp4", route => route.abort());
  await page.goto("/");
  const demo = page.locator(".lid-demo");
  await page.getByRole("group", { name: "Preview wallpapers" }).scrollIntoViewIfNeeded();
  await expect(demo.getByRole("status").filter({ hasText: "The recording couldn’t play" })).toBeVisible();
  await expect(demo.locator("[data-active=true] img")).toBeVisible();
  await expect(demo.locator("[data-active=true] video")).toHaveAttribute("data-ready", "false");
  await page.getByRole("button", { name: "Show Codex wallpaper" }).click();
  await expect.poll(() => demo.locator("[data-active=true] video").evaluate((video: HTMLVideoElement) => video.currentTime)).toBeGreaterThan(0);
});
