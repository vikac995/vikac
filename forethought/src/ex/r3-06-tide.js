/* III.6 Urgency floats up — tasks rise toward the surface as their deadlines approach. */
FT.exhibit({
  id: 'urgency-tide', room: 3, num: 6, kind: 'proposal · priority', replaces: 'manual priority sorting',
  title: 'Urgency floats up',
  hint: 'Slide time forward · drag a task down to push it under',
  height: 500,
  body: `<p>Your tasks float in water. Depth is time left: the closer a deadline, the higher a task rises, and anything due now breaks the surface and bobs there. Slide time forward and watch the week rise.</p><p>Not today? Drag a task down and it sinks. It doesn't stay buried: it drifts back up as its deadline approaches and surfaces in time. Drag a task up to deal with it sooner.</p>`,
  why: `Priority lists go stale the moment you sort them, because time keeps moving and the list doesn't. Here the order maintains itself, and "later" is a depth that wears off instead of a flag that hides things until they're overdue.`,
  flutter: `
class Task { Task(this.title, this.due); final String title; final DateTime due; Duration push = Duration.zero; DateTime? pushedAt; }

/// Time left, plus any push that wears off linearly as the deadline approaches.
Duration effectiveLeft(Task t, DateTime now) {
  final left = t.due.difference(now);
  if (t.pushedAt == null) return left;
  final span = math.max(t.due.difference(t.pushedAt!).inMinutes, t.push.inMinutes.abs()).clamp(60, 1 << 30);
  final fade = (1 - now.difference(t.pushedAt!).inMinutes / span).clamp(0.0, 1.0);
  return left + t.push * fade;                      // gone by the deadline
}

class TideView extends StatelessWidget {
  const TideView({super.key, required this.tasks, required this.now});
  final List<Task> tasks; final DateTime now;
  double depthFor(Task t, double range) =>
      math.pow((effectiveLeft(t, now).inMinutes / (72 * 60)).clamp(0.0, 1.0), .75) * range;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final range = box.maxHeight - 80;
    return Stack(children: [
      const Positioned.fill(child: RepaintBoundary(child: WaterPainterWidget())),   // ticker sleeps off-screen
      for (final t in tasks)
        AnimatedPositioned(                       // or a SpringSimulation per task
          duration: const Duration(milliseconds: 420), curve: Curves.easeOutBack,
          top: 46 + depthFor(t, range), left: columnOf(t),
          child: Draggable(axis: Axis.vertical, feedback: TaskPill(t), child: TaskPill(t)),
        ),
      // Screen readers get a ListView sorted by effectiveLeft, with "Push 6 hours" actions.
    ]);
  });
}`,
  a11y: `Each task is a button: <b>↓</b> pushes it 6 hours under, <b>↑</b> raises it 6 hours, and the new "resurfaces in…" time is announced. The time slider moves with <b>← →</b>. A hidden list keeps the tasks in urgency order for screen readers and updates when the order changes.`,
  mount(stage) {
    const { h } = FT;
    const css = h('style', null, `
.td-tank{position:absolute;left:14px;right:14px;top:14px;bottom:86px;border-radius:18px;overflow:hidden;border:1px solid var(--line);background:var(--surface-2)}
.td-pill{position:absolute;top:0;left:0;display:flex;flex-direction:column;align-items:flex-start;gap:1px;padding:5px 10px 6px;border-radius:12px;border:1px solid var(--line);background:var(--surface-2);box-shadow:var(--shadow);cursor:grab;text-align:left;font:inherit;color:var(--ink);will-change:transform}
.td-pill:active{cursor:grabbing}
.td-pill b{font-size:12.5px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:100%}
.td-pill span{font-family:var(--f-mono);font-size:10.5px;color:var(--muted);white-space:nowrap}
.td-pill.due{border-color:var(--hot)}
.td-pill.due span{color:var(--hot)}
.td-pill.soon span{color:var(--amber)}
.td-pill.pushed span::before{content:"↓ ";color:var(--accent)}
.td-pill.held{box-shadow:0 0 0 2px var(--accent),var(--shadow)}
.td-air{position:absolute;right:12px;top:8px;font-size:10px}
.td-scale{position:absolute;left:8px;font-size:9.5px;transform:translateY(-50%);pointer-events:none}
.td-time{position:absolute;left:16px;right:16px;bottom:14px;display:flex;flex-direction:column;gap:8px}
.td-time-top{display:flex;justify-content:space-between;align-items:baseline;font-size:12.5px}
.td-time-top b{font-family:var(--f-display);font-weight:400;font-size:22px}
.td-track{position:relative;height:30px;cursor:pointer}
.td-track::before{content:"";position:absolute;left:0;right:0;top:13px;height:4px;border-radius:4px;background:var(--line-2)}
.td-fill{position:absolute;left:0;top:13px;height:4px;border-radius:4px;background:var(--accent)}
.td-thumb{position:absolute;top:4px;width:22px;height:22px;margin-left:-11px;border-radius:50%;background:var(--surface-2);border:2px solid var(--accent);box-shadow:var(--shadow)}
`);
    const NOW0 = 9; // Monday 09:00
    const TASKS = [
      ['Slides to Tomo', 0.75], ['Reply to Kora', 3], ['Electricity bill', 8], ['Water plants', 20],
      ['Gift for Mira', 30], ['Book dentist', 50], ['Bike insurance', 66],
    ].map(([title, due], i) => ({ title, due, push: 0, pushedAt: 0, col: i % 2, y: FT.spring(0, FT.SPRING.smooth), ty: 0, el: null }));
    const tank = h('div', { class: 'td-tank' });
    const air = h('span', { class: 'ft-label td-air' }, 'surface = due now');
    const scales = [[6, '6 h'], [24, '1 day'], [48, '2 days'], [72, '3 days+']].map(([r, l]) => ({ r, el: h('span', { class: 'ft-label td-scale' }, l) }));
    const list = h('ol', { class: 'sr-only', 'aria-label': 'Tasks by urgency' });
    const when = h('b'), rel = h('span', { class: 'ft-mono ft-muted' });
    const fill = h('div', { class: 'td-fill' }), thumb = h('div', { class: 'td-thumb' });
    const track = h('div', { class: 'td-track', 'data-hit': '' }, fill, thumb);
    stage.append(css, tank, h('div', { class: 'td-time' }, h('div', { class: 'td-time-top' }, when, rel), track), list);
    const cv = FT.canvas(tank);
    tank.append(air, ...scales.map(s => s.el));

    let now = 0, W = 300, H = 380, held = null, visible = true;
    const SURF = 50, GUT = 58;
    let syncTrack = null;
    // a push wears off linearly: by the deadline (or over its own length, if already overdue) it's gone
    const left = t => {
      if (!t.push) return t.due - now;
      const span = Math.max(1, t.due - t.pushedAt, Math.abs(t.push));
      return (t.due - now) + t.push * FT.clamp(1 - (now - t.pushedAt) / span, 0, 1);
    };
    const depthOf = r => SURF + 26 + Math.pow(FT.clamp(r / 72, 0, 1), 0.75) * (H - SURF - 26 - 48);
    const rOfDepth = y => 72 * Math.pow(FT.clamp((y - SURF - 26) / (H - SURF - 26 - 48), 0, 1), 1 / 0.75);
    const dueText = r => r <= 0 ? (r > -0.5 ? 'due now' : `${Math.round(-r)} h late`) : r < 1 ? `in ${Math.round(r * 60)} min` : r < 36 ? `in ${Math.round(r)} h` : `in ${Math.round(r / 24)} days`;
    const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    const clock = hrs => { const t = NOW0 + hrs; return `${DAYS[Math.floor(t / 24)]} ${String(Math.floor(t % 24)).padStart(2, '0')}:00`; };

    TASKS.forEach(t => {
      t.el = h('button', { class: 'td-pill', type: 'button', 'data-hit': '' }, h('b', null, t.title), h('span'));
      tank.append(t.el);
      let y0 = 0, cy = 0; // the pill moves with the finger: measure in screen space
      FT.drag(t.el, {
        start(s, e) { held = t; y0 = t.y.x; cy = e.clientY; t.el.classList.add('held'); },
        move(s, e) {
          const y = FT.clamp(y0 + e.clientY - cy, SURF - 12, H - 44);
          t.y.set(y); place(t);
          t.el.lastChild.textContent = y < SURF + 26 ? 'raise to now' : `resurface ${dueText(rOfDepth(y))}`;
        },
        end(s) {
          held = null; t.el.classList.remove('held');
          if (!s.moved) { layout(); return; }
          const want = rOfDepth(t.y.x), real = t.due - now;
          t.push = want - real; t.pushedAt = now;
          if (Math.abs(t.push) < 0.5) t.push = 0;
          FT.haptic(t.push > 0 ? 'medium' : 'light');
          FT.intent(t.push > 0 ? `pushed “${t.title}” under by ${Math.round(t.push)} h; it fades as the deadline nears` : t.push < 0 ? `raised “${t.title}” by ${Math.round(-t.push)} h` : `“${t.title}” back to its natural depth`);
          FT.announce(`${t.title}: ${t.push > 0 ? 'pushed under, ' : ''}${dueText(real)}.`);
          layout();
        },
      }, { axis: 'y', slop: 4 });
      t.el.addEventListener('keydown', e => {
        if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
        e.preventDefault();
        const cur = left(t), real = t.due - now;
        const want = Math.max(0, cur + (e.key === 'ArrowDown' ? 6 : -6));
        t.push = want - real; t.pushedAt = now;
        FT.haptic('select'); layout();
        FT.announce(`${t.title}: due ${dueText(real)}, ${e.key === 'ArrowDown' ? 'pushed under' : 'raised'}, sits as if ${dueText(want)}.`);
      });
    });

    const place = t => {
      const pw = (W - GUT - 8 * 2 - 8) / 2;
      const x = GUT + t.col * (pw + 8);
      const r = left(t);
      const bob = r <= 0 && t !== held && !FT.reduced() ? Math.sin(performance.now() / 520 + t.col * 2 + t.due) * 3 : 0;
      t.el.style.width = pw + 'px';
      t.el.style.transform = `translate(${x}px,${(t.y.x + bob).toFixed(1)}px) rotate(${(bob * 0.4).toFixed(2)}deg)`;
    };
    let order = '';
    const layout = () => {
      W = tank.clientWidth; H = tank.clientHeight;
      for (const col of [0, 1]) {
        const ts = TASKS.filter(t => t.col === col && t !== held).map(t => ({ t, y: left(t) <= 0 ? SURF - 18 : depthOf(left(t)) - 20 }));
        ts.sort((a, b) => a.y - b.y);
        for (let i = 1; i < ts.length; i++) if (ts[i].y < ts[i - 1].y + 54) ts[i].y = ts[i - 1].y + 54;
        const over = ts.length ? ts[ts.length - 1].y - (H - 46) : 0;
        if (over > 0) for (let i = ts.length - 1; i >= 0; i--) { const lim = (H - 46) - (ts.length - 1 - i) * 54; if (ts[i].y > lim) ts[i].y = Math.max(lim, SURF - 18); }
        ts.forEach(({ t, y }) => { t.y.to(y); });
      }
      TASKS.forEach(t => {
        const r = left(t), real = t.due - now;
        t.el.classList.toggle('due', r <= 0); t.el.classList.toggle('soon', r > 0 && r < 6);
        t.el.classList.toggle('pushed', t.push > 0.5 && r - real > 0.5);
        if (t !== held) t.el.lastChild.textContent = dueText(real);
        t.el.setAttribute('aria-label', `${t.title}, due ${dueText(real)}${t.push > 0.5 && r - real > 0.5 ? `, pushed under, sits as if ${dueText(r)}` : ''}. Arrow down to push later, arrow up to raise.`);
      });
      scales.forEach(s => { s.el.style.top = depthOf(s.r) + 'px'; });
      const sorted = [...TASKS].sort((a, b) => left(a) - left(b));
      const o = sorted.map(t => t.title).join('|');
      if (o !== order) { order = o; list.replaceChildren(...sorted.map(t => h('li', null, `${t.title}: ${dueText(t.due - now)}`))); }
      when.textContent = clock(now);
      rel.textContent = now === 0 ? 'now' : `now + ${now < 24 ? now + ' h' : (now / 24).toFixed(1).replace('.0', '') + ' days'}`;
      const k = now / 72;
      fill.style.width = k * 100 + '%'; thumb.style.left = k * 100 + '%';
      if (syncTrack) syncTrack();
      loop.wake();
    };
    const drawWater = tms => {
      const { ctx, w, h: Hh } = cv;
      cv.clear();
      const acc = FT.col('--accent');
      const ph = FT.reduced() ? 0 : tms / 900;
      const wave = x => SURF + Math.sin(x / 38 + ph) * 2.2 + Math.sin(x / 17 - ph * 1.3) * 1.1;
      const g = ctx.createLinearGradient(0, SURF, 0, Hh);
      g.addColorStop(0, FT.alpha(acc, 0.07)); g.addColorStop(1, FT.alpha(acc, 0.26));
      ctx.beginPath(); ctx.moveTo(0, Hh); for (let x = 0; x <= w; x += 4) ctx.lineTo(x, wave(x)); ctx.lineTo(w, Hh); ctx.closePath();
      ctx.fillStyle = g; ctx.fill();
      ctx.beginPath(); for (let x = 0; x <= w; x += 4) x ? ctx.lineTo(x, wave(x)) : ctx.moveTo(x, wave(x));
      ctx.strokeStyle = FT.alpha(acc, 0.65); ctx.lineWidth = 1.6; ctx.stroke();
      ctx.setLineDash([2, 5]); ctx.strokeStyle = FT.alpha(acc, 0.22); ctx.lineWidth = 1;
      for (const s of scales) { const y = Math.round(depthOf(s.r)) + 0.5; ctx.beginPath(); ctx.moveTo(4, y); ctx.lineTo(w - 4, y); ctx.stroke(); }
      ctx.setLineDash([]);
    };
    const loop = FT.loop((dt, tms) => {
      let moving = false;
      for (const t of TASKS) { if (t !== held) moving = !t.y.step(dt) | moving; place(t); }
      drawWater(tms);
      return moving || (visible && !FT.reduced());
    });
    FT.visible(stage, v => { visible = v; if (v) loop.wake(); });
    const setNow = (v, how) => {
      v = FT.clamp(Math.round(v), 0, 72);
      if (v === now) return;
      const before = TASKS.filter(t => left(t) <= 0).length;
      now = v; layout();
      const after = TASKS.filter(t => left(t) <= 0).length;
      FT.haptic(after > before ? 'medium' : 'select');
      FT.intent(`${how}: ${clock(now)}, ${after} task${after === 1 ? '' : 's'} at the surface`);
      return after;
    };
    FT.drag(track, {
      start(s) { setNow(s.x / track.clientWidth * 72, 'time'); },
      move(s) { setNow(s.x / track.clientWidth * 72, 'time'); },
    }, { axis: 'x', slop: 0 });
    syncTrack = FT.slider(track, { label: 'Time', min: 0, max: 72, step: 1, big: 6, get: () => now, set: v => { const a = setNow(v, 'keys'); FT.announce(`${clock(now)}. ${a ?? TASKS.filter(t => left(t) <= 0).length} due.`); }, text: v => clock(v) });
    new ResizeObserver(() => { layout(); TASKS.forEach(t => t.y.set(t.y.t)); }).observe(tank);
    layout();
    TASKS.forEach(t => t.y.set(t.y.t));
    return {
      reset() { now = 0; TASKS.forEach(t => { t.push = 0; t.pushedAt = 0; }); layout(); syncTrack(); },
    };
  },
});
