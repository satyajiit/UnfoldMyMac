// Renders public/media/lock-screen.webp: a composed illustration of the macOS
// lock screen layout over one frame of the Ghost of Tsushima — Scarlet Wind
// preview. The clock, status glyphs, avatar and prompt are drawn here in HTML
// and CSS; nothing is captured from macOS, no personal data is read, and no
// network request is made. Reads only files inside the website directory plus
// the ffmpeg binary on PATH.
//
// Usage: node scripts/render-lock-screen.mjs

import { chromium } from "@playwright/test";
import { execFile } from "node:child_process";
import { mkdir, readFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import sharp from "sharp";

const run = promisify(execFile);
const websiteDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const sourceVideo = join(websiteDir, "public/media/ghost-tsushima-maple.mp4");
const cacheDir = join(websiteDir, ".cache");
const framePath = join(cacheDir, "lock-screen-frame.png");
const outputPath = join(websiteDir, "public/media/lock-screen.webp");

const WIDTH = 960;
const HEIGHT = 600;
const SCALE = 2;
const FRAME_TIME_SECONDS = 2.0;

// Sample values only. These never come from the machine's clock or account.
const SAMPLE_DATE = "Tuesday, September 15";
const SAMPLE_TIME = "9:41";
const PROMPT = "Touch ID or Enter Password";

async function extractFrame() {
  await mkdir(cacheDir, { recursive: true });
  await run("ffmpeg", [
    "-hide_banner",
    "-loglevel",
    "error",
    "-y",
    "-ss",
    String(FRAME_TIME_SECONDS),
    "-i",
    sourceVideo,
    "-frames:v",
    "1",
    "-pix_fmt",
    "rgb24",
    framePath,
  ]);
  const png = await readFile(framePath);
  return `data:image/png;base64,${png.toString("base64")}`;
}

const wifiGlyph = `<svg width="17" height="13" viewBox="0 0 17 13" fill="none" aria-hidden="true">
  <path d="M8.5 12.2a1.35 1.35 0 1 0 0-2.7 1.35 1.35 0 0 0 0 2.7Z" fill="#fff"/>
  <path d="M5.4 7.6a4.4 4.4 0 0 1 6.2 0" stroke="#fff" stroke-width="1.5" stroke-linecap="round"/>
  <path d="M3.1 5a7.7 7.7 0 0 1 10.8 0" stroke="#fff" stroke-width="1.5" stroke-linecap="round"/>
  <path d="M.9 2.5a10.8 10.8 0 0 1 15.2 0" stroke="#fff" stroke-width="1.5" stroke-linecap="round"/>
</svg>`;

const batteryGlyph = `<svg width="27" height="12" viewBox="0 0 27 12" fill="none" aria-hidden="true">
  <rect x="0.75" y="0.75" width="22.5" height="10.5" rx="3" stroke="#fff" stroke-opacity=".5" stroke-width="1.1"/>
  <rect x="2.25" y="2.25" width="16.9" height="7.5" rx="1.7" fill="#fff"/>
  <path d="M25 4.2v3.6a1.9 1.9 0 0 0 0-3.6Z" fill="#fff" fill-opacity=".5"/>
</svg>`;

const personGlyph = `<svg width="30" height="30" viewBox="0 0 30 30" fill="none" aria-hidden="true">
  <circle cx="15" cy="10.2" r="5.6" fill="#fff" fill-opacity=".9"/>
  <path d="M4.2 27.4c.6-5.6 5.1-9.4 10.8-9.4s10.2 3.8 10.8 9.4Z" fill="#fff" fill-opacity=".9"/>
</svg>`;

function buildHtml(frameDataUrl) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<style>
  html, body { margin: 0; padding: 0; }
  body {
    width: ${WIDTH}px;
    height: ${HEIGHT}px;
    overflow: hidden;
    position: relative;
    background: #0b0d16 url("${frameDataUrl}") center / cover no-repeat;
    font-family: -apple-system, "SF Pro Display", "SF Pro Text", system-ui, sans-serif;
    color: #fff;
    -webkit-font-smoothing: antialiased;
  }
  .vignette {
    position: absolute;
    inset: 0;
    background: linear-gradient(rgba(0, 0, 0, .30), transparent 38%);
    pointer-events: none;
  }
  .clock {
    position: absolute;
    top: 34px;
    left: 0;
    right: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
  }
  .date {
    font-size: 13.5px;
    font-weight: 500;
    line-height: 1.2;
    color: rgba(255, 255, 255, .82);
    letter-spacing: .01em;
    text-shadow: 0 1px 6px rgba(0, 0, 0, .45);
  }
  .time {
    margin-top: 2px;
    font-size: 118px;
    font-weight: 200;
    line-height: 1;
    color: #fff;
    letter-spacing: -.01em;
    font-variant-numeric: proportional-nums;
    text-shadow: 0 2px 14px rgba(0, 0, 0, .45);
  }
  .status {
    position: absolute;
    top: 16px;
    right: 16px;
    display: flex;
    align-items: center;
    gap: 9px;
    opacity: .85;
    filter: drop-shadow(0 1px 3px rgba(0, 0, 0, .45));
  }
  .status svg { display: block; }
  .login {
    position: absolute;
    left: 0;
    right: 0;
    bottom: 58px;
    display: flex;
    flex-direction: column;
    align-items: center;
  }
  .avatar {
    width: 54px;
    height: 54px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: radial-gradient(circle at 38% 30%, #a3a7b0 0%, #62666f 100%);
    box-shadow: 0 0 0 1px rgba(255, 255, 255, .35), 0 4px 14px rgba(0, 0, 0, .35);
  }
  .avatar svg { display: block; }
  .prompt {
    margin-top: 12px;
    padding: 7px 14px;
    font-size: 12.5px;
    font-weight: 500;
    line-height: 1.2;
    color: rgba(255, 255, 255, .92);
    border-radius: 999px;
    background: rgba(255, 255, 255, .16);
    -webkit-backdrop-filter: blur(18px);
    backdrop-filter: blur(18px);
    border: 1px solid rgba(255, 255, 255, .22);
    text-shadow: 0 1px 2px rgba(0, 0, 0, .25);
    white-space: nowrap;
  }
</style>
</head>
<body>
  <div class="vignette"></div>
  <div class="status">${wifiGlyph}${batteryGlyph}</div>
  <div class="clock">
    <div class="date">${SAMPLE_DATE}</div>
    <div class="time">${SAMPLE_TIME}</div>
  </div>
  <div class="login">
    <div class="avatar">${personGlyph}</div>
    <div class="prompt">${PROMPT}</div>
  </div>
</body>
</html>`;
}

async function screenshot(html) {
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({
      viewport: { width: WIDTH, height: HEIGHT },
      deviceScaleFactor: SCALE,
      offline: true,
    });
    await page.route("**/*", (route) => route.abort());
    await page.setContent(html, { waitUntil: "load" });
    await page.evaluate(async () => {
      await document.fonts.ready;
      await new Promise((done) => requestAnimationFrame(() => done()));
    });
    return await page.screenshot({ type: "png", fullPage: false });
  } finally {
    await browser.close();
  }
}

const frameDataUrl = await extractFrame();
const png = await screenshot(buildHtml(frameDataUrl));
const info = await sharp(png).webp({ quality: 88 }).toFile(outputPath);
console.log(`${outputPath} ${info.width}x${info.height} (${info.size} bytes)`);
