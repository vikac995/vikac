/* II.1 A form that reads like a sentence — tokens you tap for choices or drag to scrub, reflowing with FLIP. */
FT.exhibit({
  id: 'sentence-form', room: 2, num: 1, kind: 'form', replaces: 'a stack of labelled fields',
  title: 'A form that reads like a sentence',
  hint: 'Tap a blue word for choices · drag a solid one sideways',
  height: 420,
  body: `<p>The booking form is one sentence. Each blue word is a field. Tap it and its choices open right underneath. Drag a number or a time sideways and it counts like a dial. As words change length, the rest of the sentence slides into place instead of jumping.</p><p>You read the whole request before you send it, in the same words you'd say to a waiter.</p>`,
  why: `Labels and fields are two things to read for every one answer. A sentence makes the label and the value one thing, and the finished form doubles as its own confirmation.`,
  source: `the Vast.com A/B test, where a fill-in-the-blank contact form converted 25–40% better than the field stack, <a href="https://konigi.com/blog/mad-libs-style-form-increases-conversion-25-40" target="_blank" rel="noopener">reported by Luke Wroblewski (2010)</a>.`,
  flutter: `
// One sentence, built from TextSpans and WidgetSpans so it wraps like prose.
Text.rich(TextSpan(style: theme.textTheme.headlineSmall, children: [
  const TextSpan(text: "I'd like a table for "),
  WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic,
    child: ScrubToken<int>(
      value: party, step: 1, min: 1, max: 12, pixelsPerStep: 16,
      label: (n) => numberWords[n], semanticsLabel: 'Party size',
      onChanged: (n) { HapticFeedback.selectionClick(); setState(() => party = n); },
    )),
  const TextSpan(text: ' at '),
  WidgetSpan(child: ChoiceToken(value: place, options: places, onChanged: (p) => setState(() => place = p))),
  // ...
]));

class ScrubToken<T extends num> extends StatelessWidget {
  // Horizontal-only recognizer: vertical drags still scroll the page.
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel, value: label(value),
    onIncrease: () => onChanged(math.min(max, value + step) as T),
    onDecrease: () => onChanged(math.max(min, value - step) as T),
    child: GestureDetector(
      onHorizontalDragStart: (_) => _base = value,
      onHorizontalDragUpdate: (d) => _accumulate(d.primaryDelta!),
      onTap: () => _openChoices(context),        // MenuAnchor anchored under the word
      child: AnimatedSize(                     // neighbours reflow on a spring, never jump
        duration: Motion.springDuration, curve: Motion.spatial,
        child: Text(label(value), style: TextStyle(color: scheme.primary)),
      ),
    ),
  );
}`,
  a11y: `Every blue word is a button in reading order. <b>Left/Right</b> or <b>Up/Down</b> step a number, time or choice; <b>Enter</b> opens the choices; <b>Esc</b> closes them and returns focus. The screen reader hears the field name and value, then the full sentence after each change.`,
  mount(stage) {
    const { h } = FT;
    stage.append(h('style', { text: `
      .sf-root{position:absolute;inset:0;padding:24px 22px 18px;display:flex;flex-direction:column;gap:14px}
      .sf-sent{font-family:var(--f-display);font-size:29px;line-height:1.42;color:var(--ink);letter-spacing:-.005em;margin:0;text-wrap:pretty}
      .sf-w{display:inline-block;will-change:transform}
      .sf-tok{display:inline-block;font:inherit;line-height:1.1;color:var(--accent);background:transparent;border:0;padding:0 3px;margin:0 -3px;border-radius:6px;cursor:pointer;
        border-bottom:2px dashed color-mix(in srgb,var(--accent) 50%,transparent);transition:background .18s,color .18s}
      .sf-tok.num{border-bottom-style:solid;cursor:ew-resize}
      .sf-tok:hover{background:var(--accent-wash)}
      .sf-tok.on{background:var(--accent-soft)}
      .sf-done .sf-tok{color:var(--ok);border-bottom-color:transparent;pointer-events:none}
      .sf-key{display:flex;gap:16px;flex-wrap:wrap;font-family:var(--f-mono);font-size:11px;color:var(--muted)}
      .sf-key span{display:inline-flex;align-items:center;gap:6px}
      .sf-key i{display:inline-block;width:18px;border-bottom:2px solid var(--accent)}
      .sf-key i.d{border-bottom-style:dashed}
      .sf-foot{margin-top:auto;display:flex;flex-direction:column;gap:8px}
      .sf-msg{font-size:13.5px;color:var(--ok);min-height:20px;margin:0}
      .sf-book{width:100%;height:50px;font-size:15px}
      .sf-pick{position:absolute;z-index:4;display:flex;flex-wrap:wrap;gap:6px;padding:10px;width:max-content;max-width:calc(100% - 24px);
        background:var(--surface-2);border:1px solid var(--line);border-radius:14px;box-shadow:var(--shadow);transform-origin:20px 0}
      .sf-pick .ft-chip{height:34px;font-size:13.5px}
      .sf-pick::before{content:"";position:absolute;left:var(--nx,24px);top:-7px;width:12px;height:12px;margin-left:-6px;background:inherit;border-left:1px solid var(--line);border-top:1px solid var(--line);transform:rotate(45deg)}
    ` }));
    const WORDS = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve'];
    const hhmm = q => `${String(Math.floor(q / 4)).padStart(2, '0')}:${String((q % 4) * 15).padStart(2, '0')}`;
    const F = {
      party: { num: true, min: 1, max: 12, v: 2, px: 16, fmt: n => WORDS[n], label: 'Party size', chips: [1, 2, 3, 4, 5, 6, 8, 10] },
      place: { opts: ['Bistro Lav', 'Noa', 'Pod Gričem', 'Mali Bar'], v: 0, px: 34, label: 'Restaurant' },
      day: { opts: ['Thursday', 'Friday', 'Saturday', 'Sunday'], v: 1, px: 34, label: 'Day' },
      time: { num: true, min: 17 * 4, max: 23 * 4, v: 80, px: 14, fmt: hhmm, label: 'Time', chips: [72, 74, 76, 78, 80, 82, 84, 86] },
      seat: { opts: ['inside', 'on the terrace', 'by the window', 'at the bar'], v: 0, px: 34, label: 'Seating' },
    };
    const DEF = Object.fromEntries(Object.entries(F).map(([k, f]) => [k, f.v]));
    for (const f of Object.values(F)) {
      if (f.opts) { f.min = 0; f.max = f.opts.length - 1; f.fmt = i => f.opts[i]; f.chips = f.opts.map((_, i) => i); }
    }
    const root = h('div', { class: 'sf-root' });
    const sent = h('p', { class: 'sf-sent', 'aria-live': 'off' });
    const parts = ["I'd", 'like', 'a', 'table', 'for', '@party', 'at', '@place', 'on', '@day', 'around', '@time', ',', '@seat', '.'];
    const toks = {};
    const words = [];
    parts.forEach((p, i) => {
      let el;
      if (p[0] === '@') {
        const key = p.slice(1), f = F[key];
        el = h('button', { type: 'button', class: 'sf-tok sf-w' + (f.num ? ' num' : ''), 'data-hit': '', 'aria-haspopup': 'true' });
        toks[key] = el; el.dataset.key = key;
      } else el = h('span', { class: 'sf-w' }, p);
      words.push(el);
      const nextIsPunct = parts[i + 1] === ',' || parts[i + 1] === '.';
      sent.append(el);
      if (i < parts.length - 1 && !nextIsPunct) sent.append(' ');
    });
    const key = h('div', { class: 'sf-key' }, h('span', null, h('i'), 'drag sideways'), h('span', null, h('i', { class: 'd' }), 'tap for choices'));
    const msg = h('p', { class: 'sf-msg', role: 'status' });
    const book = h('button', { class: 'ft-btn accent sf-book', type: 'button', 'data-hit': '' });
    root.append(h('span', { class: 'ft-label' }, 'New reservation'), sent, key, h('div', { class: 'sf-foot' }, msg, book));
    stage.append(root);

    /* FLIP: words keep their screen position on change, then spring home */
    const springs = new Map(words.map(w => [w, { x: FT.spring(0, FT.SPRING.smooth), y: FT.spring(0, FT.SPRING.smooth) }]));
    const loop = FT.loop(dt => {
      let moving = false;
      for (const [w, s] of springs) {
        const a = s.x.step(dt), b = s.y.step(dt);
        if (!a || !b) moving = true;
        w.style.transform = (s.x.x || s.y.x) ? `translate(${s.x.x.toFixed(2)}px,${s.y.x.toFixed(2)}px)` : '';
      }
      return moving;
    });
    const flip = change => {
      const before = words.map(w => w.getBoundingClientRect());
      change();
      words.forEach((w, i) => {
        const a = before[i], b = w.getBoundingClientRect(), s = springs.get(w);
        const dx = a.left - b.left, dy = a.top - b.top;
        if (Math.abs(dx) > .5 || Math.abs(dy) > .5) { s.x.x += dx; s.y.x += dy; s.x.to(0); s.y.to(0); }
      });
      loop.wake();
    };
    const sentenceText = () => `I'd like a table for ${F.party.fmt(F.party.v)} at ${F.place.fmt(F.place.v)} on ${F.day.fmt(F.day.v)} around ${F.time.fmt(F.time.v)}, ${F.seat.fmt(F.seat.v)}.`;
    let booked = false;
    const paint = () => {
      for (const k in toks) {
        const f = F[k];
        toks[k].textContent = f.fmt(f.v);
        toks[k].setAttribute('aria-label', `${f.label}: ${f.fmt(f.v)}. ${f.num ? 'Arrow keys change it, ' : 'Arrow keys cycle, '}Enter for choices`);
      }
      const d = F.day.fmt(F.day.v).slice(0, 3), n = F.party.v;
      book.textContent = booked ? 'Change booking' : `Book · ${d} ${F.time.fmt(F.time.v)} · ${n} ${n === 1 ? 'person' : 'people'}`;
      book.className = booked ? 'ft-btn ghost sf-book' : 'ft-btn accent sf-book';
      sent.classList.toggle('sf-done', booked);
      msg.textContent = booked ? `Booked. ${F.place.fmt(F.place.v)} holds the table until ${F.time.fmt(F.time.v + 1)}.` : '';
    };
    const setVal = (k, v, how) => {
      const f = F[k];
      v = FT.clamp(v, f.min, f.max);
      if (v === f.v) return false;
      flip(() => { f.v = v; paint(); });
      FT.haptic('select');
      FT.intent(`${f.label} → ${f.fmt(v)} (${how})`);
      return true;
    };

    /* inline choices */
    let pick = null, pickKey = null;
    const pickSpring = FT.spring(0, FT.SPRING.snappy);
    const pickLoop = FT.loop(dt => {
      const done = pickSpring.step(dt);
      if (pick) { pick.style.opacity = String(FT.clamp(pickSpring.x, 0, 1)); pick.style.transform = `scale(${0.92 + 0.08 * pickSpring.x}) translateY(${(1 - pickSpring.x) * -6}px)`; }
      return !done;
    });
    const closePick = (refocus) => {
      if (!pick) return;
      const k = pickKey; pick.remove(); pick = null; pickKey = null; key.style.visibility = '';
      toks[k].classList.remove('on'); toks[k].setAttribute('aria-expanded', 'false');
      if (refocus) toks[k].focus();
    };
    const openPick = (k, viaKey) => {
      if (pickKey === k) { closePick(viaKey); return; }
      closePick(false);
      const f = F[k], tok = toks[k];
      pickKey = k;
      pick = h('div', { class: 'sf-pick', role: 'group', 'aria-label': `${f.label} choices` });
      f.chips.forEach(c => {
        const b = h('button', { type: 'button', class: 'ft-chip', 'aria-pressed': String(c === f.v), 'data-hit': '' }, f.fmt(c));
        b.addEventListener('click', () => { setVal(k, c, 'picked'); closePick(true); FT.announce(sentenceText()); });
        pick.append(b);
      });
      pick.addEventListener('keydown', e => {
        const bs = [...pick.querySelectorAll('button')], i = bs.indexOf(document.activeElement);
        if (e.key === 'Escape') { e.preventDefault(); closePick(true); }
        else if (e.key === 'ArrowRight' || e.key === 'ArrowDown') { e.preventDefault(); bs[(i + 1) % bs.length].focus(); }
        else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') { e.preventDefault(); bs[(i - 1 + bs.length) % bs.length].focus(); }
      });
      stage.append(pick);
      // open just below the sentence so no words are covered; a notch points up at the word
      const sr = stage.getBoundingClientRect(), tr = tok.getBoundingClientRect(), pr = sent.getBoundingClientRect();
      const pw = pick.offsetWidth;
      const left = FT.clamp(tr.left - sr.left + tr.width / 2 - pw / 2, 12, sr.width - pw - 12);
      pick.style.left = left + 'px';
      pick.style.top = (pr.bottom - sr.top + 12) + 'px';
      const notchX = FT.clamp(tr.left - sr.left + tr.width / 2 - left, 16, pw - 16);
      pick.style.setProperty('--nx', notchX + 'px');
      pick.style.transformOrigin = `${notchX}px 0`;
      key.style.visibility = 'hidden';
      tok.classList.add('on'); tok.setAttribute('aria-expanded', 'true');
      pickSpring.set(0).to(1); pickLoop.wake();
      FT.haptic('light'); FT.intent(`tap: ${f.label} choices opened under the word`);
      if (viaKey) (pick.querySelector('[aria-pressed="true"]') || pick.firstChild).focus();
    };
    stage.addEventListener('pointerdown', e => { if (pick && !pick.contains(e.target) && !e.target.closest('.sf-tok')) closePick(false); }, true);

    for (const k in toks) {
      const tok = toks[k], f = F[k];
      let base = 0;
      FT.drag(tok, {
        start() { base = f.v; },
        move(s) {
          if (!s.moved) return;
          if (pick) closePick(false);
          tok.classList.add('on');
          setVal(k, base + Math.round(s.dx / f.px), 'scrubbed');
        },
        tap() { openPick(k, false); },
        end(s) { if (s.moved) { tok.classList.remove('on'); FT.announce(sentenceText()); } },
      }, { axis: 'x', slop: 5 });
      tok.addEventListener('keydown', e => {
        const d = { ArrowRight: 1, ArrowUp: 1, ArrowLeft: -1, ArrowDown: -1 }[e.key];
        if (d) {
          e.preventDefault();
          let v = f.v + d;
          if (!f.num) v = (v + f.opts.length) % f.opts.length;
          if (setVal(k, v, 'keyboard')) FT.announce(`${f.label}: ${f.fmt(F[k].v)}`);
        } else if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openPick(k, true); }
        else if (e.key === 'Escape') closePick(true);
      });
    }
    book.addEventListener('click', () => {
      closePick(false);
      booked = !booked;
      flip(paint);
      if (booked) { FT.haptic('success'); FT.intent('booked from the sentence'); FT.announce(`Booked: ${sentenceText()}`); }
      else { FT.haptic('light'); FT.announce('Editing the booking'); }
    });
    paint();
    return {
      reset() { closePick(false); booked = false; for (const k in F) F[k].v = DEF[k]; flip(paint); },
    };
  },
});
