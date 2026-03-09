import { defineConfig, devices } from '@playwright/test';

const projectId = process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || 'demo-scholesa-e2e';
const authEmulatorHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const functionsEmulatorHost = process.env.FIREBASE_FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';
const baseURL = process.env.PLAYWRIGHT_BASE_URL || 'http://127.0.0.1:3002';

const nextEnv = [
  'NODE_ENV=production',
  'NEXT_TELEMETRY_DISABLED=1',
  'NEXT_PUBLIC_E2E_TEST_MODE=1',
  'NEXT_PUBLIC_FIREBASE_API_KEY=demo-api-key',
  'NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=127.0.0.1',
  `NEXT_PUBLIC_FIREBASE_PROJECT_ID=${projectId}`,
  `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=${projectId}.appspot.com`,
  'NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=000000000000',
  'NEXT_PUBLIC_FIREBASE_APP_ID=1:000000000000:web:e2e',
  `NEXT_PUBLIC_FIREBASE_AUTH_EMULATOR_HOST=${authEmulatorHost}`,
  `NEXT_PUBLIC_FIRESTORE_EMULATOR_HOST=${firestoreEmulatorHost}`,
  `NEXT_PUBLIC_FIREBASE_FUNCTIONS_EMULATOR_HOST=${functionsEmulatorHost}`,
  `FIREBASE_PROJECT_ID=${projectId}`,
  `GCLOUD_PROJECT=${projectId}`,
  `GOOGLE_CLOUD_PROJECT=${projectId}`,
  `FIREBASE_AUTH_EMULATOR_HOST=${authEmulatorHost}`,
  `FIRESTORE_EMULATOR_HOST=${firestoreEmulatorHost}`,
  `FIREBASE_FUNCTIONS_EMULATOR_HOST=${functionsEmulatorHost}`,
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
