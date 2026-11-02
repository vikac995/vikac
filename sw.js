/* Vikač High Kikač service worker — bump CACHE on every release */
const CACHE = 'vikac-v1.1.0';
const ASSETS = ['./', 'index.html', 'manifest.webmanifest', 'icon-192.png', 'icon-512.png', 'icon-512-maskable.png',
  'font/bangers-latin.woff2', 'font/bangers-latin-ext.woff2', 'font/barlowc-latin-700.woff2', 'font/barlowc-latin-ext-700.woff2', 'font/barlowc-latin-600.woff2', 'font/barlowc-latin-ext-600.woff2',
  'img/stretch4.jpg', 'img/stretch6.jpg', 'img/stretch7a.jpg', 'img/stretch7b.jpg', 'img/stretch8a.jpg', 'img/stretch8b.jpg', 'img/stretch8c.jpg'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET' || url.origin !== location.origin) return;
  const isPage = e.request.mode === 'navigate' || url.pathname.endsWith('index.html') || url.pathname.endsWith('/');
  if (isPage) {
    // network first for the page itself so updates arrive; cache fallback offline
    e.respondWith(fetch(e.request).then(r => { const copy = r.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); return r; }).catch(() => caches.match(e.request).then(r => r || caches.match('index.html'))));
  } else {
    e.respondWith(caches.match(e.request).then(r => r || fetch(e.request).then(res => { const copy = res.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); return res; })));
  }
});
