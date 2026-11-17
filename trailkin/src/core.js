/* Trailkin core: maths, springs, a sleeping ticker, pointer drags, haptics, sound, canvas. */
(() => {
'use strict';
const TK = window.TK = {};
const mqReduce = matchMedia('(prefers-reduced-motion: reduce)');
TK.reduced = () => mqReduce.matches;
TK.clamp = (v, a, b) => v < a ? a : v > b ? b : v;
TK.lerp = (a, b, t) => a + (b - a) * t;
TK.ease = t => 1 - Math.pow(1 - TK.clamp(t, 0, 1), 3);
TK.fmt = n => Math.round(n).toLocaleString('en-US');
TK.h = (tag, attrs, ...kids) => {
  const el = document.createElement(tag);
  if (attrs) for (const k in attrs) {
    const v = attrs[k];
    if (v == null || v === false) continue;
    if (k === 'class') el.className = v;
    else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
    else if (k === 'html') el.innerHTML = v;
    else if (k === 'text') el.textContent = v;
    else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2), v);
    else el.setAttribute(k, v === true ? '' : v);
  }
  for (const c of kids.flat()) if (c != null && c !== false) el.append(c.nodeType ? c : document.createTextNode(c));
  return el;
};

/* Seeded random (mulberry32) so a demo replays the same way. */
TK.rng = seed => () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };

/* One rAF for everything; sleeps when nothing runs. */
const subs = new Set(); let running = false, last = 0;
function frame(now) {
  const dt = Math.max(0, Math.min(0.05, (now - last) / 1000)) || 0.016; last = now;
  for (const f of [...subs]) { let keep; try { keep = f(dt, now); } catch (e) { console.error(e); keep = false; } if (keep === false) subs.delete(f); }
  if (subs.size) requestAnimationFrame(frame); else running = false;
}
TK.tick = fn => { subs.add(fn); if (!running) { running = true; last = performance.now(); requestAnimationFrame(frame); } return () => subs.delete(fn); };
TK.loop = fn => { let active = false; const step = (dt, now) => { if (!fn(dt, now)) { active = false; return false; } }; return { wake() { if (!active) { active = true; TK.tick(step); } }, get active() { return active; } }; };
TK.wait = ms => new Promise(r => setTimeout(r, TK.reduced() ? Math.min(ms, 60) : ms));

/* Springs: same tokens as the Flutter build (SpringDescription mass 1). */
TK.SPRING = { snappy: { k: 600, c: 44 }, smooth: { k: 260, c: 30 }, bouncy: { k: 320, c: 14 }, gentle: { k: 120, c: 20 } };
class Spring {
  constructor(x = 0, o = TK.SPRING.smooth) { this.x = x; this.t = x; this.v = 0; this.k = o.k; this.c = o.c; }
  to(t) { this.t = t; return this; } set(x) { this.x = this.t = x; this.v = 0; return this; } kick(v) { this.v += v; return this; }
  step(dt) {
    if (TK.reduced()) { this.x = this.t; this.v = 0; return true; }
    const n = Math.max(1, Math.ceil(dt / 0.004)), h = dt / n;
    for (let i = 0; i < n; i++) { const a = -this.k * (this.x - this.t) - this.c * this.v; this.v += a * h; this.x += this.v * h; }
    const s = Math.max(1, Math.abs(this.t)) * 0.001;
    if (Math.abs(this.x - this.t) < s && Math.abs(this.v) < s * 10) { this.x = this.t; this.v = 0; return true; }
    return false;
  }
}
TK.Spring = Spring;
TK.spring = (x, o) => new Spring(x, o);

/* Pointer drag with velocity (px/s), measured in client space. */
TK.drag = (el, h, opt = {}) => {
  el.style.touchAction = opt.axis === 'x' ? 'pan-y' : opt.axis === 'y' ? 'pan-x' : 'none';
  let s = null;
  const loc = e => { const r = el.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
  el.addEventListener('pointerdown', e => {
    if (s || (e.pointerType === 'mouse' && e.button !== 0)) return;
    const [x, y] = loc(e);
    s = { id: e.pointerId, x, y, x0: x, y0: y, cx: e.clientX, cy: e.clientY, dx: 0, dy: 0, vx: 0, vy: 0, t0: e.timeStamp, moved: false, hist: [[e.timeStamp, e.clientX, e.clientY]] };
    if (h.start && h.start(s, e) === false) { s = null; return; }
    try { el.setPointerCapture(e.pointerId); } catch (_) { /* fine */ }
    if (e.pointerType === 'mouse') e.preventDefault();
  });
  el.addEventListener('pointermove', e => {
    if (!s || e.pointerId !== s.id) return;
    const [x, y] = loc(e); s.x = x; s.y = y; s.dx = e.clientX - s.cx; s.dy = e.clientY - s.cy;
    s.hist.push([e.timeStamp, e.clientX, e.clientY]);
    while (s.hist.length > 2 && e.timeStamp - s.hist[0][0] > 80) s.hist.shift();
    const a = s.hist[0], dt = (e.timeStamp - a[0]) / 1000;
    if (dt > 0.004) { s.vx = (e.clientX - a[1]) / dt; s.vy = (e.clientY - a[2]) / dt; }
    if (!s.moved && Math.hypot(s.dx, s.dy) > 6) s.moved = true;
    h.move && h.move(s, e);
  });
  const up = (e, cancel) => {
    if (!s || e.pointerId !== s.id) return;
    const c = s; s = null; c.cancelled = cancel;
    if (e.timeStamp - c.hist[c.hist.length - 1][0] > 60) { c.vx = 0; c.vy = 0; }
    if (!c.moved && !cancel && h.tap) h.tap(c, e);
    h.end && h.end(c, e);
  };
  el.addEventListener('pointerup', e => up(e, false));
  el.addEventListener('pointercancel', e => up(e, true));
};

/* HiDPI canvas that follows its host's size. */
TK.canvas = (host, onResize) => {
  const cv = document.createElement('canvas'); host.appendChild(cv);
  const ctx = cv.getContext('2d');
  const o = { cv, ctx, w: 1, h: 1, dpr: 1 };
  o.fit = (silent) => {
    const r = host.getBoundingClientRect(); if (!r.width) return;
    o.dpr = Math.min(2.5, devicePixelRatio || 1); o.w = r.width; o.h = r.height;
    cv.width = Math.round(o.w * o.dpr); cv.height = Math.round(o.h * o.dpr);
    cv.style.width = o.w + 'px'; cv.style.height = o.h + 'px';
    ctx.setTransform(o.dpr, 0, 0, o.dpr, 0, 0); if (!silent && onResize) onResize(o);
  };
  new ResizeObserver(() => o.fit()).observe(host); o.fit(true); // first callback arrives from the observer, after the caller has finished setting up
  return o;
};

/* Haptics: the Flutter HapticFeedback vocabulary. The phone frame shows a pulse so you can "see" them on a laptop. */
const HAP = { select: [6], light: [12], medium: [20], heavy: [34], success: [14, 70, 26], fail: [24, 60, 24] };
TK.haptic = kind => {
  try { navigator.vibrate && navigator.vibrate(HAP[kind] || 12); } catch (_) { /* not allowed */ }
  document.dispatchEvent(new CustomEvent('tk-haptic', { detail: kind }));
};

/* Sound: tiny synthesized cues (no files). Off until the player turns it on. */
let actx = null; TK.soundOn = false;
const note = (f, t0, dur, type = 'sine', gain = 0.12, slide = 0) => {
  const o = actx.createOscillator(), g = actx.createGain();
  o.type = type; o.frequency.setValueAtTime(f, t0); if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(40, f + slide), t0 + dur);
  g.gain.setValueAtTime(0.0001, t0); g.gain.exponentialRampToValueAtTime(gain, t0 + 0.012); g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  o.connect(g).connect(actx.destination); o.start(t0); o.stop(t0 + dur + 0.02);
};
TK.sfx = name => {
  if (!TK.soundOn) return;
  try {
    actx = actx || new (window.AudioContext || window.webkitAudioContext)();
    const t = actx.currentTime;
    switch (name) {
      case 'tick': note(1400, t, 0.04, 'triangle', 0.05); break;
      case 'pop': note(520, t, 0.12, 'sine', 0.14, 380); break;
      case 'whoosh': note(300, t, 0.35, 'triangle', 0.05, 500); break;
      case 'thud': note(140, t, 0.18, 'sine', 0.2, -60); break;
      case 'wiggle': note(330, t, 0.09, 'square', 0.03); break;
      case 'chime': [784, 988, 1175].forEach((f, i) => note(f, t + i * 0.09, 0.5, 'sine', 0.09)); break;
      case 'fanfare': [523, 659, 784, 1047, 1319].forEach((f, i) => note(f, t + i * 0.08, 0.7, 'triangle', 0.07)); break;
      case 'crack': note(900, t, 0.05, 'square', 0.04, -500); note(220, t + 0.02, 0.12, 'sine', 0.1); break;
      case 'miss': note(400, t, 0.25, 'sine', 0.08, -220); break;
      case 'ember': note(220, t, 0.6, 'sawtooth', 0.025, 220); note(660, t + 0.15, 0.6, 'sine', 0.06); break;
    }
  } catch (_) { /* audio unavailable */ }
};

/* Screen reader announcements. */
TK.announce = msg => { const l = document.getElementById('tk-live'); if (!l) return; l.textContent = ''; setTimeout(() => { l.textContent = msg; }, 30); };
})();
