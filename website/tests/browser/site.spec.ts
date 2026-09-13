import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
const routes = ["/", "/features/", "/showcase/", "/story/", "/download/", "/blog/", "/faq/", "/privacy/", "/blog/lid-effects/", "/blog/live-wallpapers/", "/blog/connecting-your-data/"];
test("every route loads directly and survives refresh without hydration errors", async ({ page }) => {
  const errors: string[] = [];
  page.on("pageerror", error => errors.push(error.message));
  for (const route of routes) {
    const response = await page.goto(route);
    expect(response?.status()).toBe(200);
    await expect(page.locator("main h1")).toBeVisible();
    // Let static route prefetches finish before deliberately unloading the page.
    // WebKit reports interrupted fetches as page errors during rapid reloads.
    await page.waitForLoadState("networkidle");
    await page.reload();
    await page.waitForLoadState("networkidle");
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  }
  expect(errors).toEqual([]);
  expect((await page.goto("/does-not-exist/"))?.status()).toBe(404);
  await expect(page.getByRole("heading", { name: "This page has left the stage." })).toBeVisible();
});
test("appearance persists and follows system when selected", async ({ page }) => {
  await page.emulateMedia({ colorScheme: "light" });
  await page.goto("/");
  await page.getByRole("button", { name: "Dark appearance" }).click();
  await expect(page.locator("html")).toHaveClass(/dark/);
  await page.reload();
  await expect(page.locator("html")).toHaveClass(/dark/);
  await page.getByRole("button", { name: "Light appearance" }).click();
  await expect(page.locator("html")).not.toHaveClass(/dark/);
  await page.getByRole("button", { name: "System appearance" }).click();
  await page.emulateMedia({ colorScheme: "dark" });
  await expect(page.locator("html")).toHaveClass(/dark/);
});
test("lid responds to keyboard, design choice, and reset", async ({ page }) => {
  await page.goto("/");
  const slider = page.getByRole("slider", { name: "Lid angle" });
  await slider.focus();
  await slider.press("ArrowLeft");
  await expect(slider).toHaveValue("124");
  await expect(page.locator("output")).toHaveText("124°");
  await page.getByRole("button", { name: "Curtains", exact: true }).click();
  await expect(page.getByRole("button", { name: "Curtains", exact: true })).toHaveAttribute("aria-pressed", "true");
  await page.getByRole("button", { name: "Reset lid angle" }).click();
  await expect(slider).toHaveValue("125");
});
test("showcase filters and stops offscreen video", async ({ page }) => {
  await page.goto("/showcase/");
  for (const name of ["Frost", "Veil", "Fade"]) {
    await page.getByRole("button", { name: `Play ${name} preview` }).click();
    await expect.poll(() => page.locator(`#${name.toLowerCase()} video`).evaluate((video: HTMLVideoElement) => video.currentTime)).toBeGreaterThan(0);
    await page.getByRole("button", { name: `Pause ${name} preview` }).click();
  }
  await page.getByRole("button", { name: "Dynamic Wallpapers", exact: true }).click();
  await expect(page.locator(".showcase-grid article")).toHaveCount(10);
  for (const [id, name] of [["gta-vi-countdown", "GTA VI — Vice City Countdown"], ["aurora-observatory", "Aurora Observatory"]]) {
    await page.getByRole("button", { name: `Play ${name} preview` }).click();
    await expect.poll(() => page.locator(`#${id} video`).evaluate((video: HTMLVideoElement) => video.currentTime)).toBeGreaterThan(0);
    await page.getByRole("button", { name: `Pause ${name} preview` }).click();
  }
  await page.getByRole("button", { name: "Play Pulse preview" }).click();
  await expect(page.getByRole("button", { name: "Pause Pulse preview" })).toBeVisible();
  await page.locator("footer").scrollIntoViewIfNeeded();
  await expect.poll(() => page.locator("#pulse video").evaluate((video: HTMLVideoElement) => video.paused)).toBe(true);
});
test("the three collections switch app screenshots and filter their own designs", async ({ page }) => {
  await page.goto("/");
  const discovery = page.getByRole("group", { name: "Explore app collections" });
  await discovery.getByRole("button", { name: "Creative Scenes" }).click();
  await expect(discovery.getByRole("button", { name: "Creative Scenes" })).toHaveAttribute("aria-pressed", "true");
  for (const theme of ["Light", "Dark"]) {
    await page.getByRole("button", { name: `${theme} appearance` }).click();
    const screenshot = page.locator("#collection-screen img:visible");
    await expect(screenshot).toHaveAttribute("src", `/media/discovery/scenes-${theme.toLowerCase()}.webp`);
    await expect.poll(() => screenshot.evaluate((img: HTMLImageElement) => img.complete && img.naturalWidth > 0)).toBe(true);
  }
  await page.goto("/showcase/");
  const filters = page.getByRole("group", { name: "Filter showcase", exact: true });
  await filters.getByRole("button", { name: "Creative Scenes" }).click();
  await expect(page.locator(".showcase-grid article")).toHaveCount(1);
  await expect(page.locator(".showcase-grid #hinge-garden")).toBeVisible();
  await page.getByRole("button", { name: "Play Hinge Garden preview", exact: true }).click();
  await expect.poll(() => page.locator("#hinge-garden video").evaluate((video: HTMLVideoElement) => video.currentTime)).toBeGreaterThan(0);
  await filters.getByRole("button", { name: "Lid Effects" }).click();
  await expect(page.locator(".showcase-grid article")).toHaveCount(13);
  await page.getByRole("group", { name: "Filter lid effect styles" }).getByRole("button", { name: "Glass & Light" }).click();
  await expect(page.locator(".showcase-grid article")).toHaveCount(3);
  await filters.getByRole("button", { name: "Dynamic Wallpapers" }).click();
  await expect(page.locator(".showcase-grid article")).toHaveCount(10);
  await expect(page.getByRole("group", { name: "Filter lid effect styles" })).toHaveCount(0);
  await filters.getByRole("button", { name: "All designs" }).click();
  await expect(page.locator(".showcase-grid article")).toHaveCount(24);
});
test("reduced motion starts with still media and allows manual lid input", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");
  expect(await page.locator("video").evaluateAll(videos => videos.every(video => video instanceof HTMLVideoElement && video.paused && !video.autoplay))).toBe(true);
  const slider = page.getByRole("slider", { name: "Lid angle" });
  await slider.focus(); await slider.press("End");
  await expect(slider).toHaveValue("125");
});
test("all pages pass automated WCAG 2.2 AA checks in both themes", async ({ page }, testInfo) => {
  test.setTimeout(90_000);
  const audit = [];
  for (const route of routes) {
    await page.goto(route);
    for (const theme of ["Light", "Dark"]) {
      await page.getByRole("button", { name: `${theme} appearance` }).click();
      const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"]).analyze();
      audit.push({ route, theme, engine: results.testEngine, violations: results.violations, passes: results.passes.map(rule => rule.id), incomplete: results.incomplete.map(rule => ({ id: rule.id, description: rule.description, targets: rule.nodes.map(node => node.target) })) });
      expect.soft(results.violations, `${route} in ${theme} appearance`).toEqual([]);
    }
  }
  await testInfo.attach("wcag-audit", { body: JSON.stringify(audit, null, 2), contentType: "application/json" });
});
test("mobile navigation opens, navigates, and closes", async ({ page, isMobile }) => {
  test.skip(!isMobile);
  await page.goto("/");
  await page.getByRole("button", { name: "Open menu" }).click();
  await page.getByRole("navigation", { name: "Main navigation" }).getByRole("link", { name: "Features" }).click();
  await expect(page).toHaveURL(/\/features\/$/);
  await expect(page.getByRole("button", { name: "Open menu" })).toHaveAttribute("aria-expanded", "false");
});

test("failed media keeps its poster and explains the failure", async ({ page }) => {
  await page.route("**/media/curtains.mp4", route => route.abort());
  await page.goto("/");
  await page.getByRole("button", { name: "Play Curtains preview" }).click();
  await expect(page.locator("#curtains [role=status]")).toContainText("Preview could not play");
  await expect(page.locator("#curtains video")).not.toHaveClass(/loaded/);
  await expect(page.locator("#curtains img")).toBeVisible();
});

test("small-screen layout reflows at 320 pixels", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 700 });
  for (const route of ["/", "/features/", "/showcase/", "/download/", "/blog/"]) {
    await page.goto(route);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    await expect(page.getByRole("link", { name: "Get the app", exact: true }).first()).toBeVisible();
  }
});
