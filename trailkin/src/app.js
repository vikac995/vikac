/* Trailkin app: state + economy, trail map, journal, lantern, reward overlays, walk simulator. */
(() => {
'use strict';
const { h, clamp, lerp, fmt } = TK;
const screen = document.getElementById('screen');

/* ---------- species access (creatures.js provides TK.SPECIES + TK.drawKin) ---------- */
const SPECIES = () => TK.SPECIES || [];
const sp = id => SPECIES().find(s => s.id === id) || { id, name: id, tier: 'common', blurb: '' };
const drawKin = (ctx, id, x, y, size, t, o) => {
  if (TK.drawKin) return TK.drawKin(ctx, id, x, y, size, t, o || {});
  ctx.fillStyle = o && o.silhouette ? '#2a3a33' : '#6cbf7a'; ctx.beginPath(); ctx.ellipse(x, y - size / 2, size * 0.42, size / 2, 0, 0, 7); ctx.fill();
};
const tierColor = t => (TK.tierColor ? TK.tierColor(t) : ({ common: '#5E9B6E', uncommon: '#3E8FC4', rare: '#7656D1', elusive: '#D69A1C' })[t] || '#888');
const TIER_HINT = {
  common: 'Anywhere on the trail',
  uncommon: 'Past half your daily goal',
  rare: 'Waits at the summit when you reach your goal',
  elusive: 'Past 125% of your goal, or a Sunday visitor',
};

/* ---------- the economy: every number the game uses lives here ---------- */
const RULES = {
  spawnEvery: 700,                  // steps per encounter
  kcalPerNest: 40,                  // active kcal per woven nest
  maxWaiting: 6,                    // kin wait on the trail, never expire
  wayFractions: [0.0625, 0.15, 0.25, 0.375, 0.5, 0.625, 0.775, 1], // front-loaded: early stops come quickly
  elusiveAt: 1.25,
  emberGoal: 5,                     // lit embers in a week to welcome the Sunday visitor
};
const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const SHORT = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
let rnd = TK.rng(20261117);
const todayIdx = () => (new Date().getDay() + 6) % 7;

function fresh() {
  const t = todayIdx();
  const hist = ['lit', 'lit', 'rested', 'lit', 'snuffed', 'lit'];
  return {
    goal: 8000, steps: 4820, kcal: 212, nestsUsed: 2, nestsBonus: 0,
    spawned: 6, waiting: [], cracked: 4, goalRare: false, elusiveSeen: false,
    caught: {}, order: [], fresh: new Set(), buddy: 'mossbit', lure: false, stroll: null,
    walking: false, week: DAYS.map((_, i) => i < t ? hist[i] : i === t ? 'today' : 'future'), today: t, restLeft: t > 2 ? 0 : 1, emberLitToday: false,
    hints: new Set(), view: 'trail',
  };
}
let S = fresh();
function seedDemo() {
  rnd = TK.rng(20261117);
  const now = new Date(), day = (d) => { const x = new Date(now); x.setDate(x.getDate() - d); return x; };
  [['mossbit', 1, 2100, 'Great'], ['puddlepip', 1, 3400, 'Nice'], ['pebblet', 2, 900, 'Perfect'], ['burrowbun', 0, 2800, 'Great']].forEach(([id, d, at, best]) => {
    S.caught[id] = { at, when: day(d), best }; S.order.push(id);
  });
  S.waiting = [{ id: 'thistlehop', at: 4200, k: 1 }, { id: 'emberkit', at: 4760, k: 2 }];
}
seedDemo();

const nests = () => Math.max(0, Math.floor(S.kcal / RULES.kcalPerNest) + S.nestsBonus - S.nestsUsed);
const kcalToNext = () => RULES.kcalPerNest - (S.kcal % RULES.kcalPerNest);
const ways = () => RULES.wayFractions.map(f => Math.round(f * S.goal / 50) * 50);
const reachedWays = steps => ways().filter(w => steps >= w).length;
const pool = tier => SPECIES().filter(s => s.tier === tier).map(s => s.id);

function pick(progress) {
  let tier = 'common';
  const r = rnd();
  if (S.lure) { tier = r < 0.8 ? 'uncommon' : 'rare'; S.lure = false; }
  else if (progress >= 1) tier = r < 0.15 ? 'rare' : r < 0.6 ? 'uncommon' : 'common';
  else if (progress >= 0.5) tier = r < 0.35 ? 'uncommon' : 'common';
  const ids = pool(tier);
  if (!ids.length) return 'mossbit';
  // gently favour kin you haven't met, so the journal keeps filling
  const weighted = ids.flatMap(id => S.caught[id] ? [id] : [id, id, id]);
  return weighted[Math.floor(rnd() * weighted.length)];
}
let kSeq = 10;
/* Returns events for the step-in animation; mutates S. */
function addActivity(dSteps, dKcal) {
  const before = { steps: S.steps, nests: nests(), ways: reachedWays(S.steps) };
  S.steps += dSteps; S.kcal += dKcal;
  const spawns = [];
  while ((S.spawned + 1) * RULES.spawnEvery <= S.steps) {
    S.spawned++;
    const at = S.spawned * RULES.spawnEvery;
    if (S.waiting.length >= RULES.maxWaiting) continue; // the trail is full; nothing is lost, they just don't crowd you
    const e = { id: pick(at / S.goal), at, k: kSeq++ };
    S.waiting.push(e); spawns.push(e);
  }
  let goalCrossed = false;
  if (before.steps < S.goal && S.steps >= S.goal && !S.goalRare) {
    S.goalRare = true; goalCrossed = true;
    const rares = pool('rare'); const id = rares.find(r => !S.caught[r]) || rares[Math.floor(rnd() * rares.length)] || 'mossbit';
    const e = { id, at: S.goal, k: kSeq++, summit: true };
    S.waiting.push(e); spawns.push(e);
  }
  if (S.steps >= S.goal * RULES.elusiveAt && !S.elusiveSeen) {
    S.elusiveSeen = true;
    const el = pool('elusive')[0];
    if (el) { const e = { id: el, at: Math.round(S.goal * RULES.elusiveAt), k: kSeq++ }; S.waiting.push(e); spawns.push(e); }
  }
  return { before, spawns, goalCrossed, newNests: nests() - before.nests };
}

/* ---------- screen chrome ---------- */
const status = h('div', { class: 'g-status', 'aria-hidden': 'true' }, h('span', { id: 'gClock' }), h('span', null, '5G ▮▮▮ 84%'));
const vTrail = h('div', { class: 'g-view', id: 'vTrail', role: 'tabpanel', 'aria-label': 'Trail' });
const vJournal = h('div', { class: 'g-view', id: 'vJournal', role: 'tabpanel', 'aria-label': 'Journal', hidden: true });
const vLantern = h('div', { class: 'g-view', id: 'vLantern', role: 'tabpanel', 'aria-label': 'Lantern', hidden: true });
const ICON = {
  trail: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M7 21c0-4 10-4 10-8s-8-3-8-7 4-3 6-3"/><circle cx="15" cy="3.5" r="1.5" fill="currentColor"/></svg>',
  journal: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3z"/><path d="M5 17a3 3 0 0 1 3-3h11"/></svg>',
  lantern: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M9 3h6M10 3v2M14 3v2M7 8l2-3h6l2 3v10l-2 3H9l-2-3z"/><path d="M12 11c1.6 1.6 1.6 3.4 0 4.6-1.6-1.2-1.6-3 0-4.6z" fill="currentColor"/></svg>',
};
const tabs = h('div', { class: 'g-tabs', role: 'tablist', 'aria-label': 'Trailkin sections' });
const tabBtn = {};
[['trail', 'Trail'], ['journal', 'Journal'], ['lantern', 'Lantern']].forEach(([k, label]) => {
  const b = h('button', { class: 'g-tab', type: 'button', role: 'tab', 'aria-selected': k === 'trail' ? 'true' : 'false', 'aria-controls': 'v' + label, html: ICON[k] + `<span>${label}</span><span class="g-badge" hidden></span>` });
  b.addEventListener('click', () => show(k));
  tabs.append(b); tabBtn[k] = b;
});
const body = h('div', { style: { position: 'absolute', inset: '0', display: 'flex', flexDirection: 'column' } }, h('div', { style: { position: 'relative', flex: '1', minHeight: '0' } }, vTrail, vJournal, vLantern), tabs);
screen.append(body, status);
const badge = (k, n) => { const b = tabBtn[k].querySelector('.g-badge'); b.hidden = !n; b.textContent = n || ''; };
function show(k) {
  S.view = k;
  vTrail.hidden = k !== 'trail'; vJournal.hidden = k !== 'journal'; vLantern.hidden = k !== 'lantern';
  for (const key in tabBtn) tabBtn[key].setAttribute('aria-selected', key === k ? 'true' : 'false');
  if (k === 'journal') renderJournal();
  if (k === 'lantern') renderLantern();
  if (k === 'trail') trailLoop.wake();
  TK.haptic('select');
}
const clockTick = () => { const d = new Date(); document.getElementById('gClock').textContent = d.toTimeString().slice(0, 5); };
clockTick(); setInterval(clockTick, 15000);

/* Sky by real local time of day. */
function skyColors() {
  const hr = new Date().getHours() + new Date().getMinutes() / 60;
  if (hr < 6 || hr >= 21) return ['#26325E', '#55618F', '#2E4A44'];
  if (hr < 8) return ['#F6C7A8', '#B9DDF0', '#7DB98A'];
  if (hr < 17) return ['#8FD0F0', '#D2EEF7', '#8CCB85'];
  if (hr < 19.5) return ['#F2B38A', '#F7DDB2', '#86BC7E'];
  return ['#6E6AA8', '#E8A9A0', '#5E9A72'];
}
const night = () => { const hr = new Date().getHours(); return hr < 6 || hr >= 21; };

/* ================= TRAIL ================= */
const head = h('div', { class: 'g-head' });
const dayEl = h('div', { class: 'g-day' });
const stepsEl = h('div', { class: 'g-steps', 'aria-live': 'off' });
const ofEl = h('div', { class: 'g-of' });
const strollEl = h('div', { class: 'g-of', style: { color: '#7A4C00', marginTop: '4px' }, hidden: true });
const lanternPill = h('button', { class: 'g-pill', type: 'button', 'aria-label': 'Open this week\'s lantern' });
lanternPill.addEventListener('click', () => show('lantern'));
head.append(h('div', null, dayEl, stepsEl, ofEl, strollEl), lanternPill);
const bar = h('div', { class: 'g-bar', role: 'progressbar', 'aria-valuemin': '0' }, h('i'));
const trailBox = h('div', { class: 'g-trail' });
const dockN = h('div', { class: 'g-res' }), dockW = h('div', { class: 'g-res' });
const dock = h('div', { class: 'g-dock' }, dockN, dockW);
vTrail.append(head, bar, trailBox, dock);
const hits = h('div', { style: { position: 'absolute', inset: '0' } });
let shown = S.steps, shownKcal = S.kcal;
const tc = TK.canvas(trailBox, () => { scenery = null; layoutHits(); trailLoop.wake(); });
trailBox.append(hits);
let scenery = null;

function pathPt(u, W, H) {
  const top = 54, bot = H - 30;
  return [W / 2 + Math.sin(u * Math.PI * 2.35 + 0.35) * W * 0.27, bot - u * (bot - top)];
}
function uOf(steps) {
  const T = [0, ...ways()]; const n = T.length - 1;
  if (steps >= T[n]) return 1;
  let k = 0; while (steps >= T[k + 1]) k++;
  return (k + (steps - T[k]) / (T[k + 1] - T[k])) / n;
}
function bushPos(e, W, H) {
  if (e.summit) { const [x, y] = pathPt(1, W, H); return [Math.min(x + 44, W - 30), y + 6]; }
  const u = uOf(e.at); const [x, y] = pathPt(u, W, H);
  const side = (e.k % 2 ? 1 : -1);
  return [clamp(x + side * 40, 26, W - 26), y + 4];
}
function buildScenery(W, H) {
  const r = TK.rng(99); const tufts = [], flowers = [], trees = [];
  for (let i = 0; i < 70; i++) tufts.push([r() * W, 20 + r() * (H - 20), 0.6 + r() * 0.8]);
  for (let i = 0; i < 26; i++) flowers.push([r() * W, 30 + r() * (H - 40), Math.floor(r() * 3)]);
  for (let i = 0; i < 7; i++) { const left = i % 2 === 0; trees.push([left ? 8 + r() * 30 : W - 8 - r() * 30, 40 + (i / 7) * (H - 60) + r() * 20, 18 + r() * 10]); }
  return { tufts, flowers, trees };
}

function layoutHits() {
  hits.innerHTML = '';
  const W = tc.w, H = tc.h;
  S.waiting.forEach(e => {
    if (e.at > shown && !e.summit) return;
    if (e.summit && shown < S.goal) return;
    const [x, y] = bushPos(e, W, H);
    const b = h('button', { class: 'g-hit', type: 'button', style: { left: x + 'px', top: (y - 14) + 'px' }, 'aria-label': `A kin is rustling in a bush${e.summit ? ' at the summit' : ''}. Open the encounter` });
    b.addEventListener('click', () => openEncounter(e));
    hits.append(b);
  });
  const W8 = ways();
  W8.forEach((w, i) => {
    if (shown < w || i < S.cracked) return;
    const [x, y] = pathPt((i + 1) / W8.length, W, H);
    const b = h('button', { class: 'g-hit', type: 'button', style: { left: x + 'px', top: (y - 10) + 'px' }, 'aria-label': `Waystone at ${fmt(w)} steps is ready. Crack it open` });
    b.addEventListener('click', () => openCrack(i));
    hits.append(b);
  });
  if (shown < S.goal) {
    const [x, y] = pathPt(1, W, H);
    const b = h('button', { class: 'g-hit', type: 'button', style: { left: Math.min(x + 44, W - 30) + 'px', top: (y - 10) + 'px' }, 'aria-label': `A rare kin waits at the summit, ${fmt(S.goal - shown)} steps away` });
    b.addEventListener('click', () => toast(`A rare kin waits at the summit. ${fmt(S.goal - shown)} steps to go.`));
    hits.append(b);
  }
}

let bushPop = new Map();   // encounter key → spawn time (for pop-in)
let wayPop = new Map();    // waystone index → light-up time
function drawTrail(t) {
  const { ctx, w: W, h: H } = tc;
  if (!scenery) scenery = buildScenery(W, H);
  ctx.clearRect(0, 0, W, H);
  const dark = night();
  // meadow
  const g = ctx.createLinearGradient(0, 0, 0, H);
  g.addColorStop(0, dark ? '#2F5249' : '#A9DB9A'); g.addColorStop(1, dark ? '#1F3832' : '#7FC07A');
  ctx.fillStyle = g; ctx.beginPath(); ctx.roundRect ? ctx.roundRect(8, 0, W - 16, H, 26) : ctx.rect(8, 0, W - 16, H); ctx.fill();
  ctx.save(); ctx.beginPath(); ctx.roundRect ? ctx.roundRect(8, 0, W - 16, H, 26) : ctx.rect(8, 0, W - 16, H); ctx.clip();
  for (const [x, y, s] of scenery.tufts) {
    ctx.strokeStyle = dark ? 'rgba(160,220,180,.18)' : 'rgba(40,110,60,.28)'; ctx.lineWidth = 1.4; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(x - 3 * s, y); ctx.lineTo(x - 4 * s, y - 6 * s); ctx.moveTo(x, y); ctx.lineTo(x, y - 8 * s); ctx.moveTo(x + 3 * s, y); ctx.lineTo(x + 4.5 * s, y - 5.5 * s); ctx.stroke();
  }
  const FC = ['#FFFFFF', '#FFD24D', '#F59BB8'];
  for (const [x, y, c] of scenery.flowers) { ctx.fillStyle = FC[c]; ctx.globalAlpha = dark ? 0.5 : 0.9; for (let k = 0; k < 5; k++) { const a = k / 5 * 6.283; ctx.beginPath(); ctx.arc(x + Math.cos(a) * 2.2, y + Math.sin(a) * 2.2, 1.6, 0, 7); ctx.fill(); } ctx.globalAlpha = 1; ctx.fillStyle = '#F2A12E'; ctx.beginPath(); ctx.arc(x, y, 1.3, 0, 7); ctx.fill(); }
  // path
  const N = 120, pts = []; for (let i = 0; i <= N; i++) pts.push(pathPt(i / N, W, H));
  const stroke = (from, to, width, color, dash) => {
    ctx.beginPath(); ctx.lineWidth = width; ctx.strokeStyle = color; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.setLineDash(dash || []);
    for (let i = Math.floor(from * N); i <= Math.ceil(to * N); i++) { const p = pts[clamp(i, 0, N)]; i === Math.floor(from * N) ? ctx.moveTo(p[0], p[1]) : ctx.lineTo(p[0], p[1]); }
    ctx.stroke(); ctx.setLineDash([]);
  };
  const u = uOf(shown);
  stroke(0, 1, 26, dark ? 'rgba(0,0,0,.25)' : 'rgba(90,70,30,.18)');
  stroke(0, 1, 20, dark ? '#4B5B4F' : '#EADBB4');
  stroke(0, 1, 2, dark ? 'rgba(255,255,255,.25)' : 'rgba(120,90,40,.35)', [3, 9]);
  if (u > 0) { stroke(0, u, 20, dark ? '#C9A85A' : '#F6CF73'); stroke(0, u, 6, dark ? 'rgba(255,240,200,.5)' : 'rgba(255,255,255,.65)'); }
  // trees
  for (const [x, y, r] of scenery.trees) {
    ctx.fillStyle = 'rgba(0,0,0,.12)'; ctx.beginPath(); ctx.ellipse(x, y + r * 0.9, r * 0.8, r * 0.25, 0, 0, 7); ctx.fill();
    ctx.fillStyle = dark ? '#3D6650' : '#4E9E5E'; ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.fill();
    ctx.fillStyle = dark ? '#4B7A60' : '#67B871'; ctx.beginPath(); ctx.arc(x - r * 0.3, y - r * 0.3, r * 0.6, 0, 7); ctx.fill();
  }
  // home marker
  const [hx, hy] = pathPt(0, W, H);
  ctx.fillStyle = '#FFFDF8'; ctx.beginPath(); ctx.arc(hx, hy, 9, 0, 7); ctx.fill();
  ctx.fillStyle = '#23806F'; ctx.font = '700 9px Nunito Sans, sans-serif'; ctx.textAlign = 'center'; ctx.fillText('0', hx, hy + 3);
  // waystones
  const W8 = ways();
  W8.forEach((w, i) => {
    const [x, y] = pathPt((i + 1) / W8.length, W, H);
    const reached = shown >= w, cracked = i < S.cracked, last = i === W8.length - 1;
    if (last) return;
    const pop = wayPop.get(i); let sc = 1;
    if (pop != null) { const k = (t - pop) / 0.5; sc = k < 1 ? 1 + Math.sin(k * Math.PI) * 0.45 : 1; }
    ctx.save(); ctx.translate(x, y); ctx.scale(sc, sc);
    if (reached && !cracked) {
      const gl = 0.5 + 0.5 * Math.sin(t * 4 + i);
      ctx.fillStyle = `rgba(255,214,90,${0.25 + gl * 0.35})`; ctx.beginPath(); ctx.arc(0, -6, 17 + gl * 3, 0, 7); ctx.fill();
    }
    ctx.fillStyle = 'rgba(0,0,0,.18)'; ctx.beginPath(); ctx.ellipse(0, 3, 10, 3.5, 0, 0, 7); ctx.fill();
    ctx.fillStyle = reached ? (cracked ? '#B9C2B4' : '#F7E7B8') : (dark ? '#6E7C72' : '#9EAB9C');
    ctx.beginPath(); ctx.moveTo(-8, 3); ctx.quadraticCurveTo(-10, -12, 0, -16); ctx.quadraticCurveTo(10, -12, 8, 3); ctx.closePath(); ctx.fill();
    ctx.strokeStyle = 'rgba(40,40,30,.25)'; ctx.lineWidth = 1; ctx.stroke();
    if (reached && !cracked) { ctx.fillStyle = '#E58A00'; ctx.font = '800 11px Nunito Sans, sans-serif'; ctx.textAlign = 'center'; ctx.fillText('!', 0, -3); }
    else if (cracked) { ctx.strokeStyle = '#5E9B6E'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(-3.5, -6); ctx.lineTo(-0.5, -3); ctx.lineTo(4, -9); ctx.stroke(); }
    ctx.restore();
    ctx.fillStyle = dark ? 'rgba(230,240,230,.7)' : 'rgba(27,42,35,.55)'; ctx.font = '700 9.5px Nunito Sans, sans-serif';
    const lx = x + (Math.cos((i + 1) / W8.length * Math.PI * 2.35 + 0.35) > 0 ? -22 : 22);
    ctx.textAlign = 'center'; ctx.fillText(w >= 1000 ? (w / 1000).toFixed(w % 1000 ? 1 : 0) + 'k' : String(w), lx, y - 2);
  });
  // summit
  const [sx, sy] = pathPt(1, W, H);
  ctx.fillStyle = 'rgba(0,0,0,.18)'; ctx.beginPath(); ctx.ellipse(sx, sy + 4, 18, 5, 0, 0, 7); ctx.fill();
  ctx.fillStyle = '#6B5A3E'; ctx.fillRect(sx - 1.5, sy - 34, 3, 36);
  const lit = shown >= S.goal;
  if (lit) { const gl = ctx.createRadialGradient(sx, sy - 34, 0, sx, sy - 34, 34); gl.addColorStop(0, 'rgba(255,200,80,.75)'); gl.addColorStop(1, 'rgba(255,200,80,0)'); ctx.fillStyle = gl; ctx.beginPath(); ctx.arc(sx, sy - 34, 34, 0, 7); ctx.fill(); }
  ctx.fillStyle = lit ? '#FFC94D' : '#E9E2CF'; ctx.strokeStyle = '#6B5A3E'; ctx.lineWidth = 1.5;
  ctx.beginPath(); ctx.roundRect ? ctx.roundRect(sx - 7, sy - 44, 14, 16, 4) : ctx.rect(sx - 7, sy - 44, 14, 16); ctx.fill(); ctx.stroke();
  ctx.fillStyle = dark ? 'rgba(230,240,230,.85)' : 'rgba(27,42,35,.7)'; ctx.font = '800 10px Nunito Sans, sans-serif'; ctx.textAlign = 'center';
  ctx.fillText(fmt(S.goal), sx - 30, sy - 30);
  // summit kin: silhouette while you're still climbing
  const sumE = S.waiting.find(e => e.summit);
  if (!lit) {
    const rid = pool('rare').find(r => !S.caught[r]) || pool('rare')[0];
    if (rid) { const kx = Math.min(sx + 44, W - 30); drawKin(ctx, rid, kx, sy + 8, 34, t, { silhouette: true, alpha: 0.75 }); ctx.fillStyle = '#FFFDF8'; ctx.font = '800 13px Fredoka, sans-serif'; ctx.fillText('?', kx, sy - 10); }
  }
  // bushes with waiting kin
  for (const e of S.waiting) {
    if (e.summit ? shown < S.goal : e.at > shown) continue;
    if (!bushPop.has(e.k)) bushPop.set(e.k, t);
    const [bx, by] = bushPos(e, W, H);
    const age = t - bushPop.get(e.k);
    const pop = age < 0.5 ? TK.ease(age / 0.5) * (1 + Math.sin(age / 0.5 * Math.PI) * 0.3) : 1;
    const rustle = Math.sin(t * 9 + e.k) * (Math.sin(t * 0.9 + e.k * 1.7) > 0.55 ? 0.12 : 0.02);
    ctx.save(); ctx.translate(bx, by); ctx.scale(pop, pop); ctx.rotate(rustle);
    ctx.fillStyle = 'rgba(0,0,0,.18)'; ctx.beginPath(); ctx.ellipse(0, 0, 18, 5, 0, 0, 7); ctx.fill();
    const bc = e.summit ? ['#6E58C9', '#8C77E0'] : [dark ? '#2F6B4D' : '#3F9A57', dark ? '#3C805D' : '#56B46A'];
    ctx.fillStyle = bc[0]; [[-9, -9, 10], [9, -9, 10], [0, -15, 12]].forEach(([x, y, r]) => { ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.fill(); });
    ctx.fillStyle = bc[1]; [[-6, -13, 6], [6, -16, 6]].forEach(([x, y, r]) => { ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.fill(); });
    // peeking eyes that blink
    const blink = (t * 0.7 + e.k * 0.37) % 3 < 0.12;
    ctx.fillStyle = '#1B2A23';
    if (blink) { ctx.fillRect(-6, -11, 4, 1.4); ctx.fillRect(2, -11, 4, 1.4); }
    else { ctx.beginPath(); ctx.arc(-4, -11, 2.4, 0, 7); ctx.arc(4, -11, 2.4, 0, 7); ctx.fill(); ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(-3.3, -11.8, 0.9, 0, 7); ctx.arc(4.7, -11.8, 0.9, 0, 7); ctx.fill(); }
    ctx.restore();
  }
  // buddy walks the trail
  const [px, py] = pathPt(u, W, H);
  const [qx] = pathPt(Math.min(1, u + 0.01), W, H);
  const walkingAnim = Math.abs(shown - S.steps) > 1;
  const bob = walkingAnim ? Math.abs(Math.sin(t * 12)) * 4 : Math.sin(t * 2) * 1.2;
  ctx.fillStyle = 'rgba(0,0,0,.2)'; ctx.beginPath(); ctx.ellipse(px, py + 2, 13, 4, 0, 0, 7); ctx.fill();
  drawKin(ctx, S.buddy, px, py - bob, 36, t, { mood: walkingAnim ? 'happy' : 'idle', facing: qx >= px ? 1 : -1 });
  ctx.restore();
}

function renderHead() {
  const d = new Date();
  dayEl.textContent = `${DAYS[S.today]} · ${d.toTimeString().slice(0, 5)}`;
  stepsEl.textContent = fmt(shown);
  const left = S.goal - shown;
  ofEl.textContent = left > 0 ? `of ${fmt(S.goal)} steps · ${fmt(left)} to the summit` : `Summit reached · ${fmt(shown - S.goal)} past your goal`;
  bar.firstChild.style.width = Math.min(100, shown / S.goal * 100) + '%';
  bar.setAttribute('aria-valuemax', S.goal); bar.setAttribute('aria-valuenow', Math.round(shown));
  bar.setAttribute('aria-label', `${fmt(shown)} of ${fmt(S.goal)} steps`);
  [...bar.querySelectorAll('b')].forEach(b => b.remove());
  ways().slice(0, -1).forEach(w => bar.append(h('b', { style: { left: (w / S.goal * 100) + '%' } })));
  const litN = S.week.filter(x => x === 'lit').length;
  lanternPill.innerHTML = `<svg width="14" height="16" viewBox="0 0 14 16" aria-hidden="true"><path d="M7 1c3 3 5 6 5 9a5 5 0 0 1-10 0c0-2 1-3 2-4 0 2 1 3 2 3 0-3-1-5 1-8z" fill="#F2A12E"/></svg>${litN} of 7 lit`;
  if (S.stroll) {
    const rem = Math.max(0, S.stroll.until - Date.now());
    strollEl.hidden = false; strollEl.textContent = `Stroll with ${sp(S.buddy).name} · ${Math.ceil(rem / 60000)} min left · next kin is uncommon`;
    if (!rem) { S.stroll = null; strollEl.hidden = true; }
  } else strollEl.hidden = true;
  const n = nests();
  dockN.innerHTML = `<small>Nests</small><b>${n}</b><span>${fmt(kcalToNext())} kcal to the next one</span>`;
  const vis = S.waiting.filter(e => e.summit ? shown >= S.goal : e.at <= shown).length;
  dockW.innerHTML = `<small>On the trail</small><b>${vis}</b><span>${vis ? (vis === 1 ? 'kin waiting for you' : 'kin waiting for you') : 'next in ' + fmt(RULES.spawnEvery - (Math.round(shown) % RULES.spawnEvery)) + ' steps'}</span>`;
}

/* Trail loop: idle life + the step-in animation (shown → S.steps). */
let stepAnim = null;
const trailLoop = TK.loop((dt, now) => {
  const t = now / 1000;
  if (stepAnim) {
    const k = clamp((now - stepAnim.t0) / stepAnim.dur, 0, 1), e = TK.ease(k);
    const prev = shown;
    shown = lerp(stepAnim.from, S.steps, e); shownKcal = lerp(stepAnim.kFrom, S.kcal, e);
    ways().forEach((w, i) => { if (prev < w && shown >= w && i < ways().length - 1) { wayPop.set(i, t); TK.haptic('select'); TK.sfx('tick'); } });
    S.waiting.forEach(e2 => { if (!e2.summit && prev < e2.at && shown >= e2.at) { TK.sfx('pop'); TK.haptic('light'); } });
    if (k >= 1) { const done = stepAnim.done; stepAnim = null; shown = S.steps; layoutHits(); done && done(); }
    renderHead();
  }
  if (!vTrail.hidden) drawTrail(t);
  return phoneVisible && (!vTrail.hidden || stepAnim);
});
let phoneVisible = true;
new IntersectionObserver(es => { phoneVisible = es[0].isIntersecting; if (phoneVisible) trailLoop.wake(); }).observe(screen);

function stepIn(dSteps, dKcal, label) {
  const from = shown, kFrom = shownKcal;
  const ev = addActivity(dSteps, dKcal);
  syncSim();
  if (label) toast(`${label}: +${fmt(dSteps)} steps · +${fmt(dKcal)} kcal${ev.newNests > 0 ? ` · ${ev.newNests === 1 ? 'a new nest' : ev.newNests + ' new nests'} woven` : ''}`);
  if (S.view !== 'trail') show('trail');
  stepAnim = { from, kFrom, t0: performance.now(), dur: TK.reduced() ? 60 : clamp(600 + dSteps * 0.55, 700, 2600), done: () => {
    if (ev.newNests > 0) pulse(dockN);
    if (ev.goalCrossed) setTimeout(openGoal, 350);
    TK.announce(`${fmt(S.steps)} steps. ${ev.spawns.length ? ev.spawns.length + ' new kin on the trail. ' : ''}${nests()} nests.`);
  } };
  trailLoop.wake();
}
function pulse(el) { el.animate([{ transform: 'scale(1)' }, { transform: 'scale(1.08)' }, { transform: 'scale(1)' }], { duration: 420, easing: 'cubic-bezier(.3,1.6,.5,1)' }); }

/* ---------- small toast inside the phone ---------- */
let toastEl = null, toastT;
function toast(msg) {
  if (toastEl) toastEl.remove();
  toastEl = h('div', { role: 'status', style: { position: 'absolute', left: '14px', right: '14px', bottom: '96px', zIndex: '15', background: '#1B2A23', color: '#fff', borderRadius: '18px', padding: '12px 16px', font: '700 14px var(--f-body)', boxShadow: '0 12px 30px -10px rgba(0,0,0,.5)' } }, msg);
  screen.append(toastEl);
  toastEl.animate([{ transform: 'translateY(30px)', opacity: 0 }, { transform: 'translateY(0)', opacity: 1 }], { duration: 380, easing: 'cubic-bezier(.2,1.4,.4,1)' });
  clearTimeout(toastT);
  const el = toastEl;
  toastT = setTimeout(() => { el.animate([{ opacity: 1 }, { opacity: 0, transform: 'translateY(16px)' }], { duration: 300 }).onfinish = () => el.remove(); }, 2800);
}

/* ---------- layers (overlays) ---------- */
let layerOpen = null;
function layer(content, { onClose, scrim = true } = {}) {
  const L = h('div', { class: 'g-layer', role: 'dialog', 'aria-modal': 'true' });
  if (scrim) { const sc = h('div', { class: 'g-scrim' }); L.append(sc); sc.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 250 }); }
  L.append(content); screen.append(L);
  const prevFocus = document.activeElement;
  const close = (v) => {
    if (!L.isConnected) return;
    L.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 180 }).onfinish = () => L.remove();
    layerOpen = null; onClose && onClose(v);
    if (prevFocus && prevFocus.isConnected) prevFocus.focus({ preventScroll: true });
  };
  L.addEventListener('keydown', e => { if (e.key === 'Escape') { e.preventDefault(); close(); } });
  layerOpen = { close };
  setTimeout(() => { const f = L.querySelector('button, [tabindex]'); f && f.focus({ preventScroll: true }); }, 60);
  return { L, close };
}

/* ================= ENCOUNTER ================= */
function openEncounter(e) {
  if (layerOpen) layerOpen.close();
  const o = {
    species: e.id, stepsToday: Math.round(S.steps),
    getNests: () => nests(),
    useNest: () => { if (nests() <= 0) return false; S.nestsUsed++; renderHead(); return true; },
    walking: () => S.walking,
    onClose: res => {
      if (res && res.caught) {
        const first = !S.caught[e.id];
        S.caught[e.id] = { at: Math.round(S.steps), when: new Date(), best: res.best || 'Nice' };
        if (first) { S.order.push(e.id); S.fresh.add(e.id); }
        S.waiting = S.waiting.filter(x => x.k !== e.k);
        bushPop.delete(e.k);
        badge('journal', S.fresh.size);
        if (first) setTimeout(() => tabBtn.journal.animate([{ transform: 'translateY(0)' }, { transform: 'translateY(-8px)' }, { transform: 'translateY(0)' }], { duration: 500, easing: 'cubic-bezier(.3,1.6,.5,1)' }), 200);
      }
      layoutHits(); renderHead(); trailLoop.wake();
    },
  };
  if (TK.encounter) { TK.encounter.open(screen, o); return; }
  // Fallback if the encounter module failed to load: keep the game playable.
  const s = sp(e.id);
  const { close } = layer(h('div', { class: 'g-sheet' }, h('p', { class: 'g-title' }, s.name), h('p', { class: 'g-sub' }, 'The throwing scene could not load.'),
    h('button', { class: 'g-btn', type: 'button', style: { marginTop: '12px' }, onclick: () => { if (o.useNest()) { close(); o.onClose({ caught: true, species: e.id, throws: 1, best: 'Nice' }); } } }, 'Throw a nest')), {});
}

/* ================= WAYSTONE CRACK ================= */
const REWARDS = [
  { p: 0.45, key: 'nest', title: 'A spare nest', text: 'Woven from trail grass. +1 nest.' },
  { p: 0.25, key: 'scent', title: 'Scent trail', text: 'Your next kin will be uncommon or better.' },
  { p: 0.2, key: 'note', title: 'Field note', text: '' },
  { p: 0.1, key: 'treat', title: 'Berry treat', text: '' },
];
let crackCount = 0;
function rollReward() {
  if (crackCount++ === 0) return REWARDS[0];
  let r = rnd(); for (const x of REWARDS) { if (r < x.p) return x; r -= x.p; } return REWARDS[0];
}
function drawIcon(ctx, key, x, y, s, t) {
  ctx.save(); ctx.translate(x, y);
  if (key === 'nest') {
    ctx.strokeStyle = '#8A6A3A'; ctx.lineWidth = s * 0.08;
    for (let i = 0; i < 7; i++) { ctx.beginPath(); ctx.ellipse(0, 0, s * 0.42, s * 0.3, i * 0.45, 0, 7); ctx.stroke(); }
    ctx.fillStyle = '#C9A46A'; ctx.beginPath(); ctx.ellipse(0, 0, s * 0.3, s * 0.2, 0, 0, 7); ctx.fill();
    ctx.fillStyle = '#5FAF64'; ctx.beginPath(); ctx.ellipse(s * 0.28, -s * 0.28, s * 0.14, s * 0.06, -0.7, 0, 7); ctx.fill();
  } else if (key === 'scent') {
    ctx.strokeStyle = '#7656D1'; ctx.lineWidth = s * 0.07; ctx.lineCap = 'round';
    for (let k = 0; k < 3; k++) { ctx.beginPath(); for (let a = 0; a < 4.5; a += 0.1) { const r = s * (0.08 + a * 0.07); const px = Math.cos(a + t * 2 + k * 2.1) * r, py = Math.sin(a + t * 2 + k * 2.1) * r * 0.7 - k * s * 0.05; a ? ctx.lineTo(px, py) : ctx.moveTo(px, py); } ctx.globalAlpha = 0.9 - k * 0.25; ctx.stroke(); }
  } else if (key === 'note') {
    ctx.rotate(-0.12); ctx.fillStyle = '#FFF6DE'; ctx.fillRect(-s * 0.32, -s * 0.4, s * 0.64, s * 0.8);
    ctx.strokeStyle = '#C9B78E'; ctx.lineWidth = 1.5; for (let i = 0; i < 4; i++) { ctx.beginPath(); ctx.moveTo(-s * 0.22, -s * 0.2 + i * s * 0.15); ctx.lineTo(s * 0.22, -s * 0.2 + i * s * 0.15); ctx.stroke(); }
    ctx.fillStyle = '#D9546B'; ctx.beginPath(); ctx.arc(s * 0.2, -s * 0.32, s * 0.06, 0, 7); ctx.fill();
  } else {
    ['#D9546B', '#B83A57', '#E46B7E'].forEach((c, i) => { ctx.fillStyle = c; ctx.beginPath(); ctx.arc((i - 1) * s * 0.18, i === 1 ? -s * 0.08 : s * 0.05, s * 0.16, 0, 7); ctx.fill(); });
    ctx.fillStyle = '#5FAF64'; ctx.beginPath(); ctx.ellipse(0, -s * 0.28, s * 0.16, s * 0.06, 0.3, 0, 7); ctx.fill();
  }
  ctx.restore();
}
function openCrack(i) {
  const box = h('div', { style: { position: 'absolute', inset: '0', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '10px', color: '#fff', textAlign: 'center', padding: '24px' } });
  const stage = h('div', { style: { position: 'relative', width: '280px', height: '280px' } });
  const title = h('p', { style: { font: '600 26px var(--f-display)', margin: '0' } }, `Waystone · ${fmt(ways()[i])} steps`);
  const sub = h('p', { style: { margin: '0', font: '600 15px var(--f-body)', opacity: '.85', minHeight: '44px', maxWidth: '280px' } }, 'Tap the stone three times to crack it.');
  const btn = h('button', { class: 'g-btn amber', type: 'button', style: { visibility: 'hidden' } }, 'Back to the trail');
  box.append(title, stage, sub, btn);
  const { close } = layer(box, { onClose: () => { layoutHits(); renderHead(); trailLoop.wake(); } });
  const cv = TK.canvas(stage);
  const tapBtn = h('button', { type: 'button', 'aria-label': 'Crack the waystone', style: { position: 'absolute', inset: '30px', borderRadius: '50%', border: '0', background: 'transparent', cursor: 'pointer' } });
  stage.append(tapBtn);
  let hitsN = 0, cracks = [], shake = TK.spring(0, TK.SPRING.bouncy), open = TK.spring(0, TK.SPRING.smooth), reward = null, t0 = performance.now();
  const r = TK.rng(i * 31 + 7);
  const crackLine = () => { const a = r() * 6.28; const pts = [[0, 0]]; let x = 0, y = 0; for (let k = 0; k < 5; k++) { x += Math.cos(a + (r() - 0.5)) * 14; y += Math.sin(a + (r() - 0.5)) * 14; pts.push([x, y]); } return pts; };
  tapBtn.addEventListener('click', () => {
    if (reward) return;
    hitsN++; cracks.push(crackLine(), crackLine());
    shake.kick(hitsN % 2 ? 900 : -900);
    TK.sfx('crack'); TK.haptic(hitsN === 1 ? 'light' : hitsN === 2 ? 'medium' : 'heavy');
    if (hitsN >= 3) {
      reward = rollReward(); open.to(1);
      if (reward.key === 'nest') S.nestsBonus++;
      if (reward.key === 'scent') S.lure = true;
      if (reward.key === 'note') { const unk = SPECIES().filter(s => !S.caught[s.id]); const s = unk[Math.floor(rnd() * unk.length)]; if (s) { S.hints.add(s.id); reward = { ...reward, text: `${s.name}: ${s.blurb || TIER_HINT[s.tier]}` }; } else reward = { ...reward, text: 'Your journal is complete. The trail tips its hat.' }; }
      if (reward.key === 'treat') reward = { ...reward, text: `${sp(S.buddy).name} loved it and hums along on your next walk.` };
      S.cracked = Math.max(S.cracked, i + 1);
      setTimeout(() => { TK.sfx('chime'); TK.haptic('success'); title.textContent = reward.title; sub.textContent = reward.text; btn.style.visibility = 'visible'; btn.focus({ preventScroll: true }); TK.announce(`${reward.title}. ${reward.text}`); }, 380);
    } else sub.textContent = hitsN === 1 ? 'It\'s giving. Again.' : 'One more.';
    loop.wake();
  });
  btn.addEventListener('click', () => close());
  const loop = TK.loop((dt, now) => {
    if (!stage.isConnected) return false;
    const t = (now - t0) / 1000; let busy = !shake.step(dt); busy = !open.step(dt) || busy;
    const { ctx, w, h: H } = cv; ctx.clearRect(0, 0, w, H);
    const cx = w / 2, cy = H / 2 + 10, R = 78;
    if (open.x > 0.02) {
      const gl = ctx.createRadialGradient(cx, cy, 0, cx, cy, 140); gl.addColorStop(0, `rgba(255,214,110,${0.8 * open.x})`); gl.addColorStop(1, 'rgba(255,214,110,0)');
      ctx.fillStyle = gl; ctx.beginPath(); ctx.arc(cx, cy, 140, 0, 7); ctx.fill();
      ctx.save(); ctx.translate(cx, cy); ctx.rotate(t * 0.4); ctx.fillStyle = `rgba(255,240,190,${0.35 * open.x})`;
      for (let k = 0; k < 10; k++) { ctx.rotate(Math.PI / 5); ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(-10, -150); ctx.lineTo(10, -150); ctx.closePath(); ctx.fill(); }
      ctx.restore();
    }
    const sx = cx + shake.x * 0.02;
    const half = (side) => {
      ctx.save(); ctx.translate(sx + side * open.x * 70, cy + open.x * 30); ctx.rotate(side * open.x * 0.5);
      ctx.beginPath();
      if (side) { ctx.rect(side < 0 ? -R - 10 : 0, -R - 10, R + 10, 2 * R + 20); ctx.clip(); }
      ctx.fillStyle = 'rgba(0,0,0,.25)'; ctx.beginPath(); ctx.ellipse(0, R * 0.95, R * 0.85, R * 0.2, 0, 0, 7); ctx.fill();
      const sg = ctx.createRadialGradient(-R * 0.3, -R * 0.4, 10, 0, 0, R * 1.1); sg.addColorStop(0, '#E6E1D3'); sg.addColorStop(1, '#8E8A7C');
      ctx.fillStyle = sg; ctx.beginPath(); ctx.moveTo(-R * 0.9, R * 0.8); ctx.bezierCurveTo(-R * 1.15, -R * 0.4, -R * 0.5, -R * 1.05, 0, -R); ctx.bezierCurveTo(R * 0.6, -R * 1.05, R * 1.15, -R * 0.3, R * 0.9, R * 0.8); ctx.closePath(); ctx.fill();
      ctx.fillStyle = '#6FAF6A'; ctx.beginPath(); ctx.ellipse(-R * 0.45, R * 0.6, R * 0.35, R * 0.16, 0.2, 0, 7); ctx.fill();
      ctx.strokeStyle = 'rgba(255,214,110,.9)'; ctx.lineWidth = 4; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.arc(0, -R * 0.15, R * 0.28, 0.4, 2.7); ctx.moveTo(0, -R * 0.15 - R * 0.28); ctx.lineTo(0, -R * 0.15 + R * 0.1); ctx.stroke();
      ctx.strokeStyle = '#3F3A30'; ctx.lineWidth = 2.5; ctx.lineJoin = 'round';
      for (const c of cracks) { ctx.beginPath(); c.forEach(([x, y], k) => k ? ctx.lineTo(x, y - R * 0.15) : ctx.moveTo(x, y - R * 0.15)); ctx.stroke(); }
      ctx.restore();
    };
    if (open.x < 0.02) half(0); else { half(-1); half(1); }
    if (reward && open.x > 0.3) {
      const k = clamp((open.x - 0.3) / 0.7, 0, 1);
      drawIcon(cv.ctx, reward.key, cx, cy - 20 - k * 40 + Math.sin(t * 3) * 3, 70 * k + 10, t);
    }
    return busy || !!reward;
  });
  loop.wake();
}

/* ================= GOAL CROSSING ================= */
function openGoal() {
  const box = h('div', { style: { position: 'absolute', inset: '0', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '14px', textAlign: 'center', padding: '28px', color: '#2B1A00' } });
  const cvHost = h('div', { style: { position: 'absolute', inset: '0' } });
  const big = h('div', { style: { font: '700 64px/1 var(--f-display)', fontVariantNumeric: 'tabular-nums', position: 'relative' } }, fmt(S.goal));
  const msg = h('p', { style: { margin: '0', font: '600 19px/1.3 var(--f-display)', maxWidth: '280px', position: 'relative' } }, 'Summit reached. A rare kin came down to meet you.');
  const note = h('p', { style: { margin: '0', font: '700 13.5px var(--f-body)', opacity: '.75', position: 'relative' } }, "Today's ember is ready to light in the lantern.");
  const go = h('button', { class: 'g-btn', type: 'button', style: { position: 'relative' } }, 'Meet it');
  const later = h('button', { class: 'g-btn ghost', type: 'button', style: { position: 'relative', color: '#2B1A00' } }, 'Later');
  box.append(cvHost, h('div', { class: 'g-day', style: { position: 'relative', color: '#7A4C00' } }, 'Daily goal'), big, msg, note, h('div', { style: { display: 'flex', gap: '10px', position: 'relative' } }, go, later));
  const wrap = h('div', { style: { position: 'absolute', inset: '0', background: 'linear-gradient(#FFD98A,#FFB65C 55%,#F28A4B)' } }, box);
  const { close } = layer(wrap, { scrim: false });
  wrap.animate([{ clipPath: 'circle(0% at 50% 30%)' }, { clipPath: 'circle(150% at 50% 30%)' }], { duration: TK.reduced() ? 1 : 700, easing: 'cubic-bezier(.3,.8,.3,1)' });
  big.animate([{ transform: 'scale(.3)', opacity: 0 }, { transform: 'scale(1.12)', opacity: 1, offset: 0.7 }, { transform: 'scale(1)' }], { duration: 650, delay: 250, fill: 'backwards', easing: 'ease-out' });
  TK.sfx('fanfare'); TK.haptic('success'); TK.announce(`Daily goal reached: ${fmt(S.goal)} steps. A rare kin is waiting.`);
  const cv = TK.canvas(cvHost); const r = TK.rng(5);
  const leaves = Array.from({ length: 46 }, () => ({ x: r(), y: -r() * 0.6, v: 0.12 + r() * 0.2, s: 5 + r() * 7, a: r() * 6, c: ['#5FAF64', '#F2A12E', '#FFFFFF', '#D9546B', '#7656D1'][Math.floor(r() * 5)] }));
  const t0 = performance.now();
  const loop = TK.loop((dt, now) => {
    if (!cvHost.isConnected) return false;
    const t = (now - t0) / 1000, { ctx, w, h: H } = cv; ctx.clearRect(0, 0, w, H);
    for (const p of leaves) { p.y += p.v * dt; p.a += dt * 3; const x = (p.x + Math.sin(t * 1.5 + p.a) * 0.03) * w, y = p.y * H; ctx.save(); ctx.translate(x, y); ctx.rotate(p.a); ctx.fillStyle = p.c; ctx.beginPath(); ctx.ellipse(0, 0, p.s, p.s * 0.45, 0, 0, 7); ctx.fill(); ctx.restore(); }
    return t < 8;
  });
  loop.wake();
  go.addEventListener('click', () => { close(); const e = S.waiting.find(x => x.summit); if (e) setTimeout(() => openEncounter(e), 120); });
  later.addEventListener('click', () => close());
}

/* ================= BUDDY NUDGE ================= */
function openNudge() {
  if (layerOpen) layerOpen.close();
  if (S.view !== 'trail') show('trail');
  const nextW = ways().find(w => w > S.steps);
  const toGo = nextW ? nextW - Math.round(S.steps) : RULES.spawnEvery - (Math.round(S.steps) % RULES.spawnEvery);
  const mins = Math.max(1, Math.round(toGo / 100)); // ~100 steps per minute at an easy pace
  const name = sp(S.buddy).name;
  const cvHost = h('div', { style: { position: 'absolute', right: '-6px', bottom: '232px', width: '130px', height: '130px' } });
  const card = h('div', { class: 'g-sheet', style: { bottom: '96px' } },
    h('p', { class: 'g-day', style: { margin: 0 } }, `${name} · your buddy`),
    h('p', { style: { margin: '6px 0 0', font: '600 20px/1.25 var(--f-display)' } }, nextW ? `The next waystone is ${fmt(toGo)} steps away. That's about ${mins} minutes. Walk with me?` : `The next kin is ${fmt(toGo)} steps away, about ${mins} minutes. Walk with me?`),
    h('p', { class: 'g-sub' }, 'Start a stroll and the next kin you meet will be uncommon.'));
  const go = h('button', { class: 'g-btn amber', type: 'button' }, 'Start a 10-minute stroll');
  const no = h('button', { class: 'g-btn ghost', type: 'button' }, 'Not now');
  card.append(h('div', { style: { display: 'flex', gap: '8px', marginTop: '14px', flexWrap: 'wrap' } }, go, no));
  const box = h('div', { style: { position: 'absolute', inset: '0' } }, cvHost, card);
  const { close } = layer(box);
  card.animate([{ transform: 'translateY(40px)', opacity: 0 }, { transform: 'none', opacity: 1 }], { duration: 420, easing: 'cubic-bezier(.2,1.3,.4,1)' });
  TK.haptic('light'); TK.sfx('pop');
  const cv = TK.canvas(cvHost); const peek = TK.spring(0, TK.SPRING.bouncy).to(1); const t0 = performance.now();
  const loop = TK.loop((dt, now) => {
    if (!cvHost.isConnected) return false;
    peek.step(dt); const t = (now - t0) / 1000, { ctx, w, h: H } = cv; ctx.clearRect(0, 0, w, H);
    ctx.save(); ctx.translate(lerp(w + 40, w * 0.55, peek.x), H - 6); ctx.rotate(-0.25 + Math.sin(t * 2) * 0.04);
    drawKin(ctx, S.buddy, 0, 0, 96, t, { mood: 'happy', facing: -1 }); ctx.restore();
    return true;
  });
  loop.wake();
  go.addEventListener('click', () => {
    S.stroll = { until: Date.now() + 10 * 60000 }; S.lure = true; close(); renderHead();
    toast(`Stroll started. ${name} is ready when you are.`); TK.haptic('medium');
  });
  no.addEventListener('click', () => { close(); toast(`${name} will ask again in a couple of hours.`); });
}

/* ================= JOURNAL ================= */
const jHead = h('div', { class: 'g-head', style: { paddingBottom: '12px', display: 'block' } });
const jGrid = h('div', { class: 'g-grid' });
vJournal.append(jHead, h('div', { class: 'g-scroll' }, jGrid));
vJournal.style.background = '#F4EFE3';
let jLoop = null;
function renderJournal() {
  const all = SPECIES();
  const found = all.filter(s => S.caught[s.id]).length;
  jHead.innerHTML = '';
  jHead.append(h('p', { class: 'g-day', style: { margin: 0 } }, 'Field journal'), h('h2', { class: 'g-title' }, `${found} of ${all.length} kin found`),
    h('p', { class: 'g-sub' }, 'Rarer kin live further along your daily goal.'));
  jGrid.innerHTML = '';
  const cards = [];
  all.forEach(s => {
    const c = S.caught[s.id], isNew = S.fresh.has(s.id);
    const cv = h('canvas', { width: 168, height: 168, 'aria-hidden': 'true' });
    const btn = h('button', { class: 'g-card' + (isNew ? ' new' : ''), type: 'button', 'aria-label': c ? `${s.name}, ${s.tier}, found ${c.when.toLocaleDateString('en-GB', { weekday: 'long' })} at ${fmt(c.at)} steps` : `Undiscovered ${s.tier} kin. ${TIER_HINT[s.tier]}` },
      cv, h('b', null, c ? s.name : '???'),
      h('span', { class: 'g-tier', style: { background: tierColor(s.tier) } }, s.tier),
      h('small', null, c ? `${c.when.toLocaleDateString('en-GB', { weekday: 'short' })} · ${fmt(c.at)} steps` : (S.hints.has(s.id) ? 'Field note found' : TIER_HINT[s.tier].split(' ').slice(0, 4).join(' ') + '…')));
    btn.addEventListener('click', () => openEntry(s));
    jGrid.append(btn); cards.push([cv, s, !!c, isNew]);
  });
  const t0 = performance.now();
  jLoop = TK.loop((dt, now) => {
    if (vJournal.hidden) return false;
    const t = (now - t0) / 1000;
    for (const [cv, s, got, isNew] of cards) {
      const ctx = cv.getContext('2d'); ctx.setTransform(2, 0, 0, 2, 0, 0); ctx.clearRect(0, 0, 84, 84);
      ctx.fillStyle = got ? '#EAF3E3' : '#E6E0D2'; ctx.beginPath(); ctx.arc(42, 44, 36, 0, 7); ctx.fill();
      drawKin(ctx, s.id, 42, 74, 56, got ? t : 0, { silhouette: !got, mood: 'idle' });
      if (isNew && t < 1.2) { // ink stamp lands on first view
        const k = clamp(t / 0.5, 0, 1);
        ctx.save(); ctx.translate(62, 22); ctx.rotate(-0.3); ctx.scale(2.2 - k * 1.2, 2.2 - k * 1.2); ctx.globalAlpha = k;
        ctx.strokeStyle = '#D9546B'; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(0, 0, 11, 0, 7); ctx.stroke();
        ctx.fillStyle = '#D9546B'; ctx.font = '800 8px Nunito Sans, sans-serif'; ctx.textAlign = 'center'; ctx.fillText('NEW', 0, 3); ctx.restore();
        if (k >= 1 && !cv.dataset.thud) { cv.dataset.thud = 1; TK.sfx('thud'); TK.haptic('medium'); }
      }
    }
    return true;
  });
  jLoop.wake();
  setTimeout(() => { S.fresh.clear(); badge('journal', 0); }, 1500);
}
function openEntry(s) {
  const c = S.caught[s.id];
  const host = h('div', { style: { position: 'relative', height: '190px', margin: '-6px 0 4px' } });
  const sheet = h('div', { class: 'g-sheet' },
    h('button', { class: 'g-x', type: 'button', 'aria-label': 'Close' }, '✕'), host,
    h('span', { class: 'g-tier', style: { background: tierColor(s.tier) } }, s.tier),
    h('h3', { class: 'g-title', style: { marginTop: '6px' } }, c ? s.name : 'Not found yet'),
    h('p', { class: 'g-sub', style: { fontSize: '15px', color: '#34463D' } }, c ? s.blurb : (S.hints.has(s.id) ? `Field note: ${s.blurb}` : TIER_HINT[s.tier] + '.')),
    c ? h('p', { class: 'g-sub' }, `Found ${c.when.toLocaleDateString('en-GB', { weekday: 'long' })} at ${fmt(c.at)} steps · ${c.best} throw`) : null);
  if (c) {
    const mk = h('button', { class: 'g-btn' + (S.buddy === s.id ? ' ghost' : ''), type: 'button', style: { marginTop: '14px' } }, S.buddy === s.id ? 'Walking with you' : 'Make it your buddy');
    mk.addEventListener('click', () => { if (S.buddy === s.id) return; S.buddy = s.id; mk.textContent = 'Walking with you'; mk.className = 'g-btn ghost'; TK.haptic('medium'); TK.sfx('pop'); TK.announce(`${s.name} is your buddy now`); });
    sheet.append(mk);
  }
  const { close } = layer(sheet);
  sheet.querySelector('.g-x').addEventListener('click', () => close());
  sheet.animate([{ transform: 'translateY(60px)', opacity: 0 }, { transform: 'none', opacity: 1 }], { duration: 380, easing: 'cubic-bezier(.2,1.2,.4,1)' });
  const cv = TK.canvas(host); const t0 = performance.now();
  TK.loop((dt, now) => {
    if (!host.isConnected) return false;
    const t = (now - t0) / 1000, { ctx, w, h: H } = cv; ctx.clearRect(0, 0, w, H);
    ctx.fillStyle = 'rgba(0,0,0,.1)'; ctx.beginPath(); ctx.ellipse(w / 2, H - 12, 50, 9, 0, 0, 7); ctx.fill();
    drawKin(ctx, s.id, w / 2, H - 12, 160, c ? t : 0, { silhouette: !c, mood: c ? 'happy' : 'idle' });
    return true;
  }).wake();
}

/* ================= LANTERN (weekly, loss-framed) ================= */
const lHead = h('div', { class: 'g-head', style: { display: 'block' } });
const lStage = h('div', { style: { position: 'relative', flex: '1', minHeight: '0' } });
const lFoot = h('div', { style: { padding: '0 18px 14px', display: 'flex', flexDirection: 'column', gap: '8px', alignItems: 'stretch' } });
vLantern.append(lHead, lStage, lFoot);
vLantern.style.background = 'linear-gradient(#202A47,#3A3463 60%,#5A3F5E)';
vLantern.style.color = '#F4EEDF';
const lc = TK.canvas(lStage, () => lLoop.wake());
let litAnim = 0, holding = false, holdT = 0, holdBtn = null;
function emberStats() {
  const lit = S.week.filter(x => x === 'lit').length;
  const open = S.week.filter(x => x === 'future' || x === 'today').length;
  return { lit, open, reach: lit + open };
}
function renderLantern() {
  const { lit, reach } = emberStats();
  const goalMet = S.steps >= S.goal;
  lHead.innerHTML = '';
  lHead.append(h('p', { class: 'g-day', style: { margin: 0, color: '#C9BFE8' } }, "This week's lantern"),
    h('h2', { class: 'g-title', style: { color: '#FFF4D9' } }, `${lit} of 7 embers lit`),
    h('p', { class: 'g-sub', style: { color: '#D8CFF0' } }, reach >= RULES.emberGoal
      ? `${Math.max(0, RULES.emberGoal - lit)} more and a rare visitor comes on Sunday. ${reach - lit} days still in reach.`
      : `This week's visitor is out of reach. Every ember still counts toward your streak.`));
  lFoot.innerHTML = '';
  const today = S.week[S.today];
  if (today === 'today' && goalMet && !S.emberLitToday) {
    holdBtn = h('button', { class: 'g-btn amber', type: 'button', 'aria-label': "Hold to light today's ember" }, "Hold to light today's ember");
    lFoot.append(holdBtn);
    const startHold = e => { e.preventDefault(); holding = true; holdT = 0; lLoop.wake(); TK.haptic('select'); };
    const endHold = () => { holding = false; };
    holdBtn.addEventListener('pointerdown', startHold); holdBtn.addEventListener('pointerup', endHold); holdBtn.addEventListener('pointerleave', endHold); holdBtn.addEventListener('pointercancel', endHold);
    holdBtn.addEventListener('keydown', e => { if ((e.key === ' ' || e.key === 'Enter') && !e.repeat) startHold(e); });
    holdBtn.addEventListener('keyup', e => { if (e.key === ' ' || e.key === 'Enter') endHold(); });
  } else {
    holdBtn = null;
    const msg = today === 'lit' || S.emberLitToday ? "Today's ember is lit. See you tomorrow." : `Reach ${fmt(S.goal)} steps to light today's ember. ${fmt(Math.max(0, S.goal - S.steps))} to go.`;
    lFoot.append(h('p', { style: { margin: 0, font: '700 14px var(--f-body)', textAlign: 'center', color: '#E9E1FA' } }, msg));
  }
  lFoot.append(h('p', { style: { margin: 0, font: '600 12px var(--f-body)', textAlign: 'center', color: '#B9AED8' } }, S.restLeft ? 'One rest ember left this week: it saves the first missed day.' : 'Rest ember used this week.'));
  lc.cv.setAttribute('role', 'img');
  lc.cv.setAttribute('aria-label', S.week.map((s, i) => `${DAYS[i]}: ${s === 'today' ? (S.emberLitToday ? 'lit' : 'today') : s}`).join(', '));
  lLoop.wake();
}
const lLoop = TK.loop((dt, now) => {
  if (vLantern.hidden) return false;
  const t = now / 1000, { ctx, w: W, h: H } = lc; ctx.clearRect(0, 0, W, H);
  if (holding) {
    holdT += dt;
    const k = holdT / 1.2;
    if (Math.floor(holdT * 8) !== Math.floor((holdT - dt) * 8)) TK.haptic(k < 0.5 ? 'select' : 'light');
    if (k >= 1) { holding = false; S.emberLitToday = true; S.week[S.today] = 'lit'; litAnim = t; TK.sfx('ember'); TK.haptic('success'); TK.announce("Today's ember is lit"); renderLantern(); }
  } else if (holdT > 0 && !S.emberLitToday) holdT = Math.max(0, holdT - dt * 2);
  // lantern body
  const cx = W / 2, cy = H * 0.5, R = Math.min(W * 0.36, H * 0.4);
  const glow = ctx.createRadialGradient(cx, cy, 0, cx, cy, R * 1.6);
  const litN = S.week.filter(x => x === 'lit').length;
  glow.addColorStop(0, `rgba(255,190,90,${0.12 + litN * 0.06})`); glow.addColorStop(1, 'rgba(255,190,90,0)');
  ctx.fillStyle = glow; ctx.beginPath(); ctx.arc(cx, cy, R * 1.6, 0, 7); ctx.fill();
  ctx.strokeStyle = 'rgba(255,240,210,.25)'; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(cx, cy, R, Math.PI * 0.85, Math.PI * 2.15); ctx.stroke();
  S.week.forEach((st, i) => {
    const a = Math.PI * 0.85 + (i / 6) * Math.PI * 1.3;
    const x = cx + Math.cos(a) * R, y = cy + Math.sin(a) * R;
    const isToday = i === S.today;
    const state = isToday ? (S.emberLitToday ? 'lit' : (S.steps >= S.goal ? 'ready' : 'today')) : st;
    ctx.fillStyle = 'rgba(0,0,0,.25)'; ctx.beginPath(); ctx.ellipse(x, y + 16, 15, 4, 0, 0, 7); ctx.fill();
    ctx.fillStyle = '#4A3F5E'; ctx.beginPath(); ctx.roundRect ? ctx.roundRect(x - 13, y + 4, 26, 12, 4) : ctx.rect(x - 13, y + 4, 26, 12); ctx.fill();
    const flame = (sc, c1, c2) => {
      const fl = Math.sin(t * 9 + i) * 0.08;
      ctx.save(); ctx.translate(x, y + 4); ctx.scale(sc * (1 + fl), sc * (1 - fl));
      const fg = ctx.createRadialGradient(0, -8, 1, 0, -6, 18); fg.addColorStop(0, c1); fg.addColorStop(1, c2);
      ctx.fillStyle = fg; ctx.beginPath(); ctx.moveTo(0, -24); ctx.bezierCurveTo(10, -12, 10, -2, 0, 0); ctx.bezierCurveTo(-10, -2, -10, -12, 0, -24); ctx.fill(); ctx.restore();
    };
    if (state === 'lit') {
      const born = isToday && litAnim ? clamp((t - litAnim) / 0.6, 0, 1) : 1;
      const g2 = ctx.createRadialGradient(x, y - 6, 0, x, y - 6, 34); g2.addColorStop(0, 'rgba(255,200,90,.55)'); g2.addColorStop(1, 'rgba(255,200,90,0)');
      ctx.fillStyle = g2; ctx.beginPath(); ctx.arc(x, y - 6, 34, 0, 7); ctx.fill();
      flame(born * (born < 1 ? 1 + Math.sin(born * Math.PI) * 0.4 : 1), '#FFF6C8', '#FF9A2E');
    } else if (state === 'rested') flame(0.7, '#DDF3FF', '#5AA7E6');
    else if (state === 'snuffed') {
      ctx.strokeStyle = 'rgba(200,190,220,.45)'; ctx.lineWidth = 2; ctx.beginPath();
      for (let k = 0; k < 18; k++) { const yy = y + 2 - k * 1.6, xx = x + Math.sin(k * 0.6 + t * 2) * 3; k ? ctx.lineTo(xx, yy) : ctx.moveTo(xx, yy); } ctx.stroke();
    } else if (state === 'ready') {
      const k = holdT / 1.2;
      if (k > 0) flame(k, '#FFF6C8', '#FF9A2E');
      ctx.strokeStyle = `rgba(255,214,110,${0.5 + 0.5 * Math.sin(t * 5)})`; ctx.lineWidth = 2; ctx.setLineDash([3, 4]); ctx.beginPath(); ctx.arc(x, y - 6, 18, 0, 7); ctx.stroke(); ctx.setLineDash([]);
    } else {
      ctx.strokeStyle = 'rgba(230,220,250,.35)'; ctx.lineWidth = 1.5; ctx.setLineDash([3, 4]); ctx.beginPath(); ctx.moveTo(x, y - 18); ctx.bezierCurveTo(x + 8, y - 8, x + 8, y, x, y + 2); ctx.bezierCurveTo(x - 8, y, x - 8, y - 8, x, y - 18); ctx.stroke(); ctx.setLineDash([]);
      if (isToday) { const p = clamp(S.steps / S.goal, 0, 1); ctx.strokeStyle = '#FFC94D'; ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(x, y - 6, 20, -Math.PI / 2, -Math.PI / 2 + p * 6.283); ctx.stroke(); }
    }
    ctx.fillStyle = isToday ? '#FFE9B0' : 'rgba(240,232,255,.75)'; ctx.font = `${isToday ? 800 : 700} 12px Nunito Sans, sans-serif`; ctx.textAlign = 'center';
    ctx.fillText(isToday ? 'Today' : SHORT[i], x, y + 34);
  });
  // the visitor waits in the middle
  const vis = pool('elusive')[0];
  if (vis) { const ok = emberStats().lit >= RULES.emberGoal; drawKin(ctx, vis, cx, cy + R * 0.45, R * 0.75, ok ? t : 0, { silhouette: !ok, alpha: ok ? 1 : 0.55, mood: ok ? 'happy' : 'idle' }); }
  ctx.fillStyle = 'rgba(240,232,255,.7)'; ctx.font = '700 11px Nunito Sans, sans-serif'; ctx.textAlign = 'center';
  ctx.fillText(emberStats().lit >= RULES.emberGoal ? 'Your Sunday visitor is on the way' : 'Sunday visitor', cx, cy + R * 0.45 + 16);
  return true;
});

function nextDay() {
  const t = S.today;
  if (S.steps >= S.goal) S.week[t] = 'lit';
  else if (S.restLeft > 0) { S.week[t] = 'rested'; S.restLeft--; }
  else S.week[t] = 'snuffed';
  const res = S.week[t];
  let msg = res === 'lit' ? 'Yesterday\'s ember stays lit.' : res === 'rested' ? 'Your rest ember covered yesterday.' : 'Yesterday\'s ember went out. Today is a fresh one.';
  if (t === 6) {
    if (S.week.filter(x => x === 'lit').length >= RULES.emberGoal) { const el = pool('elusive')[0]; if (el) { S.waiting.push({ id: el, at: 0, k: kSeq++ }); msg += ' A rare visitor arrived on your trail.'; } }
    S.week = DAYS.map(() => 'future'); S.today = 0; S.restLeft = 1;
  } else S.today = t + 1;
  S.week[S.today] = 'today';
  const carry = nests(); // unused nests carry over to the new day
  S.steps = 640; S.kcal = 28; S.nestsUsed = 0; S.nestsBonus = carry; S.spawned = 0; S.cracked = 0; S.goalRare = false; S.elusiveSeen = false; S.emberLitToday = false; S.stroll = null;
  S.waiting = S.waiting.filter(e => !e.summit).map(e => ({ ...e, at: 0 })); // kin who waited overnight sit at the trailhead
  shown = S.steps; shownKcal = S.kcal; bushPop.clear(); wayPop.clear();
  layoutHits(); renderHead(); syncSim(); if (S.view === 'lantern') renderLantern(); else trailLoop.wake();
  toast(`Good morning. ${msg}`);
}

/* ================= simulator + page wiring ================= */
function syncSim() {
  document.getElementById('simSteps').textContent = fmt(S.steps);
  document.getElementById('simKcal').textContent = fmt(S.kcal);
  document.getElementById('simGoal').textContent = fmt(S.goal);
}
const simBtns = document.querySelectorAll('[data-sim]');
simBtns.forEach(b => b.addEventListener('click', () => {
  if (layerOpen && b.dataset.sim !== 'moving') layerOpen.close();
  switch (b.dataset.sim) {
    case 'short': stepIn(300, 12); break;
    case 'walk': stepIn(1100, 48, 'Welcome back'); break;
    case 'brisk': stepIn(3400, 150, 'Welcome back'); break;
    case 'sit': openNudge(); break;
    case 'moving': S.walking = !S.walking; b.setAttribute('aria-pressed', S.walking); toast(S.walking ? 'Walking: encounters wait until you stop.' : 'Stopped. Throw away.'); break;
    case 'day': nextDay(); break;
    case 'reset': resetDemo(); break;
  }
}));
function resetDemo() {
  S = fresh(); seedDemo(); crackCount = 0; shown = S.steps; shownKcal = S.kcal; bushPop.clear(); wayPop.clear();
  document.querySelector('[data-sim="moving"]').setAttribute('aria-pressed', 'false');
  badge('journal', 0); show('trail'); layoutHits(); renderHead(); syncSim(); toast('Demo reset.');
}
document.addEventListener('tk-haptic', () => { const d = document.getElementById('hapticDot'); d.classList.remove('on'); void d.offsetWidth; d.classList.add('on'); });
const sb = document.getElementById('soundBtn');
sb.addEventListener('click', () => { TK.soundOn = !TK.soundOn; sb.setAttribute('aria-pressed', TK.soundOn); if (TK.soundOn) TK.sfx('chime'); });
(() => {
  const root = document.documentElement, tb = document.getElementById('themeBtn'), order = ['system', 'light', 'dark'];
  let mode = 'system'; try { mode = localStorage.getItem('tk-theme') || 'system'; } catch (_) { /* blocked */ }
  if (!order.includes(mode)) mode = 'system';
  const apply = () => { if (mode === 'system') delete root.dataset.theme; else root.dataset.theme = mode; tb.setAttribute('aria-label', `Theme: ${mode}. Change theme`); };
  apply();
  tb.addEventListener('click', () => { mode = order[(order.indexOf(mode) + 1) % 3]; apply(); try { localStorage.setItem('tk-theme', mode); } catch (_) { /* ignore */ } });
})();

/* "Play it" buttons in the docs jump straight to each reward. */
window.TKApp = {
  play(name) {
    document.getElementById('play').scrollIntoView({ behavior: TK.reduced() ? 'auto' : 'smooth', block: 'start' });
    setTimeout(() => {
      if (layerOpen) layerOpen.close();
      switch (name) {
        case 'stepin': stepIn(1100, 48, 'Welcome back'); break;
        case 'throw': {
          if (S.view !== 'trail') show('trail');
          let e = S.waiting.find(x => !x.summit && x.at <= S.steps) || S.waiting[0];
          if (!e) { e = { id: pick(S.steps / S.goal), at: Math.round(S.steps), k: kSeq++ }; S.waiting.push(e); layoutHits(); }
          if (nests() <= 0) S.nestsBonus++;
          openEncounter(e); break;
        }
        case 'crack': {
          if (S.view !== 'trail') show('trail');
          const W8 = ways(); let i = S.cracked;
          if (i >= W8.length - 1 || W8[i] > S.steps) { if (i >= W8.length - 1) { S.cracked = Math.max(0, W8.length - 2); i = S.cracked; } else { S.steps = W8[i] + 20; shown = S.steps; syncSim(); } }
          layoutHits(); renderHead(); openCrack(i); break;
        }
        case 'goal': if (S.steps >= S.goal) { S.steps = S.goal - 400; shown = S.steps; S.goalRare = false; S.waiting = S.waiting.filter(e => !e.summit); } else if (S.goal - S.steps > 1400) { S.steps = S.goal - 900; shown = S.steps; } stepIn(1100, 48, 'Welcome back'); break;
        case 'nudge': openNudge(); break;
        case 'ember': if (S.steps < S.goal) { S.steps = S.goal + 120; shown = S.steps; S.goalRare = true; syncSim(); renderHead(); } S.emberLitToday = false; S.week[S.today] = 'today'; show('lantern'); setTimeout(() => holdBtn && holdBtn.focus({ preventScroll: true }), 100); break;
        case 'stamp': { const id = S.order[S.order.length - 1]; if (id) S.fresh.add(id); show('journal'); break; }
      }
    }, 450);
  },
};
document.querySelectorAll('[data-play]').forEach(b => b.addEventListener('click', () => TKApp.play(b.dataset.play)));


/* Dart highlighting for the Flutter section. */
(() => {
  const K = /^(abstract|as|async|await|bool|break|case|class|const|double|else|enum|extends|false|final|for|if|import|in|int|late|new|null|return|static|super|switch|this|true|var|void|while|with|get|set|required|String|List|Map|Future|dependencies)$/;
  const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  document.querySelectorAll('#flutter pre.code code').forEach(c => {
    const src = c.textContent; let out = '', i = 0, m;
    const re = /(\/\/[^\n]*)|('(?:[^'\\\n]|\\.)*')|(@\w+)|\b(\d+(?:\.\d+)?|\.\d+)\b|\b([A-Za-z_]\w*)\b/g;
    while ((m = re.exec(src))) {
      out += esc(src.slice(i, m.index)); i = re.lastIndex;
      const [w, cm, st, at, n, id] = m;
      if (cm) out += `<span class="c">${esc(cm)}</span>`; else if (st) out += `<span class="s">${esc(st)}</span>`;
      else if (at) out += `<span class="k">${at}</span>`; else if (n) out += `<span class="n">${n}</span>`;
      else if (K.test(id)) out += `<span class="k">${id}</span>`; else if (/^[A-Z]/.test(id)) out += `<span class="t">${id}</span>`; else out += esc(w);
    }
    c.innerHTML = out + esc(src.slice(i));
  });
})();

/* boot */
syncSim(); renderHead(); layoutHits(); trailLoop.wake();
setInterval(() => { if (S.stroll) renderHead(); }, 20000);
})();
