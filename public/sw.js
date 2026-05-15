const STALE_CACHE_PREFIXES = [
  'workbox-',
  'static-',
  'google-fonts',
  'font-awesome',
  'apis',
  'others',
];

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((cacheNames) =>
        Promise.all(
          cacheNames
            .filter((cacheName) =>
              STALE_CACHE_PREFIXES.some((prefix) => cacheName.startsWith(prefix))
            )
            .map((cacheName) => caches.delete(cacheName))
        )
      )
      .then(() => self.clients.claim())
  );
});
