/* Knightsbridge Newsagency — service worker.

   Caches the static shell so the site opens offline after the first visit,
   and degrades cleanly: it is never registered on file:// (see js/app.js),
   a missing precache entry does not abort install, and any fetch it can't
   satisfy simply falls through to the network the way it would with no SW.

   Bump CACHE_VERSION whenever the shell assets change to retire old caches. */

const CACHE_VERSION = 'kn-v7';
const SHELL_CACHE = `${CACHE_VERSION}-shell`;
const RUNTIME_CACHE = `${CACHE_VERSION}-runtime`;

/* Paths are relative to the SW scope, so the site works in a sub-folder too. */
const SHELL = [
  './',
  'index.html', 'products.html', 'product.html', 'services.html', 'about.html',
  'shop.html', 'cart.html', 'contact.html', 'success.html', '404.html',
  'style.css',
  'js/art.js', 'js/carousel.js', 'js/app.js', 'js/photo-picker.js',
  'js/images.js', 'js/reviews.js', 'js/lottery.js', 'js/chatbot.js',
  'js/page-home.js', 'js/page-products.js', 'js/page-product.js', 'js/page-services.js',
  'js/page-about.js', 'js/page-cart.js',
  'js/page-contact.js', 'js/page-success.js', 'js/page-404.js',
  'site.webmanifest',
  'favicon.svg', 'favicon.ico', 'apple-touch-icon.png',
  'assets/icons/icon-192.png', 'assets/icons/icon-512.png',
  'assets/icons/icon-maskable-512.png'
];

const FONT_HOSTS = ['fonts.googleapis.com', 'fonts.gstatic.com'];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(SHELL_CACHE);
    // Add each entry on its own so one 404 (e.g. an optional file) can't
    // fail the whole install.
    await Promise.allSettled(SHELL.map((url) => cache.add(new Request(url, { cache: 'reload' }))));
    self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys
      .filter((k) => k !== SHELL_CACHE && k !== RUNTIME_CACHE)
      .map((k) => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  const sameOrigin = url.origin === self.location.origin;

  // Google Fonts: cache-first so type survives offline after the first load.
  if (FONT_HOSTS.includes(url.hostname)) {
    event.respondWith(cacheFirst(req, RUNTIME_CACHE));
    return;
  }

  // Anything else cross-origin (Openverse API, Flickr/Wikimedia photos):
  // leave it to the network. Those already fall back to drawn SVG on error.
  if (!sameOrigin) return;

  // Page navigations: network-first, fall back to cache, then to the shell.
  if (req.mode === 'navigate') {
    event.respondWith((async () => {
      try {
        const fresh = await fetch(req);
        const cache = await caches.open(SHELL_CACHE);
        cache.put(req, fresh.clone());
        return fresh;
      } catch {
        return (await caches.match(req))
            || (await caches.match('index.html'))
            || (await caches.match('404.html'))
            || Response.error();
      }
    })());
    return;
  }

  // Same-origin assets: stale-while-revalidate.
  event.respondWith((async () => {
    const cache = await caches.open(SHELL_CACHE);
    const cached = await cache.match(req);
    const network = fetch(req).then((res) => {
      if (res && res.ok) cache.put(req, res.clone());
      return res;
    }).catch(() => cached);
    return cached || network;
  })());
});

async function cacheFirst(req, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(req);
  if (cached) return cached;
  try {
    const res = await fetch(req);
    if (res && (res.ok || res.type === 'opaque')) cache.put(req, res.clone());
    return res;
  } catch {
    return cached || Response.error();
  }
}
