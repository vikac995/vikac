/* I.2 Toggle with a tail — drag past Off and the track stretches into durations. */
FT.exhibit({
  id: 'tail-toggle', room: 1, num: 2, kind: 'toggle', replaces: 'the snooze menu',
  title: 'A toggle with a tail',
  hint: 'Tap to switch · drag the knob left, past Off',
  height: 360,
  body: `<p>Tap it and it is an ordinary switch. Keep dragging the knob past Off and the track stretches out behind it like a tail, with stops for 30 minutes, an hour, until 08:00 and until tomorrow. Let go on a stop and notifications are off for that long. A thin ring on the knob empties as the time runs out.</p><p>While you hover a stop, the label already says when they come back. You read the outcome before you let go.</p>`,
  why: `"Off" is rarely forever. People switch things off for a meeting or a night and then forget to switch them back. Putting time on the same axis as on and off makes "for how long?" one more step of the gesture you were already making.`,
  flutter: `
class TailToggle extends StatefulWidget {
  const TailToggle({super.key, required this.onChanged});
  final void Function(bool on, Duration? offFor) onChanged;
  @override State<TailToggle> createState() => _TailToggleState();
}

class _TailToggleState extends State<TailToggle> with SingleTickerProviderStateMixin {
  static const stops = [Duration(minutes: 30), Duration(hours: 1), null /* 08:00 */, Duration(days: 1)];
  late final AnimationController knob = AnimationController.unbounded(vsync: this);
  int? hovered;

  void _drag(DragUpdateDetails d) {
    knob.value = (knob.value + d.delta.dx).clamp(-tailExtent, onX);
    final i = _stopNear(knob.value);                       // within 16 dp of a stop
    if (i != hovered) { hovered = i; if (i != null) HapticFeedback.selectionClick(); }
    setState(() {});
  }

  void _release(DragEndDetails _) {
    final target = hovered != null || knob.value < onX / 2 ? offX : onX;
    knob.animateWith(SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 600, damping: 44), knob.value, target, 0));
    widget.onChanged(target == onX, hovered == null ? null : _durationFor(hovered!));
  }

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: isOn, label: 'Notifications', value: statusText,
    customSemanticsActions: { for (final s in stopLabels) CustomSemanticsAction(label: 'Off $s'): () => _setStop(s) },
    child: GestureDetector(onTap: _toggle, onHorizontalDragUpdate: _drag, onHorizontalDragEnd: _release,
      child: CustomPaint(painter: TailPainter(knob: knob, hovered: hovered), size: const Size.fromHeight(80))),
  );
}`,
  a11y: `The control is a <b>switch</b>. <b>Space</b> or <b>Enter</b> flips it. While it is off, <b>←</b> walks out along the tail (30 min, 1 h, until 08:00, until tomorrow) and <b>→</b> walks back. The status line ("Off, back on at 14:30") is linked to the switch, so screen readers read it with the state.`,
  mount(stage) {
    const { h } = FT;
    stage.classList.add('tl');
    stage.append(h('style', null, `
      .tl-head{position:absolute;left:22px;right:22px;top:22px}
      .tl-title{font-weight:600;font-size:16px}
      .tl-status{font-size:13px;color:var(--muted);margin-top:2px;min-height:20px}
      .tl-status b{color:var(--ink);font-weight:600}
      .tl-row{position:absolute;left:0;right:0;top:112px;height:80px}
      .tl-track{position:absolute;top:30px;height:38px;border-radius:19px;background:var(--line-2);transition:background .25s}
      .tl.on .tl-track{background:var(--accent)}
      .tl.timed .tl-track,.tl.tailing .tl-track{background:var(--amber)}
      .tl-hit{position:absolute;top:22px;height:54px;cursor:grab;border-radius:27px}
      .tl-hit:active{cursor:grabbing}
      .tl-thumb{position:absolute;top:34px;width:30px;height:30px;border-radius:50%;background:var(--surface-2);box-shadow:0 1px 3px rgba(0,0,0,.25),0 0 0 .5px rgba(0,0,0,.06);pointer-events:none}
      .tl-thumb svg{position:absolute;inset:0}
      .tl-stop{position:absolute;top:45px;width:8px;height:8px;margin-left:-4px;border-radius:50%;background:color-mix(in srgb,var(--surface-2) 70%,transparent);pointer-events:none}
      .tl-lab{position:absolute;top:0;transform:translateX(-50%);font-family:var(--f-mono);font-size:10.5px;white-space:nowrap;color:var(--muted);pointer-events:none;padding:3px 7px;border-radius:999px;transition:background .15s,color .15s}
      .tl-lab.sel{background:var(--amber);color:var(--bg)}
      .tl-onoff{position:absolute;top:84px;font-family:var(--f-mono);font-size:10.5px;color:var(--faint);text-transform:uppercase;letter-spacing:.08em}
      .tl-feed{position:absolute;left:22px;right:22px;bottom:18px;display:grid;gap:6px}
      .tl-n{display:grid;grid-template-columns:auto 1fr auto;gap:10px;align-items:center;padding:8px 12px;font-size:12.5px;transition:opacity .3s,filter .3s}
      .tl-n i{width:22px;height:22px;border-radius:7px;display:grid;place-items:center;font-style:normal;font-size:11px;font-weight:700;color:var(--bg)}
      .tl-n span{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
      .tl-n small{font-family:var(--f-mono);color:var(--faint);font-size:10.5px}
      .tl:not(.on) .tl-n{opacity:.38;filter:saturate(.2)}
      .tl-held{position:absolute;left:50%;bottom:66px;box-shadow:var(--shadow);transform:translateX(-50%);font-family:var(--f-mono);font-size:11px;padding:4px 10px;border-radius:999px;background:var(--surface-2);border:1px solid var(--line-2);white-space:nowrap;opacity:0;transition:opacity .25s;z-index:1}
      .tl:not(.on) .tl-held{opacity:1}
    `));
    const status = h('div', { class: 'tl-status', id: 'tl-status' });
    stage.append(h('div', { class: 'tl-head' }, h('div', { class: 'tl-title' }, 'Notifications'), status));
    const row = h('div', { class: 'tl-row' });
    const track = h('div', { class: 'tl-track' });
    const thumb = h('div', { class: 'tl-thumb' });
    thumb.innerHTML = `<svg viewBox="0 0 30 30" aria-hidden="true"><circle cx="15" cy="15" r="8" fill="none" stroke-width="3" stroke-linecap="round" transform="rotate(-90 15 15)" style="stroke:var(--amber)" stroke-dasharray="0 60"/></svg>`;
    const arc = thumb.querySelector('circle');
    const hit = h('div', { class: 'tl-hit', role: 'switch', tabindex: '0', 'aria-label': 'Notifications', 'aria-describedby': 'tl-status', 'data-hit': '' });
    const STOPS = ['30 min', '1 h', 'until 08:00', 'until tomorrow'];
    const stopEls = STOPS.map(() => h('div', { class: 'tl-stop' }));
    const SHORT = ['30 min', '1 h', 'until 8:00', 'tomorrow'];
    const labEls = SHORT.map(s => h('div', { class: 'tl-lab' }, s));
    const offLab = h('div', { class: 'tl-onoff' }, 'off'), onLab = h('div', { class: 'tl-onoff' }, 'on');
    row.append(track, ...stopEls, ...labEls, offLab, onLab, thumb, hit);
    stage.append(row);
    const feed = h('div', { class: 'tl-feed' },
      ...[['M', 'var(--accent)', 'Mira: running ten minutes late', 'now'], ['31', 'var(--amber)', 'Calendar: dentist at 16:00', '2 m'], ['€', 'var(--ok)', 'Card payment €12.40 at Pekara', '5 m']]
        .map(([ic, col, txt, t]) => h('div', { class: 'tl-n ft-card' }, h('i', { style: { background: col } }, ic), h('span', null, txt), h('small', null, t))));
    const held = h('div', { class: 'tl-held' });
    stage.append(feed, held);

    // geometry (row coordinates)
    const TW = 70, PAD = 4, TD = 30;
    let G = {};
    const layout = () => {
      const W = stage.clientWidth;
      const x0 = W - 26 - TW;
      const offX = x0 + PAD, onX = x0 + TW - PAD - TD;
      const space = Math.min(60, (offX - 14 - 50) / 3);
      const stopX = STOPS.map((_, i) => offX - (50 + i * space));
      G = { W, x0, offX, onX, stopX };
      hit.style.left = (x0 - 8) + 'px'; hit.style.width = (TW + 16) + 'px';
      offLab.style.left = (x0 + 2) + 'px'; onLab.style.left = (x0 + TW - 18) + 'px';
      stopX.forEach((x, i) => { stopEls[i].style.left = (x + TD / 2) + 'px'; labEls[i].style.left = (x + TD / 2) + 'px'; labEls[i].style.top = (i % 2 ? -24 : 2) + 'px'; });
      paintGeom();
    };

    let on = true, timed = null; // timed = { i, from, until }
    let x = 0, dragging = false, hover = -1, startX = 0;
    const sp = FT.spring(0, FT.SPRING.snappy);
    const pad2 = n => String(n).padStart(2, '0');
    const hhmm = d => `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
    const untilFor = (i, now = new Date()) => {
      const d = new Date(now);
      if (i === 0) d.setMinutes(d.getMinutes() + 30);
      else if (i === 1) d.setHours(d.getHours() + 1);
      else if (i === 2) { d.setHours(8, 0, 0, 0); if (d <= now) d.setDate(d.getDate() + 1); }
      else d.setDate(d.getDate() + 1);
      return d;
    };
    const whenText = d => {
      const now = new Date();
      const tomorrow = d.getDate() !== now.getDate();
      return `${tomorrow ? 'tomorrow at ' : 'at '}${hhmm(d)}`;
    };
    const text = () => {
      if (dragging && hover >= 0) return `Release: <b>back on ${whenText(untilFor(hover))}</b>`;
      if (dragging && x < G.offX - 12) return `Keep going to pick how long`;
      if (on) return `On · messages, calls and reminders arrive`;
      if (timed) return `Off · <b>back on ${whenText(timed.until)}</b>`;
      return `Off · nothing arrives until you switch it back on`;
    };
    const paintGeom = () => {
      const tx = dragging ? x : sp.x;
      const left = Math.min(G.x0, tx - PAD);
      track.style.left = left + 'px'; track.style.width = (G.x0 + TW - left) + 'px';
      thumb.style.left = tx + 'px';
      const ext = FT.clamp((G.offX - tx - 8) / 34, 0, 1);
      stage.classList.toggle('tailing', dragging && tx < G.offX - 12);
      stopEls.forEach((el, i) => { el.style.opacity = tx < G.stopX[i] + 20 ? 1 : 0; });
      labEls.forEach((el, i) => { el.style.opacity = String(ext * (tx < G.stopX[i] + 46 ? 1 : 0.35)); el.classList.toggle('sel', dragging && hover === i); });
    };
    const paint = () => {
      stage.classList.toggle('on', on);
      stage.classList.toggle('timed', !on && !!timed);
      hit.setAttribute('aria-checked', String(on));
      status.innerHTML = text();
      held.textContent = timed ? `3 held · arriving ${whenText(timed.until)}` : '3 held · until you switch back on';
      paintArc();
      paintGeom();
    };
    const paintArc = () => {
      const C = 2 * Math.PI * 8;
      if (!timed || on) { arc.style.opacity = 0; return; }
      arc.style.opacity = 1;
      const f = FT.clamp((timed.until - Date.now()) / (timed.until - timed.from), 0, 1);
      arc.setAttribute('stroke-dasharray', `${(C * f).toFixed(2)} ${C}`);
      if (f <= 0) { on = true; timed = null; settle(); }
    };
    const loop = FT.loop(dt => { const done = sp.step(dt); paintGeom(); return !done; });
    const settle = () => { sp.to(on ? G.onX : G.offX); loop.wake(); paint(); };
    const setOn = (v, why) => {
      on = v; timed = null; settle();
      FT.haptic(v ? 'light' : 'select');
      FT.intent(why || (v ? 'switched on' : 'switched off'));
      FT.announce(v ? 'Notifications on' : 'Notifications off');
    };
    const setTimed = i => {
      on = false; timed = { i, from: Date.now(), until: untilFor(i).getTime() };
      timed.until = new Date(timed.until);
      settle(); FT.haptic('medium');
      FT.intent(`timed off: ${STOPS[i]}`);
      FT.announce(`Notifications off, back on ${whenText(timed.until)}`);
    };
    setInterval(() => { if (timed && !on) { paintArc(); status.innerHTML = text(); } }, 1000);

    FT.drag(hit, {
      start() { startX = sp.x; x = sp.x; hover = -1; },
      move(s) {
        if (!s.moved) return;
        if (!dragging) { dragging = true; sp.set(x); }
        const minX = G.stopX[3] - 14;
        let nx = startX + s.dx;
        if (nx < minX) nx = minX - (minX - nx) * 0.25;  // soft wall at the end of the tail
        x = FT.clamp(nx, minX - 24, G.onX + 6);
        let hv = -1;
        if (x < G.stopX[0] + 20) {                           // in the tail: the nearest stop is always the answer
          let best = 1e9;
          G.stopX.forEach((sx, i) => { const d = Math.abs(x - sx); if (d < best) { best = d; hv = i; } });
        }
        if (hv >= 0) x = FT.lerp(x, G.stopX[hv], 0.6);     // magnetic stop
        if (hv !== hover) { hover = hv; if (hv >= 0) { FT.haptic('select'); FT.intent(`over stop: off ${STOPS[hv]}`); } }
        status.innerHTML = text(); paintGeom();
      },
      end(s) {
        if (!dragging) return;
        dragging = false; sp.set(x);
        if (s.cancelled) { settle(); return; }
        if (hover >= 0) setTimed(hover);
        else if (x < (G.offX + G.onX) / 2) setOn(false, 'dragged to off');
        else setOn(true, 'dragged to on');
        hover = -1; paint();
      },
      tap() { if (on) setOn(false); else setOn(true); },
    }, { axis: 'x', slop: 4 });

    hit.addEventListener('keydown', e => {
      if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); setOn(!on); }
      else if (e.key === 'ArrowLeft' && !on) { e.preventDefault(); const i = timed ? Math.min(3, timed.i + 1) : 0; setTimed(i); }
      else if (e.key === 'ArrowRight' && !on) {
        e.preventDefault();
        if (timed && timed.i > 0) setTimed(timed.i - 1);
        else if (timed) { timed = null; paint(); FT.announce('Notifications off until you switch them back on'); }
      }
    });
    new ResizeObserver(() => { layout(); sp.set(on ? G.onX : G.offX); paintGeom(); }).observe(stage);
    layout(); sp.set(G.onX); paint();
    return { reset() { on = true; timed = null; dragging = false; sp.set(G.onX); paint(); } };
  },
});
