/* III.3 Values with a margin — set a time and how sure you are, in one drag. */
FT.exhibit({
  id: 'fuzzy-values', room: 3, num: 3, kind: 'proposal · input', replaces: 'a false-precision time field',
  title: 'Values with a margin',
  hint: 'Drag sideways for the time · drag up if you’re less sure',
  height: 420,
  body: `<p>"When will you arrive?" rarely has an exact answer. Drag sideways to set the time, then drag upward to say how sure you are. The sharp pin spreads into a hill: "around 19:30, give or take 20 minutes".</p><p>Because both answers carry their margin, the app can do honest arithmetic. Mira said "around 20:00". Exact times would claim you miss each other by half an hour. With margins, it shows the real chance you arrive within 15 minutes of each other, and shades where your hills overlap.</p>`,
  why: `Forms force false precision, and then apps make confident decisions from numbers people guessed. Letting people state a margin costs one extra direction of the same drag and makes everything computed from it truthful.`,
  flutter: `
@immutable
class Fuzzy {                                       // a value people actually know
  const Fuzzy(this.mean, this.margin);              // margin = 80% interval half-width
  final Duration mean, margin;
  double get sigma => math.max(1.5, margin.inMinutes / 1.2816);
}

double chanceWithin(Fuzzy a, Fuzzy b, {int minutes = 15}) {
  final d = (a.mean - b.mean).inMinutes.toDouble();
  final s = math.sqrt(a.sigma * a.sigma + b.sigma * b.sigma);
  return _phi((minutes - d) / s) - _phi((-minutes - d) / s);   // P(|A − B| < 15 min)
}

class FuzzyTimeField extends StatelessWidget {
  const FuzzyTimeField({super.key, required this.value, required this.onChanged});
  final Fuzzy value; final ValueChanged<Fuzzy> onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
    slider: true, value: describe(value),
    onIncrease: () => onChanged(Fuzzy(value.mean + const Duration(minutes: 5), value.margin)),
    onDecrease: () => onChanged(Fuzzy(value.mean - const Duration(minutes: 5), value.margin)),
    child: GestureDetector(
      onPanUpdate: (d) {
        final mean = value.mean + Duration(minutes: (d.delta.dx * minutesPerPx).round());
        final margin = value.margin + Duration(minutes: (-d.delta.dy * marginPerPx).round());
        onChanged(Fuzzy(snap5(mean), clampMargin(snap5(margin))));
      },
      child: CustomPaint(painter: BellPainter(value, other: miraArrival)),
    ),
  );
}`,
  a11y: `The chart is one slider. <b>← →</b> move the time by 5 minutes; <b>Shift + ← →</b> (or <b>↑ ↓</b>) change the margin. It reads as "around 19:30, give or take 20 minutes; 34% chance you arrive within 15 minutes of Mira".`,
  mount(stage) {
    const { h } = FT;
    const css = h('style', null, `
.fz-top{position:absolute;left:18px;right:18px;top:16px;display:flex;justify-content:space-between;align-items:flex-start;gap:10px}
.fz-big{font-family:var(--f-display);font-size:34px;line-height:1;margin-top:6px;white-space:nowrap}
.fz-big em{font-style:italic;color:var(--accent)}
.fz-rng{font-size:12px;color:var(--muted);margin-top:6px;white-space:nowrap}
.fz-mira{flex:none;font-size:11.5px;text-align:right;color:var(--muted);line-height:1.4;padding:6px 10px;border-radius:12px;background:var(--amber-soft)}
.fz-mira b{color:var(--ink);display:block;font-size:12.5px}
.fz-plot{position:absolute;left:0;right:0;top:112px;bottom:70px;cursor:grab;outline-offset:-4px}
.fz-plot:active{cursor:grabbing}
.fz-out{position:absolute;left:18px;right:18px;bottom:14px;display:grid;grid-template-columns:auto minmax(0,1fr);gap:12px;align-items:center;padding:8px 12px;border-radius:14px;background:var(--surface-2);border:1px solid var(--line)}
.fz-pct{font-family:var(--f-display);font-size:34px;line-height:1;color:var(--ok);min-width:2.6ch;text-align:right}
.fz-txt{font-size:12.5px;line-height:1.35;color:var(--ink-2)}
.fz-txt s{color:var(--muted)}
`);
    const ask = h('div', null, h('div', { class: 'ft-label' }, 'When will you arrive?'), h('div', { class: 'fz-big' }), h('div', { class: 'fz-rng ft-mono' }));
    const [big, rng] = [ask.children[1], ask.children[2]];
    const mira = h('div', { class: 'fz-mira' }, h('b', null, 'Mira'), 'around 20:00', h('br'), 'give or take 15');
    const plot = h('div', { class: 'fz-plot', 'data-hit': '' });
    const pct = h('div', { class: 'fz-pct ft-mono' });
    const txt = h('div', { class: 'fz-txt' });
    stage.append(css, h('div', { class: 'fz-top' }, ask, mira), plot, h('div', { class: 'fz-out' }, pct, txt));

    const T0 = 18 * 60, T1 = 22 * 60, MIRA = { mu: 20 * 60, m: 15 };
    const st = { mu: 19 * 60 + 30, m: 20 };
    const sig = m => Math.max(1.6, m / 1.2816);
    const mu = FT.spring(st.mu, FT.SPRING.snappy), sg = FT.spring(sig(st.m), FT.SPRING.snappy);
    const fmt = t => `${String(Math.floor(t / 60)).padStart(2, '0')}:${String(Math.round(t % 60)).padStart(2, '0')}`;
    const erf = x => { const s = Math.sign(x); x = Math.abs(x); const t = 1 / (1 + 0.3275911 * x); return s * (1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * Math.exp(-x * x)); };
    const phi = z => 0.5 * (1 + erf(z / Math.SQRT2));
    const chance = () => { const d = st.mu - MIRA.mu, s = Math.hypot(sig(st.m), sig(MIRA.m)); return phi((15 - d) / s) - phi((-15 - d) / s); };
    const describe = () => st.m === 0 ? `at ${fmt(st.mu)} exactly` : `around ${fmt(st.mu)}, give or take ${st.m} minutes`;

    const text = () => {
      big.innerHTML = st.m === 0 ? `at <em>${fmt(st.mu)}</em>` : `around <em>${fmt(st.mu)}</em>`;
      rng.textContent = st.m === 0 ? 'exactly, no margin' : `${fmt(st.mu - st.m)} – ${fmt(st.mu + st.m)} · ±${st.m} min`;
      const p = Math.round(chance() * 100), gap = Math.abs(st.mu - MIRA.mu);
      pct.textContent = p + '%';
      const exact = gap <= 15 ? `Exact times say you meet (${gap} min apart).` : `Exact times say you miss by ${gap} min.`;
      txt.innerHTML = `chance you arrive within 15 min of Mira. <s>${exact}</s>`;
      sync();
    };
    let dragging = false, base0 = null, cv = null;
    cv = FT.canvas(plot, () => { if (cv) draw(); });
    const X = t => 18 + (t - T0) / (T1 - T0) * (cv.w - 36);
    const draw = () => {
      const { ctx, w, h: H } = cv;
      cv.clear();
      const base = H - 30, top = 10, hmax = base - top;
      const acc = FT.col('--accent'), amb = FT.col('--amber'), ok = FT.col('--ok'), line = FT.col('--line-2'), mut = FT.col('--muted'), ink = FT.col('--ink');
      // axis
      ctx.strokeStyle = line; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(10, base + 0.5); ctx.lineTo(w - 10, base + 0.5); ctx.stroke();
      ctx.font = '500 10.5px "Geist Mono", ui-monospace, monospace'; ctx.textAlign = 'center'; ctx.fillStyle = mut;
      for (let t = T0; t <= T1; t += 30) {
        const x = Math.round(X(t)) + 0.5, hr = t % 60 === 0;
        ctx.beginPath(); ctx.moveTo(x, base); ctx.lineTo(x, base + (hr ? 6 : 3)); ctx.stroke();
        if (hr) ctx.fillText(fmt(t), FT.clamp(x, 22, w - 22), base + 19);
      }
      const curve = (m, s) => t => Math.exp(-0.5 * ((t - m) / s) ** 2) * Math.min(1, Math.pow(9 / s, 0.42)) * hmax;
      const you = curve(mu.x, sg.x), her = curve(MIRA.mu, sig(MIRA.m));
      const path = (f, close) => { ctx.beginPath(); ctx.moveTo(X(T0), base); for (let t = T0; t <= T1; t += 0.5) ctx.lineTo(X(t), base - f(t)); if (close) ctx.lineTo(X(T1), base); };
      // overlap
      path(t => Math.min(you(t), her(t)), true); ctx.fillStyle = FT.alpha(ok, 0.42); ctx.fill();
      // Mira
      path(her, true); ctx.fillStyle = FT.alpha(amb, 0.16); ctx.fill();
      path(her, false); ctx.strokeStyle = amb; ctx.lineWidth = 2; ctx.stroke();
      // you
      path(you, true); ctx.fillStyle = FT.alpha(acc, 0.14); ctx.fill();
      path(you, false); ctx.strokeStyle = acc; ctx.lineWidth = 2.5; ctx.stroke();
      // labels
      ctx.font = '600 11px "Geist", system-ui, sans-serif';
      const herPk = base - her(MIRA.mu), youPk = base - you(mu.x);
      ctx.fillStyle = amb; ctx.fillText('Mira', X(MIRA.mu), herPk - 8);
      // margin bracket on the axis
      const lo = X(mu.x - sg.x * 1.2816), hi = X(mu.x + sg.x * 1.2816);
      ctx.strokeStyle = acc; ctx.lineWidth = 3; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(lo, base); ctx.lineTo(hi, base); ctx.stroke();
      // handle
      const hx = X(mu.x), hy = Math.max(top + 10, youPk);
      ctx.fillStyle = acc; ctx.beginPath(); ctx.arc(hx, hy, 8, 0, 7); ctx.fill();
      ctx.strokeStyle = FT.col('--surface-2'); ctx.lineWidth = 2.5; ctx.stroke();
      ctx.fillStyle = acc; ctx.textAlign = hx > w - 60 ? 'right' : 'left';
      ctx.fillText('You', hx + (hx > w - 60 ? -14 : 14), hy + 4);
      if (!dragging && st.m < 60) { // affordance: up = less sure
        ctx.strokeStyle = FT.alpha(ink, 0.35); ctx.lineWidth = 1.5;
        const ay = hy - 16; if (ay > top + 8) { ctx.beginPath(); ctx.moveTo(hx, ay); ctx.lineTo(hx, ay - 12); ctx.moveTo(hx - 4, ay - 8); ctx.lineTo(hx, ay - 12); ctx.lineTo(hx + 4, ay - 8); ctx.stroke(); }
      }
    };
    const loop = FT.loop(dt => { const a = mu.step(dt), b = sg.step(dt); draw(); return !(a && b); });
    const apply = (nmu, nm, how) => {
      nmu = FT.clamp(Math.round(nmu / 5) * 5, T0 + 10, T1 - 10); nm = FT.clamp(Math.round(nm / 5) * 5, 0, 60);
      if (nmu === st.mu && nm === st.m) return;
      const mChanged = nm !== st.m;
      st.mu = nmu; st.m = nm; mu.to(nmu); sg.to(sig(nm)); loop.wake(); text();
      FT.haptic('select');
      FT.intent(`${how}: ${describe()} → ${Math.round(chance() * 100)}% overlap`);
      if (how === 'keys') FT.announce(`${describe()}. ${Math.round(chance() * 100)} percent chance you arrive within 15 minutes of Mira.`);
      else if (mChanged && nm === 0) FT.intent('margin 0: a pin, false precision');
    };
    FT.drag(plot, {
      start() { dragging = true; base0 = { ...st }; },
      move(s) {
        const perPx = (T1 - T0) / (cv.w - 36);
        apply(base0.mu + s.dx * perPx, base0.m - s.dy * 0.42, Math.abs(s.dy) > Math.abs(s.dx) ? 'drag up/down = margin' : 'drag sideways = time');
      },
      tap(s) { apply(T0 + (s.x - 18) / (cv.w - 36) * (T1 - T0), st.m, 'tap = time'); },
      end() { dragging = false; draw(); },
    }, { axis: 'both' });
    plot.tabIndex = 0; plot.setAttribute('role', 'slider'); plot.setAttribute('aria-label', 'Your arrival time and margin');
    plot.setAttribute('aria-valuemin', T0); plot.setAttribute('aria-valuemax', T1);
    function sync() { plot.setAttribute('aria-valuenow', st.mu); plot.setAttribute('aria-valuetext', `${describe()}; ${Math.round(chance() * 100)}% chance you arrive within 15 minutes of Mira`); }
    plot.addEventListener('keydown', e => {
      const k = e.key;
      if (k === 'ArrowUp' || (e.shiftKey && k === 'ArrowRight')) apply(st.mu, st.m + 5, 'keys');
      else if (k === 'ArrowDown' || (e.shiftKey && k === 'ArrowLeft')) apply(st.mu, st.m - 5, 'keys');
      else if (k === 'ArrowRight') apply(st.mu + 5, st.m, 'keys');
      else if (k === 'ArrowLeft') apply(st.mu - 5, st.m, 'keys');
      else return;
      e.preventDefault();
    });
    FT.onTheme(draw);
    text(); draw();
    return { reset() { st.mu = 19 * 60 + 30; st.m = 20; mu.to(st.mu); sg.to(sig(st.m)); loop.wake(); text(); } };
  },
});
