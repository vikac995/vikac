/* II.2 Draw the command — $1 unistroke recognition over a task list, with a marking-menu style cheat sheet for novices. */
FT.exhibit({
  id: 'draw-command', room: 2, num: 2, kind: 'gesture shortcuts', replaces: 'swipe actions and overflow menus',
  title: 'Draw the command',
  hint: 'Draw ✓ ○ ^ or ✕ over a task · hold still first to see the sheet',
  height: 460,
  body: `<p>Draw a check over a task to finish it, a circle to star it, a caret to send it to the top, a cross or a strike-through to delete it. The glyph you meant flashes over the row so you can see what the page understood.</p><p>Not sure what to draw? Press and hold still for a moment. The four glyphs appear around your finger. Start drawing and they fade away. People who know the glyphs never see the sheet.</p>`,
  why: `Swipe actions hide two commands per row at most, and only one direction each. Glyphs scale to many commands, aim at the row you drew on, and the novice sheet teaches them through use until the help is no longer needed.`,
  source: `Wobbrock, Wilson &amp; Li, <a href="https://depts.washington.edu/acelab/proj/dollar/index.html" target="_blank" rel="noopener">the $1 Unistroke Recognizer (UIST 2007)</a>, and Kurtenbach &amp; Buxton's marking menus, where a pause reveals the menu and a confident stroke skips it.`,
  flutter: `
class GlyphLayer extends StatefulWidget {
  const GlyphLayer({super.key, required this.child, required this.onGlyph});
  final Widget child;
  final void Function(Glyph glyph, Offset centre) onGlyph;
  @override State<GlyphLayer> createState() => _GlyphLayerState();
}

class _GlyphLayerState extends State<GlyphLayer> {
  final _points = <Offset>[];
  Timer? _novice;
  bool _showSheet = false;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    gestures: {
      // Pan wins the arena only after slop, so plain taps still reach the rows.
      PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
        PanGestureRecognizer.new, (r) => r
          ..onDown = (d) { _points..clear()..add(d.localPosition);
              _novice = Timer(const Duration(milliseconds: 350), () => setState(() => _showSheet = true)); }
          ..onUpdate = (d) { _novice?.cancel(); setState(() { _showSheet = false; _points.add(d.localPosition); }); }
          ..onEnd = (_) {
            final match = DollarRecognizer.recognize(_points, templates, rotationWindow: 25);
            if (match.score > .78) { HapticFeedback.mediumImpact(); widget.onGlyph(match.glyph, boundsOf(_points).center); }
            setState(_points.clear);
          }),
    },
    child: Stack(children: [
      widget.child,
      IgnorePointer(child: CustomPaint(painter: InkPainter(_points), size: Size.infinite)),
      if (_showSheet) GlyphSheet(at: _points.first),   // AnimatedOpacity, fades as soon as you move
    ]),
  );
}`,
  a11y: `Each task is in the tab order. With a task focused: <b>C</b> or <b>Enter</b> completes, <b>S</b> stars, <b>T</b> sends to the top, <b>Delete</b> removes it (with an Undo button that receives focus). Every recognised glyph is announced, so drawing users with a screen reader hear the result too.`,
  mount(stage) {
    const { h } = FT;
    stage.append(h('style', { text: `
      .dg-root{position:absolute;inset:0;padding:16px 16px 12px;display:flex;flex-direction:column;gap:10px}
      .dg-head{display:flex;justify-content:space-between;align-items:baseline;padding:0 4px}
      .dg-head b{font-size:15px}
      .dg-list{position:relative;flex:1;border-radius:14px;background:var(--surface-2);border:1px solid var(--line);box-shadow:var(--shadow);overflow:hidden}
      .dg-row{position:absolute;left:0;right:0;height:52px;display:flex;align-items:center;gap:12px;padding:0 14px;border-bottom:1px solid var(--line);background:var(--surface-2);will-change:transform}
      .dg-row:focus-visible{outline-offset:-3px}
      .dg-box{flex:none;width:22px;height:22px;border-radius:50%;border:1.6px solid var(--line-2);display:grid;place-items:center;transition:background .2s,border-color .2s}
      .dg-box svg{width:13px;height:13px;stroke:var(--accent-ink);stroke-width:2.6;fill:none;stroke-dasharray:20;stroke-dashoffset:20;transition:stroke-dashoffset .3s .05s}
      .dg-row.done .dg-box{background:var(--accent);border-color:var(--accent)}
      .dg-row.done .dg-box svg{stroke-dashoffset:0}
      .dg-txt{flex:1;min-width:0;font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;transition:color .25s}
      .dg-txt s{text-decoration-color:transparent;transition:text-decoration-color .3s}
      .dg-row.done .dg-txt{color:var(--faint)}
      .dg-row.done .dg-txt s{text-decoration-color:var(--faint)}
      .dg-star{flex:none;width:18px;height:18px;fill:var(--amber);opacity:0;transform:scale(.3);transition:opacity .2s,transform .35s cubic-bezier(.3,1.6,.5,1)}
      .dg-row.starred .dg-star{opacity:1;transform:scale(1)}
      .dg-due{flex:none;font-family:var(--f-mono);font-size:11px;color:var(--muted)}
      .dg-list canvas{position:absolute;inset:0;z-index:2;touch-action:none;cursor:crosshair}
      .dg-foot{display:flex;gap:14px;justify-content:space-between;align-items:center;min-height:34px;padding:0 4px}
      .dg-legend{display:flex;gap:12px;flex-wrap:wrap;font-family:var(--f-mono);font-size:11px;color:var(--muted)}
      .dg-legend span{display:inline-flex;align-items:center;gap:5px}
      .dg-legend svg{width:16px;height:16px;stroke:var(--accent);stroke-width:2;fill:none;stroke-linecap:round;stroke-linejoin:round}
      .dg-undo{display:flex;align-items:center;justify-content:space-between;gap:10px;width:100%;font-size:13px}
      .dg-undo button{height:32px;padding:0 14px}
    ` }));
    const TASKS = [
      ['Renew passport', 'Fri'], ['Book dentist for Ana', 'Mon'], ['Return library books', 'today'],
      ['Pay electricity bill', '21 Nov'], ['Water the balcony plants', 'today'],
    ];
    const ROW = 52;
    const root = h('div', { class: 'dg-root' });
    const count = h('span', { class: 'ft-mono ft-muted', style: { fontSize: '12px' } });
    const list = h('div', { class: 'dg-list', role: 'list', 'aria-label': 'Tasks' });
    const ICON = {
      check: 'M3 9 l4 4 l9 -10', circle: 'M9 2 a7 7 0 1 0 0.01 0', caret: 'M2 15 L9 3 L16 15', x: 'M3 3 L15 15 M15 3 L3 15',
    };
    const glyphSvg = d => `<svg viewBox="0 0 18 18" aria-hidden="true"><path d="${d}"/></svg>`;
    const legend = h('div', { class: 'dg-legend', html: `<span>${glyphSvg(ICON.check)}done</span><span>${glyphSvg(ICON.circle)}star</span><span>${glyphSvg(ICON.caret)}to top</span><span>${glyphSvg(ICON.x)}delete</span>` });
    const foot = h('div', { class: 'dg-foot' }, legend);
    root.append(h('div', { class: 'dg-head' }, h('b', null, 'Today'), count), list, foot);
    stage.append(root);

    let items = [], order = [];
    const mkItems = () => {
      list.querySelectorAll('.dg-row').forEach(r => r.remove());
      items = TASKS.map(([t, due], i) => {
        const el = h('div', { class: 'dg-row', role: 'listitem', tabindex: '0', 'data-hit': '' },
          h('span', { class: 'dg-box', html: '<svg viewBox="0 0 14 14"><path d="M2.5 7.5 l3 3 l6 -7"/></svg>' }),
          h('span', { class: 'dg-txt' }, h('s', null, t)),
          h('span', { html: '<svg class="dg-star" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2.6l2.9 6 6.6.8-4.9 4.6 1.3 6.5L12 17.3l-5.9 3.2 1.3-6.5L2.5 9.4l6.6-.8z"/></svg>' }),
          h('span', { class: 'dg-due' }, due));
        const it = { i, t, el, done: false, star: false, gone: false, y: FT.spring(i * ROW, FT.SPRING.smooth), o: FT.spring(1, FT.SPRING.smooth) };
        el.addEventListener('keydown', e => keyAct(it, e));
        list.insertBefore(el, cvHost);
        return it;
      });
      order = items.slice();
    };
    const cvHost = h('div', { style: { position: 'absolute', inset: '0', zIndex: 2 } });
    list.append(cvHost);
    let cv = null;
    cv = FT.canvas(cvHost, () => { if (cv) draw(); });
    cv.cv.style.touchAction = 'none';

    const layout = () => { order.forEach((it, k) => it.y.to(k * ROW)); rowLoop.wake(); };
    const rowLoop = FT.loop(dt => {
      let moving = false;
      for (const it of items) {
        if (!it.y.step(dt)) moving = true;
        if (!it.o.step(dt)) moving = true;
        it.el.style.transform = `translateY(${it.y.x}px) scale(${0.96 + 0.04 * it.o.x})`;
        it.el.style.opacity = String(FT.clamp(it.o.x, 0, 1));
        it.el.style.visibility = it.gone && it.o.x < 0.02 ? 'hidden' : '';
      }
      return moving;
    });
    const paintRows = () => {
      for (const it of items) {
        it.el.classList.toggle('done', it.done); it.el.classList.toggle('starred', it.star);
        it.el.setAttribute('aria-label', `${it.t}${it.done ? ', done' : ''}${it.star ? ', starred' : ''}`);
      }
      const left = order.filter(it => !it.done).length;
      count.textContent = `${left} of ${order.length} left`;
    };

    /* ---------- actions ---------- */
    let undoT = null, lastDeleted = null;
    const showLegend = () => { foot.replaceChildren(legend); };
    const act = (cmd, it, how) => {
      if (!it || it.gone) return;
      if (cmd === 'check') { it.done = !it.done; FT.haptic(it.done ? 'success' : 'light'); FT.announce(`${it.t} ${it.done ? 'done' : 'not done'}`); }
      else if (cmd === 'circle') { it.star = !it.star; FT.haptic('medium'); FT.announce(`${it.t} ${it.star ? 'starred' : 'unstarred'}`); }
      else if (cmd === 'caret') { order.splice(order.indexOf(it), 1); order.unshift(it); FT.haptic('medium'); FT.announce(`${it.t} moved to the top`); }
      else if (cmd === 'x') {
        const idx = order.indexOf(it); order.splice(idx, 1); it.gone = true; it.o.to(0);
        lastDeleted = { it, idx }; FT.haptic('heavy'); FT.announce(`Deleted ${it.t}. Undo is available.`);
        const undo = h('button', { class: 'ft-btn ghost', type: 'button', 'data-hit': '' }, 'Undo');
        undo.addEventListener('click', () => {
          if (!lastDeleted) return;
          const { it: d, idx: k } = lastDeleted; lastDeleted = null;
          d.gone = false; d.o.to(1); order.splice(Math.min(k, order.length), 0, d);
          layout(); paintRows(); showLegend(); clearTimeout(undoT); FT.haptic('light'); FT.announce(`Restored ${d.t}`); d.el.focus();
        });
        foot.replaceChildren(h('div', { class: 'dg-undo', role: 'status' }, h('span', null, `Deleted “${it.t}”`), undo));
        clearTimeout(undoT); undoT = setTimeout(() => { lastDeleted = null; showLegend(); }, 6000);
        if (how === 'key') undo.focus();
      }
      FT.intent(`${how === 'key' ? 'key' : 'glyph'} ${({ check: '✓ complete', circle: '○ star', caret: '^ to top', x: '✕ delete' })[cmd]} → “${it.t}”`);
      layout(); paintRows();
    };
    const keyAct = (it, e) => {
      const k = e.key.toLowerCase();
      const cmd = (k === 'c' || k === 'enter' || k === ' ') ? 'check' : k === 's' ? 'circle' : k === 't' ? 'caret' : (k === 'delete' || k === 'backspace') ? 'x' : null;
      if (!cmd) return;
      e.preventDefault(); act(cmd, it, 'key');
      if (cmd === 'caret') it.el.focus();
    };

    /* ---------- $1 recognizer (no rotation invariance, so ^ and ✓ stay distinct) ---------- */
    const NPTS = 64, SQ = 250;
    const pdist = (a, b) => Math.hypot(b.x - a.x, b.y - a.y);
    const plen = p => { let d = 0; for (let i = 1; i < p.length; i++) d += pdist(p[i - 1], p[i]); return d; };
    const resample = (src, n) => {
      const pts = src.map(p => ({ x: p.x, y: p.y })), I = plen(pts) / (n - 1), out = [pts[0]];
      let D = 0;
      for (let i = 1; i < pts.length; i++) {
        const d = pdist(pts[i - 1], pts[i]);
        if (D + d >= I && d > 0) {
          const q = { x: pts[i - 1].x + ((I - D) / d) * (pts[i].x - pts[i - 1].x), y: pts[i - 1].y + ((I - D) / d) * (pts[i].y - pts[i - 1].y) };
          out.push(q); pts.splice(i, 0, q); D = 0;
        } else D += d;
      }
      while (out.length < n) out.push(pts[pts.length - 1]);
      return out.slice(0, n);
    };
    const bbox = p => { let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9; for (const q of p) { x0 = Math.min(x0, q.x); y0 = Math.min(y0, q.y); x1 = Math.max(x1, q.x); y1 = Math.max(y1, q.y); } return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }; };
    const centroid = p => { let x = 0, y = 0; for (const q of p) { x += q.x; y += q.y; } return { x: x / p.length, y: y / p.length }; };
    const normalise = raw => {
      let p = resample(raw, NPTS);
      const b = bbox(p), s = Math.max(b.w, b.h, 1);
      // uniform-ish scaling: keep aspect when one side is tiny, so thin strokes don't explode
      const sx = SQ / Math.max(b.w, s * 0.3), sy = SQ / Math.max(b.h, s * 0.3);
      p = p.map(q => ({ x: q.x * sx, y: q.y * sy }));
      const c = centroid(p);
      return p.map(q => ({ x: q.x - c.x, y: q.y - c.y }));
    };
    const rot = (p, a) => { const c = Math.cos(a), s = Math.sin(a); return p.map(q => ({ x: q.x * c - q.y * s, y: q.x * s + q.y * c })); };
    const pathDist = (a, b) => { let d = 0; for (let i = 0; i < a.length; i++) d += pdist(a[i], b[i]); return d / a.length; };
    const PHI = 0.5 * (-1 + Math.sqrt(5));
    const bestAngle = (p, t, lo, hi) => {
      let x1 = PHI * lo + (1 - PHI) * hi, f1 = pathDist(rot(p, x1), t), x2 = (1 - PHI) * lo + PHI * hi, f2 = pathDist(rot(p, x2), t);
      while (Math.abs(hi - lo) > 0.035) {
        if (f1 < f2) { hi = x2; x2 = x1; f2 = f1; x1 = PHI * lo + (1 - PHI) * hi; f1 = pathDist(rot(p, x1), t); }
        else { lo = x1; x1 = x2; f1 = f2; x2 = (1 - PHI) * lo + PHI * hi; f2 = pathDist(rot(p, x2), t); }
      }
      return Math.min(f1, f2);
    };
    const densify = pts => pts.map(([x, y]) => ({ x, y }));
    const T = [];
    const addT = (name, pts) => { T.push({ name, p: normalise(densify(pts)), raw: pts }); T.push({ name, p: normalise(densify(pts.slice().reverse())), raw: pts }); };
    addT('check', [[0, 55], [30, 88], [100, 0]]);
    addT('check', [[0, 45], [40, 100], [100, 0]]);
    addT('caret', [[0, 100], [50, 0], [100, 100]]);
    addT('caret', [[0, 80], [50, 0], [100, 80]]);
    addT('x', [[0, 0], [100, 100], [100, 0], [0, 100]]);
    addT('x', [[100, 0], [0, 100], [0, 0], [100, 100]]);
    for (let k = 0; k < 8; k++) {
      const a0 = k * Math.PI / 4, pts = [];
      for (let i = 0; i <= 32; i++) { const a = a0 + i / 32 * Math.PI * 2; pts.push([50 + 50 * Math.cos(a), 50 + 50 * Math.sin(a)]); }
      T.push({ name: 'circle', p: normalise(densify(pts)), raw: pts });
      T.push({ name: 'circle', p: normalise(densify(pts.slice().reverse())), raw: pts });
    }
    const recognise = raw => {
      const p = normalise(raw);
      let best = null, bd = 1e9;
      for (const t of T) { const d = bestAngle(p, t.p, -0.44, 0.44); if (d < bd) { bd = d; best = t; } }
      return { name: best.name, score: 1 - bd / (0.5 * Math.sqrt(2 * SQ * SQ)), t: best };
    };

    /* ---------- drawing ---------- */
    let stroke = null, pending = null, pendingT = 0, fadeStroke = null, ghost = null, cheat = FT.spring(0, FT.SPRING.smooth), holdT = 0;
    const rowAt = y => { const k = Math.floor(y / ROW); return order[k] || null; };
    const commitStrokes = (strokes) => {
      const all = strokes.flat();
      const b = bbox(all);
      const straight = strokes.length === 1 && pdist(all[0], all[all.length - 1]) / Math.max(1, plen(all)) > 0.9;
      let name = null, score = 1;
      if (b.w < 14 && b.h < 14) return;
      if (straight) {
        if (b.h < b.w * 0.35 && b.w > 50) name = 'x';           // strike-through
        else if (b.w > 18 && b.h > 18) {                         // first half of a two-stroke ✕: wait for the second
          pending = strokes; pendingT = performance.now(); loop.wake(); return;
        }
      } else { const r = recognise(all); name = r.name; score = r.score; }
      const target = rowAt(b.y + b.h / 2);
      fadeStroke = { strokes, t: performance.now() };
      if (!name || score < 0.74 || !target) {
        FT.haptic('warning'); FT.intent(`stroke not recognised (best ${(score * 100).toFixed(0)}%)`);
        FT.announce('Glyph not recognised. Hold still to see the four glyphs.');
      } else {
        ghost = { name, b, t: performance.now(), strike: straight };
        act(name, target, 'glyph');
      }
      loop.wake();
    };
    const tri = (ctx, x, y, s) => { ctx.beginPath(); ctx.moveTo(x - s, y + s * .6); ctx.lineTo(x, y - s * .6); ctx.lineTo(x + s, y + s * .6); };
    const glyphPath = (ctx, name, x, y, s) => {
      ctx.beginPath();
      if (name === 'check') { ctx.moveTo(x - s, y); ctx.lineTo(x - s * .35, y + s * .65); ctx.lineTo(x + s, y - s * .75); }
      else if (name === 'circle') { ctx.arc(x, y, s * .85, 0, 7); }
      else if (name === 'caret') { tri(ctx, x, y, s); }
      else { ctx.moveTo(x - s * .8, y - s * .8); ctx.lineTo(x + s * .8, y + s * .8); ctx.moveTo(x + s * .8, y - s * .8); ctx.lineTo(x - s * .8, y + s * .8); }
    };
    function draw() {
      const { ctx, w, h: H } = cv;
      cv.clear();
      const now = performance.now();
      const ink = FT.col('--ink'), acc = FT.col('--accent');
      ctx.lineCap = 'round'; ctx.lineJoin = 'round';
      const drawStroke = (pts, a) => {
        if (pts.length < 2) return;
        ctx.strokeStyle = FT.alpha(ink, a); ctx.lineWidth = 3.2;
        ctx.beginPath(); ctx.moveTo(pts[0].x, pts[0].y);
        for (let i = 1; i < pts.length - 1; i++) { const mx = (pts[i].x + pts[i + 1].x) / 2, my = (pts[i].y + pts[i + 1].y) / 2; ctx.quadraticCurveTo(pts[i].x, pts[i].y, mx, my); }
        ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y); ctx.stroke();
      };
      if (pending) pending.forEach(s => drawStroke(s, 0.75));
      if (stroke) drawStroke(stroke.pts, 0.8);
      if (fadeStroke) { const k = (now - fadeStroke.t) / 380; if (k >= 1) fadeStroke = null; else fadeStroke.strokes.forEach(s => drawStroke(s, 0.7 * (1 - k))); }
      if (ghost) {
        const k = (now - ghost.t) / 750;
        if (k >= 1) ghost = null;
        else {
          const { b } = ghost, cx = b.x + b.w / 2, cy = b.y + b.h / 2, s = Math.max(16, Math.min(40, Math.max(b.w, b.h) / 2)) * (1 + k * 0.25);
          ctx.strokeStyle = FT.alpha(acc, (1 - k) * 0.9); ctx.lineWidth = 5;
          if (ghost.strike) { ctx.beginPath(); ctx.moveTo(b.x, cy); ctx.lineTo(b.x + b.w, cy); ctx.stroke(); }
          else { glyphPath(ctx, ghost.name, cx, cy, s); ctx.stroke(); }
          ctx.fillStyle = FT.alpha(acc, (1 - k)); ctx.font = '600 12px "Geist Mono", ui-monospace, monospace';
          const lab = ({ check: 'done', circle: 'starred', caret: 'to top', x: 'deleted' })[ghost.name];
          ctx.fillText(lab, FT.clamp(cx + s + 10, 6, w - 70), FT.clamp(cy + 4, 14, H - 6));
        }
      }
      if (cheat.x > 0.01 && stroke) {
        const o = stroke.pts[0], R = 62, a = FT.clamp(cheat.x, 0, 1);
        const cx = FT.clamp(o.x, R + 26, w - R - 26), cy = FT.clamp(o.y, R + 26, H - R - 30);
        const spots = [['caret', 0, -1, 'to top'], ['check', 1, 0, 'done'], ['circle', 0, 1, 'star'], ['x', -1, 0, 'delete']];
        ctx.fillStyle = FT.alpha(FT.col('--surface-2'), 0.94 * a);
        ctx.beginPath(); ctx.arc(cx, cy, R + 34, 0, 7); ctx.fill();
        ctx.strokeStyle = FT.alpha(FT.col('--line-2'), a); ctx.lineWidth = 1; ctx.stroke();
        for (const [n, dx, dy, lab] of spots) {
          const x = cx + dx * R * (0.8 + 0.2 * a), y = cy + dy * R * (0.8 + 0.2 * a);
          ctx.fillStyle = FT.alpha(acc, 0.12 * a); ctx.beginPath(); ctx.arc(x, y, 21, 0, 7); ctx.fill();
          ctx.strokeStyle = FT.alpha(acc, a); ctx.lineWidth = 2.4; glyphPath(ctx, n, x, y - 3, 9); ctx.stroke();
          ctx.fillStyle = FT.alpha(ink, 0.8 * a); ctx.font = '500 10px "Geist Mono", ui-monospace, monospace';
          const tw = ctx.measureText(lab).width; ctx.fillText(lab, x - tw / 2, y + 16);
        }
      }
    }
    const loop = FT.loop(dt => {
      const now = performance.now();
      if (stroke && !stroke.moved && now - holdT > 350 && cheat.t === 0) { cheat.to(1); FT.haptic('light'); FT.intent('held still: novice sheet shown'); }
      if (pending && !stroke && now - pendingT > 420) {
        const p = pending; pending = null;
        fadeStroke = { strokes: p, t: now }; FT.intent('single diagonal line: no command'); FT.haptic('warning');
      }
      const c = cheat.step(dt);
      draw();
      return stroke || pending || fadeStroke || ghost || !c;
    });
    FT.drag(cv.cv, {
      start(s) {
        stroke = { pts: [{ x: s.x, y: s.y }], moved: false }; holdT = performance.now();
        if (pending && performance.now() - pendingT > 420) pending = null;
        loop.wake();
      },
      move(s) {
        if (!stroke) return;
        stroke.pts.push({ x: s.x, y: s.y });
        if (s.moved && !stroke.moved) { stroke.moved = true; cheat.to(0); }
        loop.wake();
      },
      tap(s) {
        const it = rowAt(s.y);
        if (it && s.x < 50) act('check', it, 'tap');
      },
      end(s) {
        const st = stroke; stroke = null; cheat.to(0); loop.wake();
        if (!st || !st.moved || s.cancelled) return;
        if (pending) { const strokes = pending.concat([st.pts]); pending = null; commitStrokes(strokes); }
        else commitStrokes([st.pts]);
      },
    }, { axis: 'both', slop: 6 });
    cv.cv.setAttribute('aria-hidden', 'true');
    FT.onTheme(draw);

    const reset = () => { clearTimeout(undoT); lastDeleted = null; showLegend(); mkItems(); for (const it of items) { it.y.set(it.i * ROW); it.o.set(1); } paintRows(); rowLoop.wake(); };
    reset();
    // example state so the first frame shows what glyphs do
    items[2].done = true; items[0].star = true; paintRows();
    return { reset };
  },
});
