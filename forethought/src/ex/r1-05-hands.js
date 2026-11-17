/* I.5 Sliders that hold hands — an equaliser where neighbours follow with a gaussian falloff. */
FT.exhibit({
  id: 'holding-hands', room: 1, num: 5, kind: 'sliders',
  title: 'Sliders that hold hands',
  hint: 'Drag a band up or down · double-tap to zero it',
  height: 380,
  body: `<p>Nine equaliser bands, but you rarely want to move just one. Drag a band and its neighbours come along, each a little less than the last, so one stroke shapes a smooth curve. The reach chips set how far the hold extends: Solo moves one band, Near takes a neighbour on each side, Wide moves half the range.</p><p>Double-tap any band to drop it back to zero without disturbing the others.</p>`,
  why: `Rows of independent sliders invite jagged, unnatural settings and cost nine gestures for one idea. Proportional editing is how 3D artists have sculpted meshes for decades. It turns many controls into one shape you can push.`,
  source: `proportional (soft-selection) editing in 3D modelling tools such as <a href="https://docs.blender.org/manual/en/latest/editors/3dview/controls/proportional_editing.html" target="_blank" rel="noopener">Blender</a>`,
  flutter: `
class LinkedBands extends ChangeNotifier {
  LinkedBands(this.gains);                       // dB per band, −12…12
  final List<double> gains;
  double sigma = 0.9;                            // reach in bands: 0 solo, 0.9 near, 1.8 wide
  late List<double> _start;

  void begin() => _start = [...gains];

  void dragBand(int centre, double deltaDb) {
    for (var i = 0; i < gains.length; i++) {
      final d = (i - centre).toDouble();
      final w = sigma == 0 ? (i == centre ? 1.0 : 0.0) : exp(-(d * d) / (2 * sigma * sigma));
      gains[i] = (_start[i] + deltaDb * w).clamp(-12.0, 12.0);
    }
    notifyListeners();
  }
}

class EqPainter extends CustomPainter {
  EqPainter(this.bands, this.colors) : super(repaint: bands);
  final LinkedBands bands;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    final pts = [for (var i = 0; i < 9; i++) Offset(xFor(i, size), yFor(bands.gains[i], size))];
    final curve = catmullRom(pts);               // Path through every knob
    canvas.drawPath(curve, Paint()..color = colors.primary..style = PaintingStyle.stroke..strokeWidth = 2.5);
    for (final p in pts) canvas.drawCircle(p, 9, Paint()..color = colors.surface);
  }
  @override
  bool shouldRepaint(EqPainter old) => false;    // repaint is driven by the Listenable
}

// GestureDetector(onVerticalDragStart: (_) => bands.begin(),
//   onVerticalDragUpdate: (d) => bands.dragBand(nearest, -d.localPosition.dy / pxPerDb),
//   onDoubleTapDown: (d) => bands.reset(nearestTo(d.localPosition)))`,
  a11y: `Each band is its own <b>slider</b> (−12 to +12 dB), reachable with <b>Tab</b>. <b>↑ ↓</b> change it by 1 dB and respect the current reach, so neighbours move too; <b>0</b> zeroes the focused band. The reach chips are toggle buttons.`,
  mount(stage) {
    const { h } = FT;
    stage.append(h('style', null, `
      .eq-top{position:absolute;left:16px;right:16px;top:14px;display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap}
      .eq-reach{display:flex;gap:4px;align-items:center}
      .eq-reach .ft-label{margin-right:4px}
      .eq-read{font-family:var(--f-mono);font-size:12px;color:var(--muted);font-variant-numeric:tabular-nums}
      .eq-read b{color:var(--ink)}
      .eq-pad{position:absolute;left:0;right:0;top:58px;bottom:0;cursor:ns-resize}
      .eq-band{position:absolute;top:0;bottom:30px;border-radius:12px}
      .eq-band:focus-visible{outline:2px solid var(--accent);outline-offset:-2px}
    `));
    const reachRow = h('div', { class: 'eq-reach', role: 'group', 'aria-label': 'Reach' }, h('span', { class: 'ft-label' }, 'Reach'));
    const REACH = [['Solo', 0], ['Near', 0.9], ['Wide', 1.8]];
    let sigma = 0.9;
    const chips = REACH.map(([n, s]) => {
      const b = h('button', { class: 'ft-chip', type: 'button', 'aria-pressed': String(s === sigma), 'data-hit': '' }, n);
      b.addEventListener('click', () => { sigma = s; chips.forEach(c => c.setAttribute('aria-pressed', String(c === b))); FT.haptic('select'); FT.intent(`reach: ${n}`); showReach = performance.now(); loop.wake(); });
      reachRow.append(b); return b;
    });
    const read = h('div', { class: 'eq-read' });
    stage.append(h('div', { class: 'eq-top' }, reachRow, read));
    const pad = h('div', { class: 'eq-pad', 'data-hit': '' });
    stage.append(pad);
    let ready = false;
    const cv = FT.canvas(pad, () => { if (ready) { layoutBands(); draw(); } });

    const LABELS = ['63', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'];
    const INIT = [3.5, 2.6, 1, -1.2, -2, -1, 0.8, 2.2, 3];
    const N = 9, MAXDB = 12;
    const g = INIT.map(v => FT.spring(v, FT.SPRING.snappy));
    let active = -1, start = null, dragging = false, showReach = 0, lastTap = { t: 0, i: -1 };
    const weights = c => g.map((_, i) => sigma === 0 ? (i === c ? 1 : 0) : Math.exp(-((i - c) ** 2) / (2 * sigma * sigma)));
    const geo = () => { const L = 24, R = cv.w - 24, T = 26, B = cv.h - 44; return { L, R, T, B, mid: (T + B) / 2, step: (R - L) / (N - 1) }; };
    const xOf = i => { const G = geo(); return G.L + i * G.step; };
    const yOf = db => { const G = geo(); return G.mid - db / MAXDB * (G.B - G.T) / 2; };
    const pxPerDb = () => { const G = geo(); return (G.B - G.T) / 2 / MAXDB; };

    const bandEls = LABELS.map((lab, i) => {
      const el = h('div', { class: 'eq-band' });
      pad.append(el);
      el._sync = FT.slider(el, {
        label: `${lab}${lab.endsWith('k') ? 'Hz' : ' Hz'} band`, min: -MAXDB, max: MAXDB, step: 1, big: 3,
        get: () => Math.round(g[i].t),
        set: v => { const d = v - g[i].t; const w = weights(i); g.forEach((s, j) => s.to(FT.clamp(s.t + d * w[j], -MAXDB, MAXDB))); active = i; loop.wake(); syncAll(); },
        text: v => `${v > 0 ? '+' : ''}${v} dB`,
      });
      el.addEventListener('keydown', e => { if (e.key === '0') { e.preventDefault(); g[i].to(0); active = i; loop.wake(); syncAll(); FT.announce('0 dB'); } });
      el.addEventListener('focus', () => { active = i; loop.wake(); });
      return el;
    });
    const syncAll = () => bandEls.forEach(el => el._sync());
    const layoutBands = () => { const G = geo(); bandEls.forEach((el, i) => { el.style.left = (xOf(i) - G.step / 2 + 2) + 'px'; el.style.width = (G.step - 4) + 'px'; }); };

    function spline(ctx, pts) {
      ctx.moveTo(pts[0][0], pts[0][1]);
      for (let i = 0; i < pts.length - 1; i++) {
        const p0 = pts[i - 1] || pts[i], p1 = pts[i], p2 = pts[i + 1], p3 = pts[i + 2] || p2;
        ctx.bezierCurveTo(p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6, p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6, p2[0], p2[1]);
      }
    }
    function draw() {
      const { ctx } = cv; cv.clear(); const G = geo();
      const acc = FT.col('--accent'), line = FT.col('--line-2'), muted = FT.col('--muted'), surf = FT.col('--surface-2'), amb = FT.col('--amber');
      // grid: 0 dB and ±6
      ctx.lineWidth = 1;
      for (const db of [-12, -6, 0, 6, 12]) {
        ctx.strokeStyle = FT.alpha(muted, db === 0 ? 0.45 : 0.14); ctx.setLineDash(db === 0 ? [] : [3, 4]);
        ctx.beginPath(); ctx.moveTo(G.L - 12, yOf(db)); ctx.lineTo(G.R + 12, yOf(db)); ctx.stroke();
      }
      ctx.setLineDash([]);
      ctx.font = '9.5px "Geist Mono", ui-monospace, monospace'; ctx.fillStyle = FT.alpha(muted, 0.8); ctx.textAlign = 'left';
      ctx.fillText('+12', 2, yOf(12) - 4); ctx.fillText('−12', 2, yOf(-12) + 12);
      // band rails
      const w = active >= 0 && (dragging || performance.now() - showReach < 900) ? weights(active) : null;
      for (let i = 0; i < N; i++) {
        const x = xOf(i);
        ctx.strokeStyle = FT.alpha(line, 0.9); ctx.lineWidth = 3; ctx.lineCap = 'round';
        ctx.beginPath(); ctx.moveTo(x, G.T); ctx.lineTo(x, G.B); ctx.stroke();
        if (w && w[i] > 0.02) { ctx.strokeStyle = FT.alpha(amb, 0.85 * w[i]); ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(x, yOf(0)); ctx.lineTo(x, yOf(g[i].x)); ctx.stroke(); }
        ctx.fillStyle = i === active ? FT.col('--ink') : muted; ctx.textAlign = 'center'; ctx.font = (i === active ? '600 ' : '') + '10px "Geist Mono", ui-monospace, monospace';
        ctx.fillText(LABELS[i], x, G.B + 22);
        if (w && w[i] > 0.02) { ctx.fillStyle = FT.alpha(amb, w[i]); ctx.fillRect(x - 8, G.B + 30, 16 * w[i], 2.5); }
      }
      // curve + area
      const pts = g.map((s, i) => [xOf(i), yOf(s.x)]);
      const ext = [[G.L - 14, pts[0][1]], ...pts, [G.R + 14, pts[N - 1][1]]];
      ctx.beginPath(); spline(ctx, ext); ctx.lineTo(G.R + 14, yOf(0)); ctx.lineTo(G.L - 14, yOf(0)); ctx.closePath();
      ctx.fillStyle = FT.alpha(acc, 0.13); ctx.fill();
      ctx.beginPath(); spline(ctx, ext); ctx.strokeStyle = acc; ctx.lineWidth = 2.5; ctx.stroke();
      // knobs
      for (let i = 0; i < N; i++) {
        const [x, y] = pts[i], on = i === active;
        ctx.fillStyle = surf; ctx.beginPath(); ctx.arc(x, y, on ? 10 : 8, 0, 7); ctx.fill();
        ctx.strokeStyle = acc; ctx.lineWidth = on ? 3 : 2; ctx.stroke();
      }
      const a = active >= 0 ? active : 4, v = g[a].x;
      read.innerHTML = `<b>${LABELS[a]}${LABELS[a].endsWith('k') ? 'Hz' : ' Hz'}</b> ${v >= 0 ? '+' : '−'}${Math.abs(v).toFixed(1)} dB`;
    }
    const loop = FT.loop(dt => {
      let busy = dragging || performance.now() - showReach < 950;
      for (const s of g) if (!s.step(dt)) busy = true;
      draw();
      return busy;
    });
    const nearest = x => FT.clamp(Math.round((x - geo().L) / geo().step), 0, N - 1);
    FT.drag(pad, {
      start(s) { active = nearest(s.x); start = g.map(q => q.t); FT.intent(`holding ${LABELS[active]} with reach ${sigma}`); loop.wake(); },
      move(s) {
        if (!s.moved) return;
        if (!dragging) { dragging = true; }
        const d = -s.dy / pxPerDb(), w = weights(active);
        g.forEach((q, i) => { const nv = FT.clamp(start[i] + d * w[i], -MAXDB, MAXDB); const was = Math.round(q.t); q.to(nv); if (i === active && Math.round(nv) !== was) FT.haptic('select'); });
        loop.wake();
      },
      end() { if (dragging) { FT.intent(`${LABELS[active]} set to ${g[active].t.toFixed(1)} dB`); FT.announce(`${LABELS[active]} ${Math.round(g[active].t)} dB`); syncAll(); } dragging = false; showReach = performance.now(); loop.wake(); },
      tap(s) {
        const i = nearest(s.x), now = performance.now();
        if (lastTap.i === i && now - lastTap.t < 350) { g[i].to(0); FT.haptic('medium'); FT.intent(`double-tap: ${LABELS[i]} to 0 dB`); FT.announce(`${LABELS[i]} reset to 0 dB`); lastTap = { t: 0, i: -1 }; syncAll(); }
        else lastTap = { t: now, i };
        active = i; loop.wake();
      },
    }, { axis: 'y', slop: 3 });
    FT.onTheme(draw);
    ready = true; layoutBands(); draw();
    return { reset() { g.forEach((s, i) => s.to(INIT[i])); active = -1; loop.wake(); syncAll(); } };
  },
});
