# REQ-045 PWA Cache Strategy Review

Date: 2026-03-13

## Scope

Requirement: document the active PWA cache strategy, including offline fallback behavior.

## Evidence Reviewed

- `next.config.mjs`
- `public/sw.js`
- `public/offline.html`

## Current Strategy

### PWA enablement

- The root Next.js app uses `next-pwa` through `withPWA(...)` in `next.config.mjs`.
- Output destination is `public`.
- The service worker is disabled only in development.
- `skipWaiting` is enabled.

### Offline fallback

- `public/offline.html` exists as the offline fallback surface.
- The current generated `public/sw.js` precache manifest explicitly includes `/offline.html`.

### Cache behavior in current generated service worker

The current `public/sw.js` registers Workbox routes for:

- Google Fonts: `CacheFirst`
- Font Awesome: `CacheFirst`
- Font assets: `StaleWhileRevalidate`
- Image assets: `StaleWhileRevalidate`
- JavaScript assets: `StaleWhileRevalidate`
- CSS assets: `StaleWhileRevalidate`
- Other GET requests: `StaleWhileRevalidate`

The service worker also:

- claims clients immediately
- skips waiting
- precaches static assets including icons, manifest, and offline fallback page
- cleans up outdated caches

## Conclusion

REQ-045 is satisfied by the current root web app configuration and generated service worker output. The previous deferment was stale.

## Notes

- `next-pwa` 2.x still emits known Workbox and legacy webpack deprecation warnings during production builds on Next 16. Those warnings are already tracked in `DEPENDENCY_BASELINE_SCHOLESA.md` as package debt, not a Scholesa configuration failure.
