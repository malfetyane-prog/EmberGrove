// Offline support: serve the app shell from cache, refresh it in the background.
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
  if (e.request.method !== 'GET' || new URL(e.request.url).origin !== location.origin) return;
  e.respondWith(caches.open(CACHE).then(async (cache) => {
    const cached = await cache.match(e.request, { ignoreSearch: true });
    const network = fetch(e.request).then((res) => {
      if (res.ok && new URL(e.request.url).origin === location.origin) cache.put(e.request, res.clone());
      return res;
    }).catch(() => cached);
    return cached || network;
  }));
});
