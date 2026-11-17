/* II.4 One dataset, many shapes — bars → strip → donut → unit dots, every app keeps its identity. */
FT.exhibit({
  id: 'morph-chart', room: 2, num: 4, kind: 'chart', replaces: 'a chart-type dropdown',
  title: 'One dataset, many shapes',
  hint: 'Drag sideways on the chart · or use the stops below',
  height: 470,
  body: `<p>One hour of screen time, split across six apps. Drag across the chart and the same six pieces reshape themselves: bars for comparing, a strip for proportion, a ring for "part of a whole", sixty dots for counting minutes.</p><p>Nothing fades out and nothing is redrawn. Each app keeps its colour and you can follow it with your eye through every shape, so switching views never costs you your place.</p>`,
  why: `Every chart type answers a different question. Letting people slide between them, with each item traceable, turns "which chart?" from a designer's guess into the reader's choice.`,
  source: `Heer &amp; Robertson, "Animated Transitions in Statistical Data Graphics" (InfoVis 2007), and Mike Bostock's <a href="https://bost.ocks.org/mike/constancy/" target="_blank" rel="noopener">Object Constancy</a>.`,
  flutter: `
/// One painter, one continuous parameter. t: 0 bars · 1 strip · 2 ring · 3 unit dots.
class MorphPainter extends CustomPainter {
  MorphPainter({required this.apps, required this.t}) : super(repaint: t);
  final List<AppSlice> apps;
  final ValueListenable<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    for (final (i, app) in apps.indexed) {
      final paint = Paint()..color = app.color;
      if (v <= 1) {
        final k = Curves.easeInOutCubic.transform(_stagger(v, i));
        canvas.drawRRect(RRect.lerp(barRect(i, size), stripRect(i, size), k)!, paint);
      } else if (v <= 2) {
        canvas.drawPath(bentBand(app.start, app.end, curvature: v - 1, size: size), paint);
      } else {
        for (final u in app.units) {                      // one shape per minute
          final k = _stagger(v - 2, u.index);
          canvas.save();
          canvas.translate(lerpDouble(u.arcCentre.dx, u.cell.dx, k)!, lerpDouble(u.arcCentre.dy, u.cell.dy, k)!);
          canvas.rotate(lerpDouble(u.arcAngle, 0, k)!);
          canvas.drawRRect(RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: lerpDouble(u.arcLength, dot, k)!, height: lerpDouble(thickness, dot, k)!),
            Radius.circular(dot / 2 * k)), paint);
          canvas.restore();
        }
      }
    }
  }
  @override bool shouldRepaint(MorphPainter old) => old.apps != apps;
}

// Driven by a horizontal drag; on release a SpringSimulation snaps t to the nearest whole shape.`,
  a11y: `The shape control under the chart is a slider with four named stops; <b>Left/Right</b> move between them. The chart itself is described as a table for screen readers: app name and minutes, plus the current shape.`,
  mount(stage) {
    const { h } = FT;
    stage.append(h('style', { text: `
      .mo-root{position:absolute;inset:0;padding:16px 16px 14px;display:flex;flex-direction:column;gap:10px;
        --m1:#3B47F0;--m2:#0E9A86;--m3:#DB8500;--m4:#D23F78;--m5:#8A4FE0;--m6:#2C8BD6}
      @media (prefers-color-scheme: dark){:root:not([data-theme="light"]) .mo-root{--m1:#8089FF;--m2:#2FD1B8;--m3:#FFB224;--m4:#FF6FA3;--m5:#B48CFF;--m6:#6CB8FF}}
      :root[data-theme="dark"] .mo-root{--m1:#8089FF;--m2:#2FD1B8;--m3:#FFB224;--m4:#FF6FA3;--m5:#B48CFF;--m6:#6CB8FF}
      .mo-head{display:flex;justify-content:space-between;align-items:baseline;gap:8px;padding:0 2px}
      .mo-head b{font-size:14.5px}
      .mo-shape{font-family:var(--f-mono);font-size:11.5px;color:var(--accent)}
      .mo-chart{position:relative;flex:1;min-height:0;cursor:ew-resize}
      .mo-scrub{position:relative;height:44px;margin:0 6px;touch-action:pan-y;cursor:pointer}
      .mo-scrub:focus-visible{outline-offset:2px}
      .mo-track{position:absolute;left:0;right:0;top:12px;height:4px;border-radius:2px;background:var(--line)}
      .mo-fill{position:absolute;left:0;top:12px;height:4px;border-radius:2px;background:var(--accent)}
      .mo-thumb{position:absolute;top:4px;width:20px;height:20px;margin-left:-10px;border-radius:50%;background:var(--surface-2);border:2px solid var(--accent);box-shadow:var(--shadow)}
      .mo-stop{position:absolute;top:24px;transform:translateX(-50%);font-family:var(--f-mono);font-size:10.5px;color:var(--muted);white-space:nowrap;transition:color .2s}
      .mo-stop.on{color:var(--ink)}
      .mo-stop:first-of-type{transform:none}.mo-stop:last-of-type{transform:translateX(-100%)}
      .mo-legend{display:grid;grid-template-columns:repeat(auto-fill,minmax(122px,1fr));gap:4px 10px;margin:0;padding:0;list-style:none}
      .mo-legend li{display:flex;align-items:center;gap:6px;font-size:12.5px;min-width:0}
      .mo-legend i{flex:none;width:9px;height:9px;border-radius:3px}
      .mo-legend span{flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
      .mo-legend em{font-style:normal;font-family:var(--f-mono);font-size:11px;color:var(--muted)}
    ` }));
    const APPS = [['Messages', 'Msg', 16], ['Music', 'Music', 13], ['Maps', 'Maps', 9], ['Mail', 'Mail', 8], ['Reading', 'Read', 8], ['Photos', 'Photo', 6]];
    const TOTAL = 60, SHAPES = ['Bars', 'Strip', 'Ring', 'Dots'];
    const root = h('div', { class: 'mo-root' });
    const shapeEl = h('span', { class: 'mo-shape' });
    const chart = h('div', { class: 'mo-chart', 'data-hit': '', role: 'img' });
    const scrub = h('div', { class: 'mo-scrub', 'data-hit': '' }, h('div', { class: 'mo-track' }), h('div', { class: 'mo-fill' }), h('div', { class: 'mo-thumb' }));
    const stops = SHAPES.map((s, i) => { const b = h('span', { class: 'mo-stop', style: { left: `${i / 3 * 100}%` } }, s); scrub.append(b); return b; });
    const legend = h('ul', { class: 'mo-legend' }, APPS.map(([n, , m], i) => h('li', null, h('i', { style: { background: `var(--m${i + 1})` } }), h('span', null, n), h('em', null, `${m} min`))));
    root.append(h('div', { class: 'mo-head' }, h('b', null, 'Screen time · 18:00–19:00'), shapeEl), chart, scrub, legend);
    stage.append(root);
    chart.setAttribute('aria-label', 'One hour of screen time: ' + APPS.map(a => `${a[0]} ${a[2]} minutes`).join(', '));

    let cols = [];
    const readCols = () => { const cs = getComputedStyle(root); cols = APPS.map((_, i) => cs.getPropertyValue(`--m${i + 1}`).trim()); };
    readCols();
    let cv = null;
    cv = FT.canvas(chart, () => { if (cv) draw(); });
    const T = FT.spring(0, FT.SPRING.smooth);
    const ease = x => x < .5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
    const C01 = x => FT.clamp(x, 0, 1);

    function draw() {
      const { ctx, w, h: H } = cv;
      if (!cols.length) return;
      cv.clear();
      const t = FT.clamp(T.x, 0, 3);
      const pad = 8, cx = w / 2, cy = H / 2;
      const ink = FT.col('--ink'), muted = FT.col('--muted'), surf = FT.col('--surface');
      const Ls = w - pad * 2, th0 = 42, R = Math.min(w, H) * 0.33, th1 = Math.min(40, R * 0.46);
      // segment starts along the strip centreline, s in [-L/2, L/2]
      let acc = 0;
      const seg = APPS.map(a => { const s0 = acc; acc += a[2]; return [s0 / TOTAL, acc / TOTAL]; });
      const labels = [];
      if (t <= 1) {
        const gap = 10, bw = (w - pad * 2 - gap * 5) / 6, base = H - 22, maxH = H - 58;
        APPS.forEach((a, i) => {
          const k = ease(C01(t * 1.3 - i * 0.06));
          const bx = pad + i * (bw + gap), bh = a[2] / 16 * maxH, by = base - bh;
          const sx = pad + seg[i][0] * Ls, sw = (seg[i][1] - seg[i][0]) * Ls, sy = cy - th0 / 2;
          const x = FT.lerp(bx, sx, k), y = FT.lerp(by, sy, k), ww = FT.lerp(bw, sw, k), hh = FT.lerp(bh, th0, k);
          ctx.fillStyle = cols[i];
          ctx.beginPath(); ctx.roundRect ? ctx.roundRect(x, y, ww, hh, FT.lerp(6, 3, k)) : ctx.rect(x, y, ww, hh); ctx.fill();
          if (k > 0.02) { ctx.strokeStyle = surf; ctx.lineWidth = 2 * k; ctx.stroke(); }
          const wb = 1 - t;
          if (wb > 0.01) {
            labels.push([`${a[2]}`, x + ww / 2, y - 8, wb, ink, '600 12px']);
            labels.push([a[1], x + ww / 2, base + 15, wb, muted, '500 10.5px']);
          }
          if (t > 0.6 && sw > 24) labels.push([`${a[2]}`, sx + sw / 2, cy + 4, (t - 0.6) / 0.4 * (t <= 1 ? 1 : 0), '#FFFFFF', '600 11.5px']);
        });
      } else if (t <= 2) {
        const k = ease(t - 1);
        const L = FT.lerp(Ls, Math.PI * 2 * R, k), kap = k * Math.PI * 2 / L, th = FT.lerp(th0, th1, k);
        const Ax = cx, Ay = FT.lerp(cy, cy - R, k);
        const P = (s, v) => {
          if (kap < 1e-5) return [Ax + s, Ay + v];
          const a = kap * s;
          return [Ax + Math.sin(a) / kap - v * Math.sin(a), Ay + (1 - Math.cos(a)) / kap + v * Math.cos(a)];
        };
        APPS.forEach((a, i) => {
          const s0 = (seg[i][0] - 0.5) * L, s1 = (seg[i][1] - 0.5) * L, n = 28;
          ctx.beginPath();
          for (let j = 0; j <= n; j++) { const [x, y] = P(FT.lerp(s0, s1, j / n), -th / 2); j ? ctx.lineTo(x, y) : ctx.moveTo(x, y); }
          for (let j = n; j >= 0; j--) { const [x, y] = P(FT.lerp(s0, s1, j / n), th / 2); ctx.lineTo(x, y); }
          ctx.closePath(); ctx.fillStyle = cols[i]; ctx.fill(); ctx.strokeStyle = surf; ctx.lineWidth = 2; ctx.stroke();
          const sw = (seg[i][1] - seg[i][0]) * L;
          if (k < 0.5 && sw > 24) { const [x, y] = P((s0 + s1) / 2, 0); labels.push([`${a[2]}`, x, y + 4, 1 - k * 2, '#FFFFFF', '600 11.5px']); }
        });
        if (k > 0.5) {
          labels.push(['60 min', cx, cy + 4, (k - 0.5) * 2, ink, '400 30px', 'display']);
          labels.push(['six apps', cx, cy + 24, (k - 0.5) * 2, muted, '500 10.5px']);
        }
      } else {
        const u = t - 2;
        const L = Math.PI * 2 * R, kap = 1 / R, unit = L / TOTAL;
        const cell = Math.min((w - pad * 2) / 10, (H - 36) / 6), dot = cell * 0.74;
        const gx = cx - cell * 5 + cell / 2, gy = (H - 22) / 2 - cell * 3 + cell / 2;
        let j = 0;
        APPS.forEach((a, i) => {
          ctx.fillStyle = cols[i];
          for (let q = 0; q < a[2]; q++, j++) {
            const k = ease(C01(u * 1.7 - (j / TOTAL) * 0.7));
            const s = (j + 0.5) * unit - L / 2, ang = kap * s;
            const ax = cx + Math.sin(ang) * R, ay = cy - Math.cos(ang) * R;  // ring centred at (cx, cy)
            const tx = gx + (j % 10) * cell, ty = gy + Math.floor(j / 10) * cell;
            let rot = ang; rot = ((rot + Math.PI / 2) % Math.PI + Math.PI) % Math.PI - Math.PI / 2;
            const x = FT.lerp(ax, tx, k), y = FT.lerp(ay, ty, k);
            if (k <= 0.001) {                                            // still on the ring: draw the true arc slice
              const a0 = ang - kap * unit / 2 - Math.PI / 2 - 0.004, a1 = ang + kap * unit / 2 - Math.PI / 2 + 0.004;
              ctx.beginPath(); ctx.arc(cx, cy, R + th1 / 2, a0, a1); ctx.arc(cx, cy, R - th1 / 2, a1, a0, true); ctx.closePath(); ctx.fill();
              continue;
            }
            const ww = FT.lerp(unit + 0.6, dot, k), hh = FT.lerp(th1, dot, k), r = FT.lerp(0, dot / 2, k);
            ctx.save(); ctx.translate(x, y); ctx.rotate(FT.lerp(rot, 0, k));
            ctx.beginPath(); ctx.roundRect ? ctx.roundRect(-ww / 2, -hh / 2, ww, hh, Math.min(r, ww / 2, hh / 2)) : ctx.rect(-ww / 2, -hh / 2, ww, hh); ctx.fill();
            ctx.restore();
          }
        });
        if (u < 0.35) labels.push(['60 min', cx, cy + 4, 1 - u / 0.35, ink, '400 30px', 'display']);
        if (u > 0.6) labels.push(['1 dot = 1 minute', cx, H - 6, (u - 0.6) / 0.4, muted, '500 10.5px']);
      }
      ctx.textAlign = 'center';
      for (const [txt, x, y, a, c, f, fam] of labels) {
        if (a <= 0.01) continue;
        ctx.globalAlpha = C01(a);
        ctx.fillStyle = c.startsWith('#') ? c : c;
        ctx.font = `${f} ${fam === 'display' ? '"Instrument Serif", Georgia, serif' : '"Geist Mono", ui-monospace, monospace'}`;
        ctx.fillText(txt, x, y);
      }
      ctx.globalAlpha = 1; ctx.textAlign = 'start';
    }

    let lastStop = 0;
    const paintUi = () => {
      const t = FT.clamp(T.x, 0, 3), p = t / 3 * 100;
      scrub.querySelector('.mo-thumb').style.left = p + '%';
      scrub.querySelector('.mo-fill').style.width = p + '%';
      const near = Math.round(t);
      stops.forEach((s, i) => s.classList.toggle('on', i === near));
      shapeEl.textContent = SHAPES[near];
      if (near !== lastStop) { lastStop = near; FT.haptic('select'); }
    };
    const loop = FT.loop(dt => { const done = T.step(dt); draw(); paintUi(); return !done; });
    const go = (v, how) => {
      T.to(FT.clamp(v, 0, 3)); loop.wake();
      FT.intent(`${how}: ${SHAPES[Math.round(FT.clamp(v, 0, 3))]}`);
    };
    const snap = (vel, how) => {
      const proj = T.x + vel * 0.18;
      const target = FT.clamp(Math.round(proj), 0, 3);
      go(target, how); syncAria(); FT.announce(`${SHAPES[target]} view`);
    };
    // drag on the chart: right-to-left moves forward, like turning a page
    let t0 = 0;
    FT.drag(chart, {
      start() { t0 = T.x; },
      move(s) { if (!s.moved) return; const v = FT.clamp(t0 - s.dx / (cv.w * 0.42), -0.15, 3.15); T.set(v); loop.wake(); },
      end(s) { if (s.moved) snap(-s.vx / (cv.w * 0.42), 'chart drag released'); },
      tap() { const n = (Math.round(T.t) + 1) % 4; go(n, n ? 'tap: next shape' : 'tap: back to bars'); syncAria(); FT.announce(`${SHAPES[n]} view`); },
    }, { axis: 'x', slop: 5 });
    const fromScrub = s => FT.clamp(s.x / scrub.clientWidth * 3, 0, 3);
    FT.drag(scrub, {
      start(s) { T.set(T.x); T.to(fromScrub(s)); loop.wake(); },
      move(s) { if (s.moved) { T.set(fromScrub(s)); loop.wake(); } },
      end() { snap(0, 'scrubber'); },
    }, { axis: 'x', slop: 2 });
    const syncAria = FT.slider(scrub, {
      label: 'Chart shape', min: 0, max: 3, step: 1,
      get: () => Math.round(T.t), set: v => { go(v, 'key'); FT.announce(`${SHAPES[v]} view`); },
      text: v => SHAPES[Math.round(v)],
    });
    FT.onTheme(() => { readCols(); draw(); });
    paintUi();
    return { reset() { T.set(0); lastStop = 0; draw(); paintUi(); syncAria(); } };
  },
});
