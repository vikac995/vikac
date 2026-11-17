/* II.5 Search by drawing the shape — query-by-sketch over song energy curves (z-normalised DTW). */
FT.exhibit({
  id: 'sketch-search', room: 2, num: 5, kind: 'search', replaces: 'filters you can\'t describe in words',
  title: 'Search by drawing the shape',
  hint: 'Draw a line in the box · results re-rank as you draw',
  height: 540,
  body: `<p>Some things are easier to draw than to name: a song that starts quiet and explodes, a week of sales that dipped and recovered. Draw the shape of the energy you're after, and twelve songs re-rank while your finger is still moving. The best three rise to the top with your line laid over theirs.</p><p>Size and position don't matter. A small squiggle in the corner finds the same songs as a big one, because only the shape is compared.</p>`,
  why: `Search boxes need words, and filters need you to know the axis in advance. A sketch is a query anyone can write, and laying it over the answer shows why each result matched.`,
  source: `Mannino &amp; Abouzied, <a href="https://huda-lab.github.io/papers/qetch-chi.pdf" target="_blank" rel="noopener">"Expressive Time Series Querying with Hand-Drawn Scale-Free Sketches" (Qetch, CHI 2018)</a>.`,
  flutter: `
class SketchQuery extends StatefulWidget { /* ... */ }

class _SketchQueryState extends State<SketchQuery> {
  final _ink = <Offset>[];
  List<Ranked<Song>> _ranked = const [];

  void _update() {
    final query = zNormalise(resampleByX(_ink, 48).map((p) => -p.dy).toList());
    _ranked = [
      for (final s in widget.songs)
        Ranked(s, dtw(query, s.zEnergy, window: 4)),     // Sakoe–Chiba band keeps it O(n·w)
    ]..sort((a, b) => a.distance.compareTo(b.distance));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    GestureDetector(
      onPanStart: (d) => setState(() => _ink..clear()..add(d.localPosition)),
      onPanUpdate: (d) { _ink.add(d.localPosition); _update(); },   // re-rank while drawing
      onPanEnd: (_) => HapticFeedback.lightImpact(),
      child: CustomPaint(painter: InkPainter(_ink), size: const Size.fromHeight(130)),
    ),
    Expanded(child: GridView.count(crossAxisCount: 3, children: [
      for (final (rank, r) in _ranked.indexed)
        // ImplicitlyAnimatedGrid-style: each card keyed by song so it glides to its new slot
        AnimatedSongCard(key: ValueKey(r.item.id), song: r.item, rank: rank,
            overlay: rank < 3 ? _ink : null, match: r.matchPercent),
    ])),
  ]);
}`,
  a11y: `Four example shapes are buttons above the results, so the search works without drawing. After each search the top three are announced with their match, and the full ranking is available as a list to screen readers.`,
  mount(stage) {
    const { h } = FT;
    stage.append(h('style', { text: `
      .sk-root{position:absolute;inset:0;padding:14px 16px 12px;display:flex;flex-direction:column;gap:9px;container-type:inline-size}
      @container (max-width: 390px){.sk-head .ft-label{display:none}}
      .sk-head{display:flex;justify-content:space-between;align-items:baseline;gap:8px;padding:0 2px}
      .sk-head b{font-size:14.5px}
      .sk-pad{position:relative;height:128px;flex:none;border-radius:14px;background:var(--surface-2);border:1px solid var(--line);box-shadow:var(--shadow);cursor:crosshair}
      .sk-presets{display:flex;gap:6px;overflow-x:auto;scrollbar-width:none;flex:none;padding-bottom:1px;mask-image:linear-gradient(90deg,#000 88%,transparent);-webkit-mask-image:linear-gradient(90deg,#000 88%,transparent)}
      .sk-presets::-webkit-scrollbar{display:none}
      .sk-presets .ft-chip{flex:none;height:30px;font-size:12px}
      .sk-res{position:relative;flex:1;min-height:0}
    ` }));
    const N = 48;
    const g = (u, c, w) => Math.exp(-((u - c) ** 2) / (2 * w * w));
    const SONGS = [
      ['Paper Lanterns', 'Mira Sol', u => u < 0.8 ? 0.12 + 0.85 * Math.pow(u / 0.8, 1.6) : 0.14],
      ['Low Tide', 'Harbour Lights', u => 0.92 - 0.8 * u + 0.04 * Math.sin(u * 18)],
      ['Two Summers', 'Kesta', u => 0.15 + 0.8 * g(u, 0.28, 0.09) + 0.75 * g(u, 0.72, 0.09)],
      ['Metronome Heart', 'Ivo & Lune', u => 0.58 + 0.05 * Math.sin(u * 30)],
      ['Fault Line', 'Grey Orchard', u => u < 0.55 ? 0.14 + 0.05 * Math.sin(u * 20) : 0.92],
      ['Valley Song', 'Ana Rih', u => 0.5 + 0.38 * Math.cos(u * Math.PI * 2)],
      ['Staircase', 'Northbound', u => 0.12 + Math.floor(u * 4 * 0.999) * 0.25],
      ['Slow Burn', 'Tamsin Vale', u => 0.08 + 0.88 * Math.pow(u, 3)],
      ['Afterglow', 'Lume', u => u < 0.18 ? 0.15 + u / 0.18 * 0.8 : 0.1 + 0.85 * Math.exp(-(u - 0.18) * 3.2)],
      ['Breathing Room', 'Oko', u => 0.5 + 0.33 * Math.sin(u * Math.PI * 4)],
      ['Long Way Down', 'Field Notes', u => 0.9 - 0.75 * u + 0.28 * g(u, 0.5, 0.07)],
      ['Late Bloomer', 'Veska', u => u < 0.7 ? 0.18 + 0.03 * Math.sin(u * 25) : 0.18 + (u - 0.7) / 0.3 * 0.76],
    ].map(([title, artist, f], i) => {
      const raw = Array.from({ length: N }, (_, k) => { const u = k / (N - 1); return FT.clamp(f(u) + 0.025 * Math.sin(k * 2.3 + i * 1.7), 0, 1); });
      return { i, title, artist, raw, z: zn(raw), x: FT.spring(0, FT.SPRING.smooth), y: FT.spring(0, FT.SPRING.smooth), lift: FT.spring(0, FT.SPRING.smooth), score: 0, rank: i };
    });
    function zn(a) {
      const m = a.reduce((s, v) => s + v, 0) / a.length;
      const sd = Math.max(0.08, Math.sqrt(a.reduce((s, v) => s + (v - m) ** 2, 0) / a.length));
      return a.map(v => (v - m) / sd);
    }
    const dtw = (a, b, w = 4) => {
      const n = a.length, D = Array.from({ length: n + 1 }, () => new Float64Array(n + 1).fill(Infinity));
      D[0][0] = 0;
      for (let i = 1; i <= n; i++) for (let j = Math.max(1, i - w); j <= Math.min(n, i + w); j++) {
        const c = (a[i - 1] - b[j - 1]) ** 2;
        D[i][j] = c + Math.min(D[i - 1][j], D[i][j - 1], D[i - 1][j - 1]);
      }
      return Math.sqrt(D[n][n] / n);
    };
    const PRESETS = [
      ['Slow build, big drop', u => u < 0.78 ? 0.15 + 0.8 * Math.pow(u / 0.78, 1.4) : 0.15],
      ['Fades away', u => 0.9 - 0.78 * u],
      ['Two peaks', u => 0.2 + 0.75 * g(u, 0.3, 0.1) + 0.7 * g(u, 0.7, 0.1)],
      ['Quiet, then loud', u => u < 0.6 ? 0.18 : 0.9],
    ];

    const root = h('div', { class: 'sk-root' });
    const pad = h('div', { class: 'sk-pad', 'data-hit': '', role: 'img', 'aria-label': 'Drawing area: draw how the song energy should move from start to end' });
    const presets = h('div', { class: 'sk-presets', role: 'group', 'aria-label': 'Example shapes' });
    const res = h('div', { class: 'sk-res' });
    const srList = h('ol', { class: 'sr-only', 'aria-label': 'Ranked songs' });
    root.append(h('div', { class: 'sk-head' }, h('b', null, 'Find a song that goes like this'), h('span', { class: 'ft-label' }, 'energy over time')), pad, presets, res, srList);
    stage.append(root);

    let ink = [], example = true, drawAnim = null;
    let pcv = null, rcv = null;
    pcv = FT.canvas(pad, () => { if (pcv) drawPad(); });
    rcv = FT.canvas(res, () => { if (rcv) { layout(true); drawRes(); } });

    PRESETS.forEach(([name, f]) => {
      const b = h('button', { type: 'button', class: 'ft-chip', 'data-hit': '' }, name);
      b.addEventListener('click', () => { playPreset(f); FT.intent(`example shape: ${name}`); });
      presets.append(b);
    });

    const sketchVec = () => {
      if (ink.length < 4) return null;
      let x0 = Infinity, x1 = -Infinity;
      for (const p of ink) { x0 = Math.min(x0, p.x); x1 = Math.max(x1, p.x); }
      if (x1 - x0 < 30) return null;
      const sum = new Float64Array(N), cnt = new Float64Array(N);
      for (let i = 1; i < ink.length; i++) {                // rasterise segments so fast strokes leave no gaps
        const a = ink[i - 1], b = ink[i], steps = Math.max(1, Math.ceil(Math.abs(b.x - a.x) / 2));
        for (let s = 0; s <= steps; s++) {
          const x = FT.lerp(a.x, b.x, s / steps), y = FT.lerp(a.y, b.y, s / steps);
          const k = FT.clamp(Math.round((x - x0) / (x1 - x0) * (N - 1)), 0, N - 1);
          sum[k] += y; cnt[k]++;
        }
      }
      const v = Array.from({ length: N }, (_, k) => cnt[k] ? sum[k] / cnt[k] : NaN);
      for (let k = 0; k < N; k++) if (isNaN(v[k])) {
        let l = k - 1; while (l >= 0 && isNaN(v[l])) l--;
        let r = k + 1; while (r < N && isNaN(v[r])) r++;
        v[k] = l < 0 ? v[r] : r >= N ? v[l] : FT.lerp(v[l], v[r], (k - l) / (r - l));
      }
      const H = pcv.h;
      return v.map(y => 1 - y / H);
    };
    let query = null, lastTop = null;
    const rank = (final, quiet) => {
      const v = sketchVec();
      if (!v) return;
      query = zn(v);
      for (const s of SONGS) { const d = dtw(query, s.z); s.dist = d; s.score = Math.round(100 * FT.clamp(1 - d / 1.35, 0, 1)); }
      const sorted = SONGS.slice().sort((a, b) => a.dist - b.dist);
      sorted.forEach((s, k) => { s.rank = k; s.lift.to(k < 3 ? 1 : 0); });
      layout(false); loop.wake();
      const top = sorted[0];
      if (top !== lastTop && !final && !quiet) FT.haptic('select');
      lastTop = top;
      srList.replaceChildren(...sorted.map(s => h('li', null, `${s.title} by ${s.artist}, ${s.score}% match`)));
      if (final && !quiet) {
        FT.haptic('success');
        FT.intent(`sketch → best match “${top.title}” ${top.score}%`);
        FT.announce(`Best matches: ${sorted.slice(0, 3).map(s => `${s.title}, ${s.score}%`).join('; ')}`);
      }
    };
    let cw = 100, chh = 60;
    function layout(jump) {
      if (!rcv) return;
      const W = rcv.w, gap = 8, cols = 3;
      cw = (W - gap * (cols - 1)) / cols;
      chh = Math.min(64, (rcv.h - gap * 3) / 4);
      for (const s of SONGS) {
        const tx = (s.rank % cols) * (cw + gap), ty = Math.floor(s.rank / cols) * (chh + gap);
        if (jump) { s.x.set(tx); s.y.set(ty); } else { s.x.to(tx); s.y.to(ty); }
      }
    }
    function drawPad() {
      const { ctx, w, h: H } = pcv;
      pcv.clear();
      const muted = FT.col('--muted'), line = FT.col('--line'), acc = FT.col('--accent');
      ctx.strokeStyle = line; ctx.setLineDash([3, 5]); ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(10, H / 2); ctx.lineTo(w - 10, H / 2); ctx.stroke(); ctx.setLineDash([]);
      ctx.font = '500 10px "Geist Mono", ui-monospace, monospace'; ctx.fillStyle = muted;
      ctx.fillText('loud', 10, 15); ctx.fillText('quiet', 10, H - 8);
      ctx.textAlign = 'right'; ctx.fillText(example ? 'example sketch · draw your own' : 'start → end', w - 10, H - 8); ctx.textAlign = 'start';
      if (ink.length > 1) {
        ctx.strokeStyle = acc; ctx.lineWidth = 3.2; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
        ctx.beginPath(); ctx.moveTo(ink[0].x, ink[0].y);
        for (let i = 1; i < ink.length - 1; i++) ctx.quadraticCurveTo(ink[i].x, ink[i].y, (ink[i].x + ink[i + 1].x) / 2, (ink[i].y + ink[i + 1].y) / 2);
        ctx.lineTo(ink[ink.length - 1].x, ink[ink.length - 1].y); ctx.stroke();
      }
    }
    function drawRes() {
      const { ctx } = rcv;
      rcv.clear();
      const ink2 = FT.col('--ink'), muted = FT.col('--muted'), acc = FT.col('--accent'), surf = FT.col('--surface-2'), line = FT.col('--line'), faint = FT.col('--faint');
      const order = SONGS.slice().sort((a, b) => a.lift.x - b.lift.x);
      for (const s of order) {
        const L = FT.clamp(s.lift.x, 0, 1), x = s.x.x, y = s.y.x - L * 2;
        const dim = query ? 0.5 + 0.5 * L : 1;
        ctx.globalAlpha = dim;
        ctx.fillStyle = surf; ctx.strokeStyle = L > 0.05 ? FT.alpha(acc, 0.3 + 0.7 * L) : line; ctx.lineWidth = 1 + L * 0.6;
        ctx.beginPath(); ctx.roundRect ? ctx.roundRect(x + 0.5, y + 0.5, cw - 1, chh - 1, 10) : ctx.rect(x, y, cw, chh); ctx.fill(); ctx.stroke();
        const px = x + 8, pw = cw - 16, py = y + 6, ph = chh * 0.42;
        const plot = (arr, col, lw, dash) => {
          ctx.strokeStyle = col; ctx.lineWidth = lw; ctx.setLineDash(dash || []);
          ctx.beginPath();
          arr.forEach((v, k) => { const X = px + k / (N - 1) * pw, Y = py + (1 - FT.clamp(v, -0.1, 1.1)) * ph; k ? ctx.lineTo(X, Y) : ctx.moveTo(X, Y); });
          ctx.stroke(); ctx.setLineDash([]);
        };
        plot(s.raw, L > 0.5 ? ink2 : muted, 1.6);
        if (query && L > 0.05) {
          const m = s.raw.reduce((a, b) => a + b, 0) / N, sd = Math.max(0.08, Math.sqrt(s.raw.reduce((a, b) => a + (b - m) ** 2, 0) / N));
          ctx.globalAlpha = dim * L; plot(query.map(z => m + z * sd), acc, 2, [4, 3]); ctx.globalAlpha = dim;
        }
        ctx.fillStyle = ink2; ctx.font = '600 11.5px "Geist", system-ui, sans-serif';
        let t = s.title; while (ctx.measureText(t).width > cw - 16 && t.length > 3) t = t.slice(0, -2) + '…';
        ctx.fillText(t, px, y + chh - 19);
        ctx.font = '500 10px "Geist Mono", ui-monospace, monospace';
        if (query && L > 0.5) { ctx.fillStyle = acc; ctx.fillText(`#${s.rank + 1} · ${s.score}% match`, px, y + chh - 7); }
        else { ctx.fillStyle = faint; let a = s.artist; while (ctx.measureText(a).width > cw - 16 && a.length > 3) a = a.slice(0, -2) + '…'; ctx.fillText(a, px, y + chh - 7); }
      }
      ctx.globalAlpha = 1;
    }
    const loop = FT.loop((dt, now) => {
      let moving = false;
      if (drawAnim) {
        const u = Math.min(1, (now - drawAnim.t0) / 650);
        const n = Math.max(2, Math.floor(u * drawAnim.pts.length));
        ink = drawAnim.pts.slice(0, n);
        rank(u >= 1);
        if (u >= 1) drawAnim = null; else moving = true;
        drawPad();
      }
      for (const s of SONGS) { if (!s.x.step(dt)) moving = true; if (!s.y.step(dt)) moving = true; if (!s.lift.step(dt)) moving = true; }
      drawRes();
      return moving;
    });
    const playPreset = (f, instant) => {
      const W = pcv.w, H = pcv.h, pts = [];
      for (let k = 0; k <= 60; k++) { const u = k / 60; pts.push({ x: 24 + u * (W - 48), y: 14 + (1 - f(u)) * (H - 34) + Math.sin(k * 0.9) * 1.2 }); }
      example = false;
      if (instant || FT.reduced()) { ink = pts; drawPad(); rank(true, instant); loop.wake(); return; }
      drawAnim = { pts, t0: performance.now() }; loop.wake();
    };
    FT.drag(pad, {
      start(s) { drawAnim = null; example = false; ink = [{ x: s.x, y: s.y }]; lastTop = null; drawPad(); },
      move(s) { ink.push({ x: FT.clamp(s.x, 0, pcv.w), y: FT.clamp(s.y, 2, pcv.h - 2) }); drawPad(); rank(false); },
      end(s) { if (ink.length > 3) rank(true); else FT.intent('too short to search'); },
    }, { axis: 'both', slop: 2 });
    FT.onTheme(() => { drawPad(); drawRes(); });
    const reset = () => {
      drawAnim = null; query = null; lastTop = null;
      SONGS.forEach(s => { s.rank = s.i; s.lift.set(0); });
      layout(true);
      playPreset(PRESETS[0][1], true); example = true; drawPad();
      SONGS.forEach(s => { s.lift.set(s.rank < 3 ? 1 : 0); });
      layout(true); drawRes();
    };
    reset();
    return { reset };
  },
});
