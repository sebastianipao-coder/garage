// Garage: funziona anche senza rete. Prima prova la rete (così gli aggiornamenti arrivano subito),
// se non c'è usa la copia salvata.
const CACHE = "garage-v12";
const ASSETS = ["./", "./index.html", "./config.js", "./manifest.json", "./icon-180.png", "./icon-192.png", "./icon-512.png",
  "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.js"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => Promise.all(ASSETS.map((u) => c.add(u).catch(() => {})))).then(() => self.skipWaiting()));
});
self.addEventListener("activate", (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
const withTimeout = (p, ms) => new Promise((res, rej) => { const t = setTimeout(() => rej(new Error("timeout")), ms); p.then((v) => { clearTimeout(t); res(v); }, (e) => { clearTimeout(t); rej(e); }); });
self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  const mine = url.origin === self.location.origin || url.href.startsWith("https://cdn.jsdelivr.net/npm/@supabase/");
  if (!mine) return; // dati Supabase: sempre dalla rete
  e.respondWith((async () => {
    const cache = await caches.open(CACHE);
    try {
      const res = await withTimeout(fetch(req), 5000);
      if (res && res.ok) cache.put(req.mode === "navigate" ? "./index.html" : req, res.clone());
      return res;
    } catch (err) {
      const hit = await cache.match(req.mode === "navigate" ? "./index.html" : req, { ignoreSearch: true });
      if (hit) return hit;
      throw err;
    }
  })());
});
