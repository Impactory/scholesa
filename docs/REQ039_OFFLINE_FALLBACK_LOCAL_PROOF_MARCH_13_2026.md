# REQ-039 Offline Fallback Local Proof

Date: 2026-03-13

Requirement: REQ-039 Offline fallback page

Files reviewed:
- `public/offline.html`
- `public/sw.js`
- `next.config.mjs`
- `app/layout.tsx`
- `src/components/pwa/ServiceWorkerRegister.tsx`
- `src/lib/pwa/registerServiceWorker.ts`

Findings:
- `public/offline.html` exists as a dedicated offline fallback page.
- The generated Workbox service worker in `public/sw.js` precaches `/offline.html`.
- `next.config.mjs` has `next-pwa` enabled for non-development builds with output directed to `public`.
- `app/layout.tsx` mounts `ServiceWorkerRegister`, so the registration path is active for the web app shell.
- `src/components/pwa/ServiceWorkerRegister.tsx` was corrected to call the shared `registerServiceWorker()` helper directly during hydration, avoiding missed registration caused by attaching a `window.load` listener after the page load event had already fired.

Closure rationale:
- The offline fallback page is present.
- The service worker precaches it.
- The app now registers the worker reliably from the root layout.

Status:
- REQ-039 can be marked complete.