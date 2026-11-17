/* I.4 A slider that remembers — landmarks with soft magnetism, and hold-still fine mode. */
FT.exhibit({
  id: 'landmark-slider', room: 1, num: 4, kind: 'slider',
  title: 'A slider that remembers',
  hint: 'Drag the knob · pause mid-drag for fine control',
  height: 400,
  body: `<p>The track carries three landmarks: the default, the size you used last time, and the size suggested for your screen. Drag near one and the knob settles onto it with a soft click, so you can always get back to a known value. Drag straight through and it lets go.</p><p>Hold still for a moment mid-drag and the track zooms in five times around your finger. The same movement now moves the value a fifth as much. Keep dragging to fine-tune, then let go.</p>`,
  why: `A plain slider forgets everything: where you started, what the default was, what worked last time. Landmarks give the value a memory. Fine mode answers "a little more" without a second control: you ask for precision by pausing, which is what hands do anyway.`,
  flutter: `
class LandmarkSlider extends StatefulWidget {
  const LandmarkSlider({super.key, required this.value, required this.onChanged, required this.landmarks});
  final double value;
  final ValueChanged<double> onChanged;
  final Map<String, double> landmarks;          // {'Default': 16, 'Last used': 19, 'Suggested': 18}
  @override State<LandmarkSlider> createState() => _LandmarkSliderState();
}

class _LandmarkSliderState extends State<LandmarkSlider> with SingleTickerProviderStateMixin {
  late final AnimationController zoom = AnimationController.unbounded(vsync: this, value: 1);
  Timer? _dwell;
  double _raw = 0;                                // unsnapped value, so the magnet can be escaped

  void _update(DragUpdateDetails d, double pxPerUnit) {
    _dwell?.cancel();
    _dwell = Timer(const Duration(milliseconds: 400), () {    // held still → fine mode
      HapticFeedback.lightImpact();
      zoom.animateWith(SpringSimulation(spring, zoom.value, 5, 0));
    });
    _raw = (_raw + d.delta.dx / (pxPerUnit * zoom.value)).clamp(12, 28);
    final hit = widget.landmarks.values.where((v) => (v - _raw).abs() * pxPerUnit < 6);
    final next = hit.isEmpty || zoom.value > 1.5 ? _raw : hit.first;
    if (hit.isNotEmpty && next != widget.value) HapticFeedback.selectionClick();
    widget.onChanged(next);
  }

  void _end(DragEndDetails _) {
    _dwell?.cancel();
    zoom.animateWith(SpringSimulation(spring, zoom.value, 1, 0));
  }

  @override
  Widget build(BuildContext context) => Semantics(
    slider: true, label: 'Text size', value: '\${widget.value} pixels',
    child: GestureDetector(onHorizontalDragUpdate: (d) => _update(d, pxPerUnit),
      onHorizontalDragEnd: _end,
      child: CustomPaint(painter: LandmarkTrackPainter(value: widget.value, zoom: zoom, landmarks: widget.landmarks))),
  );
}`,
  a11y: `The track is a <b>slider</b> for text size, 12 to 28 px. <b>← →</b> move by 0.5 px, <b>Page Up/Down</b> by 2 px. <b>D</b>, <b>L</b> and <b>S</b> jump to the Default, Last used and Suggested landmarks. Landing on a landmark is announced by name.`,
  mount(stage) {
    const { h } = FT;
    stage.append(h('style', null, `
      .lm-card{position:absolute;left:18px;right:18px;top:18px;height:178px;overflow:hidden;padding:14px 16px}
      .lm-card::after{content:"";position:absolute;left:0;right:0;bottom:0;height:46px;background:linear-gradient(transparent,var(--surface-2))}
      .lm-meta{display:flex;justify-content:space-between;font-family:var(--f-mono);font-size:10.5px;color:var(--muted);letter-spacing:.06em;text-transform:uppercase;margin-bottom:8px}
      .lm-meta b{color:var(--accent);font-weight:600}
      .lm-text{margin:0;line-height:1.45;color:var(--ink);font-family:var(--f-body)}
      .lm-track{position:absolute;left:0;right:0;bottom:0;height:186px;cursor:grab}
      .lm-track:active{cursor:grabbing}
      .lm-read{position:absolute;left:0;right:0;top:212px;text-align:center;font-family:var(--f-mono);font-size:12px;color:var(--muted);pointer-events:none}
      .lm-read b{color:var(--ink);font-size:15px;font-weight:600}
      .lm-fine{display:inline-block;margin-left:6px;padding:2px 8px;border-radius:999px;background:var(--accent);color:var(--accent-ink);font-size:10.5px;font-weight:600;vertical-align:1px}
    `));
    const meta = h('div', { class: 'lm-meta' }, h('span', null, 'Article · 4 min read'), h('span'));
    const sizeLab = meta.lastChild;
    const text = h('p', { class: 'lm-text' }, 'The first ferry leaves Split at 7:30 and reaches Stari Grad a little after nine. Sit on the left deck: the sun rises over Brač while the coffee is still hot, and the island comes into view slowly, one terrace at a time.');
    stage.append(h('div', { class: 'lm-card ft-card' }, meta, text));
    const read = h('div', { class: 'lm-read' });
    const track = h('div', { class: 'lm-track', 'data-hit': '' });
    stage.append(read, track);
    let ready = false;
    const cv = FT.canvas(track, () => { if (ready) draw(); });

    const MIN = 12, MAX = 28;
    const LM = [{ v: 16, name: 'Default', key: 'd', up: true }, { v: 18, name: 'Suggested', key: 's', up: false }, { v: 19, name: 'Last used', key: 'l', up: true }];
    const val = FT.spring(17, FT.SPRING.snappy);      // displayed value
    const zoom = FT.spring(0, FT.SPRING.smooth);      // 0 = full range, 1 = fine ×5
    let raw = 17, centre = 17, fine = false, dragging = false, lastMoveT = 0, snapped = null, lastX = 0;
    const PADX = 28;
    const view = () => {
      const t = FT.clamp(zoom.x, 0, 1.2), half = (MAX - MIN) / 10;
      let fmin = centre - half, fmax = centre + half;
      if (fmin < MIN) { fmax += MIN - fmin; fmin = MIN; } if (fmax > MAX) { fmin -= fmax - MAX; fmax = MAX; }
      return [FT.lerp(MIN, fmin, t), FT.lerp(MAX, fmax, t)];
    };
    const W = () => cv.w - PADX * 2;
    const xOf = v => { const [a, b] = view(); return PADX + (v - a) / (b - a) * W(); };
    const pxPer = () => { const [a, b] = view(); return W() / (b - a); };
    const TY = 92;

    function draw() {
      const { ctx } = cv; cv.clear();
      const line = FT.col('--line-2'), acc = FT.col('--accent'), muted = FT.col('--muted'), ink = FT.col('--ink'), surf = FT.col('--surface-2'), amb = FT.col('--amber');
      const [a, b] = view();
      ctx.save(); ctx.beginPath(); ctx.rect(PADX - 14, 0, W() + 28, cv.h); ctx.clip();
      // ticks every 0.5 px of value; majors on whole numbers
      for (let v = Math.ceil(a * 2) / 2; v <= b + 1e-6; v += 0.5) {
        const x = xOf(v), major = Math.abs(v - Math.round(v)) < 1e-6;
        const show4 = major && (Math.round(v) % 4 === 0 || zoom.x > 0.5);
        ctx.strokeStyle = FT.alpha(muted, major ? 0.55 : 0.25 + 0.25 * zoom.x);
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(x, TY + 14); ctx.lineTo(x, TY + 14 + (major ? 9 : 5)); ctx.stroke();
        if (show4) { ctx.fillStyle = FT.alpha(muted, 0.85); ctx.font = '10px "Geist Mono", ui-monospace, monospace'; ctx.textAlign = 'center'; ctx.fillText(String(Math.round(v)), x, TY + 36); }
      }
      // fine sub-ticks (0.1) when zoomed
      if (zoom.x > 0.15) {
        for (let v = Math.ceil(a * 10) / 10; v <= b; v += 0.1) {
          const x = xOf(v); ctx.strokeStyle = FT.alpha(muted, 0.25 * zoom.x);
          ctx.beginPath(); ctx.moveTo(x, TY + 14); ctx.lineTo(x, TY + 17); ctx.stroke();
        }
      }
      // track
      ctx.lineCap = 'round'; ctx.lineWidth = 6;
      ctx.strokeStyle = FT.alpha(line, 1); ctx.beginPath(); ctx.moveTo(xOf(MIN), TY); ctx.lineTo(xOf(MAX), TY); ctx.stroke();
      ctx.strokeStyle = acc; ctx.beginPath(); ctx.moveTo(xOf(MIN), TY); ctx.lineTo(xOf(val.x), TY); ctx.stroke();
      // landmarks: labels above or below the track, pushed apart so they never overlap
      ctx.font = '600 10.5px "Geist Mono", ui-monospace, monospace';
      const labs = LM.map(L => { const t = `${L.name} ${L.v}`; return { L, t, x: xOf(L.v), w: ctx.measureText(t).width + 12 }; });
      for (const up of [true, false]) {
        const row = labs.filter(o => o.L.up === up).sort((p, q) => p.x - q.x);
        row.forEach(o => { o.lx = o.x; });
        for (let k = 0; k < 4; k++) {
          for (let i = 1; i < row.length; i++) {
            const a = row[i - 1], b = row[i], need = (a.w + b.w) / 2 + 6 - (b.lx - a.lx);
            if (need > 0) { a.lx -= need / 2; b.lx += need / 2; }
          }
          row.forEach(o => { o.lx = FT.clamp(o.lx, PADX - 12 + o.w / 2, cv.w - PADX + 12 - o.w / 2); });
        }
      }
      for (const o of labs) {
        const { L } = o, x = o.x, on = snapped === L.name;
        if (x < PADX - 6 || x > cv.w - PADX + 6) continue;   // outside the zoomed view
        const yLab = L.up ? TY - 44 : TY + 54;
        ctx.strokeStyle = FT.alpha(on ? amb : muted, on ? 1 : 0.5); ctx.lineWidth = 1;
        ctx.beginPath();
        if (L.up) { ctx.moveTo(o.lx, yLab + 9); ctx.lineTo(x, TY - 16); ctx.lineTo(x, TY - 6); }
        else { ctx.moveTo(x, TY + 6); ctx.lineTo(x, TY + 30); ctx.lineTo(o.lx, yLab - 10); }
        ctx.stroke();
        ctx.fillStyle = on ? amb : surf; ctx.strokeStyle = on ? amb : FT.alpha(muted, 0.8); ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.arc(x, TY, 4.5, 0, 7); ctx.fill(); ctx.stroke();
        ctx.font = (on ? '600 ' : '500 ') + '10.5px "Geist Mono", ui-monospace, monospace'; ctx.textAlign = 'center';
        const tw = o.w, lx = o.lx;
        ctx.fillStyle = on ? amb : FT.alpha(surf, 0.95);
        ctx.beginPath(); ctx.roundRect ? ctx.roundRect(lx - tw / 2, yLab - 10, tw, 19, 9.5) : ctx.rect(lx - tw / 2, yLab - 10, tw, 19); ctx.fill();
        if (!on) { ctx.strokeStyle = FT.alpha(muted, 0.35); ctx.lineWidth = 1; ctx.stroke(); }
        ctx.fillStyle = on ? FT.col('--bg') : ink; ctx.textBaseline = 'middle'; ctx.fillText(o.t, lx, yLab);
        ctx.textBaseline = 'alphabetic';
      }
      ctx.restore();
      // thumb
      const tx = xOf(val.x);
      ctx.save(); ctx.shadowColor = 'rgba(0,0,0,.25)'; ctx.shadowBlur = 8; ctx.shadowOffsetY = 2;
      ctx.fillStyle = surf; ctx.beginPath(); ctx.arc(tx, TY, 13 + zoom.x * 2, 0, 7); ctx.fill(); ctx.restore();
      ctx.strokeStyle = acc; ctx.lineWidth = 2.5; ctx.beginPath(); ctx.arc(tx, TY, 13 + zoom.x * 2, 0, 7); ctx.stroke();
      // readouts
      const v = Math.round(val.x * 10) / 10;
      text.style.fontSize = val.x + 'px';
      sizeLab.innerHTML = `<b>${v.toFixed(1)} px</b>`;
      read.innerHTML = `<b>${v.toFixed(1)} px</b>${snapped ? ` · ${snapped}` : ''}${zoom.x > 0.3 ? ' <span class="lm-fine">fine ×5</span>' : ''}`;
      sync && sync();
    }
    const loop = FT.loop((dt, now) => {
      if (dragging && !fine && now - lastMoveT > 400) {
        fine = true; centre = raw; zoom.to(1); FT.haptic('light'); FT.intent('held still: fine mode ×5');
        FT.announce('Fine adjustment');
      }
      const a = val.step(dt), b = zoom.step(dt);
      draw();
      return dragging || !(a && b);
    });
    const applyRaw = (fromKey) => {
      raw = FT.clamp(raw, MIN, MAX);
      let target = raw, hit = null;
      if (zoom.x < 0.5) for (const L of LM) if (Math.abs(L.v - raw) * pxPer() < 7) { target = L.v; hit = L.name; }
      if (hit !== snapped) {
        snapped = hit;
        if (hit) { FT.haptic('select'); FT.intent(`magnet: ${hit}`); FT.announce(`${hit}, ${target} pixels`); }
      }
      val.to(dragging ? Math.round(target * 10) / 10 : target);
      loop.wake();
    };
    FT.drag(track, {
      start(s) {
        dragging = true; fine = false; lastMoveT = performance.now(); lastX = s.x;
        const tx = xOf(val.x);
        raw = Math.abs(s.x - tx) > 22 ? view()[0] + (s.x - PADX) / pxPer() : val.t;  // tap away from the knob jumps there
        applyRaw();
        loop.wake();
      },
      move(s) {
        const d = s.x - lastX; lastX = s.x;
        if (Math.abs(d) > 0.6) lastMoveT = performance.now();
        raw += d / pxPer();
        if (fine) centre = FT.clamp(centre + (raw - centre) * 0.08, MIN, MAX);  // view drifts gently after the finger
        applyRaw();
      },
      end() {
        dragging = false; fine = false; zoom.to(0);
        val.to(snapped ? LM.find(L => L.name === snapped).v : Math.round(raw * 2) / 2 === raw ? raw : Math.round(raw * 10) / 10);
        FT.intent(`released at ${val.t.toFixed(1)} px`); loop.wake();
      },
    }, { axis: 'x', slop: 3 });
    const sync = FT.slider(track, {
      label: 'Text size', min: MIN, max: MAX, step: 0.5, big: 2,
      get: () => Math.round(val.t * 10) / 10,
      set: v => { raw = v; snapped = (LM.find(L => L.v === v) || {}).name || null; val.to(v); loop.wake(); },
      text: v => `${v} pixels${(LM.find(L => L.v === v) || {}).name ? ', ' + LM.find(L => L.v === v).name : ''}`,
    });
    track.addEventListener('keydown', e => {
      const L = LM.find(l => l.key === e.key.toLowerCase());
      if (!L) return;
      e.preventDefault(); raw = L.v; snapped = L.name; val.to(L.v); loop.wake(); FT.haptic('select'); FT.announce(`${L.name}, ${L.v} pixels`); sync();
    });
    FT.onTheme(draw);
    ready = true; draw();
    return { reset() { raw = 17; snapped = null; val.to(17); zoom.to(0); loop.wake(); } };
  },
});
