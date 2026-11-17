/* III.4 Hold one over the other — drag one option onto another and only the differences stay lit. */
FT.exhibit({
  id: 'overlap-compare', room: 3, num: 4, kind: 'proposal · comparison', replaces: 'the comparison table',
  title: 'Hold one over the other',
  hint: 'Drag flat B onto flat A · drag it away to separate',
  height: 480,
  body: `<p>Two flats, seven facts each. Drag B over A. As they overlap, the rows line up, every fact they share fades to a ghost, and every difference lights up with its delta: +€90, −8 m², a balcony. Once B sits on A, one sentence sums up the trade.</p><p>Pull B away and the cards are just cards again. Comparing becomes something you do to two things you're already looking at, with no "add to compare" step and no table to read.</p>`,
  why: `Comparison tables show every fact twice, and people have to find the differences themselves. Overlap does that work for them: what's identical drops out, and what's left is exactly the decision.`,
  flutter: `
class OverlapCompare extends StatefulWidget {
  const OverlapCompare({super.key, required this.a, required this.b});
  final Listing a, b;
  @override State<OverlapCompare> createState() => _OverlapCompareState();
}

class _OverlapCompareState extends State<OverlapCompare> with SingleTickerProviderStateMixin {
  late final AnimationController pos = AnimationController.unbounded(vsync: this);
  Offset offset = Offset.zero;                       // B relative to its home slot

  double get overlap {                               // 0 … 1, from the two card rects
    final r = rectA.intersect(rectB.shift(offset));
    return r.isEmpty ? 0 : (r.width * r.height) / (rectA.width * rectA.height);
  }

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeInOut.transform(((overlap - .12) / .68).clamp(0, 1));
    return Stack(children: [
      Positioned.fromRect(rect: rectA, child: ListingCard(widget.a)),
      Positioned.fromRect(rect: rectB.shift(offset), child: GestureDetector(
        onPanUpdate: (d) => setState(() => offset += d.delta),
        onPanEnd: (_) => _settle(overlap > .45 ? snapOnA : Offset.zero),   // SpringSimulation
        child: ListingCard(widget.b, diffAgainst: widget.a, intensity: t),
      )),
      // inside ListingCard: same rows → Opacity(1 − .7 t); different rows → DeltaChip(opacity: t)
    ]);
  }
}`,
  a11y: `Use the <b>Compare</b> button: it moves B onto A and reads the differences as a list ("Rent: €90 more. Size: 8 m² smaller …"), then the summary. <b>Separate</b> moves it back. Each card is also a labelled list of its seven facts.`,
  mount(stage) {
    const { h } = FT;
    const css = h('style', null, `
.ov-top{position:absolute;left:16px;right:16px;top:14px;display:flex;justify-content:space-between;align-items:center;gap:8px}
.ov-top b{font-size:14px}
.ov-card{position:absolute;top:0;left:0;padding:0 0 6px;overflow:hidden;will-change:transform;touch-action:none}
.ov-card.b{cursor:grab}
.ov-card.b:active{cursor:grabbing}
.ov-band{height:5px}
.ov-head{display:flex;align-items:center;gap:8px;padding:8px 10px 6px}
.ov-badge{flex:none;width:22px;height:22px;border-radius:50%;display:grid;place-items:center;font-size:11.5px;font-weight:700}
.ov-name{min-width:0;font-size:12.5px;font-weight:600;line-height:1.2;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ov-name small{display:block;font-weight:400;color:var(--muted);font-size:11px}
.ov-row{position:relative;display:flex;justify-content:space-between;align-items:center;gap:4px;padding:3px 10px;height:37px;border-top:1px solid var(--line)}
.ov-row .bg{position:absolute;inset:0;opacity:0}
.ov-k{position:relative;display:flex;flex-direction:column;min-width:0}
.ov-k .ft-label{font-size:9.5px;line-height:1.2}
.ov-v{font-size:13px;font-weight:600;white-space:nowrap;font-variant-numeric:tabular-nums}
.ov-d{position:relative;flex:none;font-family:var(--f-mono);font-size:10.5px;font-weight:600;padding:2px 6px;border-radius:999px;opacity:0;white-space:nowrap}
.ov-d.good{color:var(--ok);background:var(--ok-soft)}.ov-d.bad{color:var(--hot);background:var(--hot-soft)}.ov-d.meh{color:var(--muted);background:var(--bg-2)}
.ov-foot{position:absolute;left:16px;right:16px;bottom:14px;display:flex;gap:10px;align-items:center}
.ov-verdict{flex:1;min-width:0;font-size:12.5px;line-height:1.35;color:var(--ink-2);opacity:0}
.ov-verdict b{color:var(--ink)}
.ov-foot .ft-btn{height:36px;font-size:13px;padding:0 14px;flex:none}
`);
    const ROWS = [
      ['Rent', 'rent', v => `€${v}`, (a, b) => b - a, d => `${d > 0 ? '+' : '−'}€${Math.abs(d)}`, d => d > 0 ? 'bad' : 'good'],
      ['Size', 'size', v => `${v} m²`, (a, b) => b - a, d => `${d > 0 ? '+' : '−'}${Math.abs(d)} m²`, d => d < 0 ? 'bad' : 'good'],
      ['Rooms', 'rooms', v => `${v}`, (a, b) => b - a, d => `${d > 0 ? '+' : '−'}${Math.abs(d)}`, d => d < 0 ? 'bad' : 'good'],
      ['Floor', 'floor', v => ['ground', '1st', '2nd', '3rd', '4th'][v[0]] + (v[1] ? ' · lift' : ''), (a, b) => b[0] - a[0], d => `${Math.abs(d)} ${d < 0 ? 'lower' : 'higher'}`, () => 'meh'],
      ['To tram', 'tram', v => `${v} min`, (a, b) => b - a, d => `${d > 0 ? '+' : '−'}${Math.abs(d)} min`, d => d > 0 ? 'bad' : 'good'],
      ['Balcony', 'balcony', v => v ? 'yes' : 'no', (a, b) => (b ? 1 : 0) - (a ? 1 : 0), d => d > 0 ? '+ balcony' : '− balcony', d => d > 0 ? 'good' : 'bad'],
      ['Pets', 'pets', v => v ? 'allowed' : 'no', (a, b) => (b ? 1 : 0) - (a ? 1 : 0), d => d > 0 ? '+ pets' : '− pets', d => d > 0 ? 'good' : 'bad'],
    ];
    const A = { id: 'A', street: 'Ozaljska 41', area: 'Trešnjevka', rent: 890, size: 64, rooms: 2, floor: [3, true], tram: 9, balcony: false, pets: true, tone: '--amber', soft: '--amber-soft' };
    const B = { id: 'B', street: 'Bukovačka 12', area: 'Maksimir', rent: 980, size: 56, rooms: 2, floor: [1, false], tram: 3, balcony: true, pets: true, tone: '--accent', soft: '--accent-soft' };
    const diffs = ROWS.map(([label, key, fmt, cmp, dl, tone]) => { const d = cmp(A[key], B[key]); return { label, d, text: d ? dl(d) : 'same', tone: d ? tone(d) : 'meh' }; });
    const card = (L, isB) => {
      const rows = ROWS.map(([label, key, fmt], i) => {
        const bg = h('div', { class: 'bg' });
        const v = h('span', { class: 'ov-v' }, fmt(L[key]));
        const d = isB ? h('span', { class: `ov-d ${diffs[i].tone}` }, diffs[i].text) : null;
        const r = h('div', { class: 'ov-row', role: 'listitem' }, bg, h('div', { class: 'ov-k' }, h('span', { class: 'ft-label' }, label), v), d);
        return { r, v, d, bg, same: diffs[i].d === 0, tone: diffs[i].tone };
      });
      const sub = h('small', null, L.area);
      const el = h('div', { class: 'ov-card ft-card' + (isB ? ' b' : ''), 'aria-label': `Flat ${L.id}: ${L.street}, ${L.area}`, 'data-hit': isB ? '' : null },
        h('div', { class: 'ov-band', style: { background: `var(${L.tone})` } }),
        h('div', { class: 'ov-head' }, h('span', { class: 'ov-badge', style: { background: `var(${L.soft})`, color: `var(${L.tone})` } }, L.id), h('div', { class: 'ov-name' }, L.street, sub)),
        h('div', { role: 'list' }, rows.map(r => r.r)));
      return { el, rows, sub };
    };
    const ca = card(A, false), cb = card(B, true);
    const verdict = h('div', { class: 'ov-verdict', 'aria-live': 'polite' });
    verdict.innerHTML = `<b>B costs €90 more for 8 m² less.</b> In return: a balcony and 6 minutes less to the tram, but no lift.`;
    const btn = h('button', { class: 'ft-btn ghost', type: 'button', 'data-hit': '' }, 'Compare');
    stage.append(css, h('div', { class: 'ov-top' }, h('b', null, 'Two flats, one budget'), h('span', { class: 'ft-label' }, 'Zagreb · Nov')), ca.el, cb.el, h('div', { class: 'ov-foot' }, verdict, btn));

    let W = 366, cw = 160, ax = 14, ay = 46, homeX = 0, compare = false;
    const bx = FT.spring(0, FT.SPRING.smooth), by = FT.spring(0, FT.SPRING.smooth);
    const layout = () => {
      W = stage.clientWidth; cw = Math.floor((W - 28 - 12) / 2); ax = 14; homeX = ax + cw + 12;
      for (const c of [ca, cb]) c.el.style.width = cw + 'px';
      ca.el.style.transform = `translate(${ax}px,${ay}px)`;
      const tx = compare ? ax + 9 : homeX, ty = compare ? ay + 9 : ay;
      bx.set(tx); by.set(ty); paint();
    };
    const overlap = () => {
      const hA = ca.el.offsetHeight;
      const ix = Math.max(0, Math.min(ax + cw, bx.x + cw) - Math.max(ax, bx.x));
      const iy = Math.max(0, Math.min(ay + hA, by.x + hA) - Math.max(ay, by.x));
      return (ix * iy) / (cw * hA);
    };
    let lastE = -1;
    const paint = () => {
      cb.el.style.transform = `translate(${bx.x.toFixed(1)}px,${by.x.toFixed(1)}px)`;
      const ov = overlap();
      const t = FT.clamp((ov - 0.12) / 0.68, 0, 1), e = t * t * (3 - 2 * t);
      if (Math.abs(e - lastE) < 0.002) return;
      lastE = e;
      cb.rows.forEach(r => {
        r.v.style.opacity = r.same ? (1 - 0.72 * e).toFixed(3) : 1;
        r.d.style.opacity = (r.same ? 0.8 * e : e).toFixed(3);
        r.bg.style.opacity = r.same ? 0 : (0.55 * e).toFixed(3);
        r.bg.style.background = r.tone === 'good' ? 'var(--ok-soft)' : r.tone === 'bad' ? 'var(--hot-soft)' : 'var(--bg-2)';
      });
      ca.el.style.opacity = (1 - 0.25 * e).toFixed(3);
      cb.sub.textContent = e > 0.5 ? 'compared with A' : B.area;
      verdict.style.opacity = Math.max(0, e * 1.4 - 0.4).toFixed(3);
      cb.el.style.boxShadow = e > 0 ? `0 0 0 ${(1.5 * e).toFixed(2)}px var(--accent), var(--shadow)` : '';
    };
    const loop = FT.loop(dt => { const a = bx.step(dt), b = by.step(dt); paint(); return !(a && b); });
    const settle = (on, how) => {
      const was = compare; compare = on;
      bx.to(on ? ax + 9 : homeX); by.to(on ? ay + 9 : ay); loop.wake();
      btn.textContent = on ? 'Separate' : 'Compare';
      if (on !== was || how === 'drop') {
        FT.haptic(on ? 'medium' : 'light');
        FT.intent(on ? `${how}: B snapped onto A, ${diffs.filter(d => d.d).length} differences lit` : `${how}: separated`);
        FT.announce(on ? `Comparing B with A. ${diffs.map(d => `${d.label}: ${d.d ? d.text : 'same'}`).join('. ')}. B costs 90 euros more for 8 square metres less, with a balcony and 6 minutes less to the tram, but no lift.` : 'Separated');
      }
    };
    // the card moves under the finger, so measure the drag in screen space, not card space
    let x0 = 0, y0 = 0, cx = 0, cy = 0, crossed = false;
    FT.drag(cb.el, {
      start(s, e) { x0 = bx.x; y0 = by.x; cx = e.clientX; cy = e.clientY; crossed = overlap() > 0.45; },
      move(s, e) {
        bx.set(FT.clamp(x0 + e.clientX - cx, -cw * 0.3, W - cw * 0.7)); by.set(FT.clamp(y0 + e.clientY - cy, 10, stage.clientHeight - 120));
        paint();
        const now = overlap() > 0.45;
        if (now !== crossed) { crossed = now; FT.haptic('select'); FT.intent(now ? `overlap ${Math.round(overlap() * 100)}%: release to compare` : 'overlap below 45%: release to separate'); }
      },
      tap() { settle(!compare, 'tap'); },
      end(s) { if (s.moved) settle(overlap() > 0.45, 'drop'); },
    }, { axis: 'both' });
    btn.addEventListener('click', () => settle(!compare, 'button'));
    new ResizeObserver(layout).observe(stage);
    layout();
    return { reset() { compare = false; btn.textContent = 'Compare'; bx.to(homeX); by.to(ay); loop.wake(); } };
  },
});
