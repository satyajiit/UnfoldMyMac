import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("collections and categories support direct links, refresh, and browser history", async ({ page }) => {
  const errors: string[] = [];
  page.on("pageerror", error => errors.push(error.message));
  await page.goto("/showcase/");
  await page.getByRole("navigation", { name: "Design collections" }).getByRole("link", { name: "Lid Effects" }).click();
  await expect(page).toHaveURL(/\/lid-effects\/$/);
  await page.getByRole("navigation", { name: "Lid Effects categories" }).getByRole("link", { name: "Glass & Light" }).click();
  await expect(page).toHaveURL(/\/lid-effects\/categories\/glass-light\/$/);
  await page.getByRole("heading", { name: "Frost", exact: true }).getByRole("link").click();
  await expect(page).toHaveURL(/\/lid-effects\/frost\/$/);
  await expect(page.locator("main h1")).toHaveText("Frost");
  await page.waitForLoadState("networkidle");
  await page.reload();
  await expect(page.locator("main h1")).toHaveText("Frost");
  await page.goBack();
  await expect(page).toHaveURL(/\/lid-effects\/categories\/glass-light\/$/);
  await expect(page.locator(".showcase-grid article")).toHaveCount(3);
  await page.goForward();
  await expect(page.locator("main h1")).toHaveText("Frost");
  await page.getByRole("navigation", { name: "Breadcrumb", exact: true }).getByRole("link", { name: "Lid Effects", exact: true }).click();
  await expect(page.locator(".showcase-grid article")).toHaveCount(13);
  expect(errors).toEqual([]);
});

test("library pages work without JavaScript", async ({ browser, baseURL }) => {
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  await page.goto(`${baseURL}/creative-scenes/`);
  await page.getByRole("link", { name: "Work & play", exact: true }).click();
  await page.getByRole("heading", { name: "The Workshop", exact: true }).getByRole("link").click();
  await expect(page.locator("main h1")).toHaveText("The Workshop");
  await expect(page.getByRole("heading", { name: "Your apps light the benches" })).toBeVisible();
  await context.close();
});

test("new page layouts are accessible in both themes and respect reduced motion", async ({ page }, testInfo) => {
  test.setTimeout(90_000);
  await page.emulateMedia({ reducedMotion: "reduce" });
  const routes = ["/creative-scenes/", "/dynamic-wallpapers/categories/games-sport/", "/creative-scenes/the-workshop/", "/dynamic-wallpapers/baldurs-gate-astral/", "/lid-effects/categories/glass-light/", "/lid-effects/frost/"];
  for (const route of routes) {
    expect((await page.goto(route))?.status()).toBe(200);
    await expect(page.locator("main h1")).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    expect(await page.locator("video").evaluateAll(videos => videos.every(video => video instanceof HTMLVideoElement && video.paused && !video.autoplay))).toBe(true);
    for (const theme of ["Light", "Dark"]) {
      await page.getByRole("button", { name: `${theme} appearance` }).click();
      const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"]).analyze();
      expect(results.violations, `${route} ${theme}`).toEqual([]);
      if (route === "/creative-scenes/" || route === "/creative-scenes/the-workshop/") {
        await page.screenshot({ path: testInfo.outputPath(`${route.split("/").filter(Boolean).join("-")}-${theme}.png`), fullPage: true });
      }
    }
  }
  for (const route of ["/creative-scenes/frost/", "/lid-effects/categories/work-play/", "/dynamic-wallpapers/missing/"]) expect((await page.goto(route))?.status()).toBe(404);
});

test("a design preview plays independently from its related-design links", async ({ page }) => {
  await page.goto("/creative-scenes/the-workshop/");
  await page.getByRole("button", { name: "Play The Workshop preview", exact: true }).click();
  await expect.poll(() => page.locator("#the-workshop video").evaluate((video: HTMLVideoElement) => video.currentTime)).toBeGreaterThan(0);
  await page.getByRole("button", { name: "Pause The Workshop preview", exact: true }).click();
  await expect.poll(() => page.locator("#the-workshop video").evaluate((video: HTMLVideoElement) => video.paused)).toBe(true);
  await page.getByRole("link", { name: "Explore Hinge Garden", exact: true }).click();
  await expect(page).toHaveURL(/\/creative-scenes\/hinge-garden\/$/);
});
