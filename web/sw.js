// Offline support: always try the network first, fall back to the cached app shell.
const CACHE = 'ember-grove-v1';
const FILES = ['./', 'index.html', 'manifest.webmanifest', 'js/app.js', 'js/game.js', 'js/content.js', 'js/ember.js',
  'js/grove.js', 'js/audio.js', 'js/icons.js', 'js/config.js', 'js/leaderboard.js', 'js/namefilter.js', 'icons/icon-192.png', 'icons/icon-512.png', 'icons/apple-touch-icon.png'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(FILES)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET' || url.origin !== location.origin || url.pathname.endsWith('version.txt')) return;
  e.respondWith(caches.open(CACHE).then(async (cache) => {
    try {
      // Network first (skipping the browser's HTTP cache) so updates show on the next open; cache when offline.
      const res = await Promise.race([fetch(e.request, { cache: 'no-cache' }), new Promise((_, no) => setTimeout(no, 4000))]);
      if (res.ok) cache.put(e.request, res.clone());
      return res;
    } catch (err) {
      return (await cache.match(e.request, { ignoreSearch: true })) || Response.error();
    }
  }));
});
