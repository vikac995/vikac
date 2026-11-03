/* Vikač High Kikač service worker — bump CACHE on every release */
const CACHE = 'vikac-v4.4.1';
const ASSETS = ['index.html', 'manifest.webmanifest', 'icon-192.png', 'icon-512.png', 'icon-512-maskable.png'];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => Promise.all(ASSETS.map(a => c.add(a).catch(() => null)))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE && k !== 'vikac-ocr' && k !== 'vikac-share').map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('message', e => { if (e.data === 'skipWaiting') self.skipWaiting(); });
const OCR_CACHE = 'vikac-ocr';   // reader files (6 MB) — kept across app updates
const isOcr = p => /\/(tess[^/]*\.js|eng\.traineddata\.gz)$/.test(p);
self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  // Web Share Target: the Xiaomi app posts the export image here; stash it and open the app
  if (e.request.method === 'POST' && url.pathname.endsWith('/share')) {
    e.respondWith((async () => {
      try { const fd = await e.request.formData(); const files = fd.getAll('image').filter(f => f && f.size); const c = await caches.open('vikac-share'); for (const k of await c.keys()) await c.delete(k); let i = 0; for (const f of files) await c.put('shared-' + String(i++).padStart(2, '0'), new Response(f, { headers: { 'Content-Type': f.type || 'image/png' } })); } catch (err) {}
      return Response.redirect('./?share=1', 303);
    })());
    return;
  }
  if (e.request.method !== 'GET' || url.origin !== location.origin) return;
  if (/\/video-[a-z0-9-]+\.mp4$/.test(url.pathname)) return;   // exercise videos stream straight from the server (range requests)
  // custom art PNGs: network first so a re-upload shows up without a version bump, cache when offline
  if (/\/(hero-[0-9a-z]+|lift-[a-z]+(-[0-9])?|beam|dragon|dragon-badge|ball-[1-7](-hollow)?|season-[a-z]+|ground-[a-z]+)\.png$/.test(url.pathname)) { e.respondWith(fetch(e.request).then(r => { if (r.ok) caches.open(CACHE).then(c => c.put(e.request, r.clone())); return r; }).catch(() => caches.match(e.request))); return; }
  if (isOcr(url.pathname)) { e.respondWith(caches.open(OCR_CACHE).then(c => c.match(e.request).then(r => r || fetch(e.request).then(res => { if (res.ok) c.put(e.request, res.clone()); return res; })))); return; }
  const isPage = e.request.mode === 'navigate' || url.pathname.endsWith('index.html') || url.pathname.endsWith('/');
  if (isPage) {
    e.respondWith(fetch(new Request(e.request, { cache: 'no-cache' })).then(r => { const copy = r.clone(); caches.open(CACHE).then(c => c.put('index.html', copy)); return r; }).catch(() => caches.match('index.html')));
  } else {
    e.respondWith(caches.match(e.request).then(r => r || fetch(e.request).then(res => { const copy = res.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); return res; })));
  }
});
