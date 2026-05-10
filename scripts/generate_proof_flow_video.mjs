#!/usr/bin/env node
/**
 * Generate public/videos/proof-flow.mp4 by recording the running Scholesa app
 * end-to-end across the evidence chain — Landing → Educator → Learner → Guardian
 * → Site → HQ — using the in-app E2E backend (NEXT_PUBLIC_E2E_TEST_MODE=1).
 *
 * Pipeline:
 *   1. Boot `next dev --webpack` with the same env flags Playwright e2e tests use
 *      (demo-scholesa-e2e project) so the AuthProvider wires to the fake backend
 *      and the assistant dock is hidden.
 *   2. Wait for /en to respond, then drive Chromium through a scripted tour.
 *      Role switches go through `window.__scholesaE2E.signInAs(uid, locale)` which
 *      the app exposes when E2E mode is on.
 *   3. Playwright records the session to WebM. The bundled @ffmpeg-installer
 *      static binary transcodes to H.264 MP4 (+faststart) and exports a poster.
 *
 * Run:
 *   node scripts/generate_proof_flow_video.mjs
 */

/* global document, requestAnimationFrame, window */

import { chromium } from 'playwright';
import { spawn, spawnSync } from 'node:child_process';
import { mkdirSync, rmSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import ffmpegInstaller from '@ffmpeg-installer/ffmpeg';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..');
const OUT_DIR = join(REPO_ROOT, 'public', 'videos');
const OUT_MP4 = join(OUT_DIR, 'proof-flow.mp4');
const OUT_POSTER = join(OUT_DIR, 'proof-flow-poster.jpg');
const TMP_DIR = join(HERE, 'proof-flow', '.tmp');

const PORT = 3742;
const BASE_URL = `http://127.0.0.1:${PORT}`;
const VIEWPORT = { width: 1280, height: 720 };

const NEXT_ENV = {
  ...process.env,
  NEXT_TELEMETRY_DISABLED: '1',
  NEXT_PUBLIC_E2E_TEST_MODE: '1',
  NEXT_PUBLIC_FIREBASE_API_KEY: 'demo-api-key',
  NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN: 'demo.firebaseapp.com',
  NEXT_PUBLIC_FIREBASE_PROJECT_ID: 'demo-scholesa-e2e',
  NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET: 'demo-scholesa-e2e.appspot.com',
  NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID: '000000000000',
  NEXT_PUBLIC_FIREBASE_APP_ID: '1:000000000000:web:e2e',
  FIREBASE_PROJECT_ID: 'demo-scholesa-e2e',
  GCLOUD_PROJECT: 'demo-scholesa-e2e',
  GOOGLE_CLOUD_PROJECT: 'demo-scholesa-e2e',
  PORT: String(PORT),
};

/**
 * Cross-role evidence-chain tour. Each step navigates to a real route and
 * dwells long enough for a viewer to read the surface. `auth` steps switch
 * identities through the in-app E2E hook before navigating.
 *
 * Routing constraint: window.__scholesaE2E is only attached on pages that
 * import @/src/firebase/client-init (login + every protected route). The bare
 * landing /en does not pull Firebase, so any signInAs() must run while we are
 * still on a Firebase-touching page. The tour therefore opens on /en/login,
 * stays on protected routes for every role switch, and visits /en only as the
 * closing outro (where no signInAs is needed — just a final dwell).
 */
const TOUR = [
  { label: 'Sign-in',                kind: 'public', path: '/en/login',                       dwell: 2500 },
  { label: 'Educator · Today',       kind: 'auth',   uid: 'educator-alpha',    path: '/en/educator/today',           dwell: 3500 },
  { label: 'Educator · Proof review',kind: 'goto',                              path: '/en/educator/proof-review',    dwell: 3500 },
  { label: 'Learner · Today',        kind: 'auth',   uid: 'learner-alpha',     path: '/en/learner/today',            dwell: 3500 },
  { label: 'Learner · Portfolio',    kind: 'goto',                              path: '/en/learner/portfolio',        dwell: 3500 },
  { label: 'Guardian · Summary',     kind: 'auth',   uid: 'parent-alpha',      path: '/en/parent/summary',           dwell: 3500 },
  { label: 'Site · Evidence health', kind: 'auth',   uid: 'site-alpha-admin',  path: '/en/site/evidence-health',     dwell: 3500 },
  { label: 'HQ · Capability frameworks', kind: 'auth', uid: 'hq-alpha',        path: '/en/hq/capability-frameworks', dwell: 3500 },
  { label: 'Outro · Landing',        kind: 'public', path: '/en',                              dwell: 2500, scroll: true },
];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitForServer(timeoutMs = 180_000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(`${BASE_URL}/en`, { method: 'GET' });
      if (res.status === 200 || res.status === 307 || res.status === 308) return;
    } catch {
      /* not yet listening */
    }
    await sleep(2000);
  }
  throw new Error(`Dev server did not become ready on ${BASE_URL}`);
}

async function startDevServer() {
  const child = spawn('npx', ['next', 'dev', '--webpack', '-H', '127.0.0.1', '-p', String(PORT)], {
    cwd: REPO_ROOT,
    env: NEXT_ENV,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  child.stdout.on('data', () => {});
  child.stderr.on('data', () => {});
  await waitForServer();
  // First compile of /en after readiness can still settle for a moment
  await sleep(2000);
  return child;
}

async function smoothScrollThrough(page, durationMs) {
  await page.evaluate(async (duration) => {
    await new Promise((resolve) => {
      const start = performance.now();
      const max = Math.max(
        document.body.scrollHeight - window.innerHeight,
        document.documentElement.scrollHeight - window.innerHeight,
        0,
      );
      const tick = (now) => {
        const t = Math.min(1, (now - start) / duration);
        const eased = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
        window.scrollTo({ top: max * eased, behavior: 'auto' });
        if (t < 1) requestAnimationFrame(tick);
        else resolve();
      };
      requestAnimationFrame(tick);
    });
  }, durationMs);
}

async function recordTour() {
  rmSync(TMP_DIR, { recursive: true, force: true });
  mkdirSync(TMP_DIR, { recursive: true });

  const browser = await chromium.launch();
  const context = await browser.newContext({
    viewport: VIEWPORT,
    deviceScaleFactor: 1,
    recordVideo: { dir: TMP_DIR, size: VIEWPORT },
    baseURL: BASE_URL,
  });
  const page = await context.newPage();

  // Bootstrap: hit /en/login first because it imports @/src/firebase/client-init
  // which is what attaches window.__scholesaE2E. The bare landing page does not
  // pull Firebase, so __scholesaE2E never appears if we only visit /en.
  await page.goto(`${BASE_URL}/en/login`, { waitUntil: 'load' });
  await page.waitForFunction(
    () => Boolean(/** @type {any} */ (window).__scholesaE2E),
    { timeout: 60_000 },
  );
  await sleep(400);

  for (const step of TOUR) {
    console.log(`  · ${step.label}  →  ${step.path}`);

    if (step.kind === 'auth' && step.uid) {
      await page.evaluate(
        async ({ uid, locale }) =>
          /** @type {any} */ (window).__scholesaE2E.signInAs(uid, locale),
        { uid: step.uid, locale: 'en' },
      );
      await sleep(250);
    }

    await page.goto(`${BASE_URL}${step.path}`, { waitUntil: 'load' }).catch(() => {});
    await page.waitForLoadState('domcontentloaded').catch(() => {});
    await sleep(900); // settle for hydration / data fetches

    if (step.scroll) {
      await smoothScrollThrough(page, Math.max(1200, step.dwell - 600));
    } else {
      await sleep(step.dwell);
    }
  }

  // Tail buffer so the last frame isn't truncated mid-dwell.
  await sleep(800);

  await page.close();
  await context.close();
  await browser.close();

  const candidates = readdirSync(TMP_DIR)
    .filter((f) => f.endsWith('.webm'))
    .map((f) => join(TMP_DIR, f))
    .sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
  if (!candidates[0]) throw new Error('Playwright did not produce a .webm');
  return candidates[0];
}

function ffmpeg(args, label) {
  const r = spawnSync(ffmpegInstaller.path, args, { stdio: 'inherit' });
  if (r.status !== 0) throw new Error(`ffmpeg failed (${label}) with status ${r.status}`);
}

// Trim ~2 seconds off the opening — the recording begins while Next.js is
// compiling /en/login for the first time, so the very first frames are blank.
// Skipping past the compile makes the demo open straight on the rendered UI.
const OPENING_TRIM_SECONDS = '2.0';

function transcode(webm) {
  mkdirSync(OUT_DIR, { recursive: true });
  ffmpeg(
    [
      '-y',
      '-ss', OPENING_TRIM_SECONDS,
      '-i', webm,
      '-c:v', 'libx264',
      '-preset', 'slow',
      '-crf', '21',
      '-pix_fmt', 'yuv420p',
      '-profile:v', 'high',
      '-level', '4.0',
      '-movflags', '+faststart',
      '-an',
      OUT_MP4,
    ],
    'mp4',
  );
  ffmpeg(
    [
      '-y',
      '-ss', '0.5',
      '-i', OUT_MP4,
      '-frames:v', '1',
      '-q:v', '3',
      OUT_POSTER,
    ],
    'poster',
  );
}

async function main() {
  console.log('› Booting Next.js dev server in E2E mode …');
  const dev = await startDevServer();
  try {
    console.log('› Recording cross-role evidence-chain tour …');
    const webm = await recordTour();
    console.log(`  webm: ${webm}`);
    console.log('› Transcoding WebM → MP4 (H.264) + poster frame …');
    transcode(webm);
    console.log(`  mp4:  ${OUT_MP4}`);
    console.log(`  jpg:  ${OUT_POSTER}`);
    rmSync(TMP_DIR, { recursive: true, force: true });
    console.log('✓ Proof Flow demo video generated.');
  } finally {
    dev.kill('SIGINT');
    await sleep(500);
    if (!dev.killed) dev.kill('SIGKILL');
  }
}

main().catch((err) => {
  console.error('✗ Proof Flow demo generation failed.');
  console.error(err);
  process.exit(1);
});
