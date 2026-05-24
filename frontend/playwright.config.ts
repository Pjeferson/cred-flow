import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  globalSetup: "./src/e2e/global-setup.ts",
  testDir: "./src/e2e",
  testMatch: "**/*.e2e.ts",
  fullyParallel: false,
  retries: 1,
  timeout: 30_000,
  use: {
    baseURL: "http://localhost:5173",
    trace: "on-first-retry",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
