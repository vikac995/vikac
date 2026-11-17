/* III.1 Changes that dry — every change stays wet (and undoable on its own) for a few seconds, then dries. */
FT.exhibit({
  id: 'wet-ink', room: 3, num: 1, kind: 'proposal · undo', replaces: 'the undo toast',
  title: 'Changes that dry',
  hint: 'Change anything · tap a wet row to wipe it',
  height: 540,
  body: `<p>Every change you make stays wet for a few seconds. It glistens, and a thin ring around its drop shows how dry it is. While it's wet, tap it and that one change is wiped. When it dries, it's set.</p><p>Each change dries on its own clock, so you can wipe the accent colour while keeping the text size you picked after it. Deleting a project stays wet longer, and the project stays on screen as a ghost until then.</p>`,
  why: `An undo toast covers content, disappears while you look elsewhere and only undoes the last thing. Wetness puts the undo exactly where the change happened, shows how long it lasts, and lets several changes be undone in any order.`,
  flutter: `
class WetChange<T> {
  WetChange(this.previous, {required this.dryIn});
  final T previous;
  final Duration dryIn;                      // 5 s, or 9 s for destructive changes
  final Stopwatch clock = Stopwatch()..start();
  double get wetness => (1 - clock.elapsedMilliseconds / dryIn.inMilliseconds).clamp(0, 1);
}

class WetBoundary extends StatefulWidget {
  const WetBoundary({super.key, required this.change, required this.onWipe, required this.onDry, required this.child});
  final WetChange? change; final VoidCallback onWipe, onDry; final Widget child;
  @override State<WetBoundary> createState() => _WetBoundaryState();
}

class _WetBoundaryState extends State<WetBoundary> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) {
    final c = widget.change;
    if (c == null) return;
    if (c.wetness == 0) { HapticFeedback.selectionClick(); widget.onDry(); }
    setState(() {});
  });
  @override void didUpdateWidget(WetBoundary old) {
    super.didUpdateWidget(old);
    widget.change != null ? (_ticker.isActive ? null : _ticker.start()) : _ticker.stop();
  }
  @override void dispose() { _ticker.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final w = widget.change?.wetness ?? 0;
    return Semantics(
      customSemanticsActions: { if (w > 0) const CustomSemanticsAction(label: 'Wipe change'): widget.onWipe },
      child: GestureDetector(
        onTap: w > 0 ? widget.onWipe : null,
        child: CustomPaint(foregroundPainter: SheenPainter(wetness: w), child: widget.child),
      ),
    );
  }
}
// SheenPainter: a FragmentShader specular band sliding across, opacity = wetness.`,
  a11y: `Every control is a normal button or switch. While a change is wet, its row announces "wet, can be wiped". Focus the control and press <b>Backspace</b> or <b>Delete</b> to wipe that change, or use the drop button beside it. Drying is announced with the final value.`,
  mount(stage) {
    const { h } = FT;
    const css = h('style', null, `
.wi{position:absolute;inset:16px;display:flex;flex-direction:column;gap:10px}
.wi>*{flex-shrink:0}
.wi-top{display:flex;justify-content:space-between;align-items:center;padding:0 4px}
.wi-top b{font-size:15px}
.wi-legend{display:flex;align-items:center;gap:6px;font-size:11.5px;color:var(--muted)}
.wi-legend i{width:10px;height:10px;border-radius:50%;background:var(--amber);box-shadow:0 0 0 3px var(--amber-soft)}
.wi-card{padding:4px 0;overflow:hidden}
.wi-row{position:relative;display:grid;grid-template-columns:minmax(0,1fr) auto 34px;align-items:center;gap:8px;padding:9px 8px 9px 14px;border-top:1px solid var(--line);isolation:isolate;transition:height .35s var(--ease),opacity .35s,padding .35s}
.wi-row:first-child{border-top:0}
.wi-row::before{content:"";position:absolute;inset:0;z-index:-1;background:color-mix(in srgb,var(--amber) 16%,transparent);opacity:var(--w,0)}
.wi-row::after{content:"";position:absolute;inset:0;z-index:-1;opacity:calc(var(--w,0) * .9);pointer-events:none;
  background:linear-gradient(105deg,transparent 30%,color-mix(in srgb,var(--surface-2) 75%,transparent) 45%,transparent 55%,transparent 70%,color-mix(in srgb,var(--surface-2) 40%,transparent) 76%,transparent 82%);
  background-size:260% 100%;animation:wi-sheen 2.4s linear infinite}
@keyframes wi-sheen{from{background-position:120% 0}to{background-position:-60% 0}}
.wi-lab{font-size:13.5px;font-weight:500;min-width:0}
.wi-lab small{display:block;font-size:11px;color:var(--muted);font-weight:400;font-family:var(--f-mono)}
.wi-row.wet .wi-lab small{color:var(--amber)}
.wi-sw{display:flex;gap:6px}
.wi-sw button{width:24px;height:24px;border-radius:50%;border:0;cursor:pointer;position:relative;padding:0}
.wi-sw button::after{content:"";position:absolute;inset:-4px;border-radius:50%;border:2px solid transparent;transition:border-color .2s}
.wi-sw button[aria-checked="true"]::after{border-color:var(--ink)}
.wi-step{display:flex;align-items:center;gap:2px;border:1px solid var(--line-2);border-radius:999px;padding:2px}
.wi-step button{width:30px;height:28px;border:0;background:none;border-radius:999px;cursor:pointer;font-size:16px;line-height:1}
.wi-step button:hover{background:var(--bg-2)}
.wi-step span{min-width:44px;text-align:center;font-size:12.5px}
.wi-switch{width:46px;height:28px;border-radius:999px;border:0;background:var(--line-2);position:relative;cursor:pointer;transition:background .25s}
.wi-switch::after{content:"";position:absolute;top:3px;left:3px;width:22px;height:22px;border-radius:50%;background:var(--surface-2);box-shadow:0 1px 3px rgba(0,0,0,.25);transition:transform .3s var(--ease)}
.wi-switch[aria-checked="true"]{background:var(--wi-acc)}
.wi-switch[aria-checked="true"]::after{transform:translateX(18px)}
.wi-del{height:28px;padding:0 11px;border-radius:999px;border:1px solid var(--line-2);background:none;cursor:pointer;font-size:12px;color:var(--hot)}
.wi-row.gone .wi-lab{text-decoration:line-through;text-decoration-color:var(--hot);opacity:.55}
.wi-row.gone .wi-del{color:var(--ink);border-color:var(--amber)}
.wi-drop{width:30px;height:30px;border:0;background:none;padding:0;cursor:pointer;display:grid;place-items:center;border-radius:50%;opacity:0;transition:opacity .25s}
.wi-row.wet .wi-drop,.wi-drop.set{opacity:1}
.wi-drop svg{overflow:visible}
.wi-drop .ring{fill:none;stroke:var(--amber);stroke-width:2;stroke-linecap:round;transform:rotate(-90deg);transform-origin:15px 15px}
.wi-drop .track{fill:none;stroke:var(--line-2);stroke-width:2}
.wi-drop .dot{fill:var(--amber)}
.wi-drop.set .ring,.wi-drop.set .track,.wi-drop.set .dot{display:none}
.wi-drop .tick{fill:none;stroke:var(--ok);stroke-width:2;stroke-linecap:round;stroke-linejoin:round;display:none}
.wi-drop.set .tick{display:block}
.wi-prev{padding:12px 14px;display:flex;flex-direction:column;gap:6px}
.wi-bub{align-self:flex-start;max-width:88%;padding:8px 12px;border-radius:16px 16px 16px 4px;background:var(--wi-acc);color:var(--accent-ink);line-height:1.35;transition:background .3s,font-size .3s var(--ease)}
.wi-meta{font-size:11px;color:var(--muted);font-family:var(--f-mono)}
.wi-proj-h{padding:8px 14px 2px;font-size:10.5px}
`);
    const ACCENTS = [['Ultramarine', '--accent'], ['Fern', '--ok'], ['Amber', '--amber'], ['Coral', '--hot'], ['Graphite', '--ink-2']];
    const state = { accent: 0, size: 15, receipts: true, atlas: true, borealis: true };
    const init = { ...state };
    const wet = new Map();
    const rows = {};
    const DUR = { accent: 5000, size: 5000, receipts: 5000, atlas: 9000, borealis: 9000 };
    const NAMES = { accent: 'Accent colour', size: 'Text size', receipts: 'Read receipts', atlas: 'Project Atlas', borealis: 'Project Borealis' };
    const describe = (k, v) => k === 'accent' ? ACCENTS[v][0] : k === 'size' ? `${v} px` : k === 'receipts' ? (v ? 'on' : 'off') : (v ? 'kept' : 'deleted');

    const drop = key => {
      const b = h('button', { class: 'wi-drop', type: 'button', 'data-hit': '', 'aria-label': `Wipe ${NAMES[key]} change`, tabindex: '-1' });
      b.innerHTML = `<svg width="30" height="30" viewBox="0 0 30 30" aria-hidden="true"><circle class="track" cx="15" cy="15" r="11"/><circle class="ring" cx="15" cy="15" r="11" stroke-dasharray="69.1" stroke-dashoffset="0"/><path class="dot" d="M15 9.5c2.4 3 3.6 5 3.6 6.6a3.6 3.6 0 0 1-7.2 0c0-1.6 1.2-3.6 3.6-6.6z"/><path class="tick" d="M10 15.5l3.4 3.4L20.5 11.5"/></svg>`;
      b.addEventListener('click', () => wipe(key));
      return b;
    };
    const row = (key, label, control) => {
      const small = h('small', null, '');
      const r = h('div', { class: 'wi-row', 'data-key': key }, h('div', { class: 'wi-lab' }, label, small), control, drop(key));
      r.small = small;
      r.addEventListener('keydown', e => { if ((e.key === 'Backspace' || e.key === 'Delete') && wet.has(key)) { e.preventDefault(); wipe(key); } });
      rows[key] = r;
      return r;
    };

    const sw = h('div', { class: 'wi-sw', role: 'radiogroup', 'aria-label': 'Accent colour' });
    ACCENTS.forEach(([name, tok], i) => {
      const b = h('button', { type: 'button', role: 'radio', 'aria-label': name, 'data-hit': '', style: { background: `var(${tok})` } });
      b.addEventListener('click', () => change('accent', i));
      sw.append(b);
    });
    const sizeVal = h('span', { class: 'ft-mono' });
    const step = h('div', { class: 'wi-step' },
      h('button', { type: 'button', 'aria-label': 'Smaller text', 'data-hit': '', onclick: () => change('size', Math.max(12, state.size - 1)) }, '−'),
      sizeVal,
      h('button', { type: 'button', 'aria-label': 'Larger text', 'data-hit': '', onclick: () => change('size', Math.min(20, state.size + 1)) }, '+'));
    const swit = h('button', { class: 'wi-switch', type: 'button', role: 'switch', 'aria-label': 'Show read receipts', 'data-hit': '', onclick: () => change('receipts', !state.receipts) });
    const del = key => h('button', { class: 'wi-del', type: 'button', 'data-hit': '', onclick: () => state[key] ? change(key, false) : wipe(key) });

    const bub = h('div', { class: 'wi-bub' }, 'Lake on Saturday? I’ll bring coffee.');
    const meta = h('div', { class: 'wi-meta' });
    const settings = h('div', { class: 'ft-card wi-card' },
      row('accent', 'Accent colour', sw),
      row('size', 'Text size', step),
      row('receipts', 'Read receipts', swit));
    const preview = h('div', { class: 'ft-card wi-prev' }, bub, meta);
    const projects = h('div', { class: 'ft-card wi-card' },
      h('div', { class: 'ft-label wi-proj-h' }, 'Projects'),
      row('atlas', 'Atlas', del('atlas')),
      row('borealis', 'Borealis', del('borealis')));
    const root = h('div', { class: 'wi' },
      h('div', { class: 'wi-top' }, h('b', null, 'Settings'), h('span', { class: 'wi-legend' }, h('i'), 'wet = still undoable')),
      settings, preview, projects);
    stage.append(css, root);

    const render = () => {
      const tok = ACCENTS[state.accent][1];
      root.style.setProperty('--wi-acc', `var(${tok})`);
      [...sw.children].forEach((b, i) => { b.setAttribute('aria-checked', i === state.accent); b.tabIndex = i === state.accent ? 0 : -1; });
      sizeVal.textContent = `${state.size} px`;
      swit.setAttribute('aria-checked', state.receipts);
      bub.style.fontSize = state.size + 'px';
      bub.style.color = state.accent === 2 ? 'var(--code-bg)' : state.accent === 4 ? 'var(--bg)' : 'var(--accent-ink)';
      meta.textContent = state.receipts ? 'Delivered · Read 09:42' : 'Delivered';
      for (const k of ['atlas', 'borealis']) {
        const r = rows[k], b = r.querySelector('.wi-del');
        r.classList.toggle('gone', !state[k]);
        b.textContent = state[k] ? 'Delete' : 'Keep';
        b.setAttribute('aria-label', state[k] ? `Delete project ${NAMES[k].split(' ')[1]}` : `Keep project ${NAMES[k].split(' ')[1]}`);
      }
      rows.atlas.small.textContent = rows.atlas.small.textContent || '14 files · 2.1 GB';
      rows.borealis.small.textContent = rows.borealis.small.textContent || '3 files · 80 MB';
    };

    const change = (key, next) => {
      const w = wet.get(key);
      if (w && w.prev === next) { state[key] = next; clearWet(key); render(); FT.haptic('light'); FT.intent(`${NAMES[key]} back to ${describe(key, next)}: nothing left to dry`); return; }
      if (state[key] === next) return;
      if (w) w.t0 = performance.now();
      else wet.set(key, { prev: state[key], t0: performance.now(), dur: DUR[key] });
      state[key] = next;
      rows[key].classList.add('wet');
      rows[key].querySelector('.wi-drop').tabIndex = 0;
      rows[key].querySelector('.wi-drop').classList.remove('set');
      render();
      FT.haptic(next === false ? 'medium' : 'select');
      FT.intent(`${NAMES[key]} → ${describe(key, next)} (wet for ${DUR[key] / 1000} s)`);
      FT.announce(`${NAMES[key]} ${describe(key, next)}. Wet, can be wiped for ${DUR[key] / 1000} seconds.`);
      loop.wake();
    };
    const clearWet = key => {
      wet.delete(key);
      const r = rows[key];
      r.classList.remove('wet'); r.style.setProperty('--w', 0);
      r.querySelector('.wi-drop').tabIndex = -1;
      if (key === 'atlas' || key === 'borealis') r.small.textContent = key === 'atlas' ? '14 files · 2.1 GB' : '3 files · 80 MB';
      else r.small.textContent = '';
    };
    const wipe = key => {
      const w = wet.get(key);
      if (!w) return;
      state[key] = w.prev;
      clearWet(key); render();
      FT.haptic('light');
      FT.intent(`wiped: ${NAMES[key]} back to ${describe(key, w.prev)}`);
      FT.announce(`Wiped. ${NAMES[key]} back to ${describe(key, w.prev)}.`);
    };
    const dry = key => {
      const r = rows[key];
      clearWet(key);
      const d = r.querySelector('.wi-drop');
      d.classList.add('set');
      setTimeout(() => d.classList.remove('set'), 1100);
      FT.haptic('select');
      FT.intent(`dried: ${NAMES[key]} ${describe(key, state[key])} is set`);
      FT.announce(`${NAMES[key]} set to ${describe(key, state[key])}.`);
      if (state[key] === false) {
        r.style.height = r.offsetHeight + 'px';
        requestAnimationFrame(() => { r.style.height = '0px'; r.style.paddingBlock = '0'; r.style.opacity = '0'; r.style.borderTopWidth = '0'; });
      }
    };
    const loop = FT.loop(() => {
      const now = performance.now();
      for (const [key, w] of wet) {
        const k = FT.clamp((now - w.t0) / w.dur, 0, 1);
        const r = rows[key];
        r.style.setProperty('--w', (1 - k * k).toFixed(3));
        r.querySelector('.ring').setAttribute('stroke-dashoffset', (69.1 * k).toFixed(2));
        r.small.textContent = `wet · dries in ${Math.ceil((1 - k) * w.dur / 1000)} s`;
        if (k >= 1) dry(key);
      }
      return wet.size > 0;
    });
    render();
    return {
      reset() {
        for (const k of [...wet.keys()]) clearWet(k);
        Object.assign(state, init);
        for (const k of ['atlas', 'borealis']) { const r = rows[k]; r.style.height = ''; r.style.paddingBlock = ''; r.style.opacity = ''; r.style.borderTopWidth = ''; }
        render();
      },
    };
  },
});
