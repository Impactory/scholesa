import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.PLAYWRIGHT_BASE_URL || 'http://127.0.0.1:3002';

const nextEnv = [
  'NODE_ENV=production',
  'NEXT_TELEMETRY_DISABLED=1',
  'NEXT_PUBLIC_E2E_TEST_MODE=1',
  'NEXT_PUBLIC_FIREBASE_API_KEY=demo-api-key',
  'NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=demo.firebaseapp.com',
  'NEXT_PUBLIC_FIREBASE_PROJECT_ID=demo-scholesa-e2e',
  'NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=demo-scholesa-e2e.appspot.com',
  'NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=000000000000',
  'NEXT_PUBLIC_FIREBASE_APP_ID=1:000000000000:web:e2e',
  'FIREBASE_PROJECT_ID=demo-scholesa-e2e',
  'GCLOUD_PROJECT=demo-scholesa-e2e',
  'GOOGLE_CLOUD_PROJECT=demo-scholesa-e2e',
].join(' ');

export default defineConfig({
  testDir: './test/e2e',
  timeout: 120_000,
  expect: {
    timeout: 20_000,
  },
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  use: {
    baseURL,
    headless: true,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: {
    command: `bash -lc '${nextEnv} npx next build && ${nextEnv} PORT=3002 npx next start -H 127.0.0.1 -p 3002'`,
    url: baseURL,
    timeout: 300_000,
    reuseExistingServer: false,
  },
});
