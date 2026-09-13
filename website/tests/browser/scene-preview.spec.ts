import { test, expect } from "@playwright/test";

for (const [id, name] of [["the-workshop", "The Workshop"], ["hinge-garden", "Hinge Garden"]]) {
  test(`${name} responds to charger events and reversible lid controls`, async ({ page }, testInfo) => {
    const errors: string[] = [];
    page.on("pageerror", error => errors.push(error.message));
    await page.goto(`/creative-scenes/${id}/`);
    const scene = page.locator(`#${id} [data-scene-preview]`);
    const video = scene.locator("video");
    const angle = scene.getByRole("slider", { name: `${name} lid angle`, exact: true });
    await expect(video).not.toHaveAttribute("src");
    await scene.getByRole("button", { name: "Connect charger", exact: true }).click();
    await expect(video).toHaveAttribute("src", `/media/interactive/${id}-connect.mp4`);
    await expect(video).toHaveAttribute("data-ready", "true");
    await expect.poll(() => video.evaluate((video: HTMLVideoElement) => video.currentTime)).toBeGreaterThan(0.3);
    await expect(scene).toHaveAttribute("data-charging", "true");
    await scene.getByRole("button", { name: `Pause ${name} preview`, exact: true }).click();
    const pausedAt = await video.evaluate((video: HTMLVideoElement) => video.currentTime);
    await expect.poll(() => video.evaluate((video: HTMLVideoElement) => video.paused)).toBe(true);
    await scene.getByRole("button", { name: `Play ${name} preview`, exact: true }).click();
    await expect(video).toHaveAttribute("src", `/media/interactive/${id}-connect.mp4`);
    await expect.poll(() => video.evaluate((video: HTMLVideoElement) => video.currentTime)).toBeGreaterThan(pausedAt);
    await scene.getByRole("button", { name: "Disconnect charger", exact: true }).click();
    await scene.getByRole("button", { name: "Connect charger", exact: true }).click();
    await expect(video).toHaveAttribute("src", `/media/interactive/${id}-connect.mp4`);
    await expect(video).toHaveAttribute("data-ready", "true");
    await expect.poll(() => video.evaluate((video: HTMLVideoElement) => video.currentTime)).toBeGreaterThan(2);
    await scene.screenshot({ path: testInfo.outputPath(`${id}-connected.png`) });
    await scene.getByRole("button", { name: "Close lid", exact: true }).click();
    await expect(angle).toHaveValue("8");
    await expect(video).toHaveAttribute("src", `/media/interactive/${id}-lid-charging.mp4`);
    await expect(video).toHaveAttribute("data-ready", "true");
    await expect.poll(() => video.evaluate((video: HTMLVideoElement) => video.currentTime)).toBeLessThan(1 / 60);
    await expect.poll(() => video.evaluate((video: HTMLVideoElement) => video.paused)).toBe(true);
    await scene.getByRole("button", { name: "Disconnect charger", exact: true }).click();
    await expect(video).toHaveAttribute("src", `/media/interactive/${id}-lid-battery.mp4`);
    await angle.fill("64");
    await expect.poll(() => video.evaluate((video: HTMLVideoElement) => video.currentTime)).toBeCloseTo(56 / 60, 2);
    await scene.screenshot({ path: testInfo.outputPath(`${id}-half-open.png`) });
    await angle.focus(); await angle.press("End");
    await expect(angle).toHaveValue("125");
    await expect.poll(() => video.evaluate((video: HTMLVideoElement) => video.currentTime)).toBeCloseTo(102 / 60, 2);
    await scene.getByRole("button", { name: `Reset ${name} preview`, exact: true }).click();
    await expect(scene).toHaveAttribute("data-charging", "false");
    await expect(video).toHaveAttribute("data-ready", "true");
    await expect.poll(() => video.evaluate((video: HTMLVideoElement) => video.paused)).toBe(true);
    const deck = await scene.locator("[data-mac-base]").boundingBox();
    const charger = await scene.getByRole("button", { name: "Connect charger", exact: true }).boundingBox();
    expect(charger!.y - (deck!.y + deck!.height)).toBeGreaterThan(8);
    await scene.screenshot({ path: testInfo.outputPath(`${id}-resting.png`) });
    expect(errors).toEqual([]);
  });
}

test("charging settles into its connected loop and pauses offscreen", async ({ page }) => {
  await page.goto("/creative-scenes/hinge-garden/");
  const scene = page.locator("#hinge-garden [data-scene-preview]");
  const video = scene.locator("video");
  await scene.getByRole("button", { name: "Connect charger", exact: true }).click();
  await expect(scene).toHaveAttribute("data-response", "connect");
  await expect(scene).toHaveAttribute("data-response", "idle", { timeout: 15_000 });
  await expect(video).toHaveAttribute("src", "/media/interactive/hinge-garden-idle-charging.mp4");
  await expect.poll(() => video.evaluate((video: HTMLVideoElement) => video.paused)).toBe(false);
  await page.locator("footer").scrollIntoViewIfNeeded();
  await expect.poll(() => video.evaluate((video: HTMLVideoElement) => video.paused)).toBe(true);
  await scene.scrollIntoViewIfNeeded();
  await expect.poll(() => video.evaluate((video: HTMLVideoElement) => video.paused)).toBe(false);
});

test("reduced motion uses still event states and previews remain independent", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/creative-scenes/");
  const workshop = page.locator("#the-workshop [data-scene-preview]");
  const garden = page.locator("#hinge-garden [data-scene-preview]");
  await workshop.getByRole("button", { name: "Connect charger", exact: true }).click();
  await expect(workshop).toHaveAttribute("data-response", "idle");
  await expect(workshop.locator("video")).toHaveAttribute("data-ready", "true");
  expect(await workshop.locator("video").evaluate((video: HTMLVideoElement) => video.paused)).toBe(true);
  await expect(garden).toHaveAttribute("data-charging", "false");
  await expect(garden.locator("video")).not.toHaveAttribute("src");
  await workshop.getByRole("button", { name: "Close lid", exact: true }).click();
  await expect(workshop.getByRole("slider", { name: "The Workshop lid angle", exact: true })).toHaveValue("8");
  await expect(workshop.locator("video")).toHaveAttribute("data-ready", "true");
  expect(await workshop.locator("video").evaluate((video: HTMLVideoElement) => video.paused)).toBe(true);
});

test("a failed response preserves the Mac and can be retried", async ({ page }) => {
  const route = "**/media/interactive/the-workshop-connect.mp4";
  await page.route(route, request => request.abort());
  await page.goto("/creative-scenes/the-workshop/");
  const scene = page.locator("#the-workshop [data-scene-preview]");
  await scene.getByRole("button", { name: "Connect charger", exact: true }).click();
  await expect(scene.getByRole("alert")).toContainText("This response couldn’t load");
  await expect(scene.locator("[data-mac-lid]")).toBeVisible();
  await page.unroute(route);
  await scene.getByRole("button", { name: "Try again", exact: true }).click();
  await expect(scene.getByRole("alert")).toHaveCount(0);
  await expect(scene.locator("video")).toHaveAttribute("data-ready", "true");
  await expect.poll(() => scene.locator("video").evaluate((video: HTMLVideoElement) => video.currentTime)).toBeGreaterThan(0);
});
