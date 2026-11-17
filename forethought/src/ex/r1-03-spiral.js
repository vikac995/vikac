/* I.3 Spiral dial — a multi-turn knob whose track shows magnitude. */
FT.exhibit({
  id: 'spiral-dial', room: 1, num: 3, kind: 'dial',
  title: 'The spiral dial',
  hint: 'Circle anywhere on the dial · flick to spin',
  height: 400,
  body: `<p>A knob that turns more than once. One full turn is 30 minutes, four turns is two hours, and the track spirals outward so you can see how far you've wound it. The knob rides the spiral. Every five minutes it ticks, and a flick keeps it spinning until friction stops it.</p><p>You don't have to grab the knob. Circle your finger anywhere on the dial and it follows your rotation, like a jog wheel. Big circles are calm, small fast circles cover ground.</p>`,
  why: `A round knob runs out of travel after one turn, so long ranges get crammed and lose precision. A spiral keeps the same precision on every turn and makes the total visible. You can tell 10 minutes from 100 at a glance.`,
  flutter: `
class SpiralDial extends StatefulWidget {
  const SpiralDial({super.key, required this.minutes, required this.onChanged});
  final double minutes;                        // 0…120, 30 per turn
  final ValueChanged<double> onChanged;
  @override State<SpiralDial> createState() => _SpiralDialState();
}

class _SpiralDialState extends State<SpiralDial> with SingleTickerProviderStateMixin {
  late final AnimationController theta = AnimationController.unbounded(vsync: this)
    ..value = widget.minutes / 30 * 2 * pi
    ..addListener(_emit);
  double? _lastAngle;

  void _emit() {
    final m = theta.value / (2 * pi) * 30;
    if ((m ~/ 5) != (widget.minutes ~/ 5)) HapticFeedback.selectionClick();
    widget.onChanged(m.clamp(0, 120));
  }

  void _update(DragUpdateDetails d, Offset centre) {
    final a = (d.localPosition - centre).direction;
    final delta = _lastAngle == null ? 0.0 : ((a - _lastAngle! + pi) % (2 * pi)) - pi;   // unwrap
    _lastAngle = a;
    theta.value = (theta.value + delta).clamp(0, 8 * pi);
  }

  void _end(DragEndDetails d) {
    _lastAngle = null;
    final omega = angularVelocity(d.velocity);    // rad/s from tangential speed / radius
    theta.animateWith(FrictionSimulation(0.05, theta.value, omega))
        .whenComplete(() => theta.animateWith(SpringSimulation(spring, theta.value, nearestMinute(theta.value), 0)));
  }

  @override
  Widget build(BuildContext context) => Semantics(
    slider: true, label: 'Timer', value: '\${widget.minutes.round()} minutes',
    onIncrease: () => _step(1), onDecrease: () => _step(-1),
    child: GestureDetector(onPanUpdate: (d) => _update(d, centre), onPanEnd: _end,
      child: CustomPaint(painter: SpiralPainter(theta: theta, turns: 4, r0: 46, r1: 160))),
  );
}`,
  a11y: `The dial is a <b>slider</b> from 0 to 120 minutes. <b>← →</b> change it by one minute, <b>Page Up/Down</b> by five, <b>Home/End</b> jump to the ends. The value is read as "47 minutes, ends at 15:12".`,
  mount(stage) {
    const { h } = FT;
    stage.append(h('style', null, `
      .sp-wrap{position:absolute;inset:0;cursor:grab;border-radius:24px}
      .sp-wrap:active{cursor:grabbing}
      .sp-read{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);text-align:center;pointer-events:none;line-height:1}
      .sp-num{font-family:var(--f-mono);font-variant-numeric:tabular-nums;font-size:34px;font-weight:600;letter-spacing:-.03em}
      .sp-unit{font-family:var(--f-mono);font-size:10.5px;color:var(--muted);letter-spacing:.08em;text-transform:uppercase;margin-top:4px}
      .sp-ends{position:absolute;right:16px;top:14px;font-family:var(--f-mono);font-size:11px;color:var(--muted);text-align:right;line-height:1.5;pointer-events:none}
      .sp-ends b{color:var(--ink);font-weight:600}
      .sp-turn{position:absolute;left:16px;top:14px;font-family:var(--f-mono);font-size:11px;color:var(--muted);pointer-events:none;line-height:1.5}
    `));
    const wrap = h('div', { class: 'sp-wrap', 'data-hit': '' });
    stage.append(wrap);
    let ready = false, sync = null;
    const cv = FT.canvas(wrap, () => { if (ready) draw(); });
    const num = h('div', { class: 'sp-num' }), unit = h('div', { class: 'sp-unit' }, 'minutes');
    const ends = h('div', { class: 'sp-ends' }), turn = h('div', { class: 'sp-turn' });
    stage.append(h('div', { class: 'sp-read' }, num, unit), ends, turn);

    const TURNS = 4, MAX = TURNS * 2 * Math.PI, PER = 30;
    const th = FT.spring(47 / PER * 2 * Math.PI, FT.SPRING.smooth);
    let omega = 0, coasting = false, dragging = false, lastA = null, lastBucket = -1, hist = [];
    const val = () => th.x / (2 * Math.PI) * PER;
    const geo = () => {
      const cx = cv.w / 2, cy = cv.h / 2 + 6;
      const r1 = Math.min(cv.w, cv.h) / 2 - 22, r0 = Math.max(44, r1 * 0.3);
      return { cx, cy, r0, r1, b: (r1 - r0) / MAX };
    };
    const pt = (g, t) => { const r = g.r0 + g.b * t, a = t - Math.PI / 2; return [g.cx + r * Math.cos(a), g.cy + r * Math.sin(a), r, a]; };

    function draw() {
      const { ctx } = cv; const g = geo();
      cv.clear();
      const line = FT.col('--line-2'), acc = FT.col('--accent'), muted = FT.col('--muted'), surf = FT.col('--surface-2'), ink = FT.col('--ink');
      const t = FT.clamp(th.x, 0, MAX);
      ctx.lineCap = 'round'; ctx.lineJoin = 'round';
      // full track
      ctx.strokeStyle = FT.alpha(line, 0.9); ctx.lineWidth = 9;
      ctx.beginPath();
      for (let s = 0; s <= MAX; s += 0.04) { const [x, y] = pt(g, s); s ? ctx.lineTo(x, y) : ctx.moveTo(x, y); }
      ctx.stroke();
      // minute ticks every 5 min, across the track
      for (let m = 5; m < 120; m += 5) {
        const s = m / PER * 2 * Math.PI, [x, y, , a] = pt(g, s);
        const major = m % 15 === 0;
        const L = major ? 4.5 : 2.5;
        ctx.strokeStyle = FT.alpha(s <= t ? FT.col('--accent-ink') : muted, s <= t ? 0.75 : (major ? 0.55 : 0.3));
        ctx.lineWidth = major ? 1.6 : 1.1;
        ctx.beginPath(); ctx.moveTo(x - Math.cos(a) * L, y - Math.sin(a) * L); ctx.lineTo(x + Math.cos(a) * L, y + Math.sin(a) * L); ctx.stroke();
      }
      // filled part: gradient of intensity per turn
      if (t > 0.001) {
        ctx.lineWidth = 9;
        const seg = 0.05;
        for (let s = 0; s < t; s += seg) {
          const e = Math.min(t, s + seg + 0.01);
          const [x1, y1] = pt(g, s), [x2, y2] = pt(g, e);
          ctx.strokeStyle = FT.alpha(acc, 0.55 + 0.45 * (s / MAX));
          ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
        }
      }
      // turn labels at the top, where each turn completes
      ctx.font = '500 10px "Geist Mono", ui-monospace, monospace'; ctx.textAlign = 'left'; ctx.textBaseline = 'middle';
      for (let k = 1; k <= TURNS; k++) {
        const [x, y] = pt(g, k * 2 * Math.PI);
        ctx.fillStyle = FT.alpha(k * PER <= val() + 0.01 ? ink : muted, 0.85);
        ctx.fillText(String(k * PER), x + 9, y - 1);
      }
      // start dot
      const [sx, sy] = pt(g, 0);
      ctx.fillStyle = muted; ctx.beginPath(); ctx.arc(sx, sy, 2, 0, 7); ctx.fill();
      // knob
      const [kx, ky] = pt(g, t);
      ctx.save();
      ctx.shadowColor = 'rgba(0,0,0,.28)'; ctx.shadowBlur = 10; ctx.shadowOffsetY = 2;
      ctx.fillStyle = surf; ctx.beginPath(); ctx.arc(kx, ky, 13, 0, 7); ctx.fill();
      ctx.restore();
      ctx.strokeStyle = acc; ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(kx, ky, 13, 0, 7); ctx.stroke();
      ctx.fillStyle = acc; ctx.beginPath(); ctx.arc(kx, ky, 3.5, 0, 7); ctx.fill();
      // readouts
      const v = Math.round(val());
      num.textContent = v;
      const end = new Date(Date.now() + v * 60000);
      ends.innerHTML = `ends at<br><b>${String(end.getHours()).padStart(2, '0')}:${String(end.getMinutes()).padStart(2, '0')}</b>`;
      turn.innerHTML = `turn<br><b style="color:var(--ink)">${Math.min(TURNS, Math.floor(val() / PER) + 1)} of ${TURNS}</b>`;
      sync && sync();
    }
    const tickHaptic = () => {
      const b = Math.floor(val() / 5 + 1e-6);
      if (b !== lastBucket) { if (lastBucket >= 0) FT.haptic(val() < 0.5 || val() > 119.5 ? 'medium' : 'select'); lastBucket = b; }
    };
    const loop = FT.loop(dt => {
      if (coasting) {
        th.x += omega * dt; th.t = th.x; th.v = 0;
        omega *= Math.exp(-2.6 * dt);
        if (th.x <= 0 || th.x >= MAX) { th.x = FT.clamp(th.x, 0, MAX); omega = 0; FT.haptic('medium'); }
        if (Math.abs(omega) < 0.35) { coasting = false; snap(); FT.intent(`coasted to ${Math.round(val())} min`); }
        tickHaptic(); draw();
        return true;
      }
      const done = th.step(dt); tickHaptic(); draw();
      return !done || dragging;
    });
    const snap = () => { const m = Math.round(FT.clamp(val(), 0, 120)); th.to(m / PER * 2 * Math.PI); loop.wake(); };
    const angleAt = s => { const g = geo(); return Math.atan2(s.y - g.cy, s.x - g.cx); };
    FT.drag(wrap, {
      start(s) { dragging = true; coasting = false; omega = 0; lastA = angleAt(s); th.set(th.x); hist = [[performance.now(), th.x]]; FT.intent('grabbed: following your rotation'); loop.wake(); },
      move(s) {
        const g = geo();
        if (Math.hypot(s.x - g.cx, s.y - g.cy) < 14) return; // dead zone at the centre
        const a = angleAt(s);
        let d = a - lastA; lastA = a;
        d = ((d + Math.PI) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI) - Math.PI;
        let nx = th.x + d;
        if (nx < 0 || nx > MAX) nx = FT.clamp(nx, 0, MAX);
        th.set(nx);
        const now = performance.now(); hist.push([now, nx]); while (hist.length > 2 && now - hist[0][0] > 90) hist.shift();
        loop.wake();
      },
      end(s) {
        dragging = false;
        const a = hist[0], b = hist[hist.length - 1];
        const w = b && a && b[0] - a[0] > 8 && performance.now() - b[0] < 70 ? (b[1] - a[1]) / ((b[0] - a[0]) / 1000) : 0;
        if (Math.abs(w) > 3 && !FT.reduced()) { omega = FT.clamp(w, -40, 40); coasting = true; FT.intent(`flick: ${w.toFixed(1)} rad/s, coasting`); }
        else { snap(); FT.intent(`set to ${Math.round(val())} min`); }
        FT.announce(`${Math.round(val())} minutes`);
        loop.wake();
      },
    }, { axis: 'both', slop: 2 });
    sync = FT.slider(wrap, {
      label: 'Timer length', min: 0, max: 120, step: 1, big: 5,
      get: () => Math.round(val()),
      set: v => { coasting = false; th.to(v / PER * 2 * Math.PI); loop.wake(); },
      text: v => { const e = new Date(Date.now() + v * 60000); return `${v} minutes, ends at ${String(e.getHours()).padStart(2, '0')}:${String(e.getMinutes()).padStart(2, '0')}`; },
    });
    FT.onTheme(draw);
    lastBucket = Math.floor(val() / 5);
    ready = true; draw();
    return { reset() { coasting = false; th.to(47 / PER * 2 * Math.PI); loop.wake(); } };
  },
});
