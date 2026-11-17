/* Trailkin creatures: 12 original kin drawn entirely with canvas paths.
   TK.drawKin(ctx, id, x, y, size, t, { mood, silhouette, facing, squash, alpha })
   x = centre, y = ground under the feet, size = total height in px, t = seconds. */
(() => {
'use strict';
const TK = window.TK;
const SIL = '#2E3B36';
const TAU = Math.PI * 2;

/* ---------- path helpers ---------- */
const ell = (c, x, y, rx, ry, rot = 0) => { c.beginPath(); c.ellipse(x, y, Math.max(0.01, rx), Math.max(0.01, ry), rot, 0, TAU); };
// Blob whose width tapers toward the top (topW < 1 = pear) or bottom (botW < 1 = bean-ish).
const blob = (c, cx, cy, rx, ry, topW = 1, botW = 1, n = 44) => {
  c.beginPath();
  for (let i = 0; i <= n; i++) {
    const a = (i / n) * TAU, s = Math.sin(a);
    const f = s < 0 ? 1 + (topW - 1) * -s : 1 + (botW - 1) * s;
    const px = cx + Math.cos(a) * rx * f, py = cy + s * ry;
    i ? c.lineTo(px, py) : c.moveTo(px, py);
  }
  c.closePath();
};
const leaf = (c, x, y, len, wid, ang) => {
  c.save(); c.translate(x, y); c.rotate(ang); c.beginPath();
  c.moveTo(0, 0); c.quadraticCurveTo(wid, -len * 0.5, 0, -len); c.quadraticCurveTo(-wid, -len * 0.5, 0, 0); c.restore();
};
const drop = (c, x, y, r, h, ang = 0) => { // teardrop, tip up
  c.save(); c.translate(x, y); c.rotate(ang); c.beginPath();
  c.moveTo(0, -h); c.bezierCurveTo(r * 0.9, -h * 0.45, r * 1.1, 0, 0, r * 0.15);
  c.bezierCurveTo(-r * 1.1, 0, -r * 0.9, -h * 0.45, 0, -h); c.restore();
};
const star4 = (c, x, y, r) => {
  c.beginPath();
  for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4 - Math.PI / 2, rr = i % 2 ? r * 0.32 : r; const px = x + Math.cos(a) * rr, py = y + Math.sin(a) * rr; i ? c.lineTo(px, py) : c.moveTo(px, py); }
  c.closePath();
};
const lw = (P, k) => Math.max(0.8, P.S * k);
const stroke = (c, P, col, k = 0.02) => { c.lineWidth = lw(P, k); c.strokeStyle = col; c.lineJoin = 'round'; c.lineCap = 'round'; c.stroke(); };

/* ---------- species ---------- */
// w = body width / size, bh = body height / size, shape: round | bean | pear | squat | stem
const SPECIES = [
  { id: 'mossbit', name: 'Mossbit', tier: 'common', blurb: 'Naps in park lawns and wakes up for anyone who walks past before noon.',
    shape: 'round', w: 0.64, bh: 0.6, body: '#86C06C', belly: '#D9EDB8', dark: '#3D6A37', ph: 0.3, blink: 3.6,
    front(c, P, col) {
      const { S, top } = P; const sway = Math.sin(P.t * 1.7) * 0.12;
      c.save(); c.translate(0, top + S * 0.02); c.rotate(sway * 0.4);
      c.beginPath(); c.moveTo(0, 0); c.quadraticCurveTo(S * 0.02, -S * 0.08, 0, -S * 0.14); stroke(c, P, col('#4F8A3E'), 0.022);
      c.fillStyle = col('#9ED46F'); leaf(c, 0, -S * 0.12, S * 0.15, S * 0.07, -1.0 + sway); c.fill();
      c.fillStyle = col('#7CC055'); leaf(c, 0, -S * 0.13, S * 0.12, S * 0.055, 0.9 + sway); c.fill();
      c.restore();
      if (!P.sil) { c.fillStyle = 'rgba(61,106,55,.35)'; [[-0.2, -0.33], [0.16, -0.38], [0.24, -0.25], [-0.08, -0.42]].forEach(([dx, dy]) => { ell(c, P.bw * dx, P.cy + P.bh * dy, S * 0.018, S * 0.014); c.fill(); }); }
    } },
  { id: 'puddlepip', name: 'Puddlepip', tier: 'common', blurb: 'Hops out of puddles after rain and follows your footprints home.',
    shape: 'bean', w: 0.58, bh: 0.62, body: '#6DB7E6', belly: '#D2EDFB', dark: '#2C5E86', ph: 1.1, blink: 4.2,
    back(c, P, col) {
      const { S, bw, cy } = P; const w = Math.sin(P.t * 3) * 0.15;
      c.save(); c.translate(bw * 0.45, cy + P.bh * 0.25); c.rotate(0.5 + w); c.beginPath();
      c.moveTo(0, 0); c.quadraticCurveTo(S * 0.16, -S * 0.04, S * 0.2, -S * 0.12); c.quadraticCurveTo(S * 0.12, S * 0.02, 0, S * 0.06); c.closePath();
      c.fillStyle = col('#4F9AD0'); c.fill(); c.restore();
    },
    front(c, P, col) {
      const { S, top } = P; const wob = Math.sin(P.t * 2.6) * 0.08;
      c.fillStyle = col('#9FD8F7'); drop(c, 0, top + S * 0.05, S * 0.075, S * 0.17, wob); c.fill();
      if (!P.sil) { c.fillStyle = 'rgba(255,255,255,.75)'; ell(c, -S * 0.02, top - S * 0.04, S * 0.014, S * 0.028, 0.3); c.fill(); }
    } },
  { id: 'pebblet', name: 'Pebblet', tier: 'common', blurb: 'Sits still on gravel paths. Count your steps and it starts counting with you.',
    shape: 'squat', w: 0.76, bh: 0.54, body: '#A9A8B8', belly: '#DEDDE7', dark: '#55546B', ph: 2.2, blink: 5.0,
    back(c, P, col) {
      const { bw, top, S } = P;
      c.fillStyle = col('#8E8DA0'); ell(c, -bw * 0.3, top + S * 0.06, S * 0.06, S * 0.055); c.fill(); ell(c, bw * 0.3, top + S * 0.06, S * 0.06, S * 0.055); c.fill();
      if (!P.sil) { c.fillStyle = '#C9A9B6'; ell(c, -bw * 0.3, top + S * 0.065, S * 0.03, S * 0.028); c.fill(); ell(c, bw * 0.3, top + S * 0.065, S * 0.03, S * 0.028); c.fill(); }
    },
    front(c, P, col) {
      const { bw, bh, cy, S } = P;
      c.fillStyle = col('#8A899C');
      [[-0.3, -0.18, 0.06], [0.28, -0.26, 0.045], [0.34, 0.02, 0.035], [-0.12, -0.4, 0.035]].forEach(([dx, dy, r], i) => {
        c.beginPath(); for (let k = 0; k < 6; k++) { const a = k / 6 * TAU + i, rr = S * r * (0.8 + ((k * 7 + i) % 3) * 0.12); const px = bw * dx + Math.cos(a) * rr, py = cy + bh * dy + Math.sin(a) * rr * 0.8; k ? c.lineTo(px, py) : c.moveTo(px, py); } c.closePath(); c.fill();
      });
      if (!P.sil) { c.fillStyle = '#E8D86A'; ell(c, bw * 0.05, cy - bh * 0.47, S * 0.022, S * 0.015); c.fill(); ell(c, bw * 0.11, cy - bh * 0.45, S * 0.014, S * 0.01); c.fill(); }
    } },
  { id: 'thistlehop', name: 'Thistlehop', tier: 'common', blurb: 'Lives in wild verges and springs out when your pace picks up.',
    shape: 'pear', w: 0.56, bh: 0.55, body: '#A98BDB', belly: '#E6DAF7', dark: '#583D8C', ph: 0.7, blink: 3.2,
    back(c, P, col) {
      const { bw, top, S } = P; const f = Math.sin(P.t * 2) * 0.05;
      [[-1, -0.42 - f], [1, 0.42 + f]].forEach(([sd, ang]) => {
        c.save(); c.translate(sd * bw * 0.22, top + S * 0.06); c.rotate(ang); c.beginPath();
        c.moveTo(-S * 0.055, 0); c.quadraticCurveTo(-S * 0.03, -S * 0.2, 0, -S * 0.24); c.quadraticCurveTo(S * 0.03, -S * 0.2, S * 0.055, 0); c.closePath();
        c.fillStyle = col('#9579CF'); c.fill();
        if (!P.sil) { c.beginPath(); c.moveTo(-S * 0.025, -S * 0.02); c.quadraticCurveTo(0, -S * 0.17, S * 0.025, -S * 0.02); c.closePath(); c.fillStyle = '#F1A9D8'; c.fill(); }
        c.restore();
      });
    },
    front(c, P, col) {
      const { top, S } = P;
      c.save(); c.translate(0, top + S * 0.02);
      c.fillStyle = col('#E070C6');
      for (let i = -2; i <= 2; i++) { c.save(); c.rotate(i * 0.32 + Math.sin(P.t * 3 + i) * 0.04); c.beginPath(); c.moveTo(-S * 0.016, 0); c.lineTo(0, -S * 0.1); c.lineTo(S * 0.016, 0); c.closePath(); c.fill(); c.restore(); }
      c.fillStyle = col('#79B65A'); ell(c, 0, 0, S * 0.045, S * 0.022); c.fill();
      c.restore();
    } },
  { id: 'burrowbun', name: 'Burrowbun', tier: 'common', blurb: 'Peeks out of hedges in the evening and loves a slow loop round the block.',
    shape: 'pear', w: 0.6, bh: 0.5, body: '#C99D6D', belly: '#F4E6D1', dark: '#6D4A2B', ph: 1.8, blink: 4.6,
    back(c, P, col) {
      const { bw, top, S, cy, bh } = P; const fl = Math.sin(P.t * 1.6) * 0.06;
      [[-1, -0.18, 0], [1, 0.62 + fl, 1]].forEach(([sd, ang, flop]) => {
        c.save(); c.translate(sd * bw * 0.16, top + S * 0.05); c.rotate(ang);
        ell(c, 0, -S * 0.16, S * 0.058, S * 0.18); c.fillStyle = col('#B88B5C'); c.fill();
        if (!P.sil) { ell(c, 0, -S * 0.15, S * 0.03, S * 0.14); c.fillStyle = '#F2B9A8'; c.fill(); }
        c.restore();
      });
      c.fillStyle = col('#FFF8EE'); ell(c, -bw * 0.5, cy + bh * 0.22, S * 0.07, S * 0.065); c.fill();
    } },
  { id: 'dewmoth', name: 'Dewmoth', tier: 'common', blurb: 'Drifts over morning grass, glittering with dew. Early walks find it first.',
    shape: 'round', w: 0.54, bh: 0.5, body: '#F3E393', belly: '#FFF7CF', dark: '#8C7630', ph: 2.6, blink: 3.9,
    back(c, P, col) {
      const { bw, cy, S } = P; const flap = Math.sin(P.t * 7) * 0.18;
      [[-1, -flap], [1, flap]].forEach(([sd, f]) => {
        c.save(); c.translate(sd * bw * 0.32, cy - P.bh * 0.08); c.rotate(sd * (0.5 + f)); c.scale(sd, 1);
        ell(c, S * 0.12, -S * 0.07, S * 0.15, S * 0.11, -0.35);
        if (P.sil) { c.fillStyle = SIL; c.fill(); }
        else { c.fillStyle = 'rgba(226,236,255,.88)'; c.fill(); c.strokeStyle = 'rgba(176,160,224,.9)'; c.lineWidth = lw(P, 0.012); c.stroke();
          c.fillStyle = 'rgba(190,170,240,.5)'; ell(c, S * 0.14, -S * 0.08, S * 0.04, S * 0.035); c.fill(); }
        c.restore();
      });
    },
    front(c, P, col) {
      const { top, S } = P;
      [-1, 1].forEach(sd => {
        c.beginPath(); c.moveTo(sd * S * 0.04, top + S * 0.02); c.quadraticCurveTo(sd * S * 0.05, top - S * 0.08, sd * S * 0.11, top - S * 0.1);
        stroke(c, P, col('#8C7630'), 0.014);
        c.fillStyle = col('#FFF2B0'); ell(c, sd * S * 0.115, top - S * 0.105, S * 0.03, S * 0.025); c.fill();
      });
    } },
  { id: 'emberkit', name: 'Emberkit', tier: 'uncommon', blurb: 'Glows warm on chilly evenings. Shows up once you are halfway to your goal.',
    shape: 'bean', w: 0.6, bh: 0.6, body: '#F08B4C', belly: '#FFD9A8', dark: '#87391A', ph: 0.4, blink: 4.0,
    back(c, P, col) {
      const { bw, top, S } = P;
      [[-1], [1]].forEach(([sd]) => {
        c.save(); c.translate(sd * bw * 0.28, top + S * 0.07); c.rotate(sd * 0.35); c.beginPath();
        c.moveTo(-S * 0.05, 0); c.lineTo(0, -S * 0.11); c.lineTo(S * 0.05, 0); c.closePath(); c.fillStyle = col('#D9692E'); c.fill();
        if (!P.sil) { c.beginPath(); c.moveTo(-S * 0.018, -S * 0.07); c.lineTo(0, -S * 0.11); c.lineTo(S * 0.018, -S * 0.07); c.closePath(); c.fillStyle = '#5A2410'; c.fill(); }
        c.restore();
      });
    },
    front(c, P, col) {
      const { top, S, cy, bh, bw } = P;
      if (!P.sil) { const g = c.createRadialGradient(0, cy + bh * 0.2, 0, 0, cy + bh * 0.2, bw * 0.32); g.addColorStop(0, 'rgba(255,236,150,.85)'); g.addColorStop(1, 'rgba(255,200,120,0)'); c.fillStyle = g; ell(c, 0, cy + bh * 0.2, bw * 0.32, bh * 0.25); c.fill(); }
      const fl = k => Math.sin(P.t * 9 + k) * 0.06;
      [[-0.06, 0.12, -0.35], [0, 0.2, 0], [0.06, 0.13, 0.35]].forEach(([dx, h, a], k) => {
        if (P.sil) c.fillStyle = SIL; else { const g = c.createLinearGradient(0, top, 0, top - S * h); g.addColorStop(0, '#FF8A3D'); g.addColorStop(1, '#FFE066'); c.fillStyle = g; }
        drop(c, S * dx, top + S * 0.05, S * 0.05, S * h, a + fl(k)); c.fill();
      });
    } },
  { id: 'gustlet', name: 'Gustlet', tier: 'uncommon', blurb: 'Rides the wind on bridges and hilltops. Likes a brisk pace.',
    shape: 'round', w: 0.58, bh: 0.54, body: '#E4F6F2', belly: '#FFFFFF', dark: '#3E8A80', ph: 3.0, blink: 4.4,
    back(c, P, col) {
      const { bw, cy, S } = P; const fl = Math.sin(P.t * 4) * 0.12;
      [-1, 1].forEach(sd => {
        c.save(); c.translate(sd * bw * 0.42, cy - P.bh * 0.05); c.scale(sd, 1); c.rotate(-0.3 + fl);
        c.beginPath(); c.moveTo(0, 0);
        for (let i = 0; i <= 24; i++) { const a = i / 24 * Math.PI * 2.2, r = S * 0.16 * (1 - i / 30); c.lineTo(Math.cos(a - 1.2) * r + S * 0.06, Math.sin(a - 1.2) * r * 0.8 - S * 0.02); }
        c.closePath(); c.fillStyle = col('#9EDDD3'); c.fill();
        c.restore();
      });
    },
    front(c, P, col) {
      const { top, S } = P;
      c.beginPath();
      for (let i = 0; i <= 20; i++) { const a = i / 20 * Math.PI * 2.4, r = S * 0.045 * (i / 20); const px = Math.cos(a) * r, py = top + S * 0.09 + Math.sin(a) * r; i ? c.lineTo(px, py) : c.moveTo(px, py); }
      stroke(c, P, col('#6CC7B9'), 0.016);
      c.beginPath(); c.moveTo(-S * 0.02, top + S * 0.01); c.quadraticCurveTo(S * 0.02, top - S * 0.08, S * 0.09, top - S * 0.06 + Math.sin(P.t * 4) * S * 0.01);
      stroke(c, P, col('#6CC7B9'), 0.02);
    } },
  { id: 'brambleskip', name: 'Brambleskip', tier: 'uncommon', blurb: 'Hides in hedgerows full of berries and skips along beside long walks.',
    shape: 'round', w: 0.6, bh: 0.56, body: '#4F9161', belly: '#C2E2B8', dark: '#22502E', ph: 1.4, blink: 3.5,
    back(c, P, col) {
      const { bw, top, S, cy, bh } = P;
      c.fillStyle = col('#6DB46E'); leaf(c, -bw * 0.25, top + S * 0.08, S * 0.16, S * 0.06, -0.8); c.fill(); leaf(c, bw * 0.25, top + S * 0.08, S * 0.16, S * 0.06, 0.8); c.fill();
      c.beginPath(); c.moveTo(bw * 0.45, cy + bh * 0.25);
      c.bezierCurveTo(bw * 0.8, cy + bh * 0.3, bw * 0.85, cy - bh * 0.1, bw * 0.65, cy - bh * 0.05 + Math.sin(P.t * 2) * S * 0.01);
      stroke(c, P, col('#3B7246'), 0.022);
      c.fillStyle = col('#3B7246'); [0.2, 0.55].forEach(k => { ell(c, bw * (0.55 + k * 0.25), cy + bh * (0.28 - k * 0.3), S * 0.012, S * 0.012); c.fill(); });
    },
    front(c, P, col) {
      const { bw, bh, cy, S } = P;
      [[-0.28, -0.22], [0.3, -0.3], [0.22, 0.05], [-0.05, -0.43]].forEach(([dx, dy]) => {
        c.fillStyle = col('#B23A62'); ell(c, bw * dx, cy + bh * dy, S * 0.032, S * 0.032); c.fill();
        if (!P.sil) { c.fillStyle = 'rgba(255,255,255,.7)'; ell(c, bw * dx - S * 0.01, cy + bh * dy - S * 0.01, S * 0.009, S * 0.009); c.fill(); }
      });
    } },
  { id: 'duskfin', name: 'Duskfin', tier: 'rare', blurb: 'Swims through the air at sunset. Comes to those who reach their goal.',
    shape: 'bean', w: 0.6, bh: 0.6, body: '#4E54A8', belly: '#9097E2', dark: '#1F2363', ph: 2.0, blink: 4.8, eyeLight: true,
    back(c, P, col) {
      const { bw, top, S } = P; const w = Math.sin(P.t * 2.4) * 0.08;
      [-1, 1].forEach(sd => {
        c.save(); c.translate(sd * bw * 0.44, P.cy - P.bh * 0.12); c.scale(sd, 1); c.rotate(0.15 + w);
        c.beginPath(); c.moveTo(0, 0); c.quadraticCurveTo(S * 0.1, -S * 0.1, S * 0.24, -S * 0.16); c.quadraticCurveTo(S * 0.14, -S * 0.02, S * 0.08, S * 0.05); c.closePath();
        c.fillStyle = col('#6D74D0'); c.fill();
        if (!P.sil) { c.strokeStyle = 'rgba(200,205,255,.6)'; c.lineWidth = lw(P, 0.008); [0.3, 0.55].forEach(k => { c.beginPath(); c.moveTo(S * 0.05 * k, S * 0.01); c.lineTo(S * 0.24 * k + S * 0.05, -S * 0.16 * k); c.stroke(); }); }
        c.restore();
      });
    },
    front(c, P, col) {
      const { bw, bh, cy, top, S } = P;
      c.beginPath(); c.moveTo(-S * 0.05, top + S * 0.03); c.quadraticCurveTo(-S * 0.01, top - S * 0.1, S * 0.09, top - S * 0.09 + Math.sin(P.t * 2.4) * S * 0.01); c.quadraticCurveTo(S * 0.03, top - S * 0.02, S * 0.05, top + S * 0.03); c.closePath();
      c.fillStyle = col('#6D74D0'); c.fill();
      c.fillStyle = col('#FFE8A0'); c.beginPath(); c.arc(0, top + S * 0.08, S * 0.035, 0.6, TAU - 0.6); c.arc(S * 0.015, top + S * 0.075, S * 0.028, TAU - 0.9, 0.9, true); c.closePath(); c.fill();
      if (!P.sil) [[-0.32, -0.1], [0.3, -0.2], [0.18, 0.18], [-0.2, 0.26], [0.38, 0.05]].forEach(([dx, dy], i) => {
        c.fillStyle = `rgba(255,255,255,${0.45 + 0.45 * Math.abs(Math.sin(P.t * 2 + i * 1.7))})`; star4(c, bw * dx, cy + bh * dy, S * 0.022); c.fill();
      });
    } },
  { id: 'glowcap', name: 'Glowcap', tier: 'rare', blurb: 'Lights up shady woodland paths. Rewards the days you go past your goal.',
    shape: 'stem', w: 0.42, bh: 0.5, body: '#F2E8D4', belly: '#FBF6EA', dark: '#7A6A4E', ph: 0.9, blink: 4.1, capTop: true,
    front(c, P, col) {
      const { top, S } = P; const pulse = 0.6 + 0.4 * Math.sin(P.t * 2.2);
      const capY = top + S * 0.05;
      c.beginPath(); c.moveTo(-S * 0.4, capY); c.bezierCurveTo(-S * 0.4, capY - S * 0.4, S * 0.4, capY - S * 0.4, S * 0.4, capY);
      c.quadraticCurveTo(0, capY + S * 0.08, -S * 0.4, capY); c.closePath();
      if (P.sil) c.fillStyle = SIL; else { const g = c.createLinearGradient(0, capY - S * 0.32, 0, capY); g.addColorStop(0, '#5FD0C4'); g.addColorStop(1, '#2E8F99'); c.fillStyle = g; }
      c.fill(); if (!P.sil) stroke(c, P, 'rgba(25,80,88,.6)', 0.016);
      if (!P.sil) [[-0.2, -0.17, 0.05], [0.12, -0.24, 0.04], [0.25, -0.1, 0.035], [-0.03, -0.08, 0.03], [-0.3, -0.06, 0.025]].forEach(([dx, dy, r]) => {
        c.save(); c.shadowColor = 'rgba(200,255,240,.95)'; c.shadowBlur = S * 0.06 * pulse;
        c.fillStyle = `rgba(232,255,248,${0.7 + 0.3 * pulse})`; ell(c, S * dx, capY + S * dy, S * r, S * r * 0.8); c.fill(); c.restore();
      });
    } },
  { id: 'aurorel', name: 'Aurorel', tier: 'elusive', blurb: 'Seen only on days you walk far beyond your goal. Nobody knows where it sleeps.',
    shape: 'round', w: 0.58, bh: 0.56, body: '#C9AEFF', belly: '#FFFFFF', dark: '#5E4592', ph: 2.9, blink: 5.2, rainbow: true, eyeLight: true,
    back(c, P, col) {
      const { bw, cy, bh, S } = P;
      c.beginPath(); const x0 = -bw * 0.4, y0 = cy + bh * 0.2;
      c.moveTo(x0, y0);
      for (let i = 1; i <= 24; i++) { const k = i / 24; c.lineTo(x0 - k * S * 0.42, y0 - k * S * 0.28 + Math.sin(P.t * 3 - k * 6) * S * 0.05 * k); }
      if (P.sil) c.strokeStyle = SIL; else { const g = c.createLinearGradient(x0, y0, x0 - S * 0.42, y0 - S * 0.3); g.addColorStop(0, '#FFB3D9'); g.addColorStop(0.5, '#B9A2FF'); g.addColorStop(1, '#8FE3E0'); c.strokeStyle = g; }
      c.lineWidth = lw(P, 0.05); c.lineCap = 'round'; c.stroke();
      [-1, 1].forEach(sd => { c.fillStyle = col('#B79CF5'); ell(c, sd * bw * 0.3, P.top + S * 0.05, S * 0.07, S * 0.065); c.fill(); });
    },
    front(c, P, col) {
      const { top, S } = P;
      [-1, 0, 1].forEach(k => {
        const yy = top - S * 0.08 - (k === 0 ? S * 0.04 : 0) + Math.sin(P.t * 2.5 + k) * S * 0.015;
        c.save(); if (!P.sil) { c.shadowColor = '#FFF4B8'; c.shadowBlur = S * 0.05; }
        c.fillStyle = col(['#FFC3E1', '#FFF4B8', '#A9F0EC'][k + 1]); ell(c, k * S * 0.07, yy, S * 0.024, S * 0.024); c.fill(); c.restore();
      });
    } },
];
const BY_ID = Object.fromEntries(SPECIES.map(s => [s.id, s]));
TK.SPECIES = SPECIES;
TK.speciesById = id => BY_ID[id];
TK.tierColor = tier => ({ common: '#6F9E6B', uncommon: '#3E9BD6', rare: '#8462D8', elusive: '#D9A419' })[tier] || '#888';
TK.tierLabel = tier => ({ common: 'Common', uncommon: 'Uncommon', rare: 'Rare', elusive: 'Elusive' })[tier] || tier;

/* ---------- face ---------- */
function face(c, P) {
  const { S, bw, bh, cy, sp, mood, t } = P;
  const eyeY = cy - bh * (sp.shape === 'stem' ? -0.02 : 0.06);
  const dx = bw * (sp.shape === 'stem' ? 0.25 : 0.22), r = S * 0.062;
  const period = sp.blink, ph = sp.ph * 3;
  const blinking = mood === 'idle' && ((t + ph) % period) < 0.13;
  const ink = '#241C2C';
  // cheeks
  c.fillStyle = sp.eyeLight ? 'rgba(255,170,200,.55)' : 'rgba(255,128,150,.42)';
  [-1, 1].forEach(sd => { ell(c, sd * (dx + r * 1.05), eyeY + r * 1.35, r * 0.78, r * 0.48); c.fill(); });
  c.lineCap = 'round'; c.lineJoin = 'round';
  [-1, 1].forEach(sd => {
    const ex = sd * dx;
    if (mood === 'sleep' || blinking) {
      c.beginPath();
      if (mood === 'sleep') c.arc(ex, eyeY - r * 0.2, r * 0.75, 0.25, Math.PI - 0.25); else { c.moveTo(ex - r * 0.8, eyeY); c.quadraticCurveTo(ex, eyeY + r * 0.35, ex + r * 0.8, eyeY); }
      c.lineWidth = Math.max(0.9, r * 0.32); c.strokeStyle = ink; c.stroke();
    } else if (mood === 'happy') {
      c.beginPath(); c.arc(ex, eyeY + r * 0.35, r * 0.75, Math.PI + 0.25, TAU - 0.25);
      c.lineWidth = Math.max(0.9, r * 0.34); c.strokeStyle = ink; c.stroke();
    } else if (mood === 'surprised') {
      c.fillStyle = '#FFFFFF'; ell(c, ex, eyeY, r * 1.0, r * 1.08); c.fill();
      c.lineWidth = Math.max(0.6, r * 0.12); c.strokeStyle = ink; c.stroke();
      c.fillStyle = ink; ell(c, ex, eyeY + r * 0.1, r * 0.42, r * 0.46); c.fill();
      c.fillStyle = '#FFFFFF'; ell(c, ex - r * 0.14, eyeY - r * 0.06, r * 0.14, r * 0.14); c.fill();
    } else {
      c.fillStyle = ink; ell(c, ex, eyeY, r * 0.86, r * 1.02); c.fill();
      if (sp.eyeLight) { c.fillStyle = 'rgba(160,140,255,.55)'; ell(c, ex, eyeY + r * 0.45, r * 0.55, r * 0.35); c.fill(); }
      c.fillStyle = '#FFFFFF'; ell(c, ex - r * 0.28, eyeY - r * 0.36, r * 0.36, r * 0.36); c.fill();
      ell(c, ex + r * 0.3, eyeY + r * 0.36, r * 0.15, r * 0.15); c.fill();
    }
  });
  // mouth
  const my = eyeY + r * 1.45;
  c.strokeStyle = ink; c.lineWidth = Math.max(0.8, r * 0.22);
  if (mood === 'happy') {
    c.beginPath(); c.arc(0, my - r * 0.1, r * 0.5, 0.1, Math.PI - 0.1); c.closePath(); c.fillStyle = ink; c.fill();
    c.fillStyle = '#FF8FA0'; ell(c, 0, my + r * 0.22, r * 0.25, r * 0.14); c.fill();
  } else if (mood === 'surprised') {
    c.fillStyle = ink; ell(c, 0, my + r * 0.1, r * 0.22, r * 0.3); c.fill();
  } else if (mood === 'sleep') {
    c.beginPath(); c.moveTo(-r * 0.22, my); c.lineTo(r * 0.22, my); c.stroke();
  } else {
    c.beginPath(); c.arc(-r * 0.24, my - r * 0.05, r * 0.24, 0.2, Math.PI - 0.2); c.arc(r * 0.24, my - r * 0.05, r * 0.24, 0.2, Math.PI - 0.2); c.stroke();
  }
  void t;
}

/* ---------- main draw ---------- */
TK.drawKin = (ctx, id, x, y, size, t = 0, opts = {}) => {
  const sp = BY_ID[id] || SPECIES[0];
  const sil = !!opts.silhouette, mood = opts.mood || 'idle', facing = opts.facing || 1;
  const S = size;
  const br = (sil || TK.reduced()) ? 0 : Math.sin(t * 2.3 + sp.ph);
  const sq = opts.squash || 0;
  const sy = (1 + br * 0.022) * (1 - sq), sx = (1 - br * 0.012) * (1 + sq * 0.7);
  const col = c => sil ? SIL : c;
  ctx.save();
  ctx.globalAlpha *= opts.alpha ?? 1;
  // ground shadow (never squashed)
  ctx.fillStyle = sil ? 'rgba(20,30,28,.10)' : 'rgba(20,32,26,.20)';
  ell(ctx, x, y, S * sp.w * 0.46 * sx, S * 0.05); ctx.fill();
  ctx.translate(x, y); ctx.scale(facing * sx, sy);
  const footH = S * 0.045;
  const bh = S * sp.bh, bw = S * sp.w;
  const cy = sp.shape === 'stem' ? -footH - bh / 2 : -footH - bh / 2;
  const P = { S, bh, bw, cy, top: cy - bh / 2, sil, t, sp, mood };
  // back features
  sp.back && sp.back(ctx, P, col);
  // feet
  ctx.fillStyle = col(sp.dark);
  ell(ctx, -bw * 0.2, -footH * 0.85, bw * 0.13, footH * 1.05); ctx.fill();
  ell(ctx, bw * 0.2, -footH * 0.85, bw * 0.13, footH * 1.05); ctx.fill();
  // body
  const rx = bw / 2, ry = bh / 2;
  if (sp.shape === 'pear') blob(ctx, 0, cy, rx, ry, 0.72, 1.04);
  else if (sp.shape === 'bean') blob(ctx, 0, cy, rx, ry, 0.9, 1.02);
  else if (sp.shape === 'squat') blob(ctx, 0, cy, rx, ry, 0.88, 1.08);
  else if (sp.shape === 'stem') blob(ctx, 0, cy, rx, ry, 0.82, 1.1);
  else blob(ctx, 0, cy, rx, ry, 0.96, 1.0);
  if (sil) ctx.fillStyle = SIL;
  else if (sp.rainbow) { const g = ctx.createLinearGradient(-rx, cy - ry, rx, cy + ry); g.addColorStop(0, '#FFB8DC'); g.addColorStop(0.5 + Math.sin(t) * 0.15, '#BBA6FF'); g.addColorStop(1, '#93E6E2'); ctx.fillStyle = g; }
  else ctx.fillStyle = sp.body;
  ctx.fill();
  if (!sil) {
    ctx.save(); ctx.clip();
    const hg = ctx.createRadialGradient(-rx * 0.35, cy - ry * 0.45, 0, -rx * 0.35, cy - ry * 0.45, rx * 1.1);
    hg.addColorStop(0, 'rgba(255,255,255,.38)'); hg.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = hg; ctx.fillRect(-rx * 1.2, cy - ry * 1.2, rx * 2.4, ry * 2.4);
    ctx.fillStyle = sp.belly; ctx.globalAlpha *= sp.rainbow ? 0.55 : 1;
    ell(ctx, 0, cy + ry * 0.55, rx * 0.62, ry * 0.55); ctx.fill();
    ctx.restore();
    // outline
    if (sp.shape === 'pear') blob(ctx, 0, cy, rx, ry, 0.72, 1.04);
    else if (sp.shape === 'bean') blob(ctx, 0, cy, rx, ry, 0.9, 1.02);
    else if (sp.shape === 'squat') blob(ctx, 0, cy, rx, ry, 0.88, 1.08);
    else if (sp.shape === 'stem') blob(ctx, 0, cy, rx, ry, 0.82, 1.1);
    else blob(ctx, 0, cy, rx, ry, 0.96, 1.0);
    ctx.globalAlpha *= 0.55; stroke(ctx, P, sp.dark, 0.016); ctx.globalAlpha /= 0.55;
  }
  sp.front && sp.front(ctx, P, col);
  if (!sil) face(ctx, P);
  ctx.restore();
};
})();
