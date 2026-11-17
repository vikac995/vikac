/* II.3 Scroll with terrain — flings settle on landmarks; a read-wear minimap remembers where you lingered. */
FT.exhibit({
  id: 'terrain-scroll', room: 2, num: 3, kind: 'scrolling', replaces: 'a bare scrollbar',
  title: 'Scroll with terrain',
  hint: 'Fling the notes · tap or drag the strip on the right',
  height: 470,
  body: `<p>Fling through seven years of release notes. A fling that would stop near a year heading, a bookmark or the "unread" line glides to it and stops there. A fling into the middle of nowhere stops where physics says.</p><p>The strip on the right is a map with memory. It darkens where you have lingered, so the parts you already read are visible at a glance, and its ticks show every landmark. Tap anywhere on it to go there.</p>`,
  why: `A scrollbar shows where you are and nothing else. Wear shows where you have been, landmarks show where things are, and a fling that respects them stops you somewhere useful instead of halfway down a paragraph.`,
  source: `Hill, Hollan, Wroblewski &amp; McCandless, <a href="https://acawiki.org/Edit_wear_and_read_wear" target="_blank" rel="noopener">"Edit Wear and Read Wear" (CHI 1992)</a>, and Alexander et al., <a href="https://eprints.lancs.ac.uk/id/eprint/50114/" target="_blank" rel="noopener">"Revisiting Read Wear" (CHI 2009)</a>, whose footprints scrollbar people strongly preferred.`,
  flutter: `
/// Ballistic scroll that settles on landmarks when the natural stop is close to one.
class LandmarkScrollPhysics extends BouncingScrollPhysics {
  const LandmarkScrollPhysics({required this.landmarks, super.parent});
  final List<double> landmarks;              // offsets of headings, bookmarks, the unread line

  @override
  LandmarkScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      LandmarkScrollPhysics(landmarks: landmarks, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics m, double velocity) {
    final natural = super.createBallisticSimulation(m, velocity);
    if (natural == null || m.outOfRange) return natural;
    final end = natural.x(double.infinity);                   // where friction would stop
    final pull = math.max(90.0, (end - m.pixels).abs() * .3);  // farther flings snap from farther
    final target = landmarks
        .where((l) => (l - end).abs() < pull)
        .fold<double?>(null, (b, l) => b == null || (l - end).abs() < (b - end).abs() ? l : b);
    if (target == null) return natural;
    HapticFeedback.lightImpact();
    return ScrollSpringSimulation(SpringDescription.withDampingRatio(mass: 1, stiffness: 90, ratio: 1),
        m.pixels, target.clamp(m.minScrollExtent, m.maxScrollExtent), velocity);
  }
}

// Read wear: a NotificationListener<ScrollUpdateNotification> adds dwell time per region
// while scroll speed is near zero; a CustomPainter draws heat + landmark ticks beside the list.`,
  a11y: `The notes are a focusable region. <b>Up/Down</b> scroll a line, <b>Page Up/Page Down</b> jump to the previous or next landmark, <b>Home/End</b> go to either end. The landmark you land on is announced ("2023", "Bookmark: Safety check-in", "Unread from here").`,
  mount(stage) {
    const { h } = FT;
    stage.append(h('style', { text: `
      .tr-root{position:absolute;inset:0;padding:14px 14px 14px 16px;display:flex;flex-direction:column;gap:10px}
      .tr-head{display:flex;justify-content:space-between;align-items:baseline;gap:10px;padding:0 2px}
      .tr-head b{font-size:14.5px}
      .tr-body{flex:1;display:flex;gap:8px;min-height:0}
      .tr-view{position:relative;flex:1;min-width:0;overflow:hidden;border-radius:14px;background:var(--surface-2);border:1px solid var(--line);box-shadow:var(--shadow);cursor:grab}
      .tr-view:active{cursor:grabbing}
      .tr-view::after{content:"";position:absolute;inset:auto 0 0;height:28px;background:linear-gradient(transparent,var(--surface-2));pointer-events:none}
      .tr-content{position:absolute;left:0;right:0;top:0;padding:6px 16px 40px;will-change:transform}
      .tr-year{font-family:var(--f-display);font-size:34px;line-height:1;margin:22px 0 6px;letter-spacing:-.01em;border-radius:8px;transition:background .5s,color .5s}
      .tr-entry{display:grid;grid-template-columns:auto 1fr;gap:2px 10px;padding:9px 0;border-top:1px solid var(--line);border-radius:8px;transition:background .5s}
      .tr-entry .v{font-family:var(--f-mono);font-size:11px;color:var(--muted);padding-top:2px;white-space:nowrap}
      .tr-entry p{margin:0;font-size:13.5px;line-height:1.45;color:var(--ink-2)}
      .tr-entry p b{color:var(--ink);font-weight:600}
      .tr-entry.bm .v::before{content:"";display:inline-block;width:7px;height:9px;margin-right:5px;background:var(--amber);clip-path:polygon(0 0,100% 0,100% 100%,50% 72%,0 100%)}
      .tr-unread{display:flex;align-items:center;gap:8px;margin:6px 0;font-family:var(--f-mono);font-size:10.5px;letter-spacing:.08em;text-transform:uppercase;color:var(--accent);border-radius:8px;transition:background .5s}
      .tr-unread::after{content:"";flex:1;height:1.5px;background:var(--accent)}
      .tr-land{background:var(--accent-wash)!important;transition:none!important}
      .tr-mini{position:relative;flex:none;width:30px;border-radius:10px;background:var(--surface-2);border:1px solid var(--line);cursor:pointer;overflow:hidden}
      .tr-legend{display:flex;gap:10px;font-family:var(--f-mono);font-size:10.5px;color:var(--muted);flex-wrap:wrap}
      .tr-legend i{display:inline-block;width:8px;height:8px;border-radius:2px;margin-right:4px;vertical-align:-1px}
    ` }));
    const DATA = [
      ['2019', [['1.0', 'Mar', '<b>First release.</b> Forty trails around Zagreb, drawn in the style of the old paper maps.'], ['1.2', 'Jul', '<b>Track recording.</b> Your walk is saved as a line, with distance and time.'], ['1.4', 'Nov', '<b>Night theme</b> for early starts, dim enough to keep your eyes adjusted.']]],
      ['2020', [['2.0', 'Feb', '<b>Offline maps by region.</b> Download before you leave, walk without signal.', 'bm'], ['2.3', 'Jun', '<b>Elevation profiles</b> on every trail, so the steep part is never a surprise.'], ['2.6', 'Oct', '<b>Trail conditions</b> reported by walkers: mud, fallen trees, closed bridges.']]],
      ['2021', [['3.0', 'Apr', '<b>Shared lists.</b> Plan a weekend with friends and see who has packed what.'], ['3.2', 'Aug', '<b>Huts and springs</b> on the map, with opening months.'], ['3.5', 'Dec', '<b>Watch support.</b> Turn-by-turn on your wrist, phone in the bag.']]],
      ['2022', [['4.0', 'Mar', '<b>Route builder.</b> Draw a rough line and get a path that follows real trails.'], ['4.4', 'Jul', '<b>Snow layer</b> for winter hikes, updated every morning.'], ['4.8', 'Nov', '<b>Photos pinned</b> to the exact spot where they were taken.']]],
      ['2023', [['5.0', 'Feb', '<b>Safety check-in.</b> Tell someone when you expect to be back; they hear if you are late.', 'bm'], ['5.3', 'Jun', '<b>Battery saver</b> keeps GPS alive for twenty hours.'], ['5.7', 'Oct', '<b>Every map label</b> is now readable by TalkBack and VoiceOver.']]],
      ['2024', [['6.0', 'Mar', '<b>3D terrain.</b> Tilt the map with two fingers to see the ridge you are about to climb.'], ['6.2', 'Jul', '<b>Bus and train times</b> to every trailhead.'], ['6.6', 'Nov', '<b>Group pace.</b> Everyone sees where the slowest walker is.']]],
      ['2025', [['7.0', 'Mar', '<b>Sunset warnings</b> when your pace says you will finish in the dark.'], 'unread', ['7.3', 'Jul', '<b>Difficulty in plain words:</b> "steady climb, one scramble near the top".'], ['7.8', 'Nov', '<b>One tap</b> downloads a whole national park.']]],
      ['2026', [['8.0', 'Jan', '<b>Avalanche bulletins</b>, live, for every slope on your route.'], ['8.1', 'Apr', '<b>Your year on the trails:</b> distance, height gained, favourite ridge.'], ['8.2', 'Sep', '<b>Map packs</b> for the Dinaric Alps, from Velebit to Durmitor.']]],
    ];
    const root = h('div', { class: 'tr-root' });
    const view = h('div', { class: 'tr-view', tabindex: '0', role: 'region', 'aria-label': 'Trailhead release notes, 2019 to 2026. Page Up and Page Down jump between landmarks.', 'data-hit': '' });
    const content = h('div', { class: 'tr-content' });
    const mini = h('div', { class: 'tr-mini', 'data-hit': '', 'aria-hidden': 'true' });
    const legend = h('div', { class: 'tr-legend', html: `<span><i style="background:var(--accent);opacity:.55"></i>read</span><span><i style="background:var(--amber)"></i>bookmark</span>` });
    root.append(h('div', { class: 'tr-head' }, h('b', null, 'Trailhead · what changed'), legend), h('div', { class: 'tr-body' }, view, mini));
    view.append(content);
    stage.append(root);
    const marks = [];
    for (const [year, entries] of DATA) {
      const yh = h('h4', { class: 'tr-year' }, year); content.append(yh);
      marks.push({ el: yh, kind: 'year', name: year });
      for (const e of entries) {
        if (e === 'unread') { const u = h('div', { class: 'tr-unread' }, 'Unread from here'); content.append(u); marks.push({ el: u, kind: 'unread', name: 'Unread from here' }); continue; }
        const [v, m, txt, bm] = e;
        const el = h('div', { class: 'tr-entry' + (bm ? ' bm' : '') }, h('span', { class: 'v' }, `v${v} · ${m}`), h('p', { html: txt }));
        content.append(el);
        if (bm) marks.push({ el, kind: 'bookmark', name: 'Bookmark: ' + el.querySelector('b').textContent.replace(/\.$/, '') });
      }
    }

    let y = 0, viewH = 1, contentH = 1, maxY = 0, anim = null, velo = 0;
    const BUCKETS = 56;
    let heat = new Float32Array(BUCKETS);
    let mcv = null;
    mcv = FT.canvas(mini, () => { if (mcv) measure(); });
    function measure() {
      viewH = view.clientHeight; contentH = content.offsetHeight; maxY = Math.max(0, contentH - viewH);
      for (const m of marks) m.top = Math.max(0, Math.min(maxY, m.el.offsetTop - 10));
      paintMini(); apply();
    }
    new ResizeObserver(measure).observe(view);
    const seedHeat = () => {
      heat = new Float32Array(BUCKETS);
      const unread = marks.find(m => m.kind === 'unread');
      const cut = unread ? (unread.el.offsetTop / Math.max(1, contentH)) * BUCKETS : BUCKETS * .8;
      for (let i = 0; i < BUCKETS; i++) {
        if (i >= cut) continue;
        const n = Math.sin(i * 1.7) * 0.5 + Math.sin(i * 0.43 + 1) * 0.6;
        heat[i] = Math.max(0, 2.2 + 2.4 * n + (i > 18 && i < 26 ? 3 : 0));
      }
    };
    const rubber = d => (1 - 1 / (d * 0.55 / 180 + 1)) * 180;
    const apply = () => {
      let vis = y;
      if (y < 0) vis = -rubber(-y); else if (y > maxY) vis = maxY + rubber(y - maxY);
      content.style.transform = `translateY(${(-vis).toFixed(2)}px)`;
      paintMini();
    };
    function paintMini() {
      if (!mcv || !mcv.w) return;
      const { ctx, w, h: H } = mcv;
      mcv.clear();
      const sc = H / Math.max(1, contentH);
      const acc = FT.col('--accent'), ink = FT.col('--ink'), amb = FT.col('--amber');
      let mx = 4; for (const v of heat) mx = Math.max(mx, v);
      const bh = H / BUCKETS;
      for (let i = 0; i < BUCKETS; i++) if (heat[i] > 0.05) {
        ctx.fillStyle = FT.alpha(acc, 0.1 + 0.55 * Math.min(1, heat[i] / mx));
        ctx.fillRect(3, i * bh, w - 6, bh + 0.5);
      }
      for (const m of marks) {
        const my = (m.el.offsetTop + 8) * sc;
        if (m.kind === 'year') { ctx.fillStyle = FT.alpha(ink, 0.7); ctx.fillRect(w - 11, my, 8, 1.5); }
        else if (m.kind === 'bookmark') { ctx.fillStyle = amb; ctx.beginPath(); ctx.arc(w / 2, my + 4, 3.5, 0, 7); ctx.fill(); }
        else { ctx.fillStyle = acc; ctx.fillRect(0, my, w, 2); ctx.beginPath(); ctx.moveTo(0, my - 4); ctx.lineTo(6, my + 1); ctx.lineTo(0, my + 6); ctx.fill(); }
      }
      const vy = FT.clamp(y, 0, maxY) * sc, vh = Math.max(16, viewH * sc);
      ctx.fillStyle = FT.alpha(ink, 0.06); ctx.strokeStyle = FT.alpha(ink, 0.55); ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.roundRect ? ctx.roundRect(1.5, vy + 1, w - 3, vh - 2, 6) : ctx.rect(1.5, vy + 1, w - 3, vh - 2); ctx.fill(); ctx.stroke();
    }
    FT.onTheme(paintMini);

    /* ---------- motion ---------- */
    let landing = null;
    const loop = FT.loop((dt, now) => {
      if (!anim) return false;
      const u = Math.min(1, (now - anim.t0) / (anim.T * 1000));
      if (anim.spring) { const done = anim.spring.step(dt); y = anim.spring.x; apply(); if (done) { anim = null; return false; } return true; }
      const prev = y;
      y = anim.from + (anim.to - anim.from) * (1 - Math.pow(1 - u, 3));
      velo = (y - prev) / Math.max(dt, 0.001);
      apply();
      if (u >= 1) { const m = anim.mark; anim = null; velo = 0; if (m) land(m); return false; }
      return true;
    });
    const land = m => {
      FT.haptic('light');
      m.el.classList.add('tr-land');
      clearTimeout(landing); landing = setTimeout(() => m.el.classList.remove('tr-land'), 60);
      FT.announce(m.name);
    };
    const glide = (to, v, mark) => {
      const D = Math.abs(to - y);
      if (D < 0.5) { y = to; apply(); if (mark) land(mark); return; }
      const T = FT.clamp(v ? 3 * D / Math.abs(v) : 0.42, 0.28, 1.5);
      anim = { from: y, to, t0: performance.now(), T, mark }; loop.wake();
    };
    const springTo = to => { anim = { spring: FT.spring(y, FT.SPRING.smooth).to(to) }; loop.wake(); };
    const settle = v => {
      if (y < 0 || y > maxY) { springTo(FT.clamp(y, 0, maxY)); FT.intent('pulled past the end: spring back'); return; }
      if (Math.abs(v) < 90) { FT.intent('released slowly: stays where you left it'); return; }
      const natural = FT.clamp(y + FT.project(v), 0, maxY);
      const pull = Math.max(90, Math.abs(natural - y) * 0.3);
      let best = null;
      for (const m of marks) {
        if (Math.sign(m.top - y) !== Math.sign(v) && Math.abs(m.top - y) > 2) continue; // never snap backwards against the fling
        if (Math.abs(m.top - natural) < pull && (!best || Math.abs(m.top - natural) < Math.abs(best.top - natural))) best = m;
      }
      if (best) { glide(best.top, v, best); FT.intent(`fling would stop ${Math.round(Math.abs(best.top - natural))} px from “${best.name}”: settles there`); }
      else { glide(natural, v, null); FT.intent('fling: no landmark nearby, natural stop'); }
    };

    /* ---------- input ---------- */
    let startY = 0;
    FT.drag(view, {
      start() { anim = null; startY = FT.clamp(y, -60, maxY + 60); },
      move(s) { y = startY - s.dy; apply(); },
      end(s) { settle(-s.vy); },
    }, { axis: 'y', slop: 4 });
    let wheelT = null;
    view.addEventListener('wheel', e => {
      e.preventDefault(); anim = null;
      y = FT.clamp(y + (e.deltaMode === 1 ? e.deltaY * 32 : e.deltaY), 0, maxY); apply();
      clearTimeout(wheelT);
      wheelT = setTimeout(() => {
        const near = marks.find(m => Math.abs(m.top - y) < 26);
        if (near && Math.abs(near.top - y) > 1) { glide(near.top, 0, near); FT.intent(`wheel stopped near “${near.name}”: eased onto it`); }
      }, 160);
    }, { passive: false });
    view.addEventListener('keydown', e => {
      const k = e.key;
      let to = null, mark = null;
      if (k === 'ArrowDown') to = y + 48; else if (k === 'ArrowUp') to = y - 48;
      else if (k === 'PageDown' || (k === ' ' && !e.shiftKey)) { mark = marks.find(m => m.top > y + 4); to = mark ? mark.top : maxY; }
      else if (k === 'PageUp' || (k === ' ' && e.shiftKey)) { mark = [...marks].reverse().find(m => m.top < y - 4); to = mark ? mark.top : 0; }
      else if (k === 'Home') to = 0; else if (k === 'End') to = maxY;
      else return;
      e.preventDefault(); anim = null;
      glide(FT.clamp(to, 0, maxY), 0, mark);
      if (mark) FT.intent(`key: jump to “${mark.name}”`);
    });
    // minimap: tap to jump, drag to scrub
    const miniTo = (my, smooth) => {
      const target = FT.clamp(my / mini.clientHeight * contentH - viewH / 2, 0, maxY);
      anim = null;
      if (smooth) glide(target, 0, null); else { y = target; apply(); }
    };
    FT.drag(mini, {
      start(s) { miniTo(s.y, true); FT.haptic('select'); FT.intent('minimap: jump to that region'); },
      move(s) { if (s.moved) miniTo(s.y, false); },
    }, { axis: 'y', slop: 3 });

    /* ---------- read wear: dwell time per region while the reader is still ---------- */
    let visible = false, lastY = 0, timer = null;
    const wear = () => {
      if (!visible || document.hidden) return;
      const still = Math.abs(y - lastY) < 6 && !anim; lastY = y;
      if (!still) return;
      const a = (y + viewH * 0.15) / contentH * BUCKETS, b = (y + viewH * 0.85) / contentH * BUCKETS;
      for (let i = Math.max(0, Math.floor(a)); i < Math.min(BUCKETS, Math.ceil(b)); i++) heat[i] += 0.25;
      paintMini();
    };
    FT.visible(stage, v => { visible = v; clearInterval(timer); if (v) timer = setInterval(wear, 250); });

    measure(); seedHeat(); paintMini();
    return {
      reset() { anim = null; y = 0; seedHeat(); apply(); },
    };
  },
});
