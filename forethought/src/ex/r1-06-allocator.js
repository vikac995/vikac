/* I.6 Budget that balances — a zero-sum allocator with locks. */
FT.exhibit({
  id: 'zero-sum', room: 1, num: 6, kind: 'allocation', replaces: 'five number fields',
  title: 'A budget that balances itself',
  hint: 'Drag a divider · tap a padlock to protect a category',
  height: 420,
  body: `<p>A monthly budget is a fixed amount shared out, so the control is one bar that always adds up. Drag a divider and the money moves between the two sides. If the next category is locked, the change comes from the nearest one that isn't. The total never moves.</p><p>Tap a padlock to protect rent or savings. Locked categories are hatched and refuse to change, whatever you drag.</p>`,
  why: `Five separate fields let you type numbers that don't add up, then show an error. A shared bar makes the constraint physical: you can't overspend because there is nothing to overspend into. Locks say "this part is settled" so the rest can move freely.`,
  flutter: `
class Allocation extends ChangeNotifier {
  Allocation(this.amounts, {required this.total});
  final List<double> amounts;          // € per category, always sums to total
  final double total;
  final Set<int> locked = {};

  /// Move the divider between [i] and [i + 1] by [delta] euros (positive = rightwards).
  double moveDivider(int i, double delta) {
    final gain = delta > 0 ? _nearestUnlocked(i, -1) : _nearestUnlocked(i + 1, 1);
    if (gain == null) return 0;                         // everything on that side is locked
    var need = delta.abs(), moved = 0.0;
    final step = delta > 0 ? 1 : -1;
    for (var j = delta > 0 ? i + 1 : i; j >= 0 && j < amounts.length && need > 0; j += step) {
      if (locked.contains(j)) continue;                 // skip, never change a lock
      final take = min(need, amounts[j]);
      amounts[j] -= take; need -= take; moved += take;
    }
    amounts[gain] += moved;
    notifyListeners();
    return moved * step;                                // what actually moved, for the haptic edge
  }

  int? _nearestUnlocked(int from, int dir) {
    for (var j = from; j >= 0 && j < amounts.length; j += dir) {
      if (!locked.contains(j)) return j;
    }
    return null;
  }
}

// Dividers: GestureDetector(onHorizontalDragUpdate: (d) => model.moveDivider(i, d.delta.dx / pxPerEuro))
// wrapped in Semantics(slider: true, onIncrease: () => model.moveDivider(i, 10), ...)`,
  a11y: `Each divider is a <b>slider</b> labelled with the two categories it separates. <b>← →</b> move €10, <b>Page Up/Down</b> €100; the value reads both amounts ("Food €480, Travel €260"). Padlocks are toggle buttons announcing "Rent locked".`,
  mount(stage) {
    const { h } = FT;
    stage.append(h('style', null, `
      .al-head{position:absolute;left:18px;right:18px;top:18px;display:flex;justify-content:space-between;align-items:baseline}
      .al-head b{font-size:15px}
      .al-total{font-family:var(--f-mono);font-size:13px;color:var(--muted)}
      .al-total b{color:var(--ink);font-size:15px}
      .al-delta{position:absolute;left:18px;right:18px;top:48px;font-family:var(--f-mono);font-size:11.5px;color:var(--muted);min-height:18px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
      .al-delta .p{color:var(--ok)} .al-delta .m{color:var(--hot)}
      .al-bar{position:absolute;left:18px;right:18px;top:78px;height:62px}
      .al-seg{position:absolute;top:0;bottom:0;border-radius:10px;overflow:hidden;display:flex;align-items:flex-end;padding:0 0 7px 9px;font-family:var(--f-mono);font-size:10.5px;font-weight:600;color:var(--bg);white-space:nowrap}
      .al-seg.lk{background-image:repeating-linear-gradient(-45deg,transparent 0 5px,color-mix(in srgb,var(--bg) 32%,transparent) 5px 7px)}
      .al-div{position:absolute;top:-8px;bottom:-8px;width:28px;margin-left:-14px;cursor:ew-resize;display:grid;place-items:center;border-radius:10px}
      .al-div i{width:6px;height:34px;border-radius:3px;background:var(--surface-2);box-shadow:0 0 0 1.5px var(--ink),0 2px 6px rgba(0,0,0,.25);transition:transform .15s}
      .al-div.on i{transform:scaleY(1.2)}
      .al-div.blocked i{box-shadow:0 0 0 1.5px var(--hot)}
      .al-list{position:absolute;left:18px;right:18px;top:162px;display:grid;gap:4px}
      .al-row{display:grid;grid-template-columns:12px 1fr auto auto 40px;gap:10px;align-items:center;height:38px;padding:0 0 0 12px;border-radius:10px;background:var(--surface-2);border:1px solid var(--line)}
      .al-row .sw{width:12px;height:12px;border-radius:4px}
      .al-row .nm{font-size:13.5px;font-weight:500}
      .al-row .pc{font-family:var(--f-mono);font-size:11px;color:var(--faint)}
      .al-row .am{font-family:var(--f-mono);font-variant-numeric:tabular-nums;font-size:13.5px;font-weight:600;min-width:62px;text-align:right}
      .al-lock{width:40px;height:36px;border:0;background:none;cursor:pointer;display:grid;place-items:center;color:var(--faint);border-radius:9px}
      .al-lock[aria-pressed="true"]{color:var(--ink)}
      .al-row.lk{background:var(--bg-2)}
    `));
    const CATS = [
      ['Rent', 'var(--accent)'], ['Food', 'var(--amber)'], ['Travel', 'var(--ok)'],
      ['Savings', 'color-mix(in srgb, var(--accent) 45%, var(--line-2))'], ['Fun', 'color-mix(in srgb, var(--hot) 75%, var(--amber))'],
    ];
    const TOTAL = 2400, INIT = [1100, 480, 260, 360, 200];
    let amt = [...INIT], locked = new Set();
    const shown = INIT.map(v => FT.spring(v, FT.SPRING.snappy));
    const delta = h('div', { class: 'al-delta', 'aria-live': 'off' });
    stage.append(h('div', { class: 'al-head' }, h('b', null, 'Monthly budget'), h('span', { class: 'al-total' }, 'total ', h('b', null, '€2,400'))), delta);
    const bar = h('div', { class: 'al-bar' });
    const segs = CATS.map(([n, c]) => { const s = h('div', { class: 'al-seg', style: { background: c } }); bar.append(s); return s; });
    const divs = [0, 1, 2, 3].map(i => {
      const d = h('div', { class: 'al-div', 'data-hit': '' }, h('i'));
      bar.append(d); return d;
    });
    stage.append(bar);
    const list = h('div', { class: 'al-list' });
    const rows = CATS.map(([n, c], i) => {
      const lock = h('button', { class: 'al-lock', type: 'button', 'aria-pressed': 'false', 'aria-label': `Lock ${n}`, 'data-hit': '' });
      const row = h('div', { class: 'al-row' }, h('span', { class: 'sw', style: { background: c } }), h('span', { class: 'nm' }, n), h('span', { class: 'pc' }), h('span', { class: 'am' }), lock);
      lock.addEventListener('click', () => {
        if (locked.has(i)) locked.delete(i); else locked.add(i);
        FT.haptic(locked.has(i) ? 'medium' : 'light');
        FT.intent(`${n} ${locked.has(i) ? 'locked' : 'unlocked'}`); FT.announce(`${n} ${locked.has(i) ? 'locked' : 'unlocked'}`);
        paint();
      });
      list.append(row); return row;
    });
    stage.append(list);
    const LOCK_SVG = on => `<svg width="16" height="18" viewBox="0 0 16 18" aria-hidden="true"><rect x="2" y="8" width="12" height="9" rx="2.5" fill="${on ? 'currentColor' : 'none'}" stroke="currentColor" stroke-width="1.6"/><path d="M5 8V5.5a3 3 0 0 1 6 0${on ? 'V8' : 'V4.5'}" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" ${on ? '' : 'transform="translate(3.2 -1.2)"'}/></svg>`;
    const eur = v => '€' + Math.round(v).toLocaleString('en-GB');

    /* the model: move divider i by d euros, cascading past locked or empty categories */
    const moveDivider = (i, d) => {
      if (!d) return 0;
      const gain = d > 0 ? [...Array(i + 1).keys()].reverse().find(j => !locked.has(j)) : [...Array(5).keys()].slice(i + 1).find(j => !locked.has(j));
      if (gain == null) return 0;
      let need = Math.abs(d), moved = 0;
      const order = d > 0 ? [...Array(5).keys()].slice(i + 1) : [...Array(i + 1).keys()].reverse();
      for (const j of order) { if (need <= 0) break; if (locked.has(j)) continue; const take = Math.min(need, amt[j]); amt[j] -= take; need -= take; moved += take; }
      amt[gain] += moved;
      return moved * Math.sign(d);
    };
    let before = null, dragI = -1, blocked = -1;
    const paint = () => {
      const W = bar.clientWidth, gap = 3;
      let x = 0;
      shown.forEach((s, i) => {
        const w = s.x / TOTAL * W;
        segs[i].style.left = (x + (i ? gap / 2 : 0)) + 'px';
        segs[i].style.width = Math.max(0, w - (i ? gap / 2 : 0) - (i < 4 ? gap / 2 : 0)) + 'px';
        segs[i].textContent = w > 50 ? CATS[i][0] : '';
        segs[i].classList.toggle('lk', locked.has(i));
        x += w;
        if (i < 4) { divs[i].style.left = x + 'px'; }
      });
      rows.forEach((r, i) => {
        r.querySelector('.am').textContent = eur(shown[i].x);
        r.querySelector('.pc').textContent = Math.round(shown[i].x / TOTAL * 100) + '%';
        const lk = r.querySelector('.al-lock');
        lk.innerHTML = LOCK_SVG(locked.has(i)); lk.setAttribute('aria-pressed', String(locked.has(i)));
        r.classList.toggle('lk', locked.has(i));
      });
      divs.forEach((d, i) => { d.classList.toggle('on', i === dragI); d.classList.toggle('blocked', i === blocked); d._sync && d._sync(); });
      if (before) {
        const parts = amt.map((v, i) => [i, Math.round(v - before[i])]).filter(([, dv]) => Math.abs(dv) >= 1);
        delta.innerHTML = parts.length ? parts.map(([i, dv]) => `${CATS[i][0]} <span class="${dv > 0 ? 'p' : 'm'}">${dv > 0 ? '+' : '−'}${eur(Math.abs(dv))}</span>`).join(' · ') : 'Drag to move money between categories';
      } else delta.textContent = locked.size ? `${[...locked].map(i => CATS[i][0]).join(' and ')} locked` : 'Every euro is allocated';
    };
    const loop = FT.loop(dt => { let busy = false; shown.forEach((s, i) => { s.to(amt[i]); if (!s.step(dt)) busy = true; }); paint(); return busy; });
    divs.forEach((d, i) => {
      let acc = 0, lastX = 0;
      FT.drag(d, {
        start(s, e) { before = [...amt]; dragI = i; acc = 0; lastX = e.clientX; FT.haptic('light'); FT.intent(`holding the ${CATS[i][0]} | ${CATS[i + 1][0]} divider`); loop.wake(); },
        move(s, e) {
          const W = bar.clientWidth;
          acc += (e.clientX - lastX) * TOTAL / W; lastX = e.clientX;
          const want = Math.trunc(acc / 10) * 10;      // move in €10 steps
          if (!want) return;
          const got = moveDivider(i, want);
          acc -= want;
          if (got !== want) { if (blocked !== i) { blocked = i; FT.haptic('warning'); FT.intent('blocked: nothing unlocked left on that side'); } acc = 0; }
          else { blocked = -1; FT.haptic('select'); }
          loop.wake();
        },
        end() {
          dragI = -1; blocked = -1;
          const changed = amt.map((v, j) => [j, v - before[j]]).filter(([, dv]) => dv);
          if (changed.length) FT.announce(changed.map(([j]) => `${CATS[j][0]} ${eur(amt[j])}`).join(', '));
          setTimeout(() => { if (dragI < 0) { before = null; paint(); } }, 1600);
          loop.wake();
        },
      }, { axis: 'x', slop: 2 });
      d._sync = FT.slider(d, {
        label: `Divider between ${CATS[i][0]} and ${CATS[i + 1][0]}`, min: 0, max: TOTAL, step: 10, big: 100,
        get: () => Math.round(amt.slice(0, i + 1).reduce((a, b) => a + b, 0)),
        set: v => { before = before || [...amt]; const cur = amt.slice(0, i + 1).reduce((a, b) => a + b, 0); moveDivider(i, v - cur); loop.wake(); clearTimeout(d._t); d._t = setTimeout(() => { before = null; paint(); }, 1600); },
        text: () => `${CATS[i][0]} ${eur(amt[i])}, ${CATS[i + 1][0]} ${eur(amt[i + 1])}`,
      });
    });
    new ResizeObserver(paint).observe(bar);
    paint();
    return { reset() { amt = [...INIT]; locked.clear(); before = null; loop.wake(); paint(); } };
  },
});
