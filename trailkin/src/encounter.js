/* Trailkin encounter: a meadow, one kin, and a woven nest you flick to invite it in.
   TK.encounter.open(container, { species, getNests, useNest, walking, stepsToday, onClose, hour? }) */
(() => {
'use strict';
const TK = window.TK;
const TAU = Math.PI * 2;
const { clamp, lerp } = TK;

const CSS = `
.tke{position:absolute;inset:0;z-index:30;overflow:hidden;user-select:none;-webkit-user-select:none;font-family:var(--tk-font-ui,"Fredoka","Nunito",system-ui,sans-serif);color:#1F2B26;animation:tke-in .35s ease both}
@keyframes tke-in{from{opacity:0;transform:scale(1.04)}to{opacity:1;transform:none}}
.tke.out{animation:tke-out .28s ease both}@keyframes tke-out{to{opacity:0;transform:scale(.98)}}
.tke canvas{position:absolute;inset:0;display:block}
.tke-top{position:absolute;left:0;right:0;top:0;display:flex;align-items:center;gap:10px;padding:14px 10px 10px 18px;pointer-events:none}
.tke-name{font-size:21px;font-weight:600;letter-spacing:.01em;text-shadow:0 1px 0 rgba(255,255,255,.5)}
.tke-chip{font-size:11px;font-weight:600;letter-spacing:.06em;text-transform:uppercase;color:#fff;padding:3px 9px;border-radius:999px}
.tke-x{pointer-events:auto;margin-left:auto;width:48px;height:48px;border-radius:50%;border:0;background:rgba(255,255,255,.72);backdrop-filter:blur(6px);font-size:18px;color:#1F2B26;cursor:pointer;display:grid;place-items:center}
.tke-x:focus-visible,.tke-nest:focus-visible,.tke-btn:focus-visible{outline:3px solid #fff;outline-offset:3px;box-shadow:0 0 0 6px rgba(31,43,38,.5)}
.tke.night .tke-name{color:#F3F1FF;text-shadow:none}
.tke-count{position:absolute;left:16px;bottom:22px;display:flex;align-items:center;gap:7px;font-size:15px;font-weight:600;background:rgba(255,255,255,.78);backdrop-filter:blur(6px);padding:7px 12px 7px 9px;border-radius:999px}
.tke-count i{width:18px;height:18px;border-radius:50%;background:radial-gradient(circle at 35% 35%,#E7C78C,#B98545);box-shadow:inset 0 0 0 2px rgba(110,74,32,.35)}
.tke-hint{position:absolute;left:50%;bottom:150px;transform:translateX(-50%);font-size:14px;font-weight:500;background:rgba(255,255,255,.8);padding:6px 12px;border-radius:999px;white-space:nowrap;transition:opacity .4s}
.tke-nest{position:absolute;left:50%;bottom:34px;width:112px;height:112px;margin-left:-56px;border-radius:50%;border:0;background:transparent;cursor:grab;touch-action:none}
.tke-nest:active{cursor:grabbing}
.tke-panel{position:absolute;left:18px;right:18px;top:50%;transform:translateY(-50%);background:rgba(255,253,247,.96);border-radius:24px;padding:22px 20px 18px;box-shadow:0 20px 50px -14px rgba(20,30,25,.5);text-align:center;display:flex;flex-direction:column;align-items:center;gap:8px;animation:tke-pop .45s cubic-bezier(.2,1.4,.4,1) both}
@keyframes tke-pop{from{opacity:0;transform:translateY(-44%) scale(.9)}to{opacity:1;transform:translateY(-50%)}}
.tke-panel h3{margin:0;font-size:22px;font-weight:600;line-height:1.15}
.tke-panel p{margin:0;font-family:var(--tk-font-body,"Nunito",system-ui,sans-serif);font-size:15px;line-height:1.4;color:#4A5852}
.tke-panel .tke-meta{font-size:13px;color:#6E7C75}
.tke-btn{margin-top:6px;height:48px;padding:0 22px;border-radius:999px;border:0;background:#2F6B4F;color:#fff;font:600 16px var(--tk-font-ui,"Fredoka",system-ui,sans-serif);cursor:pointer}
.tke-walk{position:absolute;inset:0;background:rgba(22,40,32,.38);backdrop-filter:blur(3px);display:none}
.tke-walk.on{display:block}
.tke-walk .tke-panel{animation:none}
.tke-card canvas{position:static;width:132px;height:120px}
`;

/* ---------- palettes by time of day ---------- */
function palette(hour) {
  if (hour >= 5 && hour < 8) return { name: 'dawn', sky: ['#F4B9A3', '#FDE6C8'], sun: '#FFE7A8', hills: ['#A9CBA0', '#8BBC86', '#74AE74'], ground: ['#8DC277', '#B2D995'], tuft: '#5E9C55', flower: ['#FFFFFF', '#FFD86B', '#F59DB8'] };
  if (hour >= 8 && hour < 17) return { name: 'day', sky: ['#7EC6F1', '#DDF2FB'], sun: '#FFF4C2', hills: ['#97CE8F', '#79BC75', '#63AC63'], ground: ['#7DBF69', '#A8DA8A'], tuft: '#4F9446', flower: ['#FFFFFF', '#FFD34D', '#E989C8'] };
  if (hour >= 17 && hour < 20) return { name: 'dusk', sky: ['#6A6DB5', '#F7B48C'], sun: '#FFC98A', hills: ['#7C9A8A', '#668876', '#557A63'], ground: ['#5F905D', '#86AE72'], tuft: '#3F6E45', flower: ['#FFE9F0', '#FFC56B', '#D9A2E8'] };
  return { name: 'night', sky: ['#141A3C', '#3D4180'], sun: '#F2EFD8', hills: ['#2F425A', '#27384D', '#1F2F40'], ground: ['#2E4B40', '#41634F'], tuft: '#22392F', flower: ['#C9D4FF', '#F2E9A8', '#B9A7F0'] };
}

/* ---------- nest drawing ---------- */
function nest(c, x, y, r, rot = 0, t = 0) {
  c.save(); c.translate(x, y); c.rotate(rot);
  const g = c.createRadialGradient(-r * 0.35, -r * 0.4, r * 0.1, 0, 0, r);
  g.addColorStop(0, '#EBCB90'); g.addColorStop(0.65, '#C4914F'); g.addColorStop(1, '#94642E');
  c.fillStyle = g; c.beginPath(); c.arc(0, 0, r, 0, TAU); c.fill();
  c.save(); c.beginPath(); c.arc(0, 0, r, 0, TAU); c.clip();
  c.lineCap = 'round';
  for (let i = -3; i <= 3; i++) { // woven fibres
    c.strokeStyle = i % 2 ? 'rgba(120,80,35,.55)' : 'rgba(250,224,170,.6)';
    c.lineWidth = Math.max(1, r * 0.11);
    c.beginPath(); c.ellipse(0, i * r * 0.27, r * 1.05, r * 0.32, 0, 0.15, Math.PI - 0.15); c.stroke();
  }
  for (let i = -2; i <= 2; i++) {
    c.strokeStyle = i % 2 ? 'rgba(250,224,170,.45)' : 'rgba(110,72,30,.45)';
    c.lineWidth = Math.max(0.8, r * 0.07);
    c.beginPath(); c.ellipse(i * r * 0.36, 0, r * 0.3, r * 1.05, 0, -1.3, 1.3); c.stroke();
  }
  c.restore();
  c.strokeStyle = 'rgba(95,62,26,.7)'; c.lineWidth = Math.max(1, r * 0.06); c.beginPath(); c.arc(0, 0, r, 0, TAU); c.stroke();
  // leaf + seed tuft on top
  c.fillStyle = '#7DBF5F';
  c.save(); c.translate(r * 0.1, -r * 0.92); c.rotate(0.6 + Math.sin(t * 3) * 0.08);
  c.beginPath(); c.moveTo(0, 0); c.quadraticCurveTo(r * 0.32, -r * 0.3, 0, -r * 0.62); c.quadraticCurveTo(-r * 0.32, -r * 0.3, 0, 0); c.fill();
  c.strokeStyle = 'rgba(40,90,40,.5)'; c.lineWidth = Math.max(0.6, r * 0.03); c.beginPath(); c.moveTo(0, 0); c.lineTo(0, -r * 0.55); c.stroke();
  c.restore();
  c.fillStyle = 'rgba(255,255,255,.35)'; c.beginPath(); c.ellipse(-r * 0.4, -r * 0.42, r * 0.22, r * 0.13, -0.6, 0, TAU); c.fill();
  c.restore();
}
// Woven ring: back half before the kin, front half after it.
function ring(c, x, y, rx, ry, half, a = 1) {
  c.save(); c.globalAlpha *= a; c.lineCap = 'round';
  const from = half === 'back' ? Math.PI : 0, to = half === 'back' ? TAU : Math.PI;
  c.strokeStyle = '#A8763A'; c.lineWidth = Math.max(4, ry * 0.42);
  c.beginPath(); c.ellipse(x, y, rx, ry, 0, from, to); c.stroke();
  c.strokeStyle = 'rgba(245,215,160,.85)'; c.lineWidth = Math.max(1.5, ry * 0.12); c.setLineDash([ry * 0.35, ry * 0.3]);
  c.beginPath(); c.ellipse(x, y - ry * 0.05, rx, ry, 0, from, to); c.stroke();
  c.strokeStyle = 'rgba(100,64,26,.6)'; c.lineDashOffset = ry * 0.3;
  c.beginPath(); c.ellipse(x, y + ry * 0.1, rx, ry, 0, from, to); c.stroke();
  c.restore();
}

/* Remember how the player last interacted, so focus rings only appear for keyboard users. */
let lastInput = 'pointer';
addEventListener('keydown', () => { lastInput = 'key'; }, true);
addEventListener('pointerdown', () => { lastInput = 'pointer'; }, true);

/* ---------- open ---------- */
function open(container, opts) {
  if (!document.getElementById('tk-enc-style')) document.head.append(TK.h('style', { id: 'tk-enc-style' }, CSS));
  const sp = TK.speciesById(opts.species) || TK.SPECIES[0];
  const hour = opts.hour ?? new Date().getHours();
  const pal = palette(hour);
  const rng = TK.rng(Date.now() & 0xffff);
  const layer = TK.h('div', { class: 'tke' + (pal.name === 'night' ? ' night' : ''), role: 'dialog', 'aria-label': `Encounter: ${sp.name}` });
  const cvHost = TK.h('div', { style: { position: 'absolute', inset: '0' } });
  layer.append(cvHost);
  const top = TK.h('div', { class: 'tke-top' },
    TK.h('span', { class: 'tke-name' }, sp.name),
    TK.h('span', { class: 'tke-chip', style: { background: TK.tierColor(sp.tier) } }, TK.tierLabel(sp.tier)));
  const closeBtn = TK.h('button', { class: 'tke-x', type: 'button', 'aria-label': 'Leave it be', title: 'Leave it be' }, '✕');
  top.append(closeBtn);
  const count = TK.h('div', { class: 'tke-count', 'aria-live': 'polite' }, TK.h('i'), TK.h('span'));
  const hint = TK.h('div', { class: 'tke-hint' }, `Flick the nest up toward ${sp.name}`);
  const nestBtn = TK.h('button', { class: 'tke-nest', type: 'button', 'aria-label': `Throw a nest to ${sp.name}. Left and right arrows aim, Space throws.` });
  const walkLayer = TK.h('div', { class: 'tke-walk', 'aria-hidden': 'true' },
    TK.h('div', { class: 'tke-panel', role: 'status' },
      TK.h('h3', null, "You're on the move"),
      TK.h('p', null, `${sp.name} will wait right here. Throw when you've stopped.`),
      TK.h('p', { class: 'tke-meta' }, 'Eyes up while you walk. Encounters never run out of time.')));
  layer.append(top, hint, count, nestBtn, walkLayer);
  container.append(layer);

  const o = TK.canvas(cvHost);
  const c = o.ctx;
  let alive = true, t0 = performance.now() / 1000;

  /* scene props in world space (gx: -1.4..1.4, z: 0..1.6) */
  const tufts = Array.from({ length: 70 }, () => ({ gx: (rng() * 2 - 1) * 1.8, z: rng() * 1.55, h: 0.6 + rng() * 0.7, f: rng() < 0.18 ? Math.floor(rng() * 3) : -1, ph: rng() * 6 })).sort((a, b) => b.z - a.z);
  const stars = Array.from({ length: 40 }, () => ({ x: rng(), y: rng() * 0.36, r: 0.5 + rng() * 1.2, ph: rng() * 6 }));

  /* layout helpers (recomputed from current size) */
  let W = 360, H = 720;
  const persp = z => 1 / (1 + 1.3 * z);
  const groundY = z => lerp(H * 0.9, H * 0.6, z) - (z > 1 ? (z - 1) * H * 0.12 : 0);
  const sx = (gx, z) => W / 2 + gx * W * 0.62 * persp(z) + par * persp(z) * 0.6;
  const horizon = () => H * 0.42;
  const kinSize = () => Math.min(W * 0.5, H * 0.27);
  const restX = () => W / 2, restY = () => H - 90, nestR = () => Math.min(34, W * 0.09);
  let par = 0; const parS = TK.spring(0, TK.SPRING.gentle);

  /* kin behaviour */
  const SPOTS = [-0.7, 0, 0.7];
  const kin = { gx: 0, spot: 1, mode: 'sway', timer: 1.6, hopFrom: 0, hopTo: 0, hopT: 0, y: 0, squash: 0, mood: 'idle', moodT: 0, scale: 1, still: false, hidden: false, facing: 1 };
  const sqS = TK.spring(0, TK.SPRING.bouncy);
  function kinThink(dt) {
    if (phase !== 'idle' && phase !== 'fly' && phase !== 'drag') return;
    kin.timer -= dt;
    if (kin.mode === 'sway') {
      kin.gx = SPOTS[kin.spot] + Math.sin(now * 1.8) * 0.07;
      if (kin.timer <= 0) {
        if (rng() < 0.45) { kin.mode = 'still'; kin.timer = 1.1 + rng() * 0.7; kin.still = true; }
        else startHop();
      }
    } else if (kin.mode === 'still') {
      kin.mood = (kin.timer < 0.9 && kin.timer > 0.35 && rng() < 0.5) ? kin.mood : kin.mood;
      if (kin.timer <= 0) { kin.still = false; startHop(); }
    } else if (kin.mode === 'hop') {
      kin.hopT += dt / 0.55;
      const u = clamp(kin.hopT, 0, 1);
      kin.gx = lerp(kin.hopFrom, kin.hopTo, TK.ease(u));
      kin.y = Math.sin(u * Math.PI) * kinSize() * 0.28;
      if (u >= 1) { kin.y = 0; kin.mode = 'sway'; kin.timer = 1.4 + rng() * 1.6; sqS.x = 0.22; sqS.v = 0; TK.sfx('tick'); }
    }
  }
  function startHop() {
    let next = kin.spot; while (next === kin.spot) next = Math.floor(rng() * 3);
    kin.facing = SPOTS[next] > kin.gx ? 1 : -1;
    kin.hopFrom = kin.gx; kin.hopTo = SPOTS[next]; kin.spot = next; kin.hopT = 0; kin.mode = 'hop'; kin.still = false;
    sqS.x = -0.12; sqS.v = 0;
  }

  /* throw state */
  let phase = 'idle', pt = 0, now = 0;
  const nestP = { x: 0, y: 0, r: 0, rot: 0, z: 0, gx: 0, a: 1 };
  const flight = { gx0: 0, gx1: 0, zt: 1, T: 0.8, curve: 0, apex: 200, u: 0 };
  const caughtRing = { t: 0 };
  let throws = 0, best = null, wiggles = 0, wiggleN = 0, willCatch = false, label = null, result = null;
  const words = [], parts = [];
  const RANK = { Perfect: 3, Great: 2, Nice: 1 };
  let aim = 0, keyAim = false;

  const nestsLeft = () => opts.getNests();
  const syncCount = () => { count.lastChild.textContent = `Nests ${nestsLeft()}`; };
  syncCount();

  function say(text, x, y, color = '#FFFFFF', big = 1) { words.push({ text, x, y, t: 0, color, big }); }
  function puff(x, y, n, kind, s = 1) {
    for (let i = 0; i < n; i++) {
      const a = rng() * TAU, sp2 = (40 + rng() * 120) * s;
      parts.push({ x, y, vx: Math.cos(a) * sp2, vy: Math.sin(a) * sp2 * 0.6 - (kind === 'dust' ? 20 : 120 * s), life: 0, max: 0.6 + rng() * 0.6, kind, rot: rng() * 6, vr: (rng() - 0.5) * 8, size: (kind === 'dust' ? 6 + rng() * 8 : 5 + rng() * 6) * s, col: kind === 'leaf' ? ['#7DBF5F', '#A6D86F', '#5E9C55', '#F2C14E'][Math.floor(rng() * 4)] : kind === 'spark' ? ['#FFF6C8', '#FFFFFF', '#FFD9F0'][Math.floor(rng() * 3)] : 'rgba(220,205,170,.7)' });
    }
  }

  /* panels */
  let panel = null;
  function showPanel(node) { closePanel(); panel = node; layer.append(node); const b = node.querySelector('button'); if (b && lastInput === 'key') setTimeout(() => b.focus({ preventScroll: true }), 60); }
  function closePanel() { if (panel) { panel.remove(); panel = null; } }
  function outOfNests() {
    const b = TK.h('button', { class: 'tke-btn', type: 'button', onclick: () => finish(false) }, 'Back to the trail');
    showPanel(TK.h('div', { class: 'tke-panel', role: 'alertdialog', 'aria-label': 'Out of nests' },
      TK.h('h3', null, 'Out of nests'),
      TK.h('p', null, 'Every 40 active kcal weaves a new one. A brisk 10-minute walk is about one.'),
      TK.h('p', { class: 'tke-meta' }, `${sp.name} will still be here when you come back.`), b));
    TK.announce(`Out of nests. Every 40 active kilocalories weaves a new one. ${sp.name} will wait.`);
  }
  function successCard() {
    const host = TK.h('div');
    const btn = TK.h('button', { class: 'tke-btn', type: 'button', onclick: () => finish(true) }, 'Back to the trail');
    const card = TK.h('div', { class: 'tke-panel tke-card', role: 'alertdialog', 'aria-label': `${sp.name} joined your journal` },
      host,
      TK.h('h3', null, `${sp.name} joined your journal`),
      TK.h('p', null, sp.blurb),
      TK.h('p', { class: 'tke-meta' }, `Found at ${TK.fmt(opts.stepsToday || 0)} steps` + (best ? ` · ${best} throw` : '')),
      btn);
    showPanel(card);
    const mini = document.createElement('canvas'); host.append(mini);
    const dpr = Math.min(2.5, devicePixelRatio || 1); mini.width = 132 * dpr; mini.height = 120 * dpr;
    const mc = mini.getContext('2d'); mc.scale(dpr, dpr);
    TK.tick(() => {
      if (!mini.isConnected) return false;
      const tt = performance.now() / 1000;
      mc.clearRect(0, 0, 132, 120);
      mc.fillStyle = 'rgba(125,191,95,.18)'; mc.beginPath(); mc.ellipse(66, 106, 52, 10, 0, 0, TAU); mc.fill();
      TK.drawKin(mc, sp.id, 66, 106, 96 + Math.sin(tt * 3) * 2, tt, { mood: 'happy' });
      return true;
    });
    TK.announce(`${sp.name} joined your journal. Found at ${TK.fmt(opts.stepsToday || 0)} steps.`);
  }
  function finish(caught) {
    if (!alive) return;
    alive = false;
    layer.classList.add('out');
    setTimeout(() => layer.remove(), 280);
    document.removeEventListener('keydown', onEsc, true);
    opts.onClose && opts.onClose({ caught, species: sp.id, throws, best });
  }
  closeBtn.addEventListener('click', () => finish(false));
  const onEsc = e => { if (e.key === 'Escape' && alive) { e.preventDefault(); finish(caught()); } };
  const caught = () => result === 'caught';
  document.addEventListener('keydown', onEsc, true);

  /* input: drag the nest */
  let dragging = false, dragPos = { x: 0, y: 0 }, lastV = { vx: 0, vy: 0 }, curveAcc = 0;
  const walking = () => !!(opts.walking && opts.walking());
  TK.drag(nestBtn, {
    start(s) {
      if (phase !== 'idle' || walking() || !alive) return false;
      if (nestsLeft() <= 0) { outOfNests(); return false; }
      dragging = true; phase = 'drag'; keyAim = false; hint.style.opacity = '0';
      TK.haptic('select'); TK.sfx('tick');
      dragPos = { x: restX(), y: restY() };
    },
    move(s) {
      if (!dragging) return;
      dragPos.x = restX() + clamp(s.dx, -W * 0.45, W * 0.45);
      dragPos.y = restY() + clamp(s.dy, -H * 0.4, 40);
      lastV = { vx: s.vx, vy: s.vy };
      parS.to(-(dragPos.x - W / 2) * 0.12);
    },
    end(s, e) {
      if (!dragging) return;
      const dur = Math.max(0.05, ((e ? e.timeStamp : s.t0) - s.t0) / 1000);
      curveAcc = s.vx - s.dx / dur; // a flick that swings sideways at the end bends the flight
      dragging = false; parS.to(0);
      if (s.cancelled || walking()) { springBack(); return; }
      const speed = -s.vy;
      if (speed < 380 || -s.dy < 18) { springBack(); return; }
      launch(dragPos.x, dragPos.y, s.vx, s.vy, null);
    },
  });
  nestBtn.addEventListener('keydown', e => {
    if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
      e.preventDefault(); keyAim = true;
      aim = clamp(aim + (e.key === 'ArrowLeft' ? -0.15 : 0.15), -0.6, 0.6);
      TK.haptic('select'); TK.sfx('tick');
      TK.announce(aim === 0 ? 'Aiming straight at it' : `Aiming ${Math.abs(Math.round(aim / 0.15))} step${Math.abs(Math.round(aim / 0.15)) > 1 ? 's' : ''} ${aim < 0 ? 'left' : 'right'}`);
    } else if (e.key === ' ' || e.key === 'Enter') {
      e.preventDefault();
      if (phase !== 'idle' || walking()) return;
      if (nestsLeft() <= 0) { outOfNests(); return; }
      keyAim = true; curveAcc = 0; launch(restX(), restY(), 0, -1700, kin.gx + aim);
    }
  });
  nestBtn.addEventListener('focus', () => { keyAim = true; });
  nestBtn.addEventListener('blur', () => { keyAim = false; });

  function springBack() {
    phase = 'return'; pt = 0; nestP.fromX = dragPos.x; nestP.fromY = dragPos.y;
  }
  // Where a flick lands: speed sets depth (saturating, so hard flicks stay playable),
  // the flick's direction on screen sets the side it travels to.
  function predict(x, y, vx, vy) {
    const speed = Math.max(0, -vy);
    const zt = 0.25 + 1.05 * (1 - Math.exp(-Math.max(0, speed - 380) / 700));
    const gx0 = (x - W / 2) / (W * 0.62);
    const ratio = clamp(vx / Math.max(1, speed), -1.2, 1.2);
    const z = Math.min(zt, 1.5);
    const dyScreen = Math.max(40, y - groundY(z));
    const gx1 = gx0 + ratio * dyScreen / (W * 0.62 * persp(z));
    return { zt, gx0, gx1, p: clamp((speed - 380) / 1150, 0, 1.3) };
  }
  function launch(x, y, vx, vy, keyTarget) {
    const pr = predict(x, y, vx, vy);
    const p = pr.p, gx0 = pr.gx0;
    let zt = pr.zt, gx1 = pr.gx1;
    if (keyTarget != null) { zt = 1; gx1 = keyTarget; }
    flight.gx0 = gx0; flight.gx1 = gx1; flight.zt = zt; flight.T = TK.reduced() ? 0.35 : 0.48 + 0.28 * zt;
    flight.curve = clamp(curveAcc / 2200, -0.5, 0.5); flight.apex = H * (0.28 + 0.12 * Math.min(1, p)); flight.u = 0; flight.key = keyTarget != null;
    flight.short = zt < 0.72;
    if (!flight.short) {
      if (!opts.useNest()) { outOfNests(); springBack(); return; }
      throws++; syncCount();
    }
    hint.style.opacity = '0';
    phase = 'fly'; pt = 0;
    TK.haptic('medium'); TK.sfx('whoosh');
  }

  function land() {
    const z = flight.zt, gx = flight.gx1;
    const x = sx(gx, Math.min(z, 1.5)), y = groundY(Math.min(z, 1.5));
    if (flight.short) {
      phase = 'short'; pt = 0; nestP.fromX = x; nestP.fromY = y;
      say('A little further!', x, y - 40, '#FFFFFF', 0.9); puff(x, y, 6, 'dust', 0.7);
      TK.sfx('thud'); TK.haptic('light');
      TK.announce('Too gentle. The nest rolled back. Flick a little harder.');
      return;
    }
    const kx = kin.gx; const dx = Math.abs(gx - kx) / 0.26, dz = Math.abs(z - 1) / 0.3;
    const err = Math.hypot(dx, dz) + (kin.mode === 'hop' ? 0.25 : 0);
    if (err < 1) {
      label = err < 0.33 ? 'Perfect' : err < 0.66 ? 'Great' : 'Nice';
      if (flight.key && label !== 'Nice') label = 'Nice';
      if (!best || RANK[label] > RANK[best]) best = label;
      const base = { common: 0.9, uncommon: 0.72, rare: 0.55, elusive: 0.4 }[sp.tier];
      const fac = { Perfect: 1.12, Great: 1.0, Nice: 0.86 }[label];
      const chance = clamp(base * fac + (kin.still ? 0.1 : 0), 0.05, 0.97);
      willCatch = Math.random() < chance;
      wiggleN = willCatch ? 2 : (Math.random() < 0.5 ? 1 : 2); wiggles = 0;
      kin.mode = 'sway'; kin.y = 0;
      say(label + '!', sx(kin.gx, 1), groundY(1) - kinSize() * 1.15, label === 'Perfect' ? '#FFE27A' : '#FFFFFF', label === 'Perfect' ? 1.25 : 1.05);
      phase = 'open'; pt = 0; TK.sfx('pop'); TK.haptic('light');
      puff(sx(kin.gx, 1), groundY(1), 8, 'leaf', 0.8);
    } else {
      phase = 'miss'; pt = 0; nestP.fromX = x; nestP.fromY = y;
      say('Missed', x, y - 30, '#FFFFFF', 0.85); puff(x, y, 8, 'dust', persp(z) * 1.6);
      TK.sfx('miss'); TK.haptic('fail');
      kin.mood = 'surprised'; kin.moodT = 0.9;
      TK.announce(`Missed. ${nestsLeft()} nests left.`);
    }
  }

  /* ---------- frame ---------- */
  const loop = () => {
    if (!alive && !layer.isConnected) return false;
    const tt = performance.now() / 1000;
    let dt = Math.min(0.05, tt - (loop.last || tt)); loop.last = tt;
    now = tt - t0; W = o.w; H = o.h;
    const isWalking = walking();
    walkLayer.classList.toggle('on', isWalking);
    walkLayer.setAttribute('aria-hidden', String(!isWalking));
    if (isWalking && dragging) { dragging = false; springBack(); }
    parS.step(dt); par = parS.x;
    sqS.to(0); sqS.step(dt); kin.squash = sqS.x;
    if (kin.moodT > 0) { kin.moodT -= dt; if (kin.moodT <= 0) kin.mood = 'idle'; }
    kinThink(dt);
    if (kin.mode === 'still' && kin.timer < 0.85 && kin.timer > 0.3) kin.mood = 'sleep'; else if (kin.mode === 'still' && kin.mood === 'sleep') kin.mood = 'idle';
    if (kin.mode !== 'still' && kin.mood === 'sleep' && phase !== 'gather' && phase !== 'wiggle') kin.mood = 'idle';
    step(dt);
    draw();
    return true;
  };
  TK.tick(loop);

  function step(dt) {
    pt += dt;
    const R = TK.reduced() ? 0.4 : 1;
    if (phase === 'fly') {
      flight.u = clamp(pt / flight.T, 0, 1);
      if (flight.u >= 1) land();
    } else if (phase === 'return' && pt > 0.35 * R) phase = 'idle';
    else if (phase === 'short' && pt > 0.9 * R) phase = 'idle';
    else if (phase === 'miss' && pt > 0.9 * R) { phase = 'idle'; if (nestsLeft() <= 0) outOfNests(); }
    else if (phase === 'open' && pt > 0.38 * R) { phase = 'gather'; pt = 0; }
    else if (phase === 'gather' && pt > 0.42 * R) { phase = 'wiggle'; pt = 0; kin.hidden = true; }
    else if (phase === 'wiggle') {
      const per = 0.62 * R;
      if (wiggles < wiggleN && pt > per * wiggles + 0.2) { wiggles++; TK.sfx('wiggle'); TK.haptic('light'); }
      if (pt > per * wiggleN + 0.35) {
        if (willCatch) {
          phase = 'caught'; pt = 0; result = 'caught';
          puff(sx(kin.gx, 1), groundY(1) - 20, 18, 'leaf', 1.1); puff(sx(kin.gx, 1), groundY(1) - 30, 14, 'spark', 1);
          TK.sfx('chime'); TK.haptic('success');
        } else {
          phase = 'popout'; pt = 0; kin.hidden = false; kin.scale = 0.4; kin.mood = 'surprised'; kin.moodT = 1.3;
          sqS.x = -0.25; puff(sx(kin.gx, 1), groundY(1) - 10, 10, 'leaf', 0.8);
          say("Almost! It's still curious", sx(kin.gx, 1), groundY(1) - kinSize() * 1.2, '#FFFFFF', 0.85);
          TK.sfx('pop'); TK.haptic('fail');
          TK.announce(`Almost. ${sp.name} hopped out and is still curious. ${nestsLeft()} nests left.`);
        }
      }
    } else if (phase === 'caught' && pt > 1.0 * R && !panel) successCard();
    else if (phase === 'popout') {
      kin.scale = lerp(kin.scale, 1, 1 - Math.exp(-dt * 10));
      if (pt > 0.7 * R) { kin.scale = 1; phase = 'idle'; if (nestsLeft() <= 0) setTimeout(() => alive && !panel && outOfNests(), 500); }
    }
    for (const p of parts) { p.life += dt; p.x += p.vx * dt; p.y += p.vy * dt; p.vy += (p.kind === 'dust' ? 10 : 260) * dt; p.vx *= 0.985; p.rot += p.vr * dt; }
    for (let i = parts.length - 1; i >= 0; i--) if (parts[i].life > parts[i].max) parts.splice(i, 1);
    for (const w of words) w.t += dt;
    for (let i = words.length - 1; i >= 0; i--) if (words[i].t > 1.3) words.splice(i, 1);
  }

  function drawBackground() {
    const hz = horizon();
    let g = c.createLinearGradient(0, 0, 0, hz);
    g.addColorStop(0, pal.sky[0]); g.addColorStop(1, pal.sky[1]);
    c.fillStyle = g; c.fillRect(0, 0, W, hz + 2);
    if (pal.name === 'night') for (const s of stars) { c.fillStyle = `rgba(255,255,255,${0.4 + 0.5 * Math.abs(Math.sin(now * 1.3 + s.ph))})`; c.beginPath(); c.arc(s.x * W, s.y * H, s.r, 0, TAU); c.fill(); }
    // sun / moon
    const sunX = W * 0.78 + par * 0.15, sunY = hz * (pal.name === 'day' ? 0.32 : 0.62);
    const sg = c.createRadialGradient(sunX, sunY, 0, sunX, sunY, W * 0.3);
    sg.addColorStop(0, pal.sun); sg.addColorStop(0.2, pal.sun); sg.addColorStop(0.21, 'rgba(255,255,255,.25)'); sg.addColorStop(1, 'rgba(255,255,255,0)');
    c.fillStyle = sg; c.fillRect(0, 0, W, hz);
    if (pal.name === 'night') { c.fillStyle = pal.sky[0]; c.beginPath(); c.arc(sunX + W * 0.025, sunY - W * 0.015, W * 0.055, 0, TAU); c.fill(); }
    // clouds
    if (pal.name !== 'night') {
      c.fillStyle = 'rgba(255,255,255,.7)';
      [[0.15, 0.16, 1], [0.55, 0.1, 0.8]].forEach(([cx, cy, k], i) => {
        const x = ((cx * W + now * (6 + i * 4)) % (W + 160)) - 80 + par * 0.1, y = cy * H;
        [[0, 0, 26], [24, -10, 20], [46, 2, 22], [20, 8, 22]].forEach(([dx, dy, r]) => { c.beginPath(); c.arc(x + dx * k, y + dy * k, r * k, 0, TAU); c.fill(); });
      });
    }
    // hills: three parallax layers
    pal.hills.forEach((col, i) => {
      const base = hz + i * H * 0.035, amp = H * (0.035 - i * 0.006), shift = par * (0.25 + i * 0.25);
      c.fillStyle = col; c.beginPath(); c.moveTo(0, H);
      for (let x = 0; x <= W; x += 8) c.lineTo(x, base - amp * (0.6 + 0.4 * Math.sin((x + shift) / W * (3 + i) + i * 1.7)) - (i === 0 ? H * 0.02 : 0));
      c.lineTo(W, H); c.closePath(); c.fill();
    });
    // ground
    const gTop = hz + H * 0.09;
    g = c.createLinearGradient(0, gTop, 0, H);
    g.addColorStop(0, pal.ground[0]); g.addColorStop(1, pal.ground[1]);
    c.fillStyle = g; c.beginPath(); c.moveTo(0, gTop + 6);
    for (let x = 0; x <= W; x += 10) c.lineTo(x, gTop + Math.sin(x / 60 + par * 0.01) * 3);
    c.lineTo(W, H); c.lineTo(0, H); c.closePath(); c.fill();
    // mown path toward the kin
    c.fillStyle = 'rgba(255,255,255,.08)';
    c.beginPath(); c.moveTo(sx(-0.55, 0), groundY(0) + 40); c.lineTo(sx(-0.85, 1.2), groundY(1.2)); c.lineTo(sx(0.85, 1.2), groundY(1.2)); c.lineTo(sx(0.55, 0), groundY(0) + 40); c.closePath(); c.fill();
  }
  function drawTuft(tf, front) {
    if (front ? tf.z >= 0.98 : tf.z < 0.98) return;
    const k = persp(tf.z), x = sx(tf.gx, tf.z), y = groundY(tf.z), hh = 22 * tf.h * k * (W / 360);
    if (y < horizon() + H * 0.08) return;
    c.strokeStyle = pal.tuft; c.lineWidth = Math.max(1, 2.4 * k); c.lineCap = 'round';
    for (let i = -2; i <= 2; i++) { const sw = Math.sin(now * 1.5 + tf.ph + i) * 2 * k; c.beginPath(); c.moveTo(x + i * 3 * k, y); c.quadraticCurveTo(x + i * 5 * k, y - hh * 0.5, x + i * 7 * k + sw, y - hh * (1 - Math.abs(i) * 0.15)); c.stroke(); }
    if (tf.f >= 0) {
      const fx = x + 4 * k, fy = y - hh * 1.05;
      c.fillStyle = pal.flower[tf.f]; for (let p = 0; p < 5; p++) { const a = p / 5 * TAU + tf.ph; c.beginPath(); c.arc(fx + Math.cos(a) * 3.2 * k, fy + Math.sin(a) * 3.2 * k, 2.6 * k, 0, TAU); c.fill(); }
      c.fillStyle = '#F2B33D'; c.beginPath(); c.arc(fx, fy, 2 * k, 0, TAU); c.fill();
    }
  }

  function draw() {
    c.clearRect(0, 0, W, H);
    drawBackground();
    for (const tf of tufts) drawTuft(tf, true); // far tufts (z >= 0.98) behind the kin
    const kx = sx(kin.gx, 1), ky = groundY(1), ks = kinSize();
    // predicted landing ellipse while dragging
    if (phase === "drag" && -lastV.vy > 380) {
      const { zt, gx1 } = predict(dragPos.x, dragPos.y, lastV.vx, lastV.vy);
      const z = Math.min(zt, 1.5), k = persp(z);
      c.strokeStyle = 'rgba(255,255,255,.75)'; c.lineWidth = 2; c.setLineDash([5, 5]);
      c.beginPath(); c.ellipse(sx(gx1, z), groundY(z), 34 * k * 1.6, 9 * k * 1.6, 0, 0, TAU); c.stroke(); c.setLineDash([]);
    } else if (phase === 'idle' && keyAim && document.activeElement === nestBtn) {
      const ax = sx(kin.gx + aim, 1);
      c.strokeStyle = 'rgba(255,255,255,.85)'; c.lineWidth = 2; c.setLineDash([5, 5]);
      c.beginPath(); c.ellipse(ax, ky, 30, 8, 0, 0, TAU); c.stroke(); c.setLineDash([]);
    }
    // kin + capture ring
    const inRing = phase === 'open' || phase === 'gather';
    const ringU = phase === 'open' ? TK.ease(pt / 0.38) : phase === 'gather' ? 1 - TK.ease(pt / 0.42) : 0;
    const rrx = lerp(14, ks * 0.42, ringU), rry = rrx * 0.32;
    if (inRing) ring(c, kx, ky - 4, rrx, rry, 'back');
    if (!kin.hidden && phase !== 'caught' && phase !== 'wiggle') {
      let sc = kin.scale, yy = ky - kin.y;
      if (phase === 'gather') { sc = lerp(1, 0.25, TK.ease(pt / 0.42)); yy = ky; }
      TK.drawKin(c, sp.id, kx, yy, ks * sc, now, { mood: phase === 'gather' ? 'sleep' : kin.mood, squash: kin.squash, facing: kin.facing });
    }
    if (inRing) ring(c, kx, ky - 4, rrx, rry, 'front');
    // closed nest wiggling / caught
    if (phase === 'gather' && pt > 0.25 || phase === 'wiggle' || phase === 'caught') {
      const per = 0.62 * (TK.reduced() ? 0.4 : 1);
      const local = phase === 'wiggle' ? (pt % per) / per : 1;
      const wob = phase === 'wiggle' && Math.floor(pt / per) < wiggleN ? Math.sin(local * Math.PI * 2) * 0.32 * Math.sin(local * Math.PI) : 0;
      const r = ks * 0.17;
      nest(c, kx, ky - r * 0.9, r, wob, now);
      if (phase === 'caught') {
        c.save(); c.globalAlpha = clamp(1 - pt / 1.2, 0, 1);
        c.strokeStyle = '#FFF6C8'; c.lineWidth = 3; c.beginPath(); c.arc(kx, ky - r, r + pt * 60, 0, TAU); c.stroke(); c.restore();
      }
    }
    for (const tf of tufts) drawTuft(tf, false); // near tufts in front of the kin
    // nest in hand / in flight / landing
    const R0 = nestR();
    if (phase === 'idle' || phase === 'drag' || phase === 'return') {
      let x = restX(), y = restY();
      if (phase === 'drag') { x = dragPos.x; y = dragPos.y; }
      if (phase === 'return') { const u = TK.ease(pt / 0.35); x = lerp(nestP.fromX, restX(), u); y = lerp(nestP.fromY, restY(), u); }
      if (nestsLeft() > 0 || phase !== 'idle') {
        const bob = phase === 'idle' ? Math.sin(now * 2.2) * 2 : 0;
        c.fillStyle = 'rgba(30,40,30,.18)'; c.beginPath(); c.ellipse(restX(), restY() + R0 + 8, R0 * 0.8, 6, 0, 0, TAU); c.fill();
        nest(c, x, y + bob, R0 * (phase === 'drag' ? 1.08 : 1), phase === 'drag' ? (x - restX()) * 0.004 : 0, now);
      }
    } else if (phase === 'fly') {
      const u = flight.u, z = flight.zt * u;
      const gx = lerp(flight.gx0, flight.gx1, u) - flight.curve * Math.sin(Math.PI * u) * 0.5;
      const k = persp(z);
      const gyy = groundY(Math.min(z, 1.5));
      const hgt = flight.apex * 4 * u * (1 - u) * (0.4 + 0.6 * k);
      const x = sx(gx, z), y = gyy - hgt - R0 * k;
      // ground shadow
      c.fillStyle = `rgba(30,40,30,${0.22 * (1 - u * 0.4)})`; c.beginPath(); c.ellipse(x, gyy, R0 * k * 0.9, R0 * k * 0.25, 0, 0, TAU); c.fill();
      const startY = lerp(restY(), y, Math.min(1, u * 6));
      nest(c, x, u < 0.16 ? startY : y, R0 * k * 1.05, u * 9 + flight.curve * u * 6, now);
    } else if (phase === 'short' || phase === 'miss') {
      const R = TK.reduced() ? 0.4 : 1;
      const u = clamp(pt / (0.9 * R), 0, 1);
      const z = Math.min(flight.zt, 1.5), k = persp(z);
      const bounce = Math.abs(Math.sin(u * Math.PI * 2.4)) * (1 - u) * 26 * k;
      let x = nestP.fromX, y = nestP.fromY - R0 * k - bounce, r = R0 * k, a = 1;
      if (phase === 'short') { const v = TK.ease(clamp((u - 0.35) / 0.65, 0, 1)); x = lerp(nestP.fromX, restX(), v); y = lerp(y, restY(), v); r = lerp(R0 * k, R0, v); }
      else a = 1 - clamp((u - 0.5) / 0.5, 0, 1);
      c.save(); c.globalAlpha = a; nest(c, x, y, r, u * 4, now); c.restore();
    }
    // particles
    for (const p of parts) {
      const a = 1 - p.life / p.max;
      c.save(); c.globalAlpha = clamp(a, 0, 1); c.translate(p.x, p.y); c.rotate(p.rot);
      if (p.kind === 'dust') { c.fillStyle = p.col; c.beginPath(); c.arc(0, 0, p.size * (1 + p.life), 0, TAU); c.fill(); }
      else if (p.kind === 'leaf') { c.fillStyle = p.col; c.beginPath(); c.moveTo(0, -p.size); c.quadraticCurveTo(p.size * 0.6, 0, 0, p.size); c.quadraticCurveTo(-p.size * 0.6, 0, 0, -p.size); c.fill(); }
      else { c.fillStyle = p.col; c.beginPath(); for (let i = 0; i < 8; i++) { const an = i * Math.PI / 4, rr = i % 2 ? p.size * 0.3 : p.size; c.lineTo(Math.cos(an) * rr, Math.sin(an) * rr); } c.closePath(); c.fill(); }
      c.restore();
    }
    // floating words
    for (const w of words) {
      const u = w.t / 1.3, a = u < 0.75 ? 1 : 1 - (u - 0.75) / 0.25;
      const s = (u < 0.15 ? lerp(0.6, 1.1, u / 0.15) : lerp(1.1, 1, Math.min(1, (u - 0.15) / 0.2))) * w.big;
      c.save(); c.globalAlpha = clamp(a, 0, 1); c.translate(w.x, w.y - u * 30); c.scale(s, s);
      c.font = '600 24px "Fredoka", "Nunito", system-ui, sans-serif'; c.textAlign = 'center'; c.textBaseline = 'middle';
      c.lineWidth = 6; c.strokeStyle = 'rgba(31,43,38,.55)'; c.lineJoin = 'round'; c.strokeText(w.text, 0, 0);
      c.fillStyle = w.color; c.fillText(w.text, 0, 0); c.restore();
    }
  }

  layer.__dbg = () => ({ phase, zt: flight.zt, gx1: flight.gx1, kinGx: kin.gx, label, willCatch, throws, result });
  if (lastInput === 'key') setTimeout(() => nestBtn.focus({ preventScroll: true }), 80);
  TK.announce(`${sp.name} is here. ${TK.tierLabel(sp.tier)}. ${nestsLeft()} nests. Flick the nest upward, or press Space to throw.`);
  return { close: () => finish(false), el: layer };
}

TK.encounter = { open };
})();
