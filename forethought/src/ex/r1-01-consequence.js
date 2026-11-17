/* I.1 Consequence button — press to preview, release to commit, slide away to cancel. */
FT.exhibit({
  id: 'consequence-button', room: 1, num: 1, kind: 'button', replaces: 'the confirm dialog',
  title: 'The button that shows its consequence',
  hint: 'Press and hold the button · slide off to cancel',
  height: 460,
  body: `<p>While your finger is down, the button shows exactly what it will do: the four old emails slide aside and the inbox count drops to its future value. Lift inside the button and it happens. Slide your finger away and everything springs back, nothing done.</p><p>Desktop buttons have always cancelled when you drag off them. Nobody could see that, so nobody used it. Here the escape route is visible.</p>`,
  why: `A dialog asks "are you sure?" after you've already decided. A preview answers "what exactly?" while you're still deciding, and it costs nothing extra: the press you were already making becomes the question.`,
  flutter: `
class ConsequenceButton extends StatefulWidget {
  const ConsequenceButton({super.key, required this.preview, required this.onCommit, required this.child});
  final ValueNotifier<bool> preview;      // the list listens and renders its future state
  final VoidCallback onCommit;
  final Widget child;
  @override State<ConsequenceButton> createState() => _State();
}

class _State extends State<ConsequenceButton> {
  bool inside = false;
  void _set(bool v) {
    if (inside == v) return;
    inside = v;
    widget.preview.value = v;             // future state, shown on a spring
    HapticFeedback.selectionClick();
  }
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerMove: (e) {
      final box = context.findRenderObject()! as RenderBox;
      _set((box.paintBounds.inflate(48)).contains(e.localPosition));   // 48 dp grace before cancelling
    },
    onPointerUp: (_) { if (inside) { HapticFeedback.mediumImpact(); widget.onCommit(); } _set(false); },
    onPointerCancel: (_) => _set(false),
    child: Semantics(button: true, hint: 'Shows the result while pressed', child: widget.child),
  );
}

// In the list: AnimatedSlide + AnimatedOpacity driven by preview, with
// Curves.easeOutBack swapped for a SpringSimulation in a custom AnimationController.`,
  a11y: `Tab to the button. Hold <b>Space</b> or <b>Enter</b> to preview, release to commit, press <b>Esc</b> while holding to cancel. The preview is announced ("Will archive 4 emails, inbox goes from 12 to 8") so a screen reader user gets the same foresight.`,
  mount(stage) {
    const { h } = FT;
    const MAILS = [
      ['Mira Kovač', 'Sunday hike: meet at 8?', '2 h', false],
      ['Lumen Bank', 'Your statement for September', '41 d', true],
      ['Tomo', 'Photos from the lake 📷', '5 h', false],
      ['Parcel desk', 'Delivered: order #22817', '63 d', true],
      ['Studio Kora', 'Invoice 204 is paid', '1 d', false],
      ['Newsletter', 'Ten ideas for autumn', '38 d', true],
      ['Airline', 'Your boarding pass (expired)', '90 d', true],
    ];
    const wrap = h('div', { style: { position: 'absolute', inset: '18px 18px 86px', display: 'flex', flexDirection: 'column' } });
    const head = h('div', { style: { display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', padding: '0 4px 8px' } },
      h('span', { style: { fontWeight: 600, fontSize: '15px' } }, 'Inbox'),
      h('span', { class: 'ft-mono ft-muted', style: { fontSize: '12px' } }));
    const countEl = head.lastChild;
    const list = h('div', { class: 'ft-card', style: { overflow: 'hidden', flex: '1', padding: '4px 0' } });
    wrap.append(head, list);
    const rows = MAILS.map(([from, subj, age, old]) => {
      const tag = h('span', { class: 'ft-label', style: { position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--accent)', opacity: 0 } }, '→ archive');
      const inner = h('div', { style: { display: 'grid', gridTemplateColumns: '1fr auto', gap: '2px 10px', padding: '7px 14px', background: 'var(--surface-2)', position: 'relative', willChange: 'transform' } },
        h('span', { style: { fontWeight: 600, fontSize: '13px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' } }, from),
        h('span', { class: 'ft-mono', style: { fontSize: '11px', color: old ? 'var(--amber)' : 'var(--muted)' } }, age),
        h('span', { style: { fontSize: '12.5px', color: 'var(--muted)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', gridColumn: '1 / -1' } }, subj));
      const row = h('div', { style: { position: 'relative', overflow: 'hidden', borderTop: '1px solid var(--line)' } }, tag, inner);
      list.append(row);
      return { row, inner, tag, old, p: FT.spring(0, FT.SPRING.smooth), c: FT.spring(0, FT.SPRING.smooth), hgt: 0 };
    });
    rows[0].row.style.borderTop = '0';
    const btn = h('button', { class: 'ft-btn', type: 'button', 'data-hit': '', style: { position: 'absolute', left: '50%', bottom: '22px', transform: 'translateX(-50%)', minWidth: '236px', height: '50px', fontSize: '15px', transition: 'background .2s, color .2s, box-shadow .2s' } });
    stage.append(wrap, btn);

    let archived = false, pressing = false, inside = false;
    const oldCount = rows.filter(r => r.old).length;
    const total = () => archived ? MAILS.length - oldCount : MAILS.length;
    const label = () => {
      if (!pressing) return archived ? `Restore ${oldCount} emails` : `Archive ${oldCount} old emails`;
      return inside ? 'Release to ' + (archived ? 'restore' : 'archive') : 'Release to cancel';
    };
    const paint = () => {
      btn.textContent = label();
      const preview = pressing && inside;
      btn.style.background = pressing ? (inside ? 'var(--accent)' : 'transparent') : 'var(--ink)';
      btn.style.color = pressing ? (inside ? 'var(--accent-ink)' : 'var(--ink)') : 'var(--bg)';
      btn.style.boxShadow = pressing && !inside ? 'inset 0 0 0 1.5px var(--line-2)' : preview ? '0 0 0 6px var(--accent-wash)' : 'none';
      const future = preview ? (archived ? MAILS.length : MAILS.length - oldCount) : total();
      countEl.innerHTML = preview ? `<s style="opacity:.5">${total()}</s> → <b style="color:var(--accent)">${future}</b> emails` : `${total()} emails`;
    };
    const loop = FT.loop(dt => {
      let moving = false;
      for (const r of rows) {
        if (!r.hgt) r.hgt = r.inner.offsetHeight + 1;
        moving = !r.p.step(dt) | moving; moving = !r.c.step(dt) | moving;
        r.inner.style.transform = `translateX(${r.p.x * 92}px)`;
        r.inner.style.opacity = String(1 - r.p.x * 0.45);
        r.tag.style.opacity = String(FT.clamp(r.p.x * 1.4, 0, 1));
        r.row.style.height = r.old ? `${Math.max(0, r.hgt * (1 - r.c.x))}px` : '';
        r.row.style.opacity = String(1 - r.c.x);
      }
      return moving;
    });
    const setPreview = on => {
      for (const r of rows) if (r.old) {
        if (!archived) r.p.to(on ? 1 : 0);
        else { r.c.to(on ? 0.4 : 1); r.p.to(0); }
      }
      loop.wake();
    };
    const commit = () => {
      archived = !archived;
      for (const r of rows) if (r.old) { r.p.to(0); r.c.to(archived ? 1 : 0); }
      loop.wake(); FT.haptic('medium');
      FT.intent(archived ? `committed: ${oldCount} emails archived` : `committed: ${oldCount} emails restored`);
      FT.announce(archived ? `Archived ${oldCount} emails. Inbox has ${total()}.` : `Restored ${oldCount} emails. Inbox has ${total()}.`);
    };
    const isInside = (e) => {
      const r = btn.getBoundingClientRect(), g = 48;
      return e.clientX > r.left - g && e.clientX < r.right + g && e.clientY > r.top - g && e.clientY < r.bottom + g;
    };
    FT.drag(btn, {
      start() { pressing = true; inside = true; setPreview(true); paint(); FT.haptic('light'); FT.intent('pressed: previewing the result'); FT.announce(`Will ${archived ? 'restore' : 'archive'} ${oldCount} emails`); },
      move(s, e) {
        const now = isInside(e);
        if (now !== inside) { inside = now; setPreview(now); paint(); FT.haptic('select'); FT.intent(now ? 'back inside: preview restored' : 'left the button: release will cancel'); }
      },
      end(s) {
        const ok = pressing && inside && !s.cancelled;
        pressing = false;
        if (ok) commit(); else { setPreview(false); FT.intent('released outside: nothing happened'); FT.announce('Cancelled'); }
        inside = false; paint();
      },
    }, { axis: 'both', slop: 4 });
    btn.addEventListener('keydown', e => {
      if ((e.key === ' ' || e.key === 'Enter') && !e.repeat && !pressing) { e.preventDefault(); pressing = true; inside = true; setPreview(true); paint(); FT.announce(`Will ${archived ? 'restore' : 'archive'} ${oldCount} emails, inbox goes from ${total()} to ${archived ? MAILS.length : MAILS.length - oldCount}. Release to confirm, Escape to cancel.`); }
      else if (e.key === 'Escape' && pressing) { e.preventDefault(); pressing = false; inside = false; setPreview(false); paint(); FT.announce('Cancelled'); }
      else if (e.key === ' ' || e.key === 'Enter') e.preventDefault();
    });
    btn.addEventListener('keyup', e => {
      if ((e.key === ' ' || e.key === 'Enter') && pressing) { e.preventDefault(); pressing = false; inside = false; commit(); paint(); }
    });
    btn.addEventListener('click', e => e.preventDefault());
    paint();
    return {
      reset() { archived = false; pressing = false; for (const r of rows) { r.p.set(0); r.c.set(0); } loop.wake(); paint(); },
    };
  },
});
