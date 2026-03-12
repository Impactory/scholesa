/**
 * Welcome to your Workbox-powered service worker!
 *
 * You'll need to register this file in your web app and you should
 * disable HTTP caching for this file too.
 * See https://goo.gl/nhQhGp
 *
 * The rest of the code is auto-generated. Please don't update this file
 * directly; instead, make changes to your Workbox build configuration
 * and re-run your build process.
 * See https://goo.gl/2aRDsh
 */

importScripts("https://storage.googleapis.com/workbox-cdn/releases/4.3.1/workbox-sw.js");

importScripts(
  "/_next/precache.fn0iu9C9__9fdfWmhmMVL.449871317937da53e424f76bbd6a2ca4.js"
);

workbox.core.skipWaiting();

workbox.core.clientsClaim();

/**
 * The workboxSW.precacheAndRoute() method efficiently caches and responds to
 * requests for URLs in the manifest.
 * See https://goo.gl/S9QRab
 */
self.__precacheManifest = [
  {
    "url": "/favicon.ico",
    "revision": "afac47a23684d5e635d1fcc745a66659"
  },
  {
    "url": "/favicon.png",
    "revision": "eab5ce4b9559edf902e68f8d99129560"
  },
  {
    "url": "/icons/icon-192.png",
    "revision": "8152efe092c34589924781e70d837ee9"
  },
  {
    "url": "/icons/icon-512.png",
    "revision": "46a7f7a0f69c46ff1e569988c15ef70f"
  },
  {
    "url": "/logo/scholesa-logo-1024.png",
    "revision": "1e0f9626979491b22a65cec04e6c0efd"
  },
  {
    "url": "/logo/scholesa-logo-128.png",
    "revision": "ab669d274bb16d9a419f7b895a629b63"
  },
  {
    "url": "/logo/scholesa-logo-192.png",
    "revision": "8152efe092c34589924781e70d837ee9"
  },
  {
    "url": "/logo/scholesa-logo-256.png",
    "revision": "edd86db4c587cbb13f7f8455aefd40f9"
  },
  {
    "url": "/logo/scholesa-logo-512.png",
    "revision": "46a7f7a0f69c46ff1e569988c15ef70f"
  },
  {
    "url": "/logo/scholesa-logo-512.webp",
    "revision": "470b871dac2781862545cb7f1c31d39e"
  },
  {
    "url": "/logo/scholesa-logo-64.png",
    "revision": "e37b123cbdbd2eb518108e3e35e7346b"
  },
  {
    "url": "/manifest.webmanifest",
    "revision": "84be2c61df6ff528613e1ecf8d4aa817"
  },
  {
    "url": "/offline.html",
    "revision": "81399209934aba9dcb01858b5fcce4a4"
  },
  {
    "url": "/scholesa.svg",
    "revision": "2cb43af40e8a99e3778bfb1d652a27b0"
  },
  {
    "url": "/workbox-4754cb34.js",
    "revision": "98d58f6ba4bb37cd18d746933f6b0ed4"
  }
].concat(self.__precacheManifest || []);
workbox.precaching.precacheAndRoute(self.__precacheManifest, {});

workbox.precaching.cleanupOutdatedCaches();

workbox.routing.registerRoute(/^https:\/\/fonts\.(?:googleapis|gstatic)\.com\/.*/i, new workbox.strategies.CacheFirst({ "cacheName":"google-fonts", plugins: [new workbox.expiration.Plugin({ maxEntries: 4, maxAgeSeconds: 31536000, purgeOnQuotaError: false })] }), 'GET');
workbox.routing.registerRoute(/^https:\/\/use\.fontawesome\.com\/releases\/.*/i, new workbox.strategies.CacheFirst({ "cacheName":"font-awesome", plugins: [new workbox.expiration.Plugin({ maxEntries: 1, maxAgeSeconds: 31536000, purgeOnQuotaError: false })] }), 'GET');
workbox.routing.registerRoute(/\.(?:eot|otf|ttc|ttf|woff|woff2|font.css)$/i, new workbox.strategies.StaleWhileRevalidate({ "cacheName":"static-font-assets", plugins: [new workbox.expiration.Plugin({ maxEntries: 4, maxAgeSeconds: 604800, purgeOnQuotaError: false })] }), 'GET');
workbox.routing.registerRoute(/\.(?:jpg|jpeg|gif|png|svg|ico|webp)$/i, new workbox.strategies.StaleWhileRevalidate({ "cacheName":"static-image-assets", plugins: [new workbox.expiration.Plugin({ maxEntries: 64, maxAgeSeconds: 86400, purgeOnQuotaError: false })] }), 'GET');
workbox.routing.registerRoute(/\.(?:js)$/i, new workbox.strategies.StaleWhileRevalidate({ "cacheName":"static-js-assets", plugins: [new workbox.expiration.Plugin({ maxEntries: 16, maxAgeSeconds: 86400, purgeOnQuotaError: false })] }), 'GET');
workbox.routing.registerRoute(/\.(?:css|less)$/i, new workbox.strategies.StaleWhileRevalidate({ "cacheName":"static-style-assets", plugins: [new workbox.expiration.Plugin({ maxEntries: 16, maxAgeSeconds: 86400, purgeOnQuotaError: false })] }), 'GET');
workbox.routing.registerRoute(/.*/i, new workbox.strategies.StaleWhileRevalidate({ "cacheName":"others", plugins: [new workbox.expiration.Plugin({ maxEntries: 16, maxAgeSeconds: 86400, purgeOnQuotaError: false })] }), 'GET');
