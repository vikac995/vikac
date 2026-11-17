/* II.6 Dwell to dive — spring-loaded folders for touch: hover while dragging and the folder opens under you. */
FT.exhibit({
  id: 'dwell-dive', room: 2, num: 6, kind: 'drag and drop', replaces: 'the "Move to…" dialog',
  title: 'Dwell to dive',
  hint: 'Drag a photo onto a folder and wait · drop anywhere to move it',
  height: 480,
  body: `<p>Drag a photo over a folder and keep it there. A ring fills, the folder springs open, and you are inside it with the photo still under your finger. Keep diving as deep as you like. To climb back out, hold the photo over a name in the path at the top.</p><p>Drop it on a folder to file it there, or on empty space to file it where you are. Lift your finger anywhere you didn't mean and the photo flies back home.</p>`,
  why: `Moving a file on a phone usually means select, menu, "Move to…", then a tree of folders in a dialog. Dwelling lets the drag itself navigate, so one continuous gesture carries the item exactly where it belongs.`,
  source: `spring-loaded folders, introduced in Mac OS 8 (1997) and still in the Finder today: hold a dragged item over a folder and it opens.`,
  flutter: `
/// A folder tile that opens itself if a drag hovers on it long enough.
class SpringLoadedFolder extends StatefulWidget {
  const SpringLoadedFolder({super.key, required this.folder, required this.onOpen, required this.onDrop});
  final Folder folder;
  final VoidCallback onOpen;
  final void Function(Photo) onDrop;
  @override State<SpringLoadedFolder> createState() => _SpringLoadedFolderState();
}

class _SpringLoadedFolderState extends State<SpringLoadedFolder> with SingleTickerProviderStateMixin {
  late final dwell = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
    ..addStatusListener((s) { if (s == AnimationStatus.completed) { HapticFeedback.mediumImpact(); widget.onOpen(); } });

  @override
  Widget build(BuildContext context) => DragTarget<Photo>(
    onWillAcceptWithDetails: (_) { dwell.forward(from: 0); return true; },
    onLeave: (_) => dwell.reverse(),
    onAcceptWithDetails: (d) { dwell.reset(); HapticFeedback.lightImpact(); widget.onDrop(d.data); },
    builder: (context, candidates, _) => Stack(alignment: Alignment.center, children: [
      FolderTile(folder: widget.folder, highlighted: candidates.isNotEmpty),
      AnimatedBuilder(animation: dwell, builder: (_, __) =>
          CircularProgressIndicator(value: dwell.value, strokeWidth: 3)),
    ]),
  );
}

// The photo is a LongPressDraggable<Photo> whose feedback lives in the root Overlay,
// so it survives the grid being replaced when a folder opens mid-drag.`,
  a11y: `Folders and path names are buttons. A focused photo opens a <b>Move to…</b> menu with <b>Enter</b>: every folder is listed with its depth, <b>Up/Down</b> choose, <b>Enter</b> moves, <b>Esc</b> closes. Each move is announced with the new location.`,
  mount(stage) {
    const { h } = FT;
    stage.append(h('style', { text: `
      .dw-root{position:absolute;inset:0;padding:14px 16px 12px;display:flex;flex-direction:column;gap:10px;
        --p1:#F5B06B;--p2:#F07C5A;--p3:#7FB6E8;--p4:#2F5D8A;--p5:#9CCF8E;--p6:#3E7A54;--p7:#F2D7A6;--p8:#5E4B8B;--p9:#E8E3D9}
      .dw-top{display:flex;align-items:center;gap:4px;min-height:34px;flex-wrap:wrap}
      .dw-crumb{position:relative;height:32px;padding:0 10px;border-radius:9px;border:1px solid transparent;background:transparent;font-size:13.5px;font-weight:500;color:var(--muted);cursor:pointer;overflow:hidden}
      .dw-crumb:last-of-type{color:var(--ink);font-weight:600}
      .dw-crumb::after{content:"";position:absolute;left:0;bottom:0;height:3px;width:calc(var(--d,0) * 100%);background:var(--accent)}
      .dw-crumb.hot{border-color:var(--accent);background:var(--accent-wash);color:var(--ink)}
      .dw-sep{color:var(--faint);font-size:12px}
      .dw-wrap{position:relative;flex:1;min-height:0}
      .dw-grid{position:absolute;inset:0;display:grid;grid-template-columns:repeat(3,minmax(0,1fr));grid-auto-rows:max-content;gap:12px 10px;align-content:start;transform-origin:50% 30%}
      .dw-item{position:relative;display:flex;flex-direction:column;align-items:center;gap:5px;padding:6px 4px;border-radius:12px;border:1px solid transparent;background:transparent;cursor:pointer;font:inherit;color:inherit;min-width:0}
      .dw-item:hover{background:var(--accent-wash)}
      .dw-name{font-size:12px;max-width:100%;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
      .dw-sub{font-family:var(--f-mono);font-size:10px;color:var(--muted);margin-top:-4px}
      .dw-icon{position:relative;width:76px;height:58px}
      .dw-fold{position:absolute;inset:6px 4px 0;border-radius:4px 9px 9px 9px;background:var(--accent-soft);border:1.5px solid color-mix(in srgb,var(--accent) 40%,transparent);transition:transform .25s}
      .dw-fold::before{content:"";position:absolute;left:-1.5px;top:-8px;width:32px;height:9px;border-radius:5px 5px 0 0;background:inherit;border:inherit;border-bottom:0}
      .dw-folder.hot .dw-fold{transform:translateY(-3px) scale(1.06);background:color-mix(in srgb,var(--accent) 30%,var(--accent-soft))}
      .dw-folder.hot{background:var(--accent-wash);border-color:color-mix(in srgb,var(--accent) 50%,transparent)}
      .dw-badge{position:absolute;right:-4px;top:-2px;min-width:20px;height:20px;padding:0 5px;border-radius:10px;background:var(--ink);color:var(--bg);font-family:var(--f-mono);font-size:10.5px;display:grid;place-items:center}
      .dw-badge.bump{animation:dwbump .45s cubic-bezier(.3,1.7,.5,1)}
      @keyframes dwbump{0%{transform:scale(1)}40%{transform:scale(1.45)}100%{transform:scale(1)}}
      .dw-ring{position:absolute;left:50%;top:50%;width:46px;height:46px;margin:-20px 0 0 -23px;pointer-events:none;opacity:0;transition:opacity .15s}
      .dw-ring circle{fill:none;stroke-width:3.5;stroke-linecap:round}
      .dw-ring .bg{stroke:color-mix(in srgb,var(--surface-2) 70%,transparent)}
      .dw-ring .fg{stroke:var(--accent);stroke-dasharray:126;stroke-dashoffset:126}
      .dw-folder.hot .dw-ring{opacity:1}
      .dw-photo{touch-action:none}
      .dw-photo .dw-icon{width:70px;height:58px;border-radius:9px;overflow:hidden;box-shadow:0 1px 2px rgba(0,0,0,.15)}
      .dw-photo.src .dw-icon{opacity:.25;outline:1.5px dashed var(--line-2);outline-offset:2px}
      .dw-icon svg{display:block;width:100%;height:100%}
      .dw-empty{grid-column:1 / -1;text-align:center;color:var(--muted);font-size:13px;padding:40px 10px;border:1.5px dashed var(--line-2);border-radius:14px}
      .dw-ghost{position:absolute;left:0;top:0;width:70px;height:58px;border-radius:9px;overflow:hidden;pointer-events:none;z-index:6;box-shadow:0 14px 30px -8px rgba(0,0,0,.45);will-change:transform}
      .dw-status{font-size:12.5px;color:var(--muted);min-height:18px;margin:0;padding:0 2px}
      .dw-status b{color:var(--ink);font-weight:600}
      .dw-menu{position:absolute;z-index:7;min-width:180px;padding:6px;background:var(--surface-2);border:1px solid var(--line);border-radius:12px;box-shadow:var(--shadow)}
      .dw-menu button{display:block;width:100%;text-align:left;height:34px;border:0;background:transparent;border-radius:8px;font-size:13px;cursor:pointer;padding:0 10px}
      .dw-menu button:hover,.dw-menu button:focus-visible{background:var(--accent-wash)}
      .dw-menu .ft-label{display:block;padding:4px 10px 6px}
    ` }));
    const INIT = () => ({
      root: { name: 'Files', parent: null, kids: ['photos', 'docs'], photos: [] },
      photos: { name: 'Photos', parent: 'root', kids: ['trips', 'family', 'shots'], photos: ['p1', 'p2', 'p3', 'p4'] },
      trips: { name: 'Trips', parent: 'photos', kids: ['lake', 'alps'], photos: ['p5'] },
      lake: { name: 'Lake 2026', parent: 'trips', kids: [], photos: ['p6', 'p7'] },
      alps: { name: 'Alps', parent: 'trips', kids: [], photos: ['p8'] },
      family: { name: 'Family', parent: 'photos', kids: [], photos: ['p9', 'p10', 'p11'] },
      shots: { name: 'Screenshots', parent: 'photos', kids: [], photos: ['p12'] },
      docs: { name: 'Documents', parent: 'root', kids: ['taxes'], photos: [] },
      taxes: { name: 'Taxes', parent: 'docs', kids: [], photos: [] },
    });
    let F = INIT(), cur = 'photos';
    const PH = {};
    for (let i = 1; i <= 13; i++) {
      const pal = [['--p3', '--p7', '--p6'], ['--p1', '--p2', '--p8'], ['--p3', '--p9', '--p4'], ['--p7', '--p1', '--p6'], ['--p5', '--p3', '--p6'], ['--p2', '--p1', '--p4']][i % 6];
      const sun = 22 + (i * 37) % 56, ridge = 48 + (i * 13) % 18;
      PH['p' + i] = {
        name: `IMG_${2030 + i * 7}`,
        svg: `<svg viewBox="0 0 100 80" aria-hidden="true"><defs><linearGradient id="dwg${i}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="var(${pal[0]})"/><stop offset="1" stop-color="var(${pal[1]})"/></linearGradient></defs><rect width="100" height="80" fill="url(#dwg${i})"/><circle cx="${sun}" cy="${24 + i % 3 * 5}" r="${8 + i % 4}" fill="var(--p9)" opacity=".9"/><path d="M0 ${ridge + 8} L${18 + i % 5 * 4} ${ridge - 8} L${40} ${ridge + 2} L${62 + i % 3 * 5} ${ridge - 16} L100 ${ridge + 4} L100 80 L0 80Z" fill="var(${pal[2]})"/><rect y="${ridge + 14}" width="100" height="40" fill="var(${pal[2]})" opacity=".6"/></svg>`,
      };
    }
    const count = id => F[id].kids.length + F[id].photos.length;
    const pathTo = id => { const p = []; while (id) { p.unshift(id); id = F[id].parent; } return p; };
    const folderOf = pid => Object.keys(F).find(k => F[k].photos.includes(pid));

    const root = h('div', { class: 'dw-root' });
    const top = h('nav', { class: 'dw-top', 'aria-label': 'Folder path' });
    const wrap = h('div', { class: 'dw-wrap' });
    const status = h('p', { class: 'dw-status', role: 'status' });
    root.append(top, wrap, status);
    stage.append(root);
    let grid = null;
    const gridS = FT.spring(1, FT.SPRING.smooth);
    let gridFrom = 1;

    const ringSvg = () => '<svg class="dw-ring" viewBox="0 0 46 46"><circle class="bg" cx="23" cy="23" r="20"/><circle class="fg" cx="23" cy="23" r="20" transform="rotate(-90 23 23)"/></svg>';
    const render = (dir) => {
      top.replaceChildren();
      pathTo(cur).forEach((id, i, arr) => {
        const b = h('button', { type: 'button', class: 'dw-crumb', 'data-drop': id, 'data-hit': '', 'aria-current': i === arr.length - 1 ? 'location' : null }, F[id].name);
        b.addEventListener('click', () => { if (id !== cur) go(id, 'out'); });
        top.append(b);
        if (i < arr.length - 1) top.append(h('span', { class: 'dw-sep', 'aria-hidden': 'true' }, '›'));
      });
      const g = h('div', { class: 'dw-grid', role: 'list', 'aria-label': `${F[cur].name}, ${count(cur)} items` });
      for (const k of F[cur].kids) {
        const n = count(k);
        const b = h('button', { type: 'button', class: 'dw-item dw-folder', 'data-drop': k, 'data-id': k, 'data-hit': '', role: 'listitem', 'aria-label': `Folder ${F[k].name}, ${n} items` },
          h('span', { class: 'dw-icon', html: `<span class="dw-fold"></span>${ringSvg()}` }, h('span', { class: 'dw-badge' }, String(n))),
          h('span', { class: 'dw-name' }, F[k].name));
        b.addEventListener('click', () => go(k, 'in'));
        g.append(b);
      }
      for (const p of F[cur].photos) {
        const b = h('button', { type: 'button', class: 'dw-item dw-photo' + (drag && drag.lifted && drag.pid === p ? ' src' : ''), 'data-pid': p, 'data-hit': '', role: 'listitem', 'aria-label': `Photo ${PH[p].name}. Enter to move it`, 'aria-haspopup': 'menu' },
          h('span', { class: 'dw-icon', html: PH[p].svg }), h('span', { class: 'dw-name' }, PH[p].name));
        b.addEventListener('keydown', e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openMenu(p, b); } });
        g.append(b);
      }
      if (!F[cur].kids.length && !F[cur].photos.length) g.append(h('div', { class: 'dw-empty' }, 'Empty folder. Drop a photo here.'));
      if (grid) grid.remove();
      grid = g; wrap.append(g);
      if (dir) { gridFrom = dir === 'in' ? 0.86 : 1.12; gridS.set(0).to(1); loop.wake(); }
    };
    const go = (id, dir, quiet) => {
      if (id === cur) return;
      cur = id; render(dir || 'in');
      if (!quiet) { FT.haptic('light'); FT.announce(`Opened ${F[id].name}`); }
    };

    /* ---------- drag ---------- */
    let drag = null;
    const ghostS = { x: FT.spring(0, FT.SPRING.snappy), y: FT.spring(0, FT.SPRING.snappy), s: FT.spring(1, FT.SPRING.smooth), r: FT.spring(0, FT.SPRING.smooth) };
    let ghost = null, flyBack = null;
    const local = e => { const r = stage.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
    const DWELL = 600;
    const setHot = (el) => {
      if (drag.hot === el) return;
      if (drag.hot) { drag.hot.classList.remove('hot'); drag.hot.style.removeProperty('--d'); const fg = drag.hot.querySelector('.fg'); if (fg) fg.style.strokeDashoffset = '126'; }
      drag.hot = el; drag.hotT = performance.now();
      if (el) { el.classList.add('hot'); FT.haptic('select'); }
    };
    const loop = FT.loop((dt, now) => {
      let moving = !gridS.step(dt);
      if (grid) { const k = gridS.x; grid.style.transform = k < 0.999 ? `scale(${FT.lerp(gridFrom, 1, k)})` : ''; grid.style.opacity = String(FT.clamp(k * 1.4, 0, 1)); }
      if (ghost) {
        for (const k in ghostS) if (!ghostS[k].step(dt)) moving = true;
        ghost.style.transform = `translate(${ghostS.x.x - 35}px,${ghostS.y.x - 29}px) rotate(${ghostS.r.x}deg) scale(${ghostS.s.x})`;
        ghost.style.opacity = String(FT.clamp((ghostS.s.x - 0.15) / 0.5, 0, 1));
        if (flyBack && moving === false) { ghost.remove(); ghost = null; flyBack(); flyBack = null; }
        else if (flyBack) moving = true;
      }
      if (drag && drag.lifted && drag.hot) {
        const id = drag.hot.dataset.drop, k = Math.min(1, (now - drag.hotT) / DWELL);
        const isCrumb = drag.hot.classList.contains('dw-crumb');
        if (id !== cur) {
          if (isCrumb) drag.hot.style.setProperty('--d', k); else { const fg = drag.hot.querySelector('.fg'); if (fg) fg.style.strokeDashoffset = String(126 * (1 - k)); }
          if (k >= 1) {
            const goingUp = pathTo(cur).includes(id);
            setHot(null);
            go(id, goingUp ? 'out' : 'in', true);
            FT.haptic('medium'); FT.intent(`dwelled ${DWELL} ms: “${F[id].name}” sprang open`);
            FT.announce(`Opened ${F[id].name}`);
            drag.cool = now;
          }
        }
        moving = true;
      }
      if (drag && drag.lifted) moving = true;
      return moving;
    });
    const hitTest = e => {
      const el = document.elementFromPoint(e.clientX, e.clientY);
      if (!el || !stage.contains(el)) return { el: null, outside: true };
      const d = el.closest('[data-drop]');
      return { el: d, outside: false };
    };
    FT.drag(wrap, {
      filter: e => !!e.target.closest('.dw-photo'),
      start(s, e) {
        const b = e.target.closest('.dw-photo');
        drag = { pid: b.dataset.pid, from: cur, src: b, lifted: false, hot: null, hotT: 0 };
      },
      move(s, e) {
        if (!drag) return;
        const [x, y] = local(e);
        if (!drag.lifted && s.moved) {
          drag.lifted = true;
          closeMenu();
          const r = drag.src.querySelector('.dw-icon').getBoundingClientRect(), sr = stage.getBoundingClientRect();
          ghost = h('div', { class: 'dw-ghost', html: PH[drag.pid].svg });
          stage.append(ghost);
          ghostS.x.set(r.left - sr.left + 35); ghostS.y.set(r.top - sr.top + 29); ghostS.s.set(1).to(1.08); ghostS.r.set(0);
          drag.src.classList.add('src');
          FT.haptic('light'); FT.intent('drag: photo lifted');
        }
        if (!drag.lifted) return;
        ghostS.x.to(x + 22); ghostS.y.to(y - 46); ghostS.r.to(FT.clamp(s.vx / 90, -9, 9));
        const { el } = hitTest(e);
        const target = el && el.dataset.drop !== undefined && el.dataset.drop !== cur ? el : null;
        if (!drag.cool || performance.now() - drag.cool > 250) setHot(target);
        ghostS.s.to(drag.hot ? 0.86 : 1.08);
        loop.wake();
      },
      end(s, e) {
        const d = drag; drag = null;
        if (!d || !d.lifted) return;
        const hot = d.hot;
        if (hot) { hot.classList.remove('hot'); hot.style.removeProperty('--d'); }
        const { outside } = hitTest(e);
        let dest = null;
        if (!s.cancelled && !outside) dest = hot ? hot.dataset.drop : cur;
        if (dest && dest !== d.from) {
          F[d.from].photos.splice(F[d.from].photos.indexOf(d.pid), 1);
          F[dest].photos.push(d.pid);
          const tile = grid.querySelector(`[data-id="${dest}"]`);
          const sr = stage.getBoundingClientRect();
          const name = pathTo(dest).map(k => F[k].name).join(' › ');
          if (tile) {
            const r = tile.querySelector('.dw-icon').getBoundingClientRect();
            ghostS.x.to(r.left - sr.left + r.width / 2); ghostS.y.to(r.top - sr.top + r.height / 2); ghostS.s.to(0.2); ghostS.r.to(0);
            flyBack = () => { render(); const bd = grid.querySelector(`[data-id="${dest}"] .dw-badge`); if (bd) { bd.classList.remove('bump'); void bd.offsetWidth; bd.classList.add('bump'); } };
          } else { ghost.remove(); ghost = null; render(); }
          status.innerHTML = `Moved <b>${PH[d.pid].name}</b> to ${name}`;
          FT.haptic('success'); FT.intent(`dropped: moved to ${F[dest].name}`); FT.announce(`Moved ${PH[d.pid].name} to ${name}`);
        } else {
          // fly home: back to its slot if visible, otherwise shrink away where it is
          if (d.from === cur && d.src.isConnected) {
            const r = d.src.querySelector('.dw-icon').getBoundingClientRect(), sr = stage.getBoundingClientRect();
            ghostS.x.to(r.left - sr.left + 35); ghostS.y.to(r.top - sr.top + 29); ghostS.s.to(1); ghostS.r.to(0);
            flyBack = () => d.src.classList.remove('src');
          } else { ghostS.s.to(0.1); flyBack = () => render(); }
          status.textContent = 'Nothing moved.';
          FT.haptic('light'); FT.intent('released with no new home: photo flies back'); FT.announce('Nothing moved');
        }
        loop.wake();
      },
    }, { axis: 'both', slop: 6 });
    wrap.style.touchAction = '';

    /* ---------- keyboard: Move to… ---------- */
    let menu = null;
    const closeMenu = (refocus) => { if (!menu) return; const r = menu._ret; menu.remove(); menu = null; if (refocus && r && r.isConnected) r.focus(); };
    const allFolders = (id = 'root', depth = 0, out = []) => { out.push([id, depth]); F[id].kids.forEach(k => allFolders(k, depth + 1, out)); return out; };
    const openMenu = (pid, btn) => {
      closeMenu();
      menu = h('div', { class: 'dw-menu', role: 'menu', 'aria-label': `Move ${PH[pid].name} to` }, h('span', { class: 'ft-label' }, 'Move to…'));
      menu._ret = btn;
      for (const [id, depth] of allFolders()) {
        if (id === 'root') continue;
        const here = id === folderOf(pid);
        const it = h('button', { type: 'button', role: 'menuitem', 'aria-disabled': here ? 'true' : null, style: { paddingLeft: `${10 + (depth - 1) * 14}px`, color: here ? 'var(--faint)' : '' } }, F[id].name + (here ? ' · here' : ''));
        if (here) { menu.append(it); continue; }
        it.addEventListener('click', () => {
          const from = folderOf(pid);
          F[from].photos.splice(F[from].photos.indexOf(pid), 1); F[id].photos.push(pid);
          closeMenu(); render();
          const name = pathTo(id).map(k => F[k].name).join(' › ');
          status.innerHTML = `Moved <b>${PH[pid].name}</b> to ${name}`;
          FT.haptic('success'); FT.announce(`Moved ${PH[pid].name} to ${name}`);
          const first = grid.querySelector('.dw-item'); if (first) first.focus();
        });
        menu.append(it);
      }
      menu.addEventListener('keydown', e => {
        const items = [...menu.querySelectorAll('button:not([aria-disabled])')], i = items.indexOf(document.activeElement);
        if (e.key === 'ArrowDown') { e.preventDefault(); items[(i + 1) % items.length].focus(); }
        else if (e.key === 'ArrowUp') { e.preventDefault(); items[(i - 1 + items.length) % items.length].focus(); }
        else if (e.key === 'Escape') { e.preventDefault(); closeMenu(true); }
      });
      stage.append(menu);
      const sr = stage.getBoundingClientRect(), br = btn.getBoundingClientRect();
      menu.style.left = FT.clamp(br.left - sr.left, 10, sr.width - menu.offsetWidth - 10) + 'px';
      menu.style.top = FT.clamp(br.bottom - sr.top + 4, 10, sr.height - menu.offsetHeight - 10) + 'px';
      menu.querySelector('[role=menuitem]:not([aria-disabled])').focus();
    };
    stage.addEventListener('pointerdown', e => { if (menu && !menu.contains(e.target)) closeMenu(); }, true);

    render();
    status.textContent = 'Photos you drag can dive into folders.';
    return {
      reset() { closeMenu(); F = INIT(); cur = 'photos'; render(); status.textContent = 'Photos you drag can dive into folders.'; },
    };
  },
});
