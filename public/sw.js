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
  "/_next/precache.DwYTP3jnt8Ogip1F5ELr-.b20afa8c0c3b1da9b450fed8dced906b.js"
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
    "revision": "b30a03641748af99505f54262e9791fc"
  },
  {
    "url": "/favicon.png",
    "revision": "30825b8590a2ed09e9487d9ba2ce34a6"
  },
  {
    "url": "/icons/icon-192.png",
    "revision": "6d25178cef39b482d4a01863827ee653"
  },
  {
    "url": "/icons/icon-512.png",
    "revision": "32e0d6614b47bcedf4d73fe3ff598a79"
  },
  {
    "url": "/logo/scholesa-logo-1024.png",
    "revision": "5abdb08e06cbd0a5d708cad554ad7bae"
  },
  {
    "url": "/logo/scholesa-logo-128.png",
    "revision": "69d372734baa1c7a4b8a35c8cb0c9cd6"
  },
  {
    "url": "/logo/scholesa-logo-192.png",
    "revision": "6d25178cef39b482d4a01863827ee653"
  },
  {
    "url": "/logo/scholesa-logo-256.png",
    "revision": "51d5c8af1040a49022b27a1aa17ac001"
  },
  {
    "url": "/logo/scholesa-logo-512.png",
    "revision": "32e0d6614b47bcedf4d73fe3ff598a79"
  },
  {
    "url": "/logo/scholesa-logo-512.webp",
    "revision": "1b87aa282c9e7ee081deac31fdf438cb"
  },
  {
    "url": "/logo/scholesa-logo-64.png",
    "revision": "cc5b7597e42a14d28355b15f163d8672"
  },
  {
    "url": "/manifest.webmanifest",
    "revision": "0caa94e6656ba58ffb9a2d80947b00ed"
  },
  {
    "url": "/offline.html",
    "revision": "81399209934aba9dcb01858b5fcce4a4"
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
