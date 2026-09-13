import { expect, test } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");
  await page.getByRole("slider", { name: "MacBook lid gesture" }).scrollIntoViewIfNeeded();
});

test("the lid pivots at a fixed hinge and stops above the keyboard deck", async ({ page }) => {
  const lid = page.locator(".lid-demo [data-mac-lid]");
  const base = page.locator(".lid-demo [data-mac-base]");
  const slider = page.getByRole("slider", { name: "Lid angle", exact: true });
  await lid.evaluate(element => {
    const probe = document.createElement("span");
    probe.dataset.hingeProbe = "true";
    probe.style.cssText = "position:absolute;bottom:0;left:50%;width:1px;height:1px";
    element.append(probe);
  });
  const hinge = page.locator("[data-hinge-probe]");
  const openHinge = (await hinge.boundingBox())!;
  const openBase = (await base.boundingBox())!;
  const openScroll = await page.evaluate(() => scrollY);
  await slider.fill("30");
  const closingHinge = (await hinge.boundingBox())!;
  const closingBase = (await base.boundingBox())!;
  const closingScroll = await page.evaluate(() => scrollY);
  expect(Math.abs(openHinge.x - closingHinge.x)).toBeLessThan(2);
  // Mobile scrolls the sidebar range into view; compare document coordinates.
  expect(Math.abs(openHinge.y + openScroll - closingHinge.y - closingScroll)).toBeLessThan(2);
  expect(closingBase.width).toBeCloseTo(openBase.width, 2);
  expect(closingBase.height).toBeCloseTo(openBase.height, 2);
  expect(Math.abs(openBase.y + openScroll - closingBase.y - closingScroll)).toBeLessThan(1);
  await slider.press("Home");
  await expect(slider).toHaveValue("30");
  const closedLid = (await lid.boundingBox())!;
  const closedBase = (await base.boundingBox())!;
  expect(closedLid.y).toBeLessThan(closedBase.y - 10);
  expect(closedLid.height).toBeGreaterThan(10);
});

test("dragging the Mac adjusts the lid and releasing leaves it in place", async ({ page }) => {
  const surface = page.getByRole("slider", { name: "MacBook lid gesture" });
  const slider = page.getByRole("slider", { name: "Lid angle", exact: true });
  const box = (await surface.boundingBox())!;
  const x = box.x + box.width / 2, y = box.y + box.height * 0.3;
  await page.mouse.move(x, y); await page.mouse.down();
  // A deliberate drag, longer than the flick gesture window.
  await page.waitForTimeout(300);
  await page.mouse.move(x, y + 80, { steps: 12 });
  const angle = Number(await slider.inputValue());
  expect(angle).toBeGreaterThan(30); expect(angle).toBeLessThan(125);
  await page.mouse.up();
  await expect(surface).toHaveAttribute("aria-valuenow", String(angle));
  await expect(surface).toHaveAttribute("data-dragging", "false");
  await page.waitForTimeout(200);
  await expect(slider).toHaveValue(String(angle));
});

test("pointer gestures hide the box outline while keyboard focus stays visible", async ({ page }) => {
  const surface = page.getByRole("slider", { name: "MacBook lid gesture" });
  const hint = page.locator("#gesture-hint");
  await page.getByRole("button", { name: "Play wallpaper loop" }).focus();
  await page.keyboard.press("Tab");
  await expect(surface).toBeFocused();
  await expect(surface).toHaveCSS("outline-style", "none");
  await expect(hint).toHaveCSS("outline-style", "solid");
  await expect(hint.getByText("Use ↑ ↓ to move. Home / End for limits.")).toBeVisible();
  const box = (await surface.boundingBox())!;
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 3);
  await page.mouse.down();
  await expect(surface).toHaveCSS("outline-style", "none");
  await expect(hint).toHaveCSS("outline-style", "none");
  await expect(hint.getByText("Drag or swipe down to close. Up to open.")).toBeVisible();
  await page.mouse.up();
  await page.keyboard.press("Tab"); await page.keyboard.press("Shift+Tab");
  await expect(surface).toBeFocused();
  await expect(hint).toHaveCSS("outline-style", "solid");
});

test("quick swipes close and reopen the lid", async ({ page }) => {
  const surface = page.getByRole("slider", { name: "MacBook lid gesture" });
  const slider = page.getByRole("slider", { name: "Lid angle", exact: true });
  const box = (await surface.boundingBox())!;
  const x = box.x + box.width / 2, y = box.y + box.height * 0.3;
  await page.mouse.move(x, y); await page.mouse.down();
  await page.mouse.move(x, y + 100, { steps: 2 }); await page.mouse.up();
  await expect(slider).toHaveValue("30");
  await page.mouse.move(x, y + 100); await page.mouse.down();
  await page.mouse.move(x, y, { steps: 2 }); await page.mouse.up();
  await expect(slider).toHaveValue("125");
});

test("hold controls stop on release, cancel, or window blur", async ({ page }) => {
  const slider = page.getByRole("slider", { name: "Lid angle", exact: true });
  const close = page.getByRole("button", { name: "Hold to close" });
  for (const stop of ["release", "cancel", "blur"]) {
    await slider.fill("100");
    await close.scrollIntoViewIfNeeded();
    const box = (await close.boundingBox())!;
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    await page.mouse.down(); await page.waitForTimeout(300);
    expect(Number(await slider.inputValue())).toBeLessThan(90);
    if (stop === "release") await page.mouse.up();
    if (stop === "cancel") await close.dispatchEvent("pointercancel");
    if (stop === "blur") await page.evaluate(() => window.dispatchEvent(new Event("blur")));
    const angle = await slider.inputValue();
    await page.waitForTimeout(200);
    await expect(slider).toHaveValue(angle);
    await page.mouse.up();
  }
  await page.getByRole("button", { name: "Hold to open" }).focus();
  await page.keyboard.press("Enter");
  await expect(slider).toHaveValue("125");
});

test("gesture surface supports keyboard and keeps the Dock beneath covers", async ({ page }) => {
  const surface = page.getByRole("slider", { name: "MacBook lid gesture" });
  await surface.focus(); await surface.press("ArrowDown");
  await expect(surface).toHaveAttribute("aria-valuenow", "120");
  await expect(page.getByRole("slider", { name: "Lid angle", exact: true })).toHaveValue("120");
  await surface.press("Home"); await expect(surface).toHaveAttribute("aria-valuenow", "30");
  await surface.press("End"); await expect(surface).toHaveAttribute("aria-valuenow", "125");
  await expect(page.locator(".lid-demo [data-mac-lid] [data-mac-dock]")).toBeVisible();
  await page.getByRole("group", { name: "Demo effect" }).getByRole("button", { name: "Frost", exact: true }).click();
  expect(await page.locator("[data-treatment=frost]").evaluate(cover => Number(getComputedStyle(cover).zIndex) > Number(getComputedStyle(cover.previousElementSibling!).zIndex))).toBe(true);
});

test("all six covers finish at the 30 degree lower limit", async ({ page }) => {
  const slider = page.getByRole("slider", { name: "Lid angle", exact: true });
  await expect(slider).toHaveAttribute("min", "30");
  for (const name of ["Curtains", "Frost", "Peekaboo", "Reverie", "Neon Coast", "Fade"]) {
    await page.getByRole("group", { name: "Demo effect" }).getByRole("button", { name, exact: true }).click();
    await slider.focus(); await slider.press("Home"); await slider.press("ArrowLeft");
    await expect(slider).toHaveValue("30");
    const cover = page.locator(".lid-demo [data-treatment]");
    const closed = await cover.evaluate(element => [...element.children].every(child => {
      const style = getComputedStyle(child);
      return element.getAttribute("data-treatment") === "split"
        ? new DOMMatrixReadOnly(style.transform).m41 === 0
        : style.opacity === "1";
    }));
    expect(closed, `${name} should cover the display at 30 degrees`).toBe(true);
  }
});

test("touch swipes change the lid without scrolling the page", async ({ page, isMobile, context }) => {
  test.skip(!isMobile);
  const surface = page.getByRole("slider", { name: "MacBook lid gesture" });
  const box = (await surface.boundingBox())!;
  const x = box.x + box.width / 2, y = box.y + box.height * 0.3;
  const scroll = await page.evaluate(() => scrollY);
  const cdp = await context.newCDPSession(page);
  await cdp.send("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: [{ x, y }] });
  await cdp.send("Input.dispatchTouchEvent", { type: "touchMove", touchPoints: [{ x, y: y + 90 }] });
  await cdp.send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
  await expect(surface).toHaveAttribute("aria-valuenow", "30");
  await expect(surface).toHaveCSS("outline-style", "none");
  await expect(page.locator("#gesture-hint")).toHaveCSS("outline-style", "none");
  expect(await page.evaluate(() => scrollY)).toBe(scroll);
});
