import { chromium } from "@playwright/test";
import { writeFile } from "node:fs/promises";
const browser = await chromium.launch({ channel: process.env.PLAYWRIGHT_CHROMIUM_CHANNEL || "chrome" });
const results = [];
for (const viewport of [{ width: 1440, height: 1100 }, { width: 390, height: 844 }]) {
  const page = await browser.newPage({ viewport });
  await page.goto("http://127.0.0.1:4173/", { waitUntil: "networkidle" });
  await page.locator("#lid-angle").scrollIntoViewIfNeeded();
  const metrics = await page.evaluate(async () => {
    const slider = document.querySelector("#lid-angle");
    const intervals = []; let previous = 0;
    await new Promise(resolve => {
      const start = performance.now();
      function frame(now) {
        if (previous) intervals.push(now - previous);
        previous = now;
        slider.value = String(Math.round(75 + Math.sin((now - start) / 700) * 50));
        slider.dispatchEvent(new Event("input", { bubbles: true }));
        if (now - start < 4000) requestAnimationFrame(frame); else resolve();
      }
      requestAnimationFrame(frame);
    });
    const sorted = intervals.slice(10).sort((a,b) => a-b);
    return { frames: sorted.length, medianMs: sorted[Math.floor(sorted.length*.5)], p95Ms: sorted[Math.floor(sorted.length*.95)], over25ms: sorted.filter(value => value > 25).length, averageFps: 1000/(sorted.reduce((a,b)=>a+b,0)/sorted.length) };
  });
  const playbackStart = Date.now();
  await page.locator("#curtains .play-button").click();
  await page.waitForFunction(() => document.querySelector("#curtains video").currentTime > 0.1);
  const startupMs = Date.now() - playbackStart;
  const baseline = await page.locator("#curtains video").evaluate(video => {
    const stats = video.getVideoPlaybackQuality();
    return { totalFrames: stats.totalVideoFrames, droppedFrames: stats.droppedVideoFrames };
  });
  await page.waitForTimeout(4000);
  const playback = await page.locator("#curtains video").evaluate(video => {
    const stats = video.getVideoPlaybackQuality();
    return { totalFrames: stats.totalVideoFrames, droppedFrames: stats.droppedVideoFrames, paused: video.paused, currentTime: video.currentTime };
  });
  const video = { startupMs, totalFrames: playback.totalFrames - baseline.totalFrames, droppedFrames: playback.droppedFrames - baseline.droppedFrames, paused: playback.paused, currentTime: playback.currentTime };
  results.push({ viewport, lid: metrics, video });
  await page.close();
}
await browser.close();
await writeFile(".cache/performance.json", JSON.stringify({ measuredAt: new Date().toISOString(), environment: "Headless Chrome on the development Mac; mobile is viewport emulation, not a physical mobile device.", results }, null, 2));
console.log(JSON.stringify(results, null, 2));
