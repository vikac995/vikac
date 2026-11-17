/* II.7 A caret that reads your speed — speed-dependent gain (letters ↔ words) plus a Shift-style callout. */
FT.exhibit({
  id: 'speed-caret', room: 2, num: 7, kind: 'text editing', replaces: 'the magnifier loupe',
  title: 'A caret that reads your speed',
  hint: 'Drag slowly or quickly on the pad · or drag on the text itself',
  height: 440,
  body: `<p>Drag on the pad under the note. Move slowly and the caret walks one letter at a time. Move quickly and it jumps whole words, which light up as it passes them. Drag up or down to change lines. Hold still for a moment before dragging to select instead.</p><p>Or drag right on the text. A callout above your finger shows the letters it is covering, with the caret inside, so your thumb never hides the spot you're aiming for. Try fixing the typo in the first line.</p>`,
  why: `A fixed ratio between finger and caret forces a choice between speed and precision. Letting speed set the ratio gives both in one gesture, the same trick that makes a laptop trackpad feel accurate.`,
  source: `Vogel &amp; Baudisch, <a href="https://www.patrickbaudisch.com/publications/2007-Vogel-CHI07-Shift.pdf" target="_blank" rel="noopener">"Shift: A Technique for Operating Pen-Based Interfaces Using Touch" (CHI 2007)</a>, and Casiez, Vogel, Balakrishnan &amp; Cockburn on speed-dependent control-display gain (2008).`,
  flutter: `
/// A trackpad strip that moves a TextEditingController's caret with speed-dependent gain.
class CaretPad extends StatefulWidget {
  const CaretPad({super.key, required this.controller});
  final TextEditingController controller;
  @override State<CaretPad> createState() => _CaretPadState();
}

class _CaretPadState extends State<CaretPad> {
  double _acc = 0;
  bool _words = false;

  void _onUpdate(DragUpdateDetails d) {
    final speed = d.primaryDelta!.abs() / (1 / 60);          // px/s, assuming 60 Hz deltas
    _words = _words ? speed > 260 : speed > 420;              // hysteresis: no flicker at the threshold
    _acc += d.delta.dx;
    final step = _words ? 26.0 : 10.0;
    while (_acc.abs() >= step) {
      final dir = _acc.sign.toInt();
      _acc -= dir * step;
      final text = widget.controller.text;
      final at = widget.controller.selection.extentOffset;
      final next = _words ? nextWordBoundary(text, at, dir) : (at + dir).clamp(0, text.length);
      widget.controller.selection = TextSelection.collapsed(offset: next);
      HapticFeedback.selectionClick();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Caret pad', hint: 'Drag slowly for letters, quickly for words',
    child: GestureDetector(onHorizontalDragUpdate: _onUpdate,
        child: CaretPadSurface(mode: _words ? 'words' : 'letters')),
  );
}

// On the text itself: a TextMagnifierConfiguration with a custom magnifierBuilder
// draws the Shift-style callout above the finger instead of the default loupe.`,
  a11y: `The note is a focusable text area. <b>Left/Right</b> move by letter, <b>Alt</b> or <b>Ctrl</b> + <b>Left/Right</b> by word, <b>Up/Down</b> by line, and <b>Shift</b> extends the selection. The word at the caret is announced as you move.`,
  mount(stage) {
    const { h } = FT;
    stage.append(h('style', { text: `
      .cr-root{position:absolute;inset:0;padding:14px 16px 12px;display:flex;flex-direction:column;gap:9px}
      .cr-head{display:flex;justify-content:space-between;align-items:center;gap:8px;padding:0 2px}
      .cr-head b{font-size:14.5px}
      .cr-mode{display:inline-flex;align-items:center;gap:8px;font-family:var(--f-mono);font-size:11px;color:var(--muted)}
      .cr-mode .pill{padding:3px 9px;border-radius:999px;border:1px solid var(--line-2);transition:background .15s,color .15s}
      .cr-mode .pill.w{background:var(--accent);color:var(--accent-ink);border-color:var(--accent)}
      .cr-mode .pill.s{background:var(--amber-soft);color:var(--ink);border-color:var(--amber)}
      .cr-text{position:relative;padding:12px 14px;border-radius:14px;background:var(--surface-2);border:1px solid var(--line);box-shadow:var(--shadow);font-size:15px;line-height:1.62;white-space:pre-wrap;word-break:normal;cursor:text;color:var(--ink-2)}
      .cr-text span{border-radius:3px;transition:background .35s,box-shadow .35s}
      .cr-text span.wp{background:var(--accent-soft);transition:none}
      .cr-text span.cp{box-shadow:inset 0 -2px 0 var(--accent);transition:none}
      .cr-text span.sel{background:color-mix(in srgb,var(--accent) 28%,transparent)}
      .cr-text span.typo{text-decoration:underline wavy var(--hot);text-underline-offset:3px}
      .cr-caret{position:absolute;left:0;top:0;width:2px;border-radius:1px;background:var(--accent);pointer-events:none}
      .cr-caret.blink{animation:crb 1.05s steps(1) infinite}
      @keyframes crb{50%{opacity:0}}
      .cr-task{display:flex;align-items:center;justify-content:space-between;gap:8px;min-height:32px;font-size:12.5px;color:var(--muted);padding:0 2px}
      .cr-task button{height:30px;padding:0 12px;font-size:12.5px}
      .cr-task .ok{color:var(--ok);font-weight:600}
      .cr-pad{position:relative;flex:1;min-height:70px;border-radius:16px;border:1.5px dashed var(--line-2);background:var(--stage);display:grid;place-items:center;cursor:ew-resize;overflow:hidden}
      .cr-pad.on{border-style:solid;border-color:var(--accent);background:var(--accent-wash)}
      .cr-pad p{margin:0;font-family:var(--f-mono);font-size:11px;color:var(--muted);text-align:center;line-height:1.5;pointer-events:none}
      .cr-meter{position:absolute;left:14px;right:14px;bottom:10px;height:4px;border-radius:2px;background:var(--line)}
      .cr-meter i{position:absolute;left:0;top:0;bottom:0;border-radius:2px;background:var(--accent);width:0}
      .cr-meter b{position:absolute;top:-4px;width:2px;height:12px;background:var(--ink);opacity:.5}
      .cr-call{position:absolute;z-index:5;pointer-events:none;padding:6px 12px;border-radius:12px;background:var(--ink);color:var(--bg);font-family:var(--f-mono);font-size:17px;white-space:pre;box-shadow:0 10px 30px -8px rgba(0,0,0,.45);transform:translate(-50%,-100%)}
      .cr-call::after{content:"";position:absolute;left:50%;bottom:-6px;margin-left:-6px;border:6px solid transparent;border-bottom:0;border-top-color:var(--ink)}
      .cr-call i{display:inline-block;width:2px;height:20px;margin:0 1px;vertical-align:-4px;background:var(--accent-2)}
    ` }));
    const TEXT0 = 'Thanks for the lake photos! We will recieve the prints on Friday and frame the best one for the hallway. A typo like that usually takes three tries to fix on a phone. Here a slow drag walks letter by letter, and a quick one jumps whole words.';
    const root = h('div', { class: 'cr-root' });
    const pill = h('span', { class: 'pill' }, 'letters');
    const box = h('div', { class: 'cr-text', tabindex: '0', role: 'textbox', 'aria-multiline': 'true', 'aria-readonly': 'true', 'aria-label': 'Note. Arrow keys move the caret.', 'data-hit': '' });
    const caret = h('div', { class: 'cr-caret blink' });
    const task = h('div', { class: 'cr-task', role: 'status' });
    const meterFill = h('i'), meter = h('div', { class: 'cr-meter' }, meterFill, h('b'));
    const pad = h('div', { class: 'cr-pad', 'data-hit': '', 'aria-hidden': 'true' }, h('p', { html: 'drag here<br>slow = letters · fast = words · hold first to select' }), meter);
    root.append(h('div', { class: 'cr-head' }, h('b', null, 'Note'), h('span', { class: 'cr-mode' }, 'moving by', pill)), box, task, pad);
    stage.append(root);

    let text = TEXT0, spans = [], pos = 0, anchor = null, words = false, fixed = false;
    const cx = FT.spring(0, FT.SPRING.snappy), cy = FT.spring(0, FT.SPRING.snappy);
    const build = () => {
      box.replaceChildren();
      spans = [...text].map(ch => { const s = h('span', null, ch); box.append(s); return s; });
      box.append(caret);
      const t = text.indexOf('recieve');
      if (t >= 0) for (let i = t; i < t + 7; i++) spans[i].classList.add('typo');
    };
    const geo = b => {
      const n = spans.length;
      if (b < n) { const s = spans[b]; return { x: s.offsetLeft, y: s.offsetTop, hgt: s.offsetHeight }; }
      const s = spans[n - 1]; return { x: s.offsetLeft + s.offsetWidth, y: s.offsetTop, hgt: s.offsetHeight };
    };
    const isSp = i => i < 0 || i >= text.length || /\s/.test(text[i]);
    const nextWord = (b, dir) => {
      if (dir > 0) { let i = b; while (i < text.length && isSp(i)) i++; while (i < text.length && !isSp(i)) i++; return i; }
      let i = b; while (i > 0 && isSp(i - 1)) i--; while (i > 0 && !isSp(i - 1)) i--; return i;
    };
    const lineMove = (b, dir) => {
      const g = geo(b);
      let best = b, bd = Infinity;
      const targetY = g.y + dir * g.hgt;
      for (let i = 0; i <= spans.length; i++) {
        const q = geo(i);
        if (Math.abs(q.y - targetY) > g.hgt * 0.5) continue;
        const d = Math.abs(q.x - g.x); if (d < bd) { bd = d; best = i; }
      }
      return best;
    };
    const nearest = (x, y) => {
      let best = 0, bd = Infinity;
      for (let i = 0; i <= spans.length; i++) {
        const q = geo(i), d = Math.abs(q.x - x) + Math.abs(q.y + q.hgt / 2 - y) * 3;
        if (d < bd) { bd = d; best = i; }
      }
      return best;
    };
    const wordAt = b => { let a = b; while (a > 0 && !isSp(a - 1)) a--; let e = b; while (e < text.length && !isSp(e)) e++; return [a, e]; };
    const paintSel = () => {
      const [a, e] = anchor == null ? [0, 0] : [Math.min(anchor, pos), Math.max(anchor, pos)];
      spans.forEach((s, i) => s.classList.toggle('sel', i >= a && i < e));
    };
    const caretLoop = FT.loop(dt => { const a = cx.step(dt), b = cy.step(dt); caret.style.transform = `translate(${cx.x - 1}px,${cy.x}px)`; return !(a && b); });
    let blinkT = null;
    const place = (b, how, jump) => {
      pos = FT.clamp(b, 0, text.length);
      const g = geo(pos);
      caret.style.height = g.hgt + 'px';
      if (jump) { cx.set(g.x); cy.set(g.y); } else { cx.to(g.x); cy.to(g.y); }
      caretLoop.wake();
      caret.classList.remove('blink'); clearTimeout(blinkT); blinkT = setTimeout(() => caret.classList.add('blink'), 500);
      paintSel(); paintTask();
    };
    const flash = (a, e, cls) => {
      for (let i = a; i < e; i++) { const s = spans[i]; if (!s) continue; s.classList.add(cls); }
      setTimeout(() => { for (let i = a; i < e; i++) spans[i] && spans[i].classList.remove(cls); }, 30);
    };
    const paintTask = () => {
      const t = text.indexOf('recieve');
      if (fixed) { task.innerHTML = '<span class="ok">Fixed: “receive”.</span><span>Nicely done.</span>'; return; }
      if (t >= 0 && pos >= t + 3 && pos <= t + 5) {
        if (!task.querySelector('button')) {
          const b = h('button', { class: 'ft-btn accent', type: 'button', 'data-hit': '' }, 'Swap to “ei”');
          b.addEventListener('click', () => {
            text = text.slice(0, t + 3) + 'ei' + text.slice(t + 5); fixed = true; build(); place(t + 5, 'fix', true);
            FT.haptic('success'); FT.intent('typo fixed at the caret'); FT.announce('Fixed: receive'); box.focus();
          });
          task.replaceChildren(h('span', { class: 'ok' }, 'Caret is on the typo.'), b);
          FT.haptic('light');
        }
      } else task.innerHTML = '<span>Task: put the caret between the <b>i</b> and <b>e</b> in “recieve”.</span>';
    };
    const setMode = w => {
      if (w === words) return;
      words = w; pill.textContent = w ? 'words' : 'letters'; pill.classList.toggle('w', w);
      FT.intent(w ? 'fast drag: gain up, caret jumps words' : 'slow drag: gain down, caret steps letters');
    };
    const sayWord = (() => { let t = null; return () => { clearTimeout(t); t = setTimeout(() => { const [a, e] = wordAt(pos); FT.announce(text.slice(a, e) || 'space'); }, 220); }; })();

    /* ---------- the pad: relative, speed-dependent gain ---------- */
    let acc = 0, accY = 0, lastX = 0, lastY = 0, holdT = 0, selecting = false, holdTimer = null;
    FT.drag(pad, {
      start(s) {
        acc = 0; accY = 0; lastX = s.x; lastY = s.y; selecting = false; holdT = performance.now();
        pad.classList.add('on');
        clearTimeout(holdTimer);
        holdTimer = setTimeout(() => { if (!moved0) { selecting = true; anchor = pos; pill.textContent = 'selecting'; pill.classList.add('s'); FT.haptic('medium'); FT.intent('held still: selection mode'); } }, 420);
        moved0 = false;
      },
      move(s) {
        if (s.moved) moved0 = true;
        const dx = s.x - lastX, dy = s.y - lastY; lastX = s.x; lastY = s.y;
        const sp = Math.abs(s.vx);
        meterFill.style.width = `${FT.clamp(sp / 900, 0, 1) * 100}%`;
        if (!selecting) { setMode(words ? sp > 260 : sp > 420); if (anchor != null) { anchor = null; paintSel(); } }
        acc += dx; accY += dy;
        const step = words && !selecting ? 26 : 10;
        while (Math.abs(acc) >= step) {
          const dir = Math.sign(acc); acc -= dir * step;
          const before = pos;
          const nb = words && !selecting ? nextWord(pos, dir) : FT.clamp(pos + dir, 0, text.length);
          if (nb === pos) { acc = 0; break; }
          place(nb, 'pad');
          if (words && !selecting) flash(Math.min(before, nb), Math.max(before, nb), 'wp'); else flash(Math.min(before, nb), Math.max(before, nb), 'cp');
          FT.haptic('select'); sayWord();
        }
        while (Math.abs(accY) >= 26) {
          const dir = Math.sign(accY); accY -= dir * 26;
          const nb = lineMove(pos, dir); if (nb !== pos) { place(nb, 'pad'); FT.haptic('select'); sayWord(); }
        }
      },
      end() {
        clearTimeout(holdTimer); pad.classList.remove('on'); meterFill.style.width = '0';
        if (selecting) { pill.classList.remove('s'); pill.textContent = words ? 'words' : 'letters'; const n = Math.abs(pos - anchor); FT.announce(`${n} characters selected`); }
        selecting = false; setMode(false);
      },
    }, { axis: 'both', slop: 2 });
    let moved0 = false;
    const meterMark = meter.querySelector('b'); meterMark.style.left = `${420 / 900 * 100}%`;

    /* ---------- the text: absolute, with a callout above the finger ---------- */
    let call = null, lastTap = 0, textHold = null, textSel = false;
    const showCall = (s) => {
      if (!call) { call = h('div', { class: 'cr-call', 'aria-hidden': 'true' }); stage.append(call); }
      const a = Math.max(0, pos - 9), e = Math.min(text.length, pos + 9);
      call.replaceChildren(text.slice(a, pos), h('i'), text.slice(pos, e));
      const br = box.getBoundingClientRect(), sr = stage.getBoundingClientRect();
      call.style.left = FT.clamp(br.left - sr.left + s.x, 120, sr.width - 120) + 'px';
      call.style.top = Math.max(46, br.top - sr.top + s.y - 34) + 'px';
    };
    FT.drag(box, {
      start(s) {
        textSel = false; clearTimeout(textHold);
        const b = nearest(s.x, s.y);
        textHold = setTimeout(() => { textSel = true; anchor = pos; paintSel(); FT.haptic('medium'); FT.intent('held on text: drag to select'); pill.textContent = 'selecting'; pill.classList.add('s'); }, 450);
        place(b, 'touch');
      },
      move(s) {
        if (!s.moved) return;
        if (!textSel) clearTimeout(textHold);
        const b = nearest(s.x, s.y);
        if (b !== pos) { place(b, 'touch'); FT.haptic('select'); }
        showCall(s);
      },
      tap(s) {
        const now = performance.now();
        if (now - lastTap < 320) {
          const [a, e] = wordAt(pos); anchor = a; place(e, 'double tap'); FT.haptic('light');
          FT.intent(`double tap: selected “${text.slice(a, e)}”`); FT.announce(`Selected ${text.slice(a, e)}`);
        } else { anchor = null; paintSel(); FT.intent('tap: caret placed'); sayWord(); }
        lastTap = now;
      },
      end() {
        clearTimeout(textHold);
        if (call) { call.remove(); call = null; }
        if (textSel) { pill.classList.remove('s'); pill.textContent = 'letters'; FT.announce(`${Math.abs(pos - anchor)} characters selected`); }
        textSel = false;
      },
    }, { axis: 'both', slop: 4 });

    box.addEventListener('keydown', e => {
      const word = e.altKey || e.ctrlKey || e.metaKey;
      let b = null;
      if (e.key === 'ArrowRight') b = word ? nextWord(pos, 1) : pos + 1;
      else if (e.key === 'ArrowLeft') b = word ? nextWord(pos, -1) : pos - 1;
      else if (e.key === 'ArrowDown') b = lineMove(pos, 1);
      else if (e.key === 'ArrowUp') b = lineMove(pos, -1);
      else if (e.key === 'Home') b = 0; else if (e.key === 'End') b = text.length;
      else return;
      e.preventDefault();
      if (e.shiftKey) { if (anchor == null) anchor = pos; } else anchor = null;
      place(b, 'key'); sayWord();
    });
    new ResizeObserver(() => place(pos, 'resize', true)).observe(box);

    const reset = () => { text = TEXT0; fixed = false; anchor = null; build(); place(text.indexOf('Friday'), 'reset', true); };
    reset();
    return { reset };
  },
});
