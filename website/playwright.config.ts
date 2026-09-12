import { defineConfig, devices } from "@playwright/test";
export default defineConfig({
  testDir: "./tests/browser", fullyParallel: true, retries: process.env.CI ? 1 : 0,
  workers: 3, reporter: [["list"], ["html", { open: "never" }]],
  use: { baseURL: "http://127.0.0.1:4173", trace: "retain-on-failure", screenshot: "only-on-failure" },
  webServer: { command: "node scripts/serve.mjs", url: "http://127.0.0.1:4173", reuseExistingServer: !process.env.CI },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"], channel: process.env.PLAYWRIGHT_CHROMIUM_CHANNEL } },
    { name: "firefox", use: { ...devices["Desktop Firefox"] } },
    { name: "webkit", use: { ...devices["Desktop Safari"] } },
    { name: "mobile", use: { ...devices["iPhone 13"], defaultBrowserType: "chromium", channel: process.env.PLAYWRIGHT_CHROMIUM_CHANNEL } },
  ],
});
