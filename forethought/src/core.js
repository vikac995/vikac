/* Forethought core: one ticker, springs, gestures, haptics, X-ray, exhibit plates.
   Every exhibit is registered with FT.exhibit({...}) and mounted by FT.build(). */
(() => {
'use strict';
const FT = window.FT = {};
const root = document.documentElement;
const mqReduce = matchMedia('(prefers-reduced-motion: reduce)');
const mqDark = matchMedia('(prefers-color-scheme: dark)');

/* ---------- math ---------- */
FT.clamp = (v, a, b) => v < a ? a : v > b ? b : v;
FT.lerp = (a, b, t) => a + (b - a) * t;
FT.map = (v, a, b, c, d) => c + (d - c) * ((v - a) / (b - a));
FT.dist = (x1, y1, x2, y2) => Math.hypot(x2 - x1, y2 - y1);
FT.reduced = () => mqReduce.matches;
FT.isDark = () => root.dataset.theme === 'dark' || (root.dataset.theme !== 'light' && mqDark.matches);

/* ---------- DOM ---------- */
FT.h = (tag, attrs, ...kids) => {
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
FT.svg = (tag, attrs) => {
  const el = document.createElementNS('http://www.w3.org/2000/svg', tag);
  if (attrs) for (const k in attrs) el.setAttribute(k, attrs[k]);
  return el;
};

/* ---------- colours (theme-aware, cached) ---------- */
let colCache = {};
const themeSubs = new Set();
FT.col = name => {
  if (!(name in colCache)) colCache[name] = getComputedStyle(root).getPropertyValue(name).trim() || '#888';
  return colCache[name];
};
FT.alpha = (hex, a) => {
  const c = hex.replace('#', '');
  const n = parseInt(c.length === 3 ? c.split('').map(x => x + x).join('') : c.slice(0, 6), 16);
  return `rgba(${n >> 16 & 255},${n >> 8 & 255},${n & 255},${a})`;
};
FT.onTheme = fn => { themeSubs.add(fn); return () => themeSubs.delete(fn); };
const themeChanged = () => { colCache = {}; themeSubs.forEach(f => { try { f(); } catch (e) { console.error(e); } }); };
mqDark.addEventListener('change', themeChanged);
new MutationObserver(themeChanged).observe(root, { attributes: true, attributeFilter: ['data-theme'] });

/* ---------- ticker: one rAF for the whole page; sleeps when idle ---------- */
const subs = new Set();
let running = false, last = 0, fpsAvg = 16.7;
function frame(now) {
  const raw = now - last; last = now;
  const dt = Math.max(0, Math.min(0.05, raw / 1000)) || 0.016;
  fpsAvg = fpsAvg * 0.9 + raw * 0.1;
  for (const f of [...subs]) {
    let keep;
    try { keep = f(dt, now); } catch (e) { console.error(e); keep = false; }
    if (keep === false) subs.delete(f);
  }
  if (xray.on) xrayFrame(now);
  if (subs.size || xray.on) requestAnimationFrame(frame); else running = false;
}
FT.tick = fn => {
  subs.add(fn);
  if (!running) { running = true; last = performance.now(); requestAnimationFrame(frame); }
  return () => subs.delete(fn);
};
/* A loop runs fn(dt, now) every frame while fn returns truthy; wake() restarts it. */
FT.loop = fn => {
  let active = false;
  const step = (dt, now) => { if (!fn(dt, now)) { active = false; return false; } };
  return { wake() { if (!active) { active = true; FT.tick(step); } }, get active() { return active; } };
};

/* ---------- springs (semi-implicit Euler, sub-stepped: identical at 60/90/120 Hz) ----------
   Presets mirror Flutter SpringDescription(mass: 1, stiffness, damping). */
FT.SPRING = {
  snappy: { k: 600, c: 44 },   // spatial fast  — thumbs, knobs
  smooth: { k: 260, c: 30 },   // spatial default — panels, cards
  bouncy: { k: 320, c: 16 },   // expressive overshoot — rewards, arrivals
  gentle: { k: 120, c: 20 },   // effects slow — colour, opacity, sheen
};
class Spring {
  constructor(x = 0, opt = FT.SPRING.smooth) { this.x = x; this.t = x; this.v = 0; this.k = opt.k; this.c = opt.c; this.m = opt.m || 1; this.eps = opt.eps || 0.001; }
  to(t) { this.t = t; return this; }
  set(x) { this.x = this.t = x; this.v = 0; return this; }
  kick(v) { this.v += v; return this; }
  step(dt) {
    if (FT.reduced()) { this.x = this.t; this.v = 0; return true; }
    const n = Math.max(1, Math.ceil(dt / 0.004)), h = dt / n;
    for (let i = 0; i < n; i++) {
      const a = (-this.k * (this.x - this.t) - this.c * this.v) / this.m;
      this.v += a * h; this.x += this.v * h;
    }
    if (this.done) { this.x = this.t; this.v = 0; return true; }
    return false;
  }
  get done() { const s = Math.max(1, Math.abs(this.t)) * this.eps; return Math.abs(this.x - this.t) < s && Math.abs(this.v) < s * 10; }
}
FT.Spring = Spring;
FT.spring = (x, opt) => new Spring(x, opt);

/* Momentum projection, like Flutter's FrictionSimulation: where would a fling stop? */
FT.project = (v, decel = 0.998) => (v / 1000) * decel / (1 - decel);

/* ---------- haptics: a small vocabulary, named after Flutter's HapticFeedback ---------- */
const HAPTIC = {
  select: [[6], 'HapticFeedback.selectionClick()'],
  light: [[10], 'HapticFeedback.lightImpact()'],
  medium: [[18], 'HapticFeedback.mediumImpact()'],
  heavy: [[30], 'HapticFeedback.heavyImpact()'],
  success: [[12, 70, 22], 'lightImpact() → 70 ms → mediumImpact()'],
  warning: [[20, 90, 20], 'mediumImpact() × 2'],
  error: [[28, 50, 28, 50, 28], 'HapticFeedback.vibrate() pattern'],
};
let lastHaptic = 0;
FT.haptic = kind => {
  const h = HAPTIC[kind] || HAPTIC.light;
  const now = performance.now();
  if (kind === 'select' && now - lastHaptic < 28) return; // never buzz faster than a finger can feel
  lastHaptic = now;
  try { if (navigator.vibrate) navigator.vibrate(h[0]); } catch (e) { /* not allowed here */ }
  xrayNote('haptic', h[1]);
};

/* ---------- screen reader announcements ---------- */
let liveT;
FT.announce = msg => {
  const live = document.getElementById('live');
  if (!live) return;
  clearTimeout(liveT); live.textContent = '';
  liveT = setTimeout(() => { live.textContent = msg; }, 30);
};

/* ---------- semantic intent (exhibits tell X-ray what they decided) ---------- */
FT.intent = (text, from) => {
  if (from && from.closest) { const pl = from.closest('.plate'); if (pl) xray.exhibit = pl.dataset.exhibit; }
  xrayNote('intent', text);
};

/* ---------- canvas helper: HiDPI, auto-resizing ---------- */
FT.canvas = (host, onResize) => {
  const cv = document.createElement('canvas');
  host.appendChild(cv);
  const ctx = cv.getContext('2d');
  const o = { cv, ctx, w: 1, h: 1, dpr: 1 };
  o.fit = () => {
    const r = host.getBoundingClientRect();
    if (!r.width) return;
    o.dpr = Math.min(2.5, window.devicePixelRatio || 1);
    o.w = r.width; o.h = r.height;
    cv.width = Math.round(o.w * o.dpr); cv.height = Math.round(o.h * o.dpr);
    cv.style.width = o.w + 'px'; cv.style.height = o.h + 'px';
    ctx.setTransform(o.dpr, 0, 0, o.dpr, 0, 0);
    onResize && onResize(o);
  };
  o.clear = () => ctx.clearRect(0, 0, o.w, o.h);
  new ResizeObserver(o.fit).observe(host);
  o.fit();
  return o;
};

/* ---------- pointer gestures with velocity, slop and capture ----------
   FT.drag(el, { start(s,e), move(s,e), end(s,e), tap(s,e) }, { axis:'x'|'y'|'both', slop:6 })
   s = { x, y (local), x0, y0, dx, dy, vx, vy (px/s), t (ms), moved, cancelled, id }
   axis 'x' sets touch-action: pan-y so the page still scrolls vertically over horizontal controls. */
FT.drag = (el, h, opt = {}) => {
  const axis = opt.axis || 'both';
  el.style.touchAction = axis === 'x' ? 'pan-y' : axis === 'y' ? 'pan-x' : 'none';
  const slop = opt.slop ?? 6;
  let s = null;
  const local = e => { const r = el.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
  const down = e => {
    if (s || (e.pointerType === 'mouse' && e.button !== 0)) return;
    if (h.filter && !h.filter(e)) return;
    const [x, y] = local(e);
    s = { id: e.pointerId, x, y, x0: x, y0: y, cx0: e.clientX, cy0: e.clientY, dx: 0, dy: 0, vx: 0, vy: 0, t: 0, t0: e.timeStamp, moved: false, cancelled: false, hist: [[e.timeStamp, e.clientX, e.clientY]], type: e.pointerType };
    if (h.start && h.start(s, e) === false) { s = null; return; }
    try { el.setPointerCapture(e.pointerId); } catch (err) { /* ok */ }
    if (opt.preventDefault !== false && e.pointerType === 'mouse') e.preventDefault();
  };
  const move = e => {
    if (!s || e.pointerId !== s.id) return;
    const [x, y] = local(e);
    s.x = x; s.y = y; s.dx = e.clientX - s.cx0; s.dy = e.clientY - s.cy0; s.t = e.timeStamp - s.t0;
    s.hist.push([e.timeStamp, e.clientX, e.clientY]);
    while (s.hist.length > 2 && e.timeStamp - s.hist[0][0] > 90) s.hist.shift();
    const a = s.hist[0], dtv = (e.timeStamp - a[0]) / 1000;
    if (dtv > 0.004) { s.vx = (e.clientX - a[1]) / dtv; s.vy = (e.clientY - a[2]) / dtv; }
    if (!s.moved && Math.hypot(s.dx, s.dy) > slop) s.moved = true;
    h.move && h.move(s, e);
  };
  const up = (e, cancelled) => {
    if (!s || e.pointerId !== s.id) return;
    const cur = s; s = null;
    cur.cancelled = !!cancelled; cur.t = e.timeStamp - cur.t0;
    if (cur.hist.length && e.timeStamp - cur.hist[cur.hist.length - 1][0] > 70) { cur.vx = 0; cur.vy = 0; } // finger stopped before lifting
    if (!cur.moved && !cancelled && h.tap) h.tap(cur, e);
    h.end && h.end(cur, e);
  };
  el.addEventListener('pointerdown', down);
  el.addEventListener('pointermove', move);
  el.addEventListener('pointerup', e => up(e, false));
  el.addEventListener('pointercancel', e => up(e, true));
  el.addEventListener('lostpointercapture', e => { if (s && e.pointerId === s.id) up(e, true); });
  return { get active() { return !!s; } };
};

/* Pause work for exhibits that scroll out of view (battery). */
FT.visible = (el, cb) => {
  const io = new IntersectionObserver(es => es.forEach(en => cb(en.isIntersecting)), { rootMargin: '120px' });
  io.observe(el);
};

/* Make a custom control keyboard + screen-reader operable in one call. */
FT.slider = (el, { label, min, max, step = 1, get, set, text, big }) => {
  el.setAttribute('role', 'slider'); el.tabIndex = 0;
  el.setAttribute('aria-label', label);
  el.setAttribute('aria-valuemin', min); el.setAttribute('aria-valuemax', max);
  const sync = () => { const v = get(); el.setAttribute('aria-valuenow', Math.round(v * 100) / 100); el.setAttribute('aria-valuetext', text ? text(v) : String(v)); };
  el.addEventListener('keydown', e => {
    let v = get(); const B = big || step * 10;
    const map = { ArrowRight: step, ArrowUp: step, ArrowLeft: -step, ArrowDown: -step, PageUp: B, PageDown: -B };
    if (e.key in map) v += map[e.key]; else if (e.key === 'Home') v = min; else if (e.key === 'End') v = max; else return;
    e.preventDefault(); set(FT.clamp(v, min, max), 'key'); sync(); FT.haptic('select');
  });
  sync();
  return sync;
};

/* ---------- Dart syntax highlighter for the Flutter panes ---------- */
const DART_K = /\b(abstract|as|async|await|break|case|class|const|continue|default|do|double|dynamic|else|enum|extends|final|for|if|implements|import|in|int|is|late|library|mixin|new|null|num|on|override|required|return|static|super|switch|this|throw|true|false|try|var|void|while|with|yield|bool|String|List|Map|Set|get|set)\b/;
FT.dart = src => {
  const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const re = /(\/\/[^\n]*)|('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")|(@\w+)|\b(\d+(?:\.\d+)?)\b|\b([A-Z][A-Za-z0-9_]*)\b|\b([a-z_][A-Za-z0-9_]*)\b/g;
  let out = '', i = 0, m;
  while ((m = re.exec(src))) {
    out += esc(src.slice(i, m.index)); i = re.lastIndex;
    const [w, c, s, at, n, T, id] = m;
    if (c) out += `<span class="c">${esc(c)}</span>`;
    else if (s) out += `<span class="s">${esc(s)}</span>`;
    else if (at) out += `<span class="k">${at}</span>`;
    else if (n) out += `<span class="n">${n}</span>`;
    else if (T) out += DART_K.test(T) ? `<span class="k">${T}</span>` : `<span class="t">${T}</span>`;
    else if (id && DART_K.test(id) && id.match(DART_K)[0] === id) out += `<span class="k">${id}</span>`;
    else out += esc(w);
  }
  return out + esc(src.slice(i));
};

/* ---------- exhibits ---------- */
const defs = [];
const ROMAN = ['', 'I', 'II', 'III'];
FT.exhibit = d => defs.push(d);
FT.build = () => {
  defs.sort((a, b) => a.room - b.room || a.num - b.num);
  for (const d of defs) {
    const list = document.getElementById(`room-${d.room}-list`);
    if (!list) continue;
    const stage = FT.h('div', { class: 'stage', style: { height: (d.height || 360) + 'px' }, role: 'group', 'aria-label': `${d.title}: live demo` });
    const resetBtn = FT.h('button', { class: 'reset', type: 'button' }, 'Reset');
    const plate = FT.h('article', { class: 'plate', id: `ex-${d.id}`, 'data-exhibit': d.title },
      FT.h('div', { class: 'stage-wrap' }, stage,
        FT.h('div', { class: 'stage-bar' }, FT.h('span', { class: 'hint' }, d.hint || ''), resetBtn)),
      FT.h('div', { class: 'plate-text' },
        FT.h('p', { class: 'ex-num' }, FT.h('b', null, `${ROMAN[d.room]}.${d.num}`), d.kind ? FT.h('span', null, d.kind) : null,
          d.replaces ? FT.h('span', { class: 'replaces' }, 'replaces: ' + d.replaces) : null),
        FT.h('h3', null, d.title),
        FT.h('div', { class: 'ex-body', html: d.body }),
        d.why ? FT.h('p', { class: 'ex-why', html: `<b>Principle</b>${d.why}` }) : null,
        d.source ? FT.h('p', { class: 'ex-src', html: `Grounded in: ${d.source}` }) : null,
        FT.h('div', { class: 'ex-more' },
          d.flutter ? FT.h('details', null, FT.h('summary', null, 'Flutter build', FT.h('small', null, 'Dart')), FT.h('pre', { class: 'code' }, FT.h('code', { html: FT.dart(d.flutter.trim()) }))) : null,
          d.a11y ? FT.h('details', null, FT.h('summary', null, 'Keyboard & screen reader'), FT.h('p', { class: 'a11y', html: d.a11y })) : null)));
    list.append(plate);
    let api = null;
    try { api = d.mount(stage, { plate }) || null; }
    catch (err) { console.error(`[${d.id}]`, err); stage.append(FT.h('div', { class: 'ft-center ft-muted' }, 'This exhibit failed to start.')); }
    if (api && api.reset) resetBtn.addEventListener('click', () => { api.reset(); FT.announce(`${d.title} reset`); });
    else resetBtn.hidden = true;
    stage.addEventListener('pointerdown', () => { xray.exhibit = d.title; }, true);
    stage.addEventListener('focusin', () => { xray.exhibit = d.title; });
  }
  setupChrome();
};

/* ---------- X-ray: what the page hears ---------- */
const xray = { on: false, ptrs: new Map(), last: null, exhibit: '', cv: null, ctx: null, notes: [] };
function xrayNote(kind, text) {
  if (!xray.on) return;
  const el = document.getElementById(kind === 'haptic' ? 'hudHaptic' : 'hudIntent');
  if (el) el.textContent = (kind === 'intent' && xray.exhibit ? xray.exhibit + ' → ' : '') + text;
  if (kind === 'haptic' && xray.last) xray.last.pulses.push({ t: performance.now() });
}
function classify(p, now, ended) {
  const dist = Math.hypot(p.x - p.x0, p.y - p.y0);
  const speed = Math.hypot(p.vx, p.vy);
  if (!ended) {
    if (dist < 8) return now - p.t0 > 500 ? 'long-press' : 'press';
    return 'drag' + (Math.abs(p.x - p.x0) > Math.abs(p.y - p.y0) * 1.8 ? ' · horizontal' : Math.abs(p.y - p.y0) > Math.abs(p.x - p.x0) * 1.8 ? ' · vertical' : ' · free');
  }
  if (dist < 8) return now - p.t0 > 500 ? 'long-press · released' : 'tap';
  return speed > 700 ? 'fling' : 'drag · released';
}
function xrayPointer(e) {
  if (!xray.on) return;
  const now = performance.now();
  if (e.type === 'pointerdown') {
    const p = { x: e.clientX, y: e.clientY, x0: e.clientX, y0: e.clientY, t0: now, vx: 0, vy: 0, trail: [[now, e.clientX, e.clientY]], down: true, pulses: [], type: e.pointerType, end: 0 };
    xray.ptrs.set(e.pointerId, p); xray.last = p;
  } else {
    const p = xray.ptrs.get(e.pointerId);
    if (!p || !p.down) return;
    p.trail.push([now, e.clientX, e.clientY]);
    const back = p.trail.filter(q => now - q[0] < 90)[0] || p.trail[0];
    const dts = (now - back[0]) / 1000;
    if (dts > 0.004) { p.vx = (e.clientX - back[1]) / dts; p.vy = (e.clientY - back[2]) / dts; }
    p.x = e.clientX; p.y = e.clientY;
    if (e.type === 'pointerup' || e.type === 'pointercancel') {
      if (now - p.trail[p.trail.length - 2]?.[0] > 70) { p.vx = 0; p.vy = 0; }
      p.down = false; p.end = now; p.label = classify(p, now, true);
    }
  }
}
['pointerdown', 'pointermove', 'pointerup', 'pointercancel'].forEach(t => window.addEventListener(t, xrayPointer, { capture: true, passive: true }));
function xrayFrame(now) {
  const { cv, ctx } = xray;
  if (!cv) return;
  const W = innerWidth, H = innerHeight, dpr = Math.min(2, devicePixelRatio || 1);
  if (cv.width !== Math.round(W * dpr) || cv.height !== Math.round(H * dpr)) { cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr); }
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, W, H);
  const acc = FT.col('--accent'), amb = FT.col('--amber'), ok = FT.col('--ok');
  for (const [id, p] of xray.ptrs) {
    const age = p.down ? 0 : now - p.end;
    if (age > 900) { xray.ptrs.delete(id); continue; }
    const fade = 1 - age / 900;
    // trail
    p.trail = p.trail.filter(q => now - q[0] < 500);
    ctx.lineCap = 'round';
    for (let i = 1; i < p.trail.length; i++) {
      const a = p.trail[i - 1], b = p.trail[i];
      ctx.strokeStyle = FT.alpha(acc, (1 - (now - b[0]) / 500) * fade * 0.9);
      ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(a[1], a[2]); ctx.lineTo(b[1], b[2]); ctx.stroke();
    }
    // finger pad: a 48 dp target ~ 9 mm, the size a fingertip really covers
    ctx.strokeStyle = FT.alpha(acc, 0.55 * fade); ctx.lineWidth = 1.5; ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.arc(p.x, p.y, 24, 0, 7); ctx.stroke(); ctx.setLineDash([]);
    ctx.fillStyle = FT.alpha(acc, 0.9 * fade); ctx.beginPath(); ctx.arc(p.x, p.y, 4, 0, 7); ctx.fill();
    // origin
    ctx.strokeStyle = FT.alpha(acc, 0.35 * fade); ctx.beginPath(); ctx.arc(p.x0, p.y0, 5, 0, 7); ctx.stroke();
    // velocity vector (100 ms look-ahead)
    const sp = Math.hypot(p.vx, p.vy);
    if (sp > 40) {
      const ex = p.x + p.vx * 0.1, ey = p.y + p.vy * 0.1, ang = Math.atan2(p.vy, p.vx);
      ctx.strokeStyle = FT.alpha(amb, fade); ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(ex, ey); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(ex, ey); ctx.lineTo(ex - 9 * Math.cos(ang - 0.45), ey - 9 * Math.sin(ang - 0.45));
      ctx.moveTo(ex, ey); ctx.lineTo(ex - 9 * Math.cos(ang + 0.45), ey - 9 * Math.sin(ang + 0.45)); ctx.stroke();
    }
    // haptic pulses
    p.pulses = p.pulses.filter(q => now - q.t < 450);
    for (const q of p.pulses) {
      const k = (now - q.t) / 450;
      ctx.strokeStyle = FT.alpha(ok, (1 - k) * 0.9); ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(p.x, p.y, 26 + k * 30, 0, 7); ctx.stroke();
    }
    // label
    const label = p.down ? classify(p, now, false) : p.label;
    ctx.font = '600 11px "Geist Mono", ui-monospace, monospace';
    const txt = `${label}  ${Math.round(sp)} px/s`;
    const tw = ctx.measureText(txt).width + 14;
    let lx = p.x + 30, ly = p.y - 44;
    if (lx + tw > W - 8) lx = p.x - 30 - tw;
    if (ly < 8) ly = p.y + 30;
    ctx.fillStyle = FT.alpha(FT.col('--code-bg'), 0.9 * fade);
    ctx.beginPath(); ctx.roundRect ? ctx.roundRect(lx, ly, tw, 22, 6) : ctx.rect(lx, ly, tw, 22); ctx.fill();
    ctx.fillStyle = FT.alpha('#FFFFFF', fade); ctx.fillText(txt, lx + 7, ly + 15);
    if (p === xray.last) {
      document.getElementById('hudGesture').textContent = label + (p.type ? ` (${p.type})` : '');
      document.getElementById('hudVel').textContent = `${Math.round(sp)} px/s` + (sp > 40 ? ` · ${Math.round(Math.atan2(-p.vy, p.vx) * 180 / Math.PI)}°` : '');
    }
  }
  document.getElementById('hudFps').textContent = `${fpsAvg.toFixed(1)} ms / frame`;
}
function setXray(on) {
  xray.on = on;
  document.body.classList.toggle('xray', on);
  ['xrayBtn', 'xrayBtn2'].forEach(id => { const b = document.getElementById(id); if (b) b.setAttribute('aria-pressed', on); });
  const b2 = document.getElementById('xrayBtn2'); if (b2) b2.textContent = on ? 'Turn off X-ray' : 'Turn on X-ray';
  if (on) { FT.tick(() => xray.on); FT.announce('X-ray on: touch areas outlined, gestures and haptics shown'); }
  else { xray.ctx && xray.ctx.clearRect(0, 0, xray.cv.width, xray.cv.height); FT.announce('X-ray off'); }
}

/* ---------- page chrome: theme, x-ray, nav highlight ---------- */
function setupChrome() {
  xray.cv = document.getElementById('xrayCanvas');
  xray.ctx = xray.cv && xray.cv.getContext('2d');
  ['xrayBtn', 'xrayBtn2'].forEach(id => { const b = document.getElementById(id); b && b.addEventListener('click', () => setXray(!xray.on)); });
  const tb = document.getElementById('themeBtn');
  const order = ['system', 'light', 'dark'];
  let mode = 'system';
  try { mode = localStorage.getItem('ft-theme') || 'system'; } catch (e) { /* storage blocked */ }
  if (!order.includes(mode)) mode = 'system';
  const apply = () => {
    if (mode === 'system') delete root.dataset.theme; else root.dataset.theme = mode;
    tb.setAttribute('aria-label', `Theme: ${mode}. Change theme`);
    tb.title = `Theme: ${mode}`;
  };
  if (mode !== 'system') apply(); else tb.setAttribute('aria-label', 'Theme: system. Change theme');
  tb.addEventListener('click', () => {
    mode = order[(order.indexOf(mode) + 1) % 3]; apply();
    try { localStorage.setItem('ft-theme', mode); } catch (e) { /* ignore */ }
    FT.announce(`Theme ${mode}`);
  });
  document.querySelectorAll('.blueprint pre.code code').forEach(c => { c.innerHTML = FT.dart(c.textContent); });
  // The comparison table measures this page live, so its numbers can't drift from the code.
  const plates = document.querySelectorAll('.plates');
  const count = sel => [...plates].reduce((n, p) => n + p.querySelectorAll(sel).length, 0);
  const put = (k, txt) => { const td = document.querySelector(`[data-count="${k}"]`); if (td) td.textContent = txt; };
  put('tabindex', `${count('.stage [tabindex], .stage button, .stage input, .stage select, .stage textarea')} in the demos, counted live`);
  put('role', `${count('.stage [role]')}, counted live`);
  const dl = defs.filter(d => d.flutter).map(d => d.flutter.trim().split('\n').filter(l => l.trim()).length);
  if (dl.length) put('dart', `${Math.round(dl.reduce((a, b) => a + b, 0) / dl.length)} lines of Dart on average`);
  const links = [...document.querySelectorAll('.rooms-nav a')];
  const secs = links.map(a => document.querySelector(a.getAttribute('href'))).filter(Boolean);
  const io = new IntersectionObserver(es => {
    es.forEach(en => { if (en.isIntersecting) links.forEach(a => a.classList.toggle('on', a.getAttribute('href') === '#' + en.target.id)); });
  }, { rootMargin: '-40% 0px -55% 0px' });
  secs.forEach(s => io.observe(s));
}
})();
