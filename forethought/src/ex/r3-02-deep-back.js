/* III.2 Distance is depth — drag the back chevron: the further you pull, the further back you go. */
FT.exhibit({
  id: 'deep-back', room: 3, num: 2, kind: 'proposal · navigation', replaces: 'tapping back five times',
  title: 'Distance is depth',
  hint: 'Drag the ‹ chevron to the right · tap it to go back one',
  height: 500,
  body: `<p>Tap the back chevron and you go back one screen, as always. Drag it to the right instead and the screen you're on shrinks while every screen behind it fans out above it. Each 60 px of pull reaches one level further back. Release on Inbox and you're in the Inbox, three screens in one move. Pull back toward the start and nothing happens.</p><p>The gesture lives on the chevron, never on the screen edge, so it never fights Android's system back gesture or its predictive-back animation.</p>`,
  why: `Your history is a stack you can't see, so getting back to a known place means counting taps. Showing the whole stack as you pull turns navigation into choosing a destination: you see where you'll land before you let go.`,
  flutter: `
class DeepBackChevron extends StatefulWidget {
  const DeepBackChevron({super.key});
  @override State<DeepBackChevron> createState() => _DeepBackChevronState();
}

class _DeepBackChevronState extends State<DeepBackChevron> {
  double pull = 0;
  int target = 0;                                  // levels back
  late List<Route<dynamic>> stack;                 // filled by a NavigatorObserver

  int _levelsFor(double dx) => ((dx + 30) / 60).floor().clamp(0, stack.length - 1);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.maybePop(context),
    onHorizontalDragStart: (_) => DeepBackOverlay.show(context, stack),    // OverlayEntry: the fan
    onHorizontalDragUpdate: (d) {
      pull = math.max(0, pull + d.delta.dx);
      final t = _levelsFor(pull);
      if (t != target) { target = t; HapticFeedback.selectionClick(); }
      DeepBackOverlay.update(pull: pull, target: target);                // springs, not tweens
    },
    onHorizontalDragEnd: (_) {
      DeepBackOverlay.hide();
      if (target > 0) {
        final dest = stack[stack.length - 1 - target];
        Navigator.popUntil(context, (r) => r == dest);
        HapticFeedback.mediumImpact();
      }
      pull = 0; target = 0;
    },
    child: Semantics(
      button: true, label: 'Back',
      customSemanticsActions: { for (var i = 2; i < stack.length; i++)
        CustomSemanticsAction(label: 'Back $i levels'): () => Navigator.popUntil(context, (r) => r == stack[stack.length - 1 - i]) },
      child: const Icon(Icons.arrow_back_ios_new),
    ),
  );
}`,
  a11y: `The chevron is a normal Back button: <b>Enter</b> goes back one. Press <b>→</b> to open the fan and pick a level, <b>←</b> to step forward again, <b>Enter</b> to jump, <b>Esc</b> to cancel. Each level is announced by name ("Inbox, 3 levels back"). In Flutter the chevron gets one custom semantics action per level.`,
  mount(stage) {
    const { h } = FT;
    const css = h('style', null, `
.db-frame{position:absolute;left:50%;top:18px;transform:translateX(-50%);border-radius:30px;border:1px solid var(--line-2);background:var(--bg-2);overflow:hidden;box-shadow:var(--shadow)}
.db-scr{position:absolute;inset:0;background:var(--surface-2);border-radius:22px;transform-origin:50% 0;will-change:transform;overflow:hidden;box-shadow:0 -1px 0 var(--line),0 12px 30px -16px rgba(0,0,0,.35);transition:box-shadow .2s}
.db-scr.tgt{box-shadow:0 0 0 2px var(--accent),0 16px 40px -14px rgba(0,0,0,.4)}
.db-dim{position:absolute;inset:0;background:var(--ink);opacity:0;pointer-events:none;border-radius:inherit}
.db-head{height:52px;display:flex;align-items:center;gap:4px;padding:0 14px;border-bottom:1px solid var(--line);font-weight:600;font-size:14.5px;white-space:nowrap}
.db-head .chev{width:22px;height:22px;flex:none;color:var(--accent)}
.db-head .lv{margin-left:auto;font-family:var(--f-mono);font-size:10.5px;font-weight:500;color:var(--accent);background:var(--accent-wash);border-radius:999px;padding:3px 8px;opacity:0}
.db-body{padding:12px 14px;display:flex;flex-direction:column;gap:6px;font-size:13px}
.db-item{display:flex;justify-content:space-between;align-items:center;gap:8px;padding:10px 12px;border-radius:12px;background:var(--bg);border:0;text-align:left;font:inherit;color:inherit;cursor:default}
.db-item.go{cursor:pointer;background:var(--accent-wash);color:var(--ink)}
.db-item.go:hover{background:var(--accent-soft)}
.db-item small{color:var(--muted);font-size:11.5px}
.db-item .arr{color:var(--accent);font-weight:600}
.db-big{font-family:var(--f-display);font-size:30px;line-height:1;margin:6px 0 8px}
.db-bub{max-width:82%;padding:8px 11px;border-radius:14px 14px 14px 4px;background:var(--bg);line-height:1.35}
.db-bub.me{align-self:flex-end;border-radius:14px 14px 4px 14px;background:var(--accent);color:var(--accent-ink)}
.db-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:8px}
.db-tile{aspect-ratio:1;border-radius:12px;border:0;padding:8px;display:flex;align-items:flex-end;font:inherit;font-size:11.5px;color:var(--ink);text-align:left}
.db-lake{height:180px;border-radius:14px;position:relative;overflow:hidden;background:linear-gradient(180deg,var(--accent-soft) 0 45%,var(--accent) 45% 100%)}
.db-lake::before{content:"";position:absolute;left:-10%;right:-10%;top:28%;height:30%;background:var(--ok);border-radius:50% 50% 0 0/100% 100% 0 0;opacity:.85}
.db-lake::after{content:"";position:absolute;left:58%;top:60%;width:42px;height:9px;background:var(--surface-2);border-radius:0 0 12px 12px;box-shadow:0 -10px 0 -3px var(--amber)}
.db-handle{position:absolute;width:48px;height:48px;border:0;background:transparent;border-radius:14px;cursor:grab;z-index:5;padding:0}
.db-handle:active{cursor:grabbing}
.db-handle::after{content:"";position:absolute;inset:6px;border-radius:12px;background:var(--accent-wash);opacity:0;transition:opacity .2s}
.db-handle.live::after{opacity:1}
.db-pill{position:absolute;left:50%;bottom:14px;transform:translate(-50%,8px);background:var(--ink);color:var(--bg);font-size:12px;font-weight:600;padding:8px 14px;border-radius:999px;white-space:nowrap;opacity:0;transition:opacity .18s,transform .25s var(--ease);z-index:6;pointer-events:none}
.db-pill.on{opacity:1;transform:translate(-50%,0)}
.db-crumbs{position:absolute;left:0;right:0;bottom:-2px;display:none}
`);
    const chev = '<svg class="chev" viewBox="0 0 24 24" aria-hidden="true"><path d="M15 5l-7 7 7 7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>';
    const SCREENS = [
      { t: 'Post', body: () => [h('div', { class: 'db-big' }, 'Good morning'), item('Inbox', '3 new', 1), item('Drafts', '2'), item('Sent', ''), item('Archive', '1,204')] },
      { t: 'Inbox', body: () => [item('Mira Kovač', 'Lake photos are in', 2), item('Lumen Bank', 'Statement ready'), item('Tomo', 'Saturday?'), item('Studio Kora', 'Invoice 204 paid')] },
      { t: 'Mira Kovač', body: () => [h('div', { class: 'db-bub' }, 'Lake photos are in!'), h('div', { class: 'db-bub' }, 'The one with the boat is my favourite.'), h('div', { class: 'db-bub me' }, 'Send them over'), item('3 attachments', '6.2 MB', 3)] },
      { t: 'Attachments', body: () => [h('div', { class: 'db-grid' },
        tile('photo.jpg', 'linear-gradient(180deg,var(--accent-soft) 0 45%,var(--accent) 45%)', 4),
        tile('route.gpx', 'var(--ok-soft)'), tile('list.txt', 'var(--amber-soft)'))] },
      { t: 'photo.jpg', body: () => [h('div', { class: 'db-lake', role: 'img', 'aria-label': 'A boat on a lake below green hills' }), h('div', { class: 'db-item' }, h('span', null, 'Sat 07:52'), h('small', null, '4.1 MB · 4032 × 3024'))] },
    ];
    function item(a, b, to) {
      const el = h(to ? 'button' : 'div', { class: 'db-item' + (to ? ' go' : ''), type: to ? 'button' : null, 'data-hit': to ? '' : null },
        h('span', null, a), h('small', null, b, to ? h('span', { class: 'arr' }, '  ›') : ''));
      if (to) el.addEventListener('click', () => forward(to));
      return el;
    }
    function tile(name, bg, to) {
      const el = h(to ? 'button' : 'div', { class: 'db-tile', type: to ? 'button' : null, 'data-hit': to ? '' : null, style: { background: bg, cursor: to ? 'pointer' : 'default' } }, h('span', { style: { background: 'var(--surface-2)', padding: '2px 6px', borderRadius: '6px' } }, name));
      if (to) el.addEventListener('click', () => forward(to));
      return el;
    }
    const frame = h('div', { class: 'db-frame' });
    const scr = SCREENS.map((s, i) => {
      const lv = h('span', { class: 'lv' });
      const el = h('div', { class: 'db-scr' },
        h('div', { class: 'db-head' }, i ? h('span', { html: chev, style: { display: 'flex' } }) : null, h('span', null, s.t), lv),
        h('div', { class: 'db-body' }, s.body()), h('div', { class: 'db-dim' }));
      frame.append(el);
      return { el, lv, dim: el.querySelector('.db-dim'), x: FT.spring(0, FT.SPRING.smooth), y: FT.spring(0, FT.SPRING.smooth), s: FT.spring(1, FT.SPRING.smooth), d: FT.spring(0, FT.SPRING.gentle) };
    });
    const handle = h('button', { class: 'db-handle', type: 'button', 'data-hit': '', 'aria-label': 'Back' });
    const pill = h('div', { class: 'db-pill', 'aria-hidden': 'true' });
    frame.append(handle, pill);
    stage.append(css, frame);

    let depth = 4, fan = false, pull = 0, target = 4, fw = 280, fh = 440;
    const layout = () => {
      fw = Math.min(stage.clientWidth - 56, 300); fh = stage.clientHeight - 36;
      frame.style.width = fw + 'px'; frame.style.height = fh + 'px';
      handle.style.left = '4px'; handle.style.top = '2px';
      aim(true);
    };
    const levelsFor = p => FT.clamp(Math.floor((p + 30) / 60), 0, depth);
    // compute every screen's target pose
    const aim = (instant) => {
      const open = fan ? FT.clamp((pull - 6) / 46, 0, 1) : 0;
      scr.forEach((c, i) => {
        let x, y, s, d;
        if (i > depth) { x = fw + 30; y = 0; s = 1; d = 0; }
        else {
          const k = depth - i;
          const restX = k === 0 ? 0 : -fw * 0.28, restS = 1, restY = 0, restD = k === 0 ? 0 : 0.12;
          const fanS = 0.8 - k * 0.025, fanY = 16 + i * 40, fanX = k === 0 ? Math.min(pull * 0.12, 26) : 0;
          const isT = fan && i === target && target !== depth;
          x = FT.lerp(restX, fanX, open); y = FT.lerp(restY, fanY - (isT ? 8 : 0), open); s = FT.lerp(restS, fanS + (isT ? 0.02 : 0), open);
          d = fan ? (isT || target === depth && k === 0 ? 0 : 0.07 * open) : restD;
          c.el.classList.toggle('tgt', isT);
          c.lv.style.opacity = fan && k > 0 ? open : 0;
          c.lv.textContent = k === 1 ? '1 back' : `${k} back`;
        }
        c.x.to(x); c.y.to(y); c.s.to(s); c.d.to(d);
        c.el.inert = i !== depth;
        c.el.setAttribute('aria-hidden', i !== depth);
        if (instant) { c.x.set(x); c.y.set(y); c.s.set(s); c.d.set(d); }
      });
      handle.hidden = depth === 0;
      handle.setAttribute('aria-label', depth ? `Back to ${SCREENS[depth - 1].t}` : 'Back');
      pill.classList.toggle('on', fan && open > 0.5);
      pill.textContent = target === depth ? 'Release to stay here' : `Release: back to ${SCREENS[target].t} · ${depth - target} level${depth - target > 1 ? 's' : ''}`;
      loop.wake();
    };
    const loop = FT.loop(dt => {
      let moving = false;
      for (const c of scr) {
        moving = !c.x.step(dt) | moving; moving = !c.y.step(dt) | moving; moving = !c.s.step(dt) | moving; moving = !c.d.step(dt) | moving;
        c.el.style.transform = `translate(${c.x.x.toFixed(2)}px,${c.y.x.toFixed(2)}px) scale(${c.s.x.toFixed(4)})`;
        c.el.style.visibility = c.x.x > fw + 10 ? 'hidden' : 'visible';
        c.dim.style.opacity = c.d.x.toFixed(3);
      }
      return moving;
    });
    const go = (to, how) => {
      const from = depth;
      depth = to; target = to; fan = false; pull = 0;
      aim();
      handle.classList.remove('live');
      FT.haptic(from - to > 1 ? 'medium' : 'light');
      FT.intent(`${how}: ${SCREENS[from].t} → ${SCREENS[to].t} (${from - to} level${from - to > 1 ? 's' : ''})`);
      FT.announce(`${SCREENS[to].t}`);
    };
    const forward = to => {
      if (fan || to !== depth + 1) return;
      const c = scr[to];
      c.x.set(fw + 30); c.y.set(0); c.s.set(1);
      depth = to; target = to;
      aim(); FT.haptic('select');
      FT.intent(`forward to ${SCREENS[to].t}`);
      FT.announce(SCREENS[to].t);
    };
    const back1 = () => { if (depth > 0) go(depth - 1, 'tap'); };
    const setPull = p => {
      pull = Math.max(0, p);
      const t = depth - levelsFor(pull);
      if (t !== target) { target = t; FT.haptic('select'); FT.intent(t === depth ? 'pull: cancel zone' : `pull ${Math.round(pull)} px → ${SCREENS[t].t}, ${depth - t} back`); if (kb) FT.announce(t === depth ? 'Stay here' : `${SCREENS[t].t}, ${depth - t} level${depth - t > 1 ? 's' : ''} back`); }
      aim();
    };
    let kb = false;
    FT.drag(handle, {
      start() { if (!depth) return false; handle.classList.add('live'); },
      move(s) { if (!s.moved) return; fan = true; setPull(s.dx); },
      tap() { back1(); },
      end(s) {
        handle.classList.remove('live');
        if (!s.moved) return;
        if (s.cancelled || target === depth) { fan = false; pull = 0; target = depth; aim(); FT.intent('released in the cancel zone: stayed'); return; }
        go(target, 'deep back');
      },
    }, { axis: 'x', slop: 5 });
    handle.addEventListener('click', e => { if (e.detail === 0 && !kb) back1(); });
    handle.addEventListener('keydown', e => {
      if (e.key === 'ArrowRight') { e.preventDefault(); kb = true; fan = true; setPull(Math.min(depth, levelsFor(pull) + 1) * 60); }
      else if (e.key === 'ArrowLeft' && kb) { e.preventDefault(); const l = levelsFor(pull) - 1; if (l < 0) return; setPull(l * 60); }
      else if (e.key === 'Escape' && kb) { e.preventDefault(); kb = false; fan = false; pull = 0; target = depth; aim(); FT.announce('Cancelled'); }
      else if (e.key === 'Enter' && kb) { e.preventDefault(); kb = false; if (target !== depth) go(target, 'deep back (keys)'); else { fan = false; pull = 0; aim(); } }
    });
    handle.addEventListener('blur', () => { if (kb) { kb = false; fan = false; pull = 0; target = depth; aim(); } });
    new ResizeObserver(layout).observe(stage);
    layout();
    return { reset() { depth = 4; target = 4; fan = false; pull = 0; aim(true); } };
  },
});
